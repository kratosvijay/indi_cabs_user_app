import * as admin from "firebase-admin";
admin.initializeApp({
    projectId: "projecttaxi-df0d2",
});
const db = admin.firestore();

async function main() {
    const collections = await db.listCollections();
    console.log("Collections:", collections.map(c => c.id).join(", "));
}

main().catch(console.error);
