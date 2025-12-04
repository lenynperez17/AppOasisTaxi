const admin = require('firebase-admin');

// Usar las credenciales de aplicación por defecto del entorno
admin.initializeApp({
  projectId: 'app-oasis-taxi'
});

const db = admin.firestore();

const adminData = {
  fullName: "Administrador Oasis Taxi",
  email: "lepereza@ucvvirtual.edu.pe",
  phone: "999999999",
  phoneVerified: true,
  emailVerified: false,
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

db.collection('users').doc('B32OPOB41KVGeO9c2FZRY2ZA0zr2').set(adminData)
  .then(() => {
    console.log('✅ Usuario admin creado exitosamente');
    console.log('UID:', 'B32OPOB41KVGeO9c2FZRY2ZA0zr2');
    console.log('Email:', 'lepereza@ucvvirtual.edu.pe');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
