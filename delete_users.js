const admin = require('firebase-admin');
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// UIDs a eliminar (todos excepto admin)
const usersToDelete = [
  'IyZKGnSHALeu5BoWHGRnCKDvoon1',  // Eduardo Fernández
  'XISLqMmoZnaUiftViwJ22voXVhF3',  // Djpana Panamix
  'nkAHXDGCvqaEYHE0QPqBb3sDlLt2', // Isaac Colina
];

async function deleteUsers() {
  console.log('Eliminando usuarios...\n');

  for (const uid of usersToDelete) {
    try {
      // 1. Obtener info del usuario antes de eliminar
      let userEmail = 'desconocido';
      try {
        const userRecord = await auth.getUser(uid);
        userEmail = userRecord.email || 'sin email';
      } catch (e) {
        // Usuario no existe en Auth
      }

      // 2. Eliminar documento de Firestore
      try {
        await db.collection('users').doc(uid).delete();
        console.log('Firestore: Eliminado users/' + uid);
      } catch (e) {
        console.log('Firestore: No se pudo eliminar users/' + uid + ' - ' + e.message);
      }

      // 3. Eliminar subcolecciones comunes
      const subcollections = ['favorites', 'notifications', 'trips', 'payments'];
      for (const sub of subcollections) {
        try {
          const docs = await db.collection('users').doc(uid).collection(sub).listDocuments();
          for (const doc of docs) {
            await doc.delete();
          }
          if (docs.length > 0) {
            console.log('   Eliminados ' + docs.length + ' docs de ' + sub);
          }
        } catch (e) {
          // Subcolección no existe
        }
      }

      // 4. Eliminar de Firebase Auth
      try {
        await auth.deleteUser(uid);
        console.log('Auth: Eliminado ' + userEmail + ' (' + uid + ')');
      } catch (e) {
        console.log('Auth: No se pudo eliminar ' + uid + ' - ' + e.message);
      }

      console.log('');
    } catch (e) {
      console.error('Error con ' + uid + ': ' + e.message);
    }
  }

  // Verificar usuarios restantes
  console.log('Verificando usuarios restantes...\n');
  const listResult = await auth.listUsers(100);
  console.log('Total usuarios en Auth: ' + listResult.users.length);
  listResult.users.forEach(user => {
    console.log('   - ' + user.email + ' (' + user.uid + ')');
  });

  console.log('\nLimpieza completada!');
  process.exit(0);
}

deleteUsers().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
