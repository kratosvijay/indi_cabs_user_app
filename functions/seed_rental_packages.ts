import * as admin from "firebase-admin";

const projectIds = ["projecttaxi-df0d2", "indicabs-prod"];

const rentalPackages = [
  {
    id: "1_hr_10_km",
    display_name: "1 hr 10 km",
    duration_hours: 1,
    km_limit: 10,
    extra_km_charge: 18,
    extra_hour_charge: 150,
    price_hatchback: 350,
    price_sedan: 400,
    price_suv: 550,
    price_auto: 0,
    price_actingdriver: 250
  },
  {
    id: "2_hr_20_km",
    display_name: "2 hr 20 km",
    duration_hours: 2,
    km_limit: 20,
    extra_km_charge: 18,
    extra_hour_charge: 150,
    price_hatchback: 600,
    price_sedan: 700,
    price_suv: 900,
    price_auto: 0,
    price_actingdriver: 400
  },
  {
    id: "4_hr_40_km",
    display_name: "4 hr 40 km",
    duration_hours: 4,
    km_limit: 40,
    extra_km_charge: 18,
    extra_hour_charge: 150,
    price_hatchback: 1100,
    price_sedan: 1300,
    price_suv: 1600,
    price_auto: 0,
    price_actingdriver: 700
  },
  {
    id: "8_hr_80_km",
    display_name: "8 hr 80 km",
    duration_hours: 8,
    km_limit: 80,
    extra_km_charge: 18,
    extra_hour_charge: 150,
    price_hatchback: 2000,
    price_sedan: 2400,
    price_suv: 3000,
    price_auto: 0,
    price_actingdriver: 1200
  }
];

/**
 * Seeds rental packages for the specified project.
 * @param {string} projectId The project ID.
 */
async function seedForProject(projectId: string) {
  console.log(`\nSeeding rental packages for project: ${projectId}`);

  // Initialize a separate app instance for the given project
  const app = admin.initializeApp({ projectId: projectId }, projectId);
  const db = app.firestore();
  const batch = db.batch();

  for (const pkg of rentalPackages) {
    const ref = db.collection("rental_packages").doc(pkg.id);
    batch.set(ref, pkg, { merge: true });
  }

  await batch.commit();
  console.log(`Successfully seeded ${rentalPackages.length} rental packages for ${projectId}!`);
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
