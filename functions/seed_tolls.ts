import * as admin from "firebase-admin";

const projectIds = ["projecttaxi-df0d2", "indicabs-prod"];

const tolls = [
  // Pre-existing
  {name: "Vanagaram_Toll", lat: 13.0560, lng: 80.1607, fare: 50},
  {name: "Surapattu_Toll", lat: 13.1415, lng: 80.1834, fare: 50},
  {name: "Perungudi_Toll", lat: 12.9567, lng: 80.2423, fare: 45},
  {name: "Uthandi_Toll", lat: 12.8718, lng: 80.2425, fare: 60},
  {name: "Sholavaram_Toll", lat: 13.2386, lng: 80.1654, fare: 55},
  {name: "Paranur_Toll", lat: 12.7230, lng: 79.9926, fare: 65},
  {name: "Egattur_ITEL_Toll", lat: 12.8227, lng: 80.2230, fare: 45},
  {name: "Mathur_Toll", lat: 12.9575, lng: 79.8804, fare: 60},
  {name: "Nemili_Toll", lat: 12.9298, lng: 79.7712, fare: 55},
  {name: "Minjur_Toll", lat: 13.2758, lng: 80.2608, fare: 50},
  {name: "Vandalur_Toll", lat: 12.8887, lng: 80.0844, fare: 50},

  // Newly discovered through geofence mapping
  {name: "Nemili_Toll_South", lat: 12.9818, lng: 79.9692, fare: 55},
  {name: "ECR_Poonjeri_Toll", lat: 12.6154, lng: 80.1698, fare: 60},
  {name: "ECR_Kovalam_Toll", lat: 12.7841, lng: 80.2447, fare: 60},
  {name: "ITEL_Toll_OMR_1", lat: 12.9007, lng: 80.2316, fare: 45},
  {name: "ITEL_Toll_OMR_2", lat: 12.9498, lng: 80.2358, fare: 45},
  {name: "Varadharajapuram_Toll", lat: 12.9301, lng: 80.0800, fare: 50},
  {name: "Chinnamullavoyal_Toll", lat: 13.2541, lng: 80.2397, fare: 50},
  {name: "Palavedu_Toll", lat: 13.1401, lng: 80.0531, fare: 50},
  {name: "Kolappancheri_Toll", lat: 13.0656, lng: 80.0743, fare: 50},
];

/**
 * Seeds tolls for the specified project.
 * @param {string} projectId The project ID.
 */
async function seedForProject(projectId: string) {
  console.log(`\nSeeding tolls for project: ${projectId}`);

  // Initialize a separate app instance for the given project
  const app = admin.initializeApp({projectId: projectId}, projectId);
  const db = app.firestore();
  const batch = db.batch();

  for (const toll of tolls) {
    const ref = db.collection("geofenced_zones").doc(toll.name);
    const offset = 0.003;

    const boundary = [
      new admin.firestore.GeoPoint(toll.lat + offset, toll.lng + offset),
      new admin.firestore.GeoPoint(toll.lat + offset, toll.lng - offset),
      new admin.firestore.GeoPoint(toll.lat - offset, toll.lng - offset),
      new admin.firestore.GeoPoint(toll.lat - offset, toll.lng + offset),
    ];

    batch.set(ref, {
      surcharge_amount: toll.fare,
      boundary: boundary,
    }, {merge: true});
  }

  await batch.commit();
  console.log(`Successfully seeded ${tolls.length} tolls for ${projectId}!`);
  await app.delete();
}

/**
 * Main execution function.
 */
async function main() {
  for (const p of projectIds) {
    await seedForProject(p);
  }
}

main().catch(console.error);
