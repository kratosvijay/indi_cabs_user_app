import * as admin from "firebase-admin";
admin.initializeApp({
    projectId: "projecttaxi-df0d2", // using project ID from prior log
});
const db = admin.firestore();

async function main() {
    const snapshot = await db.collection("geofenced_zones").get();
    console.log(`Found ${snapshot.docs.length} zones.`);
    for (const doc of snapshot.docs) {
        console.log(`Zone ID: ${doc.id}`);
        const data = doc.data();
        console.log(`  surcharge_amount:`, data.surcharge_amount);
        if (data.boundary && Array.isArray(data.boundary)) {
            console.log(`  boundary points count:`, data.boundary.length);
            if (data.boundary.length > 0) {
                console.log(`  boundary typeof point 0:`, typeof data.boundary[0]);
                console.log(`  boundary point 0 constructor:`, data.boundary[0] && data.boundary[0].constructor ? data.boundary[0].constructor.name : null);
                console.log(`  boundary point 0:`, data.boundary[0]);
            }
        } else {
            console.log(`  boundary:`, data.boundary);
        }
    }
}

main().catch(console.error);
