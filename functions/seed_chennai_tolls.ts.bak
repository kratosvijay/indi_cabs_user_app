import * as admin from "firebase-admin";

admin.initializeApp({
    projectId: "projecttaxi-df0d2"
});

const db = admin.firestore();

// A list of major toll plazas across Chennai and their approximate center points and standard one-way fares
const tolls = [
    { name: "Vanagaram_Toll", lat: 13.0560, lng: 80.1607, fare: 50 },
    { name: "Surapattu_Toll", lat: 13.1415, lng: 80.1834, fare: 50 },
    { name: "Perungudi_Toll", lat: 12.9567, lng: 80.2423, fare: 45 },
    // Uthandi (Mayajaal) is already seeded, but we'll overwrite it for consistency
    { name: "Uthandi_Toll", lat: 12.8718, lng: 80.2425, fare: 60 },
    { name: "Sholavaram_Toll", lat: 13.2386, lng: 80.1654, fare: 55 },
    { name: "Paranur_Toll", lat: 12.7230, lng: 79.9926, fare: 65 },
    { name: "Egattur_ITEL_Toll", lat: 12.8227, lng: 80.2230, fare: 45 },
    { name: "Mathur_Toll", lat: 12.9575, lng: 79.8804, fare: 60 },
    { name: "Nemili_Toll", lat: 12.9298, lng: 79.7712, fare: 55 },
    { name: "Minjur_Toll", lat: 13.2758, lng: 80.2608, fare: 50 },
    { name: "Vandalur_Toll", lat: 12.8887, lng: 80.0844, fare: 50 }
];

async function main() {
    const batch = db.batch();

    for (const toll of tolls) {
        const ref = db.collection('geofenced_zones').doc(toll.name);

        // Create a bounding box roughly ~300m - 400m around the point
        // 0.003 degrees latitude is roughly 333 meters
        const offset = 0.003;

        // Create the square polygon geometry
        const boundary = [
            new admin.firestore.GeoPoint(toll.lat + offset, toll.lng + offset),
            new admin.firestore.GeoPoint(toll.lat + offset, toll.lng - offset),
            new admin.firestore.GeoPoint(toll.lat - offset, toll.lng - offset),
            new admin.firestore.GeoPoint(toll.lat - offset, toll.lng + offset),
        ];

        batch.set(ref, {
            surcharge_amount: toll.fare,
            boundary: boundary
        }, { merge: true }); // Merges or creates if new
    }

    await batch.commit();
    console.log(`Successfully seeded ${tolls.length} major toll gates inside Chennai!`);
}

main().catch(console.error);
