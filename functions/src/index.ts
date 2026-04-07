/* eslint-disable @typescript-eslint/no-var-requires */
import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";

setGlobalOptions({region: "asia-south1"});
// **FIXED:** Re-added 'onDocumentUpdated' and added required types
import {
  onDocumentUpdated,
  FirestoreEvent,
  Change,
  DocumentSnapshot,
} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {defineString} from "firebase-functions/params";
import * as nodemailer from "nodemailer";
// **FIXED:** Removed Razorpay import
import {v4 as uuidv4} from "uuid";

const geminiApiKey = defineString("GEMINI_API_KEY");
const cashfreeAppId = defineString("CASHFREE_APP_ID");
const cashfreeSecretKey = defineString("CASHFREE_SECRET_KEY");
const exotelAccountSid = defineString("EXOTEL_ACCOUNT_SID");
const exotelApiKey = defineString("EXOTEL_API_KEY");
const exotelApiToken = defineString("EXOTEL_API_TOKEN");
// e.g., "api" or "api.exotel.com"
const exotelSubdomain = defineString("EXOTEL_SUBDOMAIN");
const exotelVirtualNumber = defineString("EXOTEL_VIRTUAL_NUMBER");

admin.initializeApp();
const db = admin.firestore();

// --- (Interfaces) ---
interface VehiclePricing {
  baseFare: number;
  minimumFare: number;
  perKilometer: number;
  perMinute?: number;
  description?: string;
}

interface PricingRules {
  city_name: string;
  currency_symbol: string;
  isSurgeActive: boolean;
  surgeMultiplier: number;
  vehicle_types: { [key: string]: VehiclePricing };
}

interface CalculateFaresData {
  distanceMeters: number;
  durationSeconds?: number;
  tollCost: number;
  pickupLocation: { latitude: number; longitude: number; };
  destinationLocation?: { latitude: number; longitude: number; };
  intermediateStops?: { location: { latitude: number; longitude: number; }; }[];
  routePolyline?: { latitude: number; longitude: number; }[];
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type RideData = any;

interface GeofencedZone {
  boundary: admin.firestore.GeoPoint[];
  surcharge_amount?: number;
}

interface ChatPart {
  text: string;
}
interface ChatHistory {
  role: "user" | "model";
  parts: ChatPart[];
}
interface ChatbotData {
  prompt: string;
  history: ChatHistory[];
}
interface EmailData {
  subject: string;
  body: string;
}

interface CreateOrderData {
  amount: number; // Amount in smallest currency unit (e.g., paise)
  currency: string; // e.g., "INR"
}

/* eslint-disable @typescript-eslint/naming-convention */
interface VerifyPaymentData {
  order_id: string; // Cashfree order ID
  amount?: number; // Optional verification amount
}
/* eslint-enable @typescript-eslint/naming-convention */


/**
 * Helper function to generate a random 4-digit PIN
 * @return {string} A 4-digit PIN.
 */
function generatePin(): string {
  return (Math.floor(1000 + Math.random() * 9000)).toString();
}

/**
 * Calculates fares based on distance, time, and rules from Firestore.
 * @param {CallableRequest<CalculateFaresData>} request The request object.
 * @return {Promise<any>}
 */
export const calculateFares = onCall(async (
  request: CallableRequest<CalculateFaresData>
) => {
  // 1. Check Auth
  if (!request.auth) {
    logger.warn("Unauthenticated user tried to call calculateFares.");
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }
  const {
    distanceMeters,
    tollCost,
    pickupLocation,
    destinationLocation,
    intermediateStops,
    routePolyline,
  } = request.data;
  if (!distanceMeters || !pickupLocation) {
    throw new HttpsError("invalid-argument", "Missing data.");
  }
  const distanceKm = distanceMeters / 1000.0;
  const safeTollCost = tollCost || 0;

  // 1. Gather all points to check for geofence surcharges
  const routePoints: admin.firestore.GeoPoint[] = [];
  routePoints.push(
    new admin.firestore.GeoPoint(
      pickupLocation.latitude,
      pickupLocation.longitude
    )
  );

  if (destinationLocation) {
    routePoints.push(
      new admin.firestore.GeoPoint(
        destinationLocation.latitude,
        destinationLocation.longitude
      )
    );
  }

  if (intermediateStops && Array.isArray(intermediateStops)) {
    for (const stop of intermediateStops) {
      if (
        stop.location &&
        typeof stop.location.latitude === "number" &&
        typeof stop.location.longitude === "number"
      ) {
        routePoints.push(
          new admin.firestore.GeoPoint(
            stop.location.latitude,
            stop.location.longitude
          )
        );
      }
    }
  }

  if (routePolyline && Array.isArray(routePolyline)) {
    for (const point of routePolyline) {
      if (
        typeof point.latitude === "number" &&
        typeof point.longitude === "number"
      ) {
        routePoints.push(
          new admin.firestore.GeoPoint(
            point.latitude,
            point.longitude
          )
        );
      }
    }
  }

  try {
    const rulesDoc = await db.collection("pricing_rules").doc("Chennai").get();
    if (!rulesDoc.exists) {
      throw new HttpsError("not-found", "Pricing rules not found.");
    }
    const rules = rulesDoc.data() as PricingRules;
    const vehiclePricingMap = rules.vehicle_types;
    const now = new Date();
    const timeZone = "Asia/Kolkata";
    const istFormatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timeZone,
      hour: "2-digit",
      hour12: false,
      weekday: "short",
    });
    const parts = istFormatter.formatToParts(now);
    let currentHour = 0;
    let currentDayString = "";
    for (const part of parts) {
      if (part.type === "hour") currentHour = parseInt(part.value) % 24;
      if (part.type === "weekday") currentDayString = part.value;
    }
    if (currentDayString === "") {
      throw new HttpsError(
        "internal", "Could not determine time zone data."
      );
    }

    // Default time-based logic override check
    // If database says isSurgeActive is true, use db multiplier.
    // Otherwise fallback to existing time-based logic.
    let surgeMultiplier = 1.0;
    if (rules.isSurgeActive && rules.surgeMultiplier) {
      surgeMultiplier = rules.surgeMultiplier;
    } else {
      // Fallback to time-based surge logic if not explicitly active in DB
      const isWeekend = currentDayString === "Sat" ||
        currentDayString === "Sun";
      if (isWeekend) {
        if (currentHour >= 15 && currentHour < 21) surgeMultiplier = 1.20;
      } else {
        const isMorningSurge = currentHour >= 8 && currentHour < 11;
        const isEveningSurge = currentHour >= 17 && currentHour < 21;
        if (isMorningSurge || isEveningSurge) surgeMultiplier = 1.20;
      }
    }

    let nightCharge = 0.0;
    if (currentHour >= 22 || currentHour < 6) {
      nightCharge = 30.0;
    }

    let geofenceSurcharge = 0.0;
    const zonesSnapshot = await db.collection("geofenced_zones").get();

    // Check all route points against all zones.
    // Apply the sum of all intersected surcharges.
    for (const doc of zonesSnapshot.docs) {
      const zone = doc.data() as GeofencedZone;
      if (zone.surcharge_amount && zone.surcharge_amount > 0 && zone.boundary) {
        let intersectsZone = false;
        for (const point of routePoints) {
          if (isPointInPolygon(point, zone.boundary)) {
            intersectsZone = true;
            break;
          }
        }

        if (intersectsZone) {
          geofenceSurcharge += zone.surcharge_amount;
          logger.info(
            `Found intersecting zone ${doc.id}, ` +
            `added surcharge ${zone.surcharge_amount}. ` +
            `Total is ${geofenceSurcharge}`
          );
        }
      }
    }
    const calculatedFares: { [key: string]: number } = {};
    Object.entries(vehiclePricingMap).forEach(([vehicleType, pricing]) => {
      let fare = pricing.baseFare;

      // 1. Distance Charge
      if (distanceKm <= 12) {
        fare += distanceKm * pricing.perKilometer;
      } else {
        // First 12 km at normal price
        fare += 12 * pricing.perKilometer;
        // Remaining km at reduced price (price - 2)
        const reducedRate = Math.max(0, pricing.perKilometer - 2);
        fare += (distanceKm - 12) * reducedRate;
      }

      // 2. Time Charge (new)
      if (pricing.perMinute && request.data.durationSeconds) {
        const durationMinutes = request.data.durationSeconds / 60.0;
        fare += (durationMinutes * pricing.perMinute);
      }

      // 3. Surge
      fare *= surgeMultiplier;

      // 4. Minimum Fare (Apply minimum to Base + Distance + Time + Surge)
      if (fare < pricing.minimumFare) fare = pricing.minimumFare;

      // 5. Extras (Night, Toll, Geofence) - ADDED ON TOP OF MINIMUM FARE
      fare += nightCharge + safeTollCost + geofenceSurcharge;

      calculatedFares[vehicleType] = Math.round(fare);
    });
    const result = {
      fares: calculatedFares,
      appliedSurcharge: geofenceSurcharge,
      appliedToll: safeTollCost,
    };
    // **FIXED:** max-len and operator-linebreak
    const logMessage = `Fares for ${distanceKm}km ` +
      `(Day: ${currentDayString}, Hour: ${currentHour}):`;
    logger.info(logMessage, result);
    return result;
  } catch (error) {
    logger.error("Error calculating fares:", error);
    throw new HttpsError(
      "internal", "Error calculating fare."
    );
  }
});


/**
 * Creates a ride/rental request with a sequential ID and safety PINs.
 * @param {CallableRequest<RideData>} request The request object.
 * @return {Promise<{rideId: string}>}
 */
export const createRideRequest = onCall(async (
  request: CallableRequest<RideData>
) => {
  // Debug Logging
  logger.info(
    "createRideRequest called. Auth: " + JSON.stringify(request.auth) +
    ", AppCheck: " + JSON.stringify(request.app)
  );

  // Log header presence to debug UNAUTHENTICATED error
  const authHeader = request.rawRequest.headers.authorization;
  logger.info(
    `Auth Header: ${authHeader ?
      "Present (" + authHeader.substring(0, 20) + "...)" :
      "Missing"
    }`
  );

  if (!request.auth) {
    logger.warn(
      "createRideRequest: Unauthorized access attempt (request.auth is null)"
    );
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }
  const userId = request.auth.uid;
  // **FIXED:** @typescript-eslint/no-explicit-any
  // Removed redundant 'as any' since RideData is already 'any'
  const rideData = request.data;
  if (!rideData) {
    throw new HttpsError("invalid-argument", "Missing ride data.");
  }

  const counterRef = db.collection("counters").doc("ride_counter");

  let newRideIdString = ""; // **FIXED:** Initialize here

  const isRental = rideData.rideType === "rental";
  const collectionPath = isRental ? "rental_requests" : "ride_requests";

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const firestoreData: any = {
    ...rideData,
    pickupLocation: new admin.firestore.GeoPoint(
      rideData.pickupLocation.latitude,
      rideData.pickupLocation.longitude
    ),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "searching", // **ALWAYS** start as 'searching'
  };

  if (rideData.destinationLocation) {
    firestoreData.destinationLocation = new admin.firestore.GeoPoint(
      rideData.destinationLocation.latitude,
      rideData.destinationLocation.longitude
    );
  }

  // **FIXED:** Convert intermediate stops to use GeoPoints
  if (rideData.intermediateStops && Array.isArray(rideData.intermediateStops)) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    firestoreData.intermediateStops = rideData.intermediateStops.map(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (stop: any) => {
        // Ensure we have a location object with lat/lng
        if (
          stop.location &&
          typeof stop.location.latitude === "number" &&
          typeof stop.location.longitude === "number"
        ) {
          return {
            ...stop,
            location: new admin.firestore.GeoPoint(
              stop.location.latitude,
              stop.location.longitude
            ),
          };
        }
        return stop;
      }
    );
  }

  if (isRental || rideData.vehicleClass === "ActingDriver") {
    const startRidePin = generatePin();
    let endRidePin = generatePin();
    while (endRidePin === startRidePin) {
      endRidePin = generatePin();
    }
    firestoreData.startRidePin = startRidePin;
    firestoreData.endRidePin = endRidePin;
  } else {
    // Daily/Multi-Stop rides
    firestoreData.safetyPin = generatePin();
  }

  // 1. Run the transaction to create the ride & update counter
  try {
    await db.runTransaction(
      async (transaction: admin.firestore.Transaction) => {
        const counterDoc = await transaction.get(counterRef);
        let newCount = 1;
        if (counterDoc.exists) {
          const data = counterDoc.data();
          newCount = (data?.current_id || 0) + 1;
        } else {
          logger.info("ride_counter document missing, initializing with 1");
        }

        newRideIdString = "ID" + newCount.toString().padStart(15, "0");

        // Ensure newRideIdString was actually generated
        if (!newRideIdString || newRideIdString === "ID000000000000000") {
          throw new Error("Failed to generate a valid sequential Ride ID.");
        }

        const newRideDocRef = db.collection(collectionPath)
          .doc(newRideIdString);

        // Final security/sanity check before write
        if (rideData.userId !== userId) {
          logger.error(`Security Mismatch: App userId (${rideData.userId}) ` +
            `!= Auth userId (${userId})`);
          throw new Error("User ID mismatch security violation.");
        }

        transaction.set(newRideDocRef, firestoreData);
        transaction.set(counterRef, {current_id: newCount}, {merge: true});

        logger.info(`Transaction success: Created ride ${newRideIdString} ` +
          `for user ${userId}`);
      });
  } catch (error) {
    logger.error(`Error creating ride doc for user ${userId}:`, error);
    throw new HttpsError(
      "internal",
      "Failed to create ride document."
    );
  }

  // **FIXED:** Create the docRef *after* the transaction,
  // once newRideIdString is guaranteed to be set.
  const newRideDocRef = db.collection(collectionPath).doc(newRideIdString);

  // 2. NOW, find a driver (outside the transaction)
  try {
    let driversQuery: admin.firestore.Query = db.collection("drivers")
      .where("isOnline", "==", true)
      .where("isAvailable", "==", true);

    if (rideData.vehicleClass === "ActingDriver") {
      driversQuery = driversQuery.where("isActingDriver", "==", true);
    } else {
      // **FIXED:** Filter by 'vehicleClass' for both Daily and Rental
      driversQuery = driversQuery.where(
        "vehicleClass", "==", rideData.vehicleClass
      );
    }

    const availableDrivers = await driversQuery.limit(5).get();
    logger.info(`DriverSearch: Found ${availableDrivers.size} ` +
      "online/available drivers matching vehicleClass " +
      rideData.vehicleClass);

    // If no specific vehicle match, check why (Diagnostic Log)
    if (availableDrivers.empty) {
      const allOnline = await db.collection("drivers")
        .where("isOnline", "==", true)
        .where("isAvailable", "==", true)
        .limit(1).get();
      logger.warn(`DriverSearch: No match for ${rideData.vehicleClass}. ` +
        `General online drivers available: ${!allOnline.empty}`);
    }

    // 3. If a driver is found, assign them.
    if (!availableDrivers.empty) {
      const driverToAssign = availableDrivers.docs[0];
      const driver = driverToAssign.data();

      // This update will trigger onRideRequestUpdated
      await newRideDocRef.update({
        status: "accepted",
        driverId: driverToAssign.id,
        driverName: driver.displayName || "N/A",
        driverPhone: driver.phoneNumber || "N/A",
        driverPhotoUrl: driver.photoUrl || "",
        carModel: driver.carName || "N/A",
        carNumber: driver.vehicleNumber || "N/A",
      });

      // Mark driver as unavailable
      await driverToAssign.ref.update({
        isAvailable: false,
        assignedRideId: newRideIdString,
      });
    } else {
      logger.warn(`No drivers found for ride ${newRideIdString}.`);
    }
  } catch (error) {
    logger.error(`Error assigning driver for ride ${newRideIdString}:`, error);
  }

  // 4. Return the Ride ID
  logger.info(`Created ride ${newRideIdString} for user ${userId}`);
  return {
    rideId: newRideIdString,
  };
});

// **--- NEW EMAIL FUNCTION ---**

// **SUPPORT EMAIL FUNCTION (MODIFIED FOR TICKETING)**
export const sendSupportEmail = onCall(async (
  request: CallableRequest<EmailData>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }

  const uid = request.auth.uid;
  const userEmail = request.auth.token.email || "No email provided";
  const {subject, body} = request.data;

  if (!subject || !body) {
    throw new HttpsError("invalid-argument", "Missing subject or body.");
  }

  const appEmail = process.env.GMAIL_EMAIL;
  const appPassword = process.env.GMAIL_APP_PASSWORD;

  if (!appEmail || !appPassword) {
    logger.error("SUPPORT EMAIL ERROR: Credentials missing.");
    throw new HttpsError("internal", "Server configuration error.");
  }

  // Generate Ticket Info
  const ticketId = uuidv4().substring(0, 8).toUpperCase();
  const secretToken = uuidv4();

  // Get User's FCM Token for notifications
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const fcmToken = userDoc.data()?.fcmToken || null;

  const ticketData = {
    userId: uid,
    userEmail: userEmail,
    userName: userDoc.data()?.displayName || "IndiCabs User",
    subject: subject,
    status: "open",
    secretToken: secretToken,
    fcmToken: fcmToken,
    admins: [] as string[], // **NEW:** List of authorized admin UIDs
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const ticketRef = admin.firestore()
    .collection("support_tickets").doc(ticketId);

  try {
    // 1. Create the Ticket in Firestore
    await ticketRef.set(ticketData);

    // 2. Add the Initial Message
    await ticketRef.collection("messages").add({
      sender: "user",
      text: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    const adminLink = `https://indicabs-prod.web.app/admin/ticket.html?id=${ticketId}&token=${secretToken}`;

    const transporter = nodemailer.createTransport({
      host: "smtp.hostinger.com",
      port: 465,
      secure: true,
      auth: {user: appEmail, pass: appPassword},
    });

    const mailOptions = {
      from: `"Support System (Ticket: ${ticketId})" <${appEmail}>`,
      to: "support@indicabs.net",
      replyTo: userEmail,
      subject: `[TICKET: ${ticketId}] ${subject}`,
      text: "A new support ticket has been opened.\n\n" +
            `Ticket ID: ${ticketId}\n` +
            `User ID: ${uid}\n` +
            `User Email: ${userEmail}\n\n` +
            `Message:\n${body}\n\n` +
            `REPLY TO THIS TICKET SECURELY:\n${adminLink}`,
      html: `<h3>New Support Ticket: ${ticketId}</h3>` +
            `<p><b>User:</b> ${userEmail}</p>` +
            `<p><b>Subject:</b> ${subject}</p>` +
            `<p><b>Message:</b><br>${body.replace(/\n/g, "<br>")}</p>` +
            "<br><br>" +
            `<a href="${adminLink}" style="background-color: #007bff; ` +
            "color: white; padding: 10px 20px; text-decoration: none; " +
            "border-radius: 5px;\">Reply to Ticket</a>",
    };

    await transporter.sendMail(mailOptions);
    logger.info(`Ticket ${ticketId} created and email sent.`);
    return {success: true, ticketId: ticketId};
  } catch (error) {
    logger.error("Error creating ticket/sending email:", error);
    throw new HttpsError("internal", "Failed to process support request.");
  }
});

// **--- ADMIN TICKET PORTAL LOGIC ---**

/**
 * Handles admin replies via the web interface.
 * This is an HTTPS function that will be called by the web portal.
 */
export const addAdminReply = onCall(async (request) => {
  const {ticketId, token, masterToken, message} = request.data;
  const MASTER_KEY = "indi_cabs_admin_master_2026_q2_az9x2";

  if (!ticketId || !message) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const ticketRef = admin.firestore()
    .collection("support_tickets").doc(ticketId);
  const ticketDoc = await ticketRef.get();

  const isMaster = masterToken === MASTER_KEY;
  const isInvalidToken = !isMaster && ticketDoc.data()?.secretToken !== token;
  if (!ticketDoc.exists || isInvalidToken) {
    throw new HttpsError("permission-denied", "Invalid ticket ID or token.");
  }

  try {
    // 1. Add Message
    await ticketRef.collection("messages").add({
      sender: "admin",
      text: message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Update Ticket (and refresh FCM token for future use)
    const userId = ticketDoc.data()?.userId;
    let freshToken = ticketDoc.data()?.fcmToken || null;
    if (userId) {
      const userDoc = await admin.firestore()
        .collection("users").doc(userId).get();
      freshToken = userDoc.data()?.fcmToken || freshToken;
    }
    await ticketRef.update({
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(freshToken ? {fcmToken: freshToken} : {}),
    });

    // 3. Send Push Notification to User (Non-blocking)
    // Try the token saved on the ticket first, then fall back to the
    // most recent token from the user's profile for freshness.
    let fcmToken = ticketDoc.data()?.fcmToken;
    if (!fcmToken) {
      const userId = ticketDoc.data()?.userId;
      if (userId) {
        const userDoc = await admin.firestore()
          .collection("users").doc(userId).get();
        fcmToken = userDoc.data()?.fcmToken || null;
      }
    }

    if (fcmToken) {
      try {
        const payload = {
          token: fcmToken,
          notification: {
            title: "💬 Support Reply",
            body: message.length > 60 ?
              message.substring(0, 60) + "..." : message,
          },
          data: {
            ticketId: ticketId,
            type: "support_reply",
          },
          android: {
            // Route to our pre-created high importance channel
            notification: {
              channelId: "high_importance_channel",
              priority: "high" as const,
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };
        await admin.messaging().send(payload);
        logger.info(`FCM sent to user for ticket ${ticketId}`);
      } catch (fcmError) {
        logger.error(`FCM Failed for ticket ${ticketId}:`, fcmError);
        // We continue anyway so the message storage isn't blocked
      }
    } else {
      logger.warn(`No FCM token found for ticket ${ticketId}`);
    }

    return {success: true};
  } catch (error) {
    logger.error("Error adding admin reply:", error);
    throw new HttpsError("internal", "Failed to add reply.");
  }
});

/**
 * Fetches ticket details and messages for the admin portal.
 * Restricted by ticketId and secretToken.
 */
export const getTicketDetails = onCall(async (request) => {
  const {ticketId, token, masterToken} = request.data;
  const MASTER_KEY = "indi_cabs_admin_master_2026_q2_az9x2";

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "Missing ticketId.");
  }

  const ticketRef = admin.firestore()
    .collection("support_tickets").doc(ticketId);
  const ticketDoc = await ticketRef.get();

  const isMaster = masterToken === MASTER_KEY;
  const isInvalidToken = !isMaster && ticketDoc.data()?.secretToken !== token;
  if (!ticketDoc.exists || isInvalidToken) {
    throw new HttpsError("permission-denied", "Invalid ticket ID or token.");
  }

  try {
    const messagesSnapshot = await ticketRef.collection("messages")
      .orderBy("timestamp", "asc").get();

    const messages = messagesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      ticket: {
        id: ticketDoc.id,
        ...ticketDoc.data(),
      },
      messages: messages,
    };
  } catch (error) {
    logger.error("Error fetching ticket details:", error);
    throw new HttpsError("internal", "Failed to retrieve ticket info.");
  }
});

/**
 * Closes a ticket from the admin portal.
 */
export const closeTicket = onCall(async (request) => {
  const {ticketId, token, masterToken} = request.data;
  const MASTER_KEY = "indi_cabs_admin_master_2026_q2_az9x2";

  if (!ticketId) {
    throw new HttpsError("invalid-argument", "Missing ticketId.");
  }

  const ticketRef = admin.firestore()
    .collection("support_tickets").doc(ticketId);
  const ticketDoc = await ticketRef.get();

  const isMaster = masterToken === MASTER_KEY;
  const isInvalidToken = !isMaster && ticketDoc.data()?.secretToken !== token;
  if (!ticketDoc.exists || isInvalidToken) {
    throw new HttpsError("permission-denied", "Invalid ticket ID or token.");
  }

  try {
    await ticketRef.update({status: "closed"});
    return {success: true};
  } catch (error) {
    logger.error("Error closing ticket:", error);
    throw new HttpsError("internal", "Failed to close ticket.");
  }
});

/**
 * Retrieves a list of all support tickets for the admin dashboard.
 * Supports both master token and admin auth.
 */
export const getAdminTicketsList = onCall(async (request) => {
  const {masterToken} = request.data;
  // This is the master key for the owner's immediate access without an account
  const MASTER_KEY = "indi_cabs_admin_master_2026_q2_az9x2";

  let isAuthorized = false;

  // 1. Check Master Token
  if (masterToken === MASTER_KEY) {
    isAuthorized = true;
  }

  // 2. Check Firebase Auth + Admin Role (Future)
  if (!isAuthorized && request.auth) {
    const adminDoc = await admin.firestore()
      .collection("admins").doc(request.auth.uid).get();
    if (adminDoc.exists) {
      isAuthorized = true;
    }
  }

  if (!isAuthorized) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  try {
    const snapshot = await admin.firestore()
      .collection("support_tickets")
      .orderBy("lastMessageAt", "desc")
      .get();

    const tickets = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {success: true, tickets};
  } catch (error) {
    logger.error("Error fetching admin tickets:", error);
    throw new HttpsError("internal", "Failed to retrieve tickets.");
  }
});

// **--- NEW CHATBOT FUNCTION ---**

/**
 * Gets a response from the Gemini API.
 * @param {CallableRequest<ChatbotData>} request The request object.
 * @return {Promise<{response: string}>} Promise that resolves with response.
 */
export const getChatbotResponse = onCall(async (
  request: CallableRequest<ChatbotData>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }

  const prompt = request.data.prompt;
  const history = request.data.history || [];

  if (!prompt) {
    throw new HttpsError("invalid-argument", "Missing 'prompt'.");
  }

  const apiKey = geminiApiKey.value();

  const model = "gemini-2.5-flash-preview-09-2025";
  const apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/" +
    `${model}:generateContent?key=${apiKey}`;

  const systemInstruction = {
    role: "model",
    parts: [{
      text: "You are a friendly and helpful support agent for a " +
        "taxi app. Be concise. Do not answer questions " +
        "unrelated to the taxi service.",
    }],
  };

  const contents = [
    systemInstruction,
    ...history,
    {
      role: "user",
      parts: [{text: prompt}],
    },
  ];

  try {
    const response = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({contents}),
    });

    if (!response.ok) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const errorData = await response.json() as any;
      logger.error("Gemini API Error:", errorData);
      throw new HttpsError(
        "internal", "Failed to get response from AI."
      );
    }

    const data = await response.json();
    const botResponse = data.candidates?.[0]?.content?.parts?.[0]?.text ||
      "Sorry, I couldn't process that. Please try again.";

    return {response: botResponse};
  } catch (error) {
    logger.error("Error calling Gemini API:", error);
    throw new HttpsError(
      "internal", "An error occurred while contacting support."
    );
  }
});


// **--- NEW CASHFREE FUNCTIONS ---**

/**
 * Creates a Cashfree Order on the server.
 * @param {CallableRequest<CreateOrderData>} request The request object.
 * @return {Promise<{orderId: string, paymentSessionId: string,
 * paymentDocId: string}>}
 */
export const createWalletOrder = onCall(async (
  request: CallableRequest<CreateOrderData>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }
  const uid = request.auth.uid;
  const {amount, currency} = request.data; // Amount in paise
  if (!amount || !currency || amount <= 0) {
    throw new HttpsError("invalid-argument", "Missing 'amount' or 'currency'.");
  }

  const amountInRupees = amount / 100.0;
  // Get phone number from auth or provide fallback
  const userPhone = request.auth.token.phone_number || "9999999999";

  try {
    // 1. Create a "pending" payment document in Firestore
    const paymentHistoryRef = db.collection("users").doc(uid)
      .collection("payment_history").doc(); // Create new doc ref

    await paymentHistoryRef.set({
      amount: amountInRupees,
      status: "PENDING", // Status is pending
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      type: "credit",
      userId: uid,
    });
    const paymentDocId = paymentHistoryRef.id;

    // 2. Create Cashfree order
    let appId: string;
    let secretKey: string;

    try {
      // **FIXED:** max-len
      appId = cashfreeAppId.value() ||
        "122159383830534a2818b3e83373951221";
      secretKey = cashfreeSecretKey.value() ||
        "cfsk_ma_prod_dbc842b88cfc4660f817dc4186d5a380_c19d4e45";
    } catch {
      appId = "122159383830534a2818b3e83373951221";
      secretKey =
        "cfsk_ma_prod_dbc842b88cfc4660f817dc4186d5a380_c19d4e45";
    }

    const url = "https://api.cashfree.com/pg/orders";

    const body = {
      order_amount: amountInRupees,
      order_currency: "INR",
      order_id: paymentDocId,
      customer_details: {
        customer_id: uid,
        customer_phone: userPhone,
      },
      order_meta: {
        return_url: "https://indicabs.in/payment-success?order_id={order_id}",
      },
    };

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "x-client-id": appId,
        "x-client-secret": secretKey,
        "x-api-version": "2023-08-01",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const err = await response.text();
      logger.error("Cashfree order error: " + err);
      throw new Error("Failed to create Cashfree order");
    }

    const data = await response.json();

    // 3. Update the pending payment doc with the Cashfree Order details
    await paymentHistoryRef.update({
      cashfreeOrderId: paymentDocId,
      paymentSessionId: data.payment_session_id,
    });

    logger.info(`Created Cashfree order ${paymentDocId} for user ${uid}`);
    return {
      orderId: paymentDocId, // Using paymentDocId as the global orderId in DB
      paymentSessionId: data.payment_session_id,
      paymentDocId: paymentDocId,
    };
  } catch (error) {
    logger.error("Error creating Cashfree order:", error);
    throw new HttpsError("internal", "Failed to create Cashfree order.");
  }
});

/**
 * Verifies a Cashfree payment and updates the user's wallet.
 * This is transactional.
 * @param {CallableRequest<VerifyPaymentData>} request The request object.
 * @return {Promise<{success: boolean, newBalance: number}>}
 */
/* eslint-disable camelcase */
export const verifyWalletPayment = onCall(async (
  request: CallableRequest<VerifyPaymentData>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }

  const uid = request.auth.uid;
  const {
    order_id,
  } = request.data;

  if (!order_id) {
    throw new HttpsError("invalid-argument", "Missing order_id.");
  }

  // 1. Fetch order status from Cashfree API
  let appId: string;
  let secretKey: string;

  try {
    // **FIXED:** max-len
    appId = cashfreeAppId.value() ||
      "122159383830534a2818b3e83373951221";
    secretKey = cashfreeSecretKey.value() ||
      "cfsk_ma_prod_dbc842b88cfc4660f817dc4186d5a380_c19d4e45";
  } catch {
    appId = "122159383830534a2818b3e83373951221";
    secretKey = "cfsk_ma_prod_dbc842b88cfc4660f817dc4186d5a380_c19d4e45";
  }

  const url = `https://api.cashfree.com/pg/orders/${order_id}`;

  try {
    const response = await fetch(url, {
      headers: {
        "x-client-id": appId,
        "x-client-secret": secretKey,
        "x-api-version": "2023-08-01",
      },
    });

    if (!response.ok) {
      throw new Error("Failed to fetch order status from Cashfree");
    }

    const orderData = await response.json();
    if (orderData.order_status !== "PAID") {
      throw new HttpsError("failed-precondition", "Order not paid yet.");
    }

    // 2. Status is PAID, find the pending payment document
    // order_id is exactly the paymentDocId we used
    const paymentDocRef = db.collection("users").doc(uid)
      .collection("payment_history").doc(order_id);

    // 3. Run Transaction to update wallet and payment status
    const userWalletRef = db.collection("users").doc(uid);

    let newBalance = 0;
    let amountToCredit = 0;

    await db.runTransaction(
      async (transaction: admin.firestore.Transaction) => {
        const paymentDoc = await transaction.get(paymentDocRef);
        if (!paymentDoc.exists) {
          throw new Error("Payment document not found.");
        }
        if (paymentDoc.data()?.status === "successful") {
          throw new Error("Payment has already been processed.");
        }

        amountToCredit = paymentDoc.data()?.amount; // Amount in Rupees

        const userDoc = await transaction.get(userWalletRef);
        if (!userDoc.exists) {
          throw new Error("User document not found.");
        }

        const currentBalance = userDoc.data()?.wallet_balance || 0;
        newBalance = currentBalance + amountToCredit;

        transaction.update(userWalletRef, {
          wallet_balance: newBalance,
        });

        transaction.update(paymentDocRef, {
          status: "successful",
          cfPaymentId: orderData.order_id,
        });
      });

    logger.info(
      `User ${uid} added ${amountToCredit} to wallet. New: ${newBalance}`
    );
    return {success: true, newBalance: newBalance};
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } catch (error: any) {
    logger.error(`Error verifying payment for user ${uid}:`, error.message);
    throw new HttpsError(
      "internal", error.message || "Failed to update wallet."
    );
  }
});
/* eslint-enable camelcase */


// **--- NEW: NOTIFICATION TRIGGER ---**
/**
 * Triggers when a ride_request is updated.
 * Used to send a notification when a driver accepts the ride.
 * @param {FirestoreEvent<Change<DocumentSnapshot>>} event The Firestore event.
 * @return {Promise<void>} A promise that resolves when operations are complete.
 */
export const onRideRequestUpdated = onDocumentUpdated(
  "ride_requests/{rideId}",
  async (event: FirestoreEvent<Change<DocumentSnapshot> | undefined>) => {
    if (!event.data) {
      logger.warn("No event data found for onRideRequestUpdated.");
      return;
    }
    const dataBefore = event.data.before.data();
    const dataAfter = event.data.after.data();

    if (!dataBefore || !dataAfter) {
      logger.warn("Missing data before or after update.");
      return;
    }

    if (
      dataBefore.status === "searching" &&
      dataAfter.status === "accepted" &&
      dataAfter.driverId
    ) {
      const userId = dataAfter.userId;
      const driverId = dataAfter.driverId;
      const rideId = event.data.after.id;

      try {
        // 1. Get the User's FCM Token
        const userDoc = await db.collection("users").doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (!fcmToken) {
          // **FIXED:** max-len
          const warnMsg =
            `User ${userId} has no FCM token.Cannot send notification.`;
          logger.warn(warnMsg);
          // Don't stop, still try to save to history
        }

        // 2. Get the Driver's details
        const driverDoc = await db.collection("drivers").doc(driverId).get();
        const driverName = driverDoc.data()?.displayName || "Your driver";
        const carNumber = driverDoc.data()?.vehicleNumber || "";

        // 3. Build the notification content
        const notificationTitle = "Your ride is on the way!";
        const notificationBody =
          `${driverName} (${carNumber}) is arriving soon.`;

        // 4. Build the payload for the push notification
        const payload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            rideId: rideId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        // 5. Build the data to save to Firestore notification history
        const notificationData = {
          title: notificationTitle,
          body: notificationBody,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: {
            rideId: rideId,
          },
        };

        // 6. Send the push notification (if token exists)
        if (fcmToken) {
          logger.info(`Sending ride notification to user ${userId} `);
          await admin.messaging().sendToDevice(fcmToken, payload);
        }

        // 7. **NEW:** Save the notification to the user's subcollection
        await db.collection("users").doc(userId)
          .collection("notifications").add(notificationData);
      } catch (error) {
        logger.error(
          `Failed to send notification for ride ${rideId}`,
          error
        );
      }
    }
  });


// --- Helper Functions ---
/**
 * Helper function: Point-in-Polygon check.
 * @param {admin.firestore.GeoPoint} point The point to check.
 * @param {admin.firestore.GeoPoint[]} polygon The polygon boundaries.
 * @return {boolean} True if the point is inside, false otherwise.
 */
function isPointInPolygon(
  point: admin.firestore.GeoPoint,
  polygon: admin.firestore.GeoPoint[]
): boolean {
  if (polygon.length === 0) return false;
  let intersectCount = 0;
  for (let j = 0; j < polygon.length - 1; j++) {
    if (_rayCastIntersect(point, polygon[j], polygon[j + 1])) {
      intersectCount++;
    }
  }
  if (_rayCastIntersect(point, polygon[polygon.length - 1], polygon[0])) {
    intersectCount++;
  }
  return intersectCount % 2 === 1;
}

/**
 * Ray casting helper for isPointInPolygon.
 * @param {admin.firestore.GeoPoint} point The point to check.
 * @param {admin.firestore.GeoPoint} vertA The first vertex of the segment.
 * @param {admin.firestore.GeoPoint} vertB The second vertex of the segment.
 *IA
 * @return {boolean} True if the ray intersects the segment.
 */
function _rayCastIntersect(
  point: admin.firestore.GeoPoint,
  vertA: admin.firestore.GeoPoint,
  vertB: admin.firestore.GeoPoint
): boolean {
  const aY = vertA.latitude;
  const bY = vertB.latitude;
  const aX = vertA.longitude;
  const bX = vertB.longitude;
  const pY = point.latitude;
  const pX = point.longitude;

  if ((aY > pY && bY > pY) || (aY < pY && bY < pY)) {
    return false;
  }
  if (aX < pX && bX < pX) {
    return false;
  }
  if (aX > pX && bX > pX) {
    return true;
  }
  if (aX === bX) {
    return pX <= aX;
  }
  const numerator = (pY - aY) * (bX - aX);
  const denominator = bY - aY;
  const intersectX = (numerator / denominator) + aX;
  return intersectX >= pX;
}

// **--- NEW EXOTEL CALL MASKING FUNCTION ---**

interface MaskedCallData {
  rideId: string;
}

/**
 * Initiates a masked call between user and driver using Exotel.
 * @param {CallableRequest<MaskedCallData>} request The request object.
 * @return {Promise<{success: boolean, message: string}>}
 */
export const bridgeCall = onCall(async (
  request: CallableRequest<MaskedCallData>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }
  const userId = request.auth.uid;
  const {rideId} = request.data;

  if (!rideId) {
    throw new HttpsError("invalid-argument", "Missing 'rideId'.");
  }

  try {
    // 1. Fetch Ride Details
    const rideDoc = await db.collection("ride_requests").doc(rideId).get();
    // Check rental requests if not found in ride_requests
    let rideData = rideDoc.data();
    if (!rideDoc.exists) {
      const rentalDoc = await db.collection("rental_requests")
        .doc(rideId).get();
      if (!rentalDoc.exists) {
        throw new HttpsError("not-found", "Ride not found.");
      }
      rideData = rentalDoc.data();
    }

    if (!rideData) {
      throw new HttpsError("not-found", "Ride data is empty.");
    }

    // 2. Get Phone Numbers
    // User's phone number (Caller)
    const userDoc = await db.collection("users").doc(userId).get();
    const userPhone = userDoc.data()?.phoneNumber;

    // Driver's phone number (Callee)
    const driverId = rideData.driverId;
    if (!driverId) {
      throw new HttpsError("failed-precondition", "No driver assigned.");
    }
    const driverDoc = await db.collection("drivers").doc(driverId).get();
    const driverPhone = driverDoc.data()?.phoneNumber;

    if (!userPhone || !driverPhone) {
      throw new HttpsError(
        "failed-precondition", "Missing phone numbers for call."
      );
    }

    // 3. Prepare Exotel Request
    const accountSid = exotelAccountSid.value();
    const apiKey = exotelApiKey.value();
    const apiToken = exotelApiToken.value();
    const subdomain = exotelSubdomain.value() || "api";
    const virtualNumber = exotelVirtualNumber.value();

    const domain = subdomain.includes(".exotel.com") ?
      subdomain :
      `${subdomain}.exotel.com`;
    const url = `https://${domain}/v1/Accounts/${accountSid}/Calls/connect.json`;

    // Form Data
    const formData = new URLSearchParams();
    formData.append("From", userPhone);
    formData.append("To", driverPhone);
    formData.append("CallerId", virtualNumber);
    formData.append("Record", "true"); // Optional: Record the call

    // 4. Make the API Call
    const authHeader = "Basic " +
      Buffer.from(`${apiKey}:${apiToken}`).toString("base64");

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": authHeader,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: formData,
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Exotel API Error:", errorText);
      throw new HttpsError("internal", "Failed to initiate call via Exotel.");
    }

    const responseData = await response.json();
    logger.info("Exotel Call Initiated:", responseData);

    return {success: true, message: "Call initiated successfully."};
  } catch (error) {
    logger.error("Error initiating masked call:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to initiate call.");
  }
});

/**
 * Creates a synced metro booking in ride history using the shared counter.
 * @param {CallableRequest<any>} request The request object.
 * @return {Promise<{rideId: string}>}
 */
export const createMetroBooking = onCall(async (
  request: CallableRequest<Record<string, unknown>>
) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated.");
  }
  const userId = request.auth.uid;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = request.data as any;

  const counterRef = db.collection("counters").doc("ride_counter");
  let newRideIdString = "";

  try {
    await db.runTransaction(async (transaction) => {
      const counterDoc = await transaction.get(counterRef);
      let newCount = 1;
      if (counterDoc.exists) {
        newCount = (counterDoc.data()?.current_id || 0) + 1;
      }
      newRideIdString = "ID" + newCount.toString().padStart(15, "0");

      const metroDocRef = db.collection("metro_bookings").doc(newRideIdString);

      const firestoreData = {
        userId: userId,
        orderId: data.orderId,
        transactionId: data.transactionId,
        status: data.status || "confirmed",
        pickupAddress: data.sourceStation,
        pickupLocation: new admin.firestore.GeoPoint(
          data.sourceLocation.latitude,
          data.sourceLocation.longitude
        ),
        destinationAddress: data.destStation,
        destinationLocation: new admin.firestore.GeoPoint(
          data.destLocation.latitude,
          data.destLocation.longitude
        ),
        totalFare: data.totalFare,
        qrCodeData: data.qrCodeData,
        rideType: "Metro",
        ticketType: data.ticketType,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.set(metroDocRef, firestoreData);
      transaction.set(counterRef, {current_id: newCount}, {merge: true});
    });

    return {rideId: newRideIdString};
  } catch (error) {
    logger.error("Error creating synced metro booking:", error);
    throw new HttpsError("internal", "Failed to save metro booking.");
  }
});
