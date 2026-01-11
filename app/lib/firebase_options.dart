// 🚖 OASIS TAXI PERÚ - Configuración Firebase CORRECTA ✅
// Proyecto: app-oasis-taxi (Project Number: 747030072271)
// Última actualización: 2025-01-09
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuraciones Firebase para OASIS TAXI PERÚ
/// Proyecto correcto: app-oasis-taxi con datos reales verificados
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError('DefaultFirebaseOptions no configurado para Windows');
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions no configurado para Linux');
      default:
        throw UnsupportedError('DefaultFirebaseOptions no soportado para esta plataforma.');
    }
  }

  /// Configuración Firebase para Web - Project: app-oasis-taxi
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDSJTGoS9yv6mi8-c3V1o1CltAeKZeHx5U',
    appId: '1:747030072271:web:PLACEHOLDER',
    messagingSenderId: '747030072271',
    projectId: 'app-oasis-taxi',
    authDomain: 'app-oasis-taxi.firebaseapp.com',
    storageBucket: 'app-oasis-taxi.firebasestorage.app',
  );

  /// Configuración Firebase para Android - Project: app-oasis-taxi
  /// Package: com.oasistaxis.app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSJTGoS9yv6mi8-c3V1o1CltAeKZeHx5U',
    appId: '1:747030072271:android:e09dc1cadcff2834f560ba',
    messagingSenderId: '747030072271',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.firebasestorage.app',
  );

  /// Configuración Firebase para iOS - Project: app-oasis-taxi
  /// Bundle ID: com.oasistaxis.app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBdwktxZJBpUuKzEzrPMyEpFXIKY4p-UFc',
    appId: '1:747030072271:ios:41418181e11cd237f560ba',
    messagingSenderId: '747030072271',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.firebasestorage.app',
    iosBundleId: 'com.oasistaxis.app',
  );

  /// Configuración Firebase para macOS - Project: app-oasis-taxi
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBdwktxZJBpUuKzEzrPMyEpFXIKY4p-UFc',
    appId: '1:747030072271:ios:41418181e11cd237f560ba',
    messagingSenderId: '747030072271',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.firebasestorage.app',
    iosBundleId: 'com.oasistaxis.app',
  );
}