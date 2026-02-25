import * as admin from "firebase-admin";

admin.initializeApp({
    projectId: "projecttaxi-df0d2"
});

const db = admin.firestore();

async function main() {
    const mayajaalRef = db.collection('geofenced_zones').doc('Mayajaal_Toll');

    const boundary = [
        new admin.firestore.GeoPoint(12.9000, 80.2200),
        new admin.firestore.GeoPoint(12.9000, 80.2400),
        new admin.firestore.GeoPoint(12.8300, 80.2400),
        new admin.firestore.GeoPoint(12.8300, 80.2200)
    ];

    await mayajaalRef.set({
        surcharge_amount: 60,
        boundary: boundary
    });
    console.log("Mayajaal_Toll added to database!");
}

main().catch(console.error);
