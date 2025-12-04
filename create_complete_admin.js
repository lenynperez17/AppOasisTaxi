const admin = require('firebase-admin');

// Inicializar con credenciales de aplicación por defecto
admin.initializeApp({
  projectId: 'app-oasis-taxi'
});

const auth = admin.auth();
const db = admin.firestore();

const adminEmail = 'taxioasistours@gmail.com';
const adminPassword = 'Admin123!';

async function createCompleteAdmin() {
  try {
    console.log('🔧 Creando usuario en Firebase Auth...');

    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
      email: adminEmail,
      password: adminPassword,
      emailVerified: true, // Pre-verificado
      displayName: 'Administrador Oasis Taxi',
    });

    console.log('✅ Usuario creado en Firebase Auth');
    console.log('   UID:', userRecord.uid);
    console.log('   Email:', userRecord.email);

    // Datos del documento de Firestore
    const adminData = {
      fullName: "Administrador Oasis Taxi",
      email: adminEmail,
      phone: "999999999",
      phoneVerified: true,
      emailVerified: true,
      profilePhotoUrl: "",
      userType: "admin",
      activeMode: "admin",
      currentMode: "admin",
      availableRoles: ["admin"],
      isDualAccount: false,
      isAdmin: true,
      adminLevel: "super_admin",
      permissions: [
        "users.read", "users.write", "users.delete",
        "drivers.read", "drivers.write", "drivers.approve", "drivers.reject", "drivers.documents.verify",
        "trips.read", "trips.write", "trips.cancel",
        "analytics.read", "promotions.read", "promotions.write",
        "settings.read", "settings.write", "reports.read", "system.manage"
      ],
      rating: 5,
      totalTrips: 0,
      balance: 0,
      isActive: true,
      isVerified: true,
      twoFactorEnabled: false,
      deviceInfo: { trustedDevices: [], lastDeviceId: "" },
      securitySettings: {
        loginAttempts: 0,
        passwordHistory: [],
        lastPasswordChange: admin.firestore.FieldValue.serverTimestamp()
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: null,
      fcmToken: "",
      fcmTokenUpdatedAt: null,
      phoneHash: ""
    };

    console.log('🔧 Creando documento en Firestore...');

    // Crear documento en Firestore con el UID del usuario
    await db.collection('users').doc(userRecord.uid).set(adminData);

    console.log('✅ Documento creado en Firestore');
    console.log('');
    console.log('═══════════════════════════════════════');
    console.log('✅ ADMIN CREADO EXITOSAMENTE');
    console.log('═══════════════════════════════════════');
    console.log('📧 Email:', adminEmail);
    console.log('🔑 Password:', adminPassword);
    console.log('🆔 UID:', userRecord.uid);
    console.log('═══════════════════════════════════════');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'auth/email-already-exists') {
      console.log('ℹ️  El usuario ya existe en Firebase Auth');
      console.log('   Intenta recuperar la contraseña o usa otro email');
    }
    process.exit(1);
  }
}

createCompleteAdmin();
