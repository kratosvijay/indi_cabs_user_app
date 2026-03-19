const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Recursive function to get data from a collection and its documents' subcollections
async function getCollectionData(db, colRef) {
  const snapshot = await colRef.get();
  const data = {};

  for (const doc of snapshot.docs) {
    const docData = doc.data();
    const docId = doc.id;
    data[docId] = {
      _data: docData,
      _subs: {}
    };

    // Automatically discover and fetch all sub-collections for this document
    const subCollections = await doc.ref.listCollections();
    for (const subCol of subCollections) {
      console.log(`    - Fetching sub-collection: ${colRef.path}/${docId}/${subCol.id}`);
      const subData = await getCollectionData(db, subCol);
      if (Object.keys(subData).length > 0) {
        data[docId]._subs[subCol.id] = subData;
      }
    }
  }
  return data;
}

const collectionsToSkip = ['system_logs', 'logs'];

async function exportData(projectId, keyPath, outputFile) {
  console.log(`Exporting ALL data from project: ${projectId} (Skipping: ${collectionsToSkip.join(', ')})...`);
  const serviceAccount = require(path.resolve(keyPath));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId
  }, 'export');

  const db = admin.app('export').firestore();
  const allData = {};

  // Automatically discover all root-level collections
  const rootCollections = await db.listCollections();
  
  for (const col of rootCollections) {
    if (collectionsToSkip.includes(col.id)) {
      console.log(`  - Skipping collection: ${col.id}`);
      continue;
    }
    console.log(`  - Fetching root collection: ${col.id}`);
    allData[col.id] = await getCollectionData(db, col);
  }

  fs.writeFileSync(outputFile, JSON.stringify(allData, null, 2));
  console.log(`Export complete! Data saved to ${outputFile}`);
}

async function writeCollectionData(db, colRef, data) {
  const batch = db.batch();
  let count = 0;

  for (const docId in data) {
    const docRef = colRef.doc(docId);
    const { _data, _subs } = data[docId];

    batch.set(docRef, _data);
    count++;

    // Commit batches to avoid limits
    if (count >= 400) {
      await batch.commit();
      console.log(`    - Committed 400 docs to ${colRef.path}`);
      count = 0;
    }

    if (_subs) {
      for (const subColName in _subs) {
        await writeCollectionData(db, docRef.collection(subColName), _subs[subColName]);
      }
    }
  }

  if (count > 0) {
    await batch.commit();
    console.log(`    - Committed remaining ${count} docs to ${colRef.path}`);
  }
}

async function importData(projectId, keyPath, inputFile) {
  console.log(`Importing ALL data to project: ${projectId}...`);
  if (!fs.existsSync(inputFile)) {
    console.error(`Error: File ${inputFile} not found.`);
    process.exit(1);
  }

  const serviceAccount = require(path.resolve(keyPath));
  const data = JSON.parse(fs.readFileSync(inputFile, 'utf8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId
  }, 'import');

  const db = admin.app('import').firestore();

  for (const colName in data) {
    console.log(`  - Writing collection: ${colName}`);
    await writeCollectionData(db, db.collection(colName), data[colName]);
  }

  console.log(`Import complete!`);
}

const args = process.argv.slice(2);
const mode = args.includes('--export') ? 'export' : args.includes('--import') ? 'import' : null;
const projectId = args[args.indexOf('--project') + 1];
const keyPath = args[args.indexOf('--key') + 1];
const filePath = 'firestore_seed_data.json';

if (!mode || !projectId || !keyPath) {
  console.log('Usage:');
  console.log('  node migrate_firestore.js --export --project <id> --key <path>');
  console.log('  node migrate_firestore.js --import --project <id> --key <path>');
  process.exit(1);
}

if (mode === 'export') {
  exportData(projectId, keyPath, filePath).catch(console.error);
} else {
  importData(projectId, keyPath, filePath).catch(console.error);
}
