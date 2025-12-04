const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'app-oasis-taxi' });
const db = admin.firestore();

const uid = '9kWqHsP68icHIUx3afD59s8rjAo1';

const adminData = {
  fullName: "Administrador Oasis Taxi",
  email: "taxioasistours@gmail.com",
  phone: "999999999",
  phoneVerified: true,
  emailVerified: true,
  profilePhotoUrl: "https://lh3.googleusercontent.com/a/ACg8ocLupk14xQyGHTr5zckHldBekY6577VZiCXpZJuc3J-qnBGEwONq=s96-c",
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

db.collection('users').doc(uid).set(adminData, { merge: true })
  .then(() => {
    console.log('✅ Documento de admin creado/actualizado exitosamente');
    console.log('UID:', uid);
    console.log('Email:', 'taxioasistours@gmail.com');
    console.log('');
    console.log('Ahora puedes iniciar sesión con Google usando taxioasistours@gmail.com');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
