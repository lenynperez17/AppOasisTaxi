const admin = require('firebase-admin');
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

const ADMIN_UID = '9kWqHsP68icHIUx3afD59s8rjAo1';

async function cleanAdminAccount() {
  console.log('🔧 Limpiando cuenta admin...\n');

  // 1. Actualizar documento en Firestore - SOLO campos de admin
  const adminData = {
    // Identificación
    uid: ADMIN_UID,
    email: 'taxioasistours@gmail.com',
    displayName: 'Oasis Taxi Admin',
    fullName: 'Oasis Taxi Admin',
    
    // Rol SOLO admin
    role: 'admin',
    isAdmin: true,
    userType: 'admin',  // Cambiado de 'dual' a 'admin'
    
    // Permisos de admin
    permissions: [
      'manage_users',
      'manage_drivers', 
      'manage_trips',
      'manage_payments',
      'manage_settings',
      'view_analytics',
      'manage_promotions',
      'manage_zones'
    ],
    
    // Estado
    isActive: true,
    emailVerified: true,
    disabled: false,
    
    // Configuración
    settings: {
      timezone: 'America/Lima',
      language: 'es',
      notifications: {
        sms: false,
        email: true,
        push: true
      }
    },
    
    // Timestamps
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2025-10-21T20:34:06Z')),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    
    // Campos a ELIMINAR (se ponen como FieldValue.delete())
    // Estos campos NO deben existir en una cuenta admin
    currentMode: admin.firestore.FieldValue.delete(),
    availableRoles: admin.firestore.FieldValue.delete(),
    modeHistory: admin.firestore.FieldValue.delete(),
    upgradeHistory: admin.firestore.FieldValue.delete(),
    vehicleInfo: admin.firestore.FieldValue.delete(),
    documents: admin.firestore.FieldValue.delete(),
    driverStatus: admin.firestore.FieldValue.delete(),
    dni: admin.firestore.FieldValue.delete(),
    license: admin.firestore.FieldValue.delete(),
    phoneNumber: admin.firestore.FieldValue.delete(),
    authProvider: admin.firestore.FieldValue.delete(),
    authProviders: admin.firestore.FieldValue.delete(),
    profilePhotoUrl: admin.firestore.FieldValue.delete(),
    photoURL: admin.firestore.FieldValue.delete(),
    fcmToken: admin.firestore.FieldValue.delete(),
    fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
    lastLoginAt: admin.firestore.FieldValue.delete(),
    metadata: admin.firestore.FieldValue.delete(),
  };

  await db.collection('users').doc(ADMIN_UID).update(adminData);
  console.log('✅ Documento Firestore actualizado - Solo datos de admin\n');

  // 2. Actualizar custom claims en Firebase Auth
  await auth.setCustomUserClaims(ADMIN_UID, {
    admin: true,
    role: 'admin',
    permissions: [
      'manage_users',
      'manage_drivers',
      'manage_trips', 
      'manage_payments',
      'manage_settings',
      'view_analytics',
      'manage_promotions',
      'manage_zones'
    ],
    // Bloquear acceso como pasajero/conductor
    blockedRoles: ['passenger', 'driver']
  });
  console.log('✅ Custom claims actualizados en Firebase Auth\n');

  // 3. Verificar resultado
  const userRecord = await auth.getUser(ADMIN_UID);
  console.log('📋 Usuario Auth actualizado:');
  console.log('   Email:', userRecord.email);
  console.log('   Custom Claims:', JSON.stringify(userRecord.customClaims, null, 2));

  const userDoc = await db.collection('users').doc(ADMIN_UID).get();
  const data = userDoc.data();
  console.log('\n📋 Documento Firestore actualizado:');
  console.log('   role:', data.role);
  console.log('   userType:', data.userType);
  console.log('   isAdmin:', data.isAdmin);
  console.log('   currentMode:', data.currentMode || '(eliminado)');
  console.log('   vehicleInfo:', data.vehicleInfo || '(eliminado)');
  console.log('   documents:', data.documents || '(eliminado)');

  console.log('\n✅ Cuenta admin limpiada correctamente!');
  process.exit(0);
}

cleanAdminAccount().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
