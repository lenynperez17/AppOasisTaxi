const admin = require('firebase-admin');
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'app-oasis-taxi.firebasestorage.app'
});

const db = admin.firestore();
const storage = admin.storage().bucket();

// UID del admin (el único que debe quedar)
const ADMIN_UID = '9kWqHsP68icHIUx3afD59s8rjAo1';

async function cleanupAll() {
  console.log('='.repeat(60));
  console.log('LIMPIEZA COMPLETA DE FIREBASE');
  console.log('='.repeat(60));
  console.log('');

  // 1. Limpiar usuarios huérfanos en Firestore
  console.log('1. LIMPIANDO USUARIOS HUERFANOS...');
  console.log('-'.repeat(40));
  const usersSnapshot = await db.collection('users').get();
  let usersDeleted = 0;

  for (const doc of usersSnapshot.docs) {
    if (doc.id !== ADMIN_UID) {
      await doc.ref.delete();
      console.log('   Eliminado: ' + doc.id.substring(0, 20) + '...');
      usersDeleted++;
    }
  }
  console.log('   Total eliminados: ' + usersDeleted);
  console.log('');

  // 2. Limpiar colección rides
  console.log('2. LIMPIANDO RIDES...');
  console.log('-'.repeat(40));
  const ridesSnapshot = await db.collection('rides').get();
  let ridesDeleted = 0;

  for (const doc of ridesSnapshot.docs) {
    await doc.ref.delete();
    ridesDeleted++;
  }
  console.log('   Total eliminados: ' + ridesDeleted);
  console.log('');

  // 3. Limpiar colección trips
  console.log('3. LIMPIANDO TRIPS...');
  console.log('-'.repeat(40));
  const tripsSnapshot = await db.collection('trips').get();
  let tripsDeleted = 0;

  for (const doc of tripsSnapshot.docs) {
    await doc.ref.delete();
    tripsDeleted++;
  }
  console.log('   Total eliminados: ' + tripsDeleted);
  console.log('');

  // 4. Limpiar colección negotiations
  console.log('4. LIMPIANDO NEGOTIATIONS...');
  console.log('-'.repeat(40));
  const negotiationsSnapshot = await db.collection('negotiations').get();
  let negotiationsDeleted = 0;

  for (const doc of negotiationsSnapshot.docs) {
    await doc.ref.delete();
    negotiationsDeleted++;
  }
  console.log('   Total eliminados: ' + negotiationsDeleted);
  console.log('');

  // 5. Limpiar colección drivers
  console.log('5. LIMPIANDO DRIVERS...');
  console.log('-'.repeat(40));
  const driversSnapshot = await db.collection('drivers').get();
  let driversDeleted = 0;

  for (const doc of driversSnapshot.docs) {
    await doc.ref.delete();
    driversDeleted++;
  }
  console.log('   Total eliminados: ' + driversDeleted);
  console.log('');

  // 6. Limpiar notification_metrics
  console.log('6. LIMPIANDO NOTIFICATION_METRICS...');
  console.log('-'.repeat(40));
  const metricsSnapshot = await db.collection('notification_metrics').get();
  let metricsDeleted = 0;

  for (const doc of metricsSnapshot.docs) {
    await doc.ref.delete();
    metricsDeleted++;
  }
  console.log('   Total eliminados: ' + metricsDeleted);
  console.log('');

  // 7. Limpiar security_logs
  console.log('7. LIMPIANDO SECURITY_LOGS...');
  console.log('-'.repeat(40));
  const logsSnapshot = await db.collection('security_logs').get();
  let logsDeleted = 0;

  for (const doc of logsSnapshot.docs) {
    await doc.ref.delete();
    logsDeleted++;
  }
  console.log('   Total eliminados: ' + logsDeleted);
  console.log('');

  // 8. Limpiar cleanup_logs
  console.log('8. LIMPIANDO CLEANUP_LOGS...');
  console.log('-'.repeat(40));
  const cleanupLogsSnapshot = await db.collection('cleanup_logs').get();
  let cleanupLogsDeleted = 0;

  for (const doc of cleanupLogsSnapshot.docs) {
    await doc.ref.delete();
    cleanupLogsDeleted++;
  }
  console.log('   Total eliminados: ' + cleanupLogsDeleted);
  console.log('');

  // 9. Limpiar Storage (fotos de conductores eliminados)
  console.log('9. LIMPIANDO STORAGE...');
  console.log('-'.repeat(40));
  try {
    const [files] = await storage.getFiles({ prefix: 'drivers/' });
    let filesDeleted = 0;

    for (const file of files) {
      // No eliminar archivos del admin
      if (!file.name.includes(ADMIN_UID)) {
        await file.delete();
        filesDeleted++;
      }
    }
    console.log('   Archivos en drivers/ eliminados: ' + filesDeleted);

    // Limpiar carpeta users/
    const [userFiles] = await storage.getFiles({ prefix: 'users/' });
    let userFilesDeleted = 0;

    for (const file of userFiles) {
      if (!file.name.includes(ADMIN_UID)) {
        await file.delete();
        userFilesDeleted++;
      }
    }
    console.log('   Archivos en users/ eliminados: ' + userFilesDeleted);
  } catch (e) {
    console.log('   Error accediendo storage: ' + e.message);
  }
  console.log('');

  // Resumen final
  console.log('='.repeat(60));
  console.log('RESUMEN DE LIMPIEZA');
  console.log('='.repeat(60));
  console.log('Usuarios eliminados:      ' + usersDeleted);
  console.log('Rides eliminados:         ' + ridesDeleted);
  console.log('Trips eliminados:         ' + tripsDeleted);
  console.log('Negotiations eliminados:  ' + negotiationsDeleted);
  console.log('Drivers eliminados:       ' + driversDeleted);
  console.log('Metrics eliminados:       ' + metricsDeleted);
  console.log('Security logs eliminados: ' + logsDeleted);
  console.log('Cleanup logs eliminados:  ' + cleanupLogsDeleted);
  console.log('');
  console.log('Usuario admin preservado: ' + ADMIN_UID);
  console.log('');
  console.log('LIMPIEZA COMPLETADA!');

  process.exit(0);
}

cleanupAll().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
