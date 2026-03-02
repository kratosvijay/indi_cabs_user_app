import * as admin from "firebase-admin";

// Initialize without options; will pick up local credentials
// or Firebase CLI login
try {
  admin.initializeApp();
} catch (e) {
  admin.initializeApp({
    projectId: "projecttaxi-df0d2",
  });
}
const db = admin.firestore();

/**
 * Deletes manual tolls from the database.
 */
async function deleteTolls() {
  console.log("Fetching geofenced_zones...");
  const snapshot = await db.collection("geofenced_zones").get();

  let deletedCount = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    // Assuming the tolls we added manually have a surcharge > 0
    // and no specific 'type' or type='toll'.
    // You listed tolls with surcharge=60 and 200 earlier.
    // We'll delete any zone with a surcharge.
    if (data.surcharge_amount && data.surcharge_amount > 0) {
      console.log(
        `Deleting toll zone: ${doc.id} (Surcharge: ` +
        `${data.surcharge_amount})`
      );
      await doc.ref.delete();
      deletedCount++;
    }
  }

  console.log(
    `\nSuccessfully deleted ${deletedCount} toll zones.`
  );
  console.log(
    "You can now rely entirely on Google Maps API for dynamic tolls!"
  );
}

deleteTolls().catch(console.error).finally(() => process.exit(0));
