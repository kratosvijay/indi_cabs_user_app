import * as admin from "firebase-admin";

// Initialize without options, it should pick up FIREBASE_CONFIG locally
try {
  admin.initializeApp();
} catch (e) {
  admin.initializeApp({
    projectId: "projecttaxi-df0d2",
  });
}
const db = admin.firestore();

/**
 * Checks all geofenced zones.
 */
async function check() {
  const snapshot = await db.collection("geofenced_zones").get();
  console.log(`Found ${snapshot.size} zones.`);
  for (const doc of snapshot.docs) {
    const data = doc.data();
    console.log(
      `${doc.id}: type=${data.type}, surcharge=${data.surcharge_amount}`
    );
  }
}

check().catch(console.error).finally(() => process.exit(0));
