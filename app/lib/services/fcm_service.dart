import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../config/fcm_config.dart';
import 'firebase_service.dart';

/// Servicio FCM V1 API - Implementación completa y funcional
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // Cache del access token para no regenerarlo en cada request
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;

  /// Inicializar servicio FCM
  Future<void> initialize() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('✅ FCM Token: ${token?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Error inicializando FCM: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Obtener Access Token OAuth2 para FCM V1 API
  Future<String?> _getAccessToken() async {
    try {
      // Si el token está en cache y no ha expirado, usarlo
      if (_cachedAccessToken != null && _tokenExpiry != null) {
        if (DateTime.now().isBefore(_tokenExpiry!)) {
          return _cachedAccessToken;
        }
      }

      // Cargar Service Account JSON desde assets
      final serviceAccountJson = await rootBundle.loadString(
        FCMConfig.serviceAccountPath,
      );
      final accountCredentials = ServiceAccountCredentials.fromJson(
        json.decode(serviceAccountJson),
      );

      // Obtener cliente autenticado
      final client = await clientViaServiceAccount(
        accountCredentials,
        FCMConfig.scopes,
      );

      // Obtener access token
      final accessToken = client.credentials.accessToken.data;

      // Cachear token (expira en ~1 hora, usar 50 min para seguridad)
      _cachedAccessToken = accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));

      client.close();

      debugPrint('✅ Access Token obtenido exitosamente');
      return accessToken;
    } catch (e) {
      debugPrint('❌ Error obteniendo Access Token: $e');
      debugPrint('⚠️ Asegúrate de tener service-account.json en assets/');
      await _firebaseService.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Enviar notificación usando FCM V1 API
  Future<bool> _sendFCMNotification({
    required String fcmToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
    AndroidConfig? androidConfig,
    IOSConfig? iosConfig,
  }) async {
    try {
      // Validar token FCM
      if (!isValidFCMToken(fcmToken)) {
        debugPrint('❌ Token FCM inválido');
        return false;
      }

      // Obtener Access Token OAuth2
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('❌ No se pudo obtener Access Token');
        return false;
      }

      // Construir payload FCM V1 (estructura diferente a Legacy)
      final Map<String, dynamic> message = {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          if (imageUrl != null) 'image': imageUrl,
        },
        'data': {
          ...data,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      // Configuración Android
      if (androidConfig != null) {
        message['android'] = {
          'priority': 'high',
          'notification': {
            'channel_id': androidConfig.channelId,
            if (androidConfig.color != null) 'color': androidConfig.color,
            if (androidConfig.icon != null) 'icon': androidConfig.icon,
            'sound': 'default',
          },
        };
      }

      // Configuración iOS
      if (iosConfig != null) {
        message['apns'] = {
          'payload': {
            'aps': {
              if (iosConfig.sound != null) 'sound': iosConfig.sound,
              if (iosConfig.badge != null) 'badge': iosConfig.badge,
              if (iosConfig.contentAvailable) 'content-available': 1,
            },
          },
        };
      }

      final payload = {'message': message};

      // Enviar request HTTP POST a FCM V1
      debugPrint('📤 Enviando notificación FCM V1...');
      final response = await http.post(
        Uri.parse(FCMConfig.fcmEndpoint),
        headers: FCMConfig.getHeaders(accessToken),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('✅ Notificación enviada: ${responseData['name']}');
        return true;
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Excepción enviando notificación: $e');
      await _firebaseService.recordError(e, stackTrace);
      return false;
    }
  }

  /// Enviar notificación a conductor
  Future<bool> sendRideNotificationToDriver({
    required String driverFcmToken,
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
    required double estimatedDistance,
    String? passengerName,
  }) async {
    return await _sendFCMNotification(
      fcmToken: driverFcmToken,
      title: '¡Nueva solicitud de viaje!',
      body: '${passengerName ?? "Un pasajero"} solicita viaje desde $pickupAddress',
      data: {
        'type': 'ride_request',
        'tripId': tripId,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'estimatedFare': estimatedFare.toString(),
        'estimatedDistance': estimatedDistance.toString(),
        'passengerName': passengerName ?? '',
      },
      androidConfig: AndroidConfig(
        channelId: 'oasis_taxi_rides',
        color: '#4CAF50',
      ),
    );
  }

  /// Enviar notificación a múltiples conductores
  Future<List<String>> sendRideNotificationToMultipleDrivers({
    required List<UserModel> drivers,
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
    required double estimatedDistance,
    String? passengerName,
  }) async {
    final List<String> successfulTokens = [];
    final driversWithTokens = drivers.where((d) =>
      d.fcmToken != null && isValidFCMToken(d.fcmToken!)
    ).toList();

    debugPrint('📱 Enviando a ${driversWithTokens.length} conductores');

    for (final driver in driversWithTokens) {
      final success = await sendRideNotificationToDriver(
        driverFcmToken: driver.fcmToken!,
        tripId: tripId,
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        estimatedFare: estimatedFare,
        estimatedDistance: estimatedDistance,
        passengerName: passengerName,
      );

      if (success) successfulTokens.add(driver.fcmToken!);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ Enviadas: ${successfulTokens.length}/${driversWithTokens.length}');
    return successfulTokens;
  }

  /// Actualización de estado del viaje
  Future<bool> sendTripStatusUpdate({
    required String userFcmToken,
    required String tripId,
    required String status,
    String? driverName,
    String? vehicleInfo,
    Map<String, dynamic> customData = const {},
  }) async {
    String title = 'Actualización de viaje';
    String body = 'Tu viaje ha sido actualizado';

    switch (status.toLowerCase()) {
      case 'accepted':
        title = '¡Viaje aceptado!';
        body = '${driverName ?? "Tu conductor"} ha aceptado el viaje';
        break;
      case 'arrived':
        title = '¡Tu conductor llegó!';
        body = '${driverName ?? "El conductor"} está esperándote';
        break;
      case 'started':
        title = '¡Viaje iniciado!';
        body = 'En camino a tu destino';
        break;
      case 'completed':
        title = '¡Viaje completado!';
        body = 'Has llegado a tu destino';
        break;
      case 'cancelled':
        title = 'Viaje cancelado';
        body = 'Tu viaje ha sido cancelado';
        break;
    }

    return await _sendFCMNotification(
      fcmToken: userFcmToken,
      title: title,
      body: body,
      data: {
        'type': 'trip_status_update',
        'tripId': tripId,
        'status': status,
        'driverName': driverName ?? '',
        'vehicleInfo': vehicleInfo ?? '',
        ...customData,
      },
      androidConfig: AndroidConfig(channelId: 'oasis_taxi_rides'),
    );
  }

  /// Notificación personalizada
  Future<bool> sendCustomNotification({
    required String userFcmToken,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    String? imageUrl,
  }) async {
    return await _sendFCMNotification(
      fcmToken: userFcmToken,
      title: title,
      body: body,
      data: {'type': 'custom', ...data},
      imageUrl: imageUrl,
    );
  }

  /// Notificación promocional
  Future<bool> sendPromotionalNotification({
    required String userFcmToken,
    required String promoCode,
    required String discount,
    required String expiryDate,
  }) async {
    return await _sendFCMNotification(
      fcmToken: userFcmToken,
      title: '🎉 ¡Nueva promoción disponible!',
      body: 'Usa el código $promoCode y obtén $discount de descuento',
      data: {
        'type': 'promotion',
        'promoCode': promoCode,
        'discount': discount,
        'expiryDate': expiryDate,
      },
      androidConfig: AndroidConfig(channelId: 'oasis_taxi_promotions'),
    );
  }

  /// Limpiar tokens inválidos
  Future<int> cleanupInvalidTokens() async {
    try {
      int cleanedCount = 0;
      final usersSnapshot = await _firebaseService.firestore
          .collection('users')
          .where('fcmToken', isNull: false)
          .get();

      for (final doc in usersSnapshot.docs) {
        final token = doc.data()['fcmToken'] as String?;
        if (token != null && !isValidFCMToken(token)) {
          await doc.reference.update({'fcmToken': null});
          cleanedCount++;
        }
      }

      debugPrint('✅ Limpiados $cleanedCount tokens');
      return cleanedCount;
    } catch (e) {
      debugPrint('❌ Error limpiando tokens: $e');
      return 0;
    }
  }

  /// Alerta de emergencia
  Future<bool> sendEmergencyAlert({
    required String emergencyContactToken,
    required String passengerName,
    required String currentLocation,
    required String tripId,
  }) async {
    return await _sendFCMNotification(
      fcmToken: emergencyContactToken,
      title: '🚨 ALERTA DE EMERGENCIA',
      body: '$passengerName necesita ayuda urgente en $currentLocation',
      data: {
        'type': 'emergency',
        'passengerName': passengerName,
        'location': currentLocation,
        'tripId': tripId,
        'priority': 'urgent',
      },
      androidConfig: AndroidConfig(
        channelId: 'oasis_taxi_emergency',
        color: '#FF0000',
      ),
    );
  }

  /// Confirmación de pago
  Future<bool> sendPaymentSuccess({
    required String userFcmToken,
    required String tripId,
    required double amount,
    required String paymentMethod,
  }) async {
    return await _sendFCMNotification(
      fcmToken: userFcmToken,
      title: '✅ Pago procesado',
      body: 'Se procesó el pago de S/$amount con $paymentMethod',
      data: {
        'type': 'payment_success',
        'tripId': tripId,
        'amount': amount.toString(),
        'paymentMethod': paymentMethod,
      },
      androidConfig: AndroidConfig(channelId: 'oasis_taxi_payments'),
    );
  }

  /// Conductor llegó
  Future<bool> sendDriverArrivedToPassenger({
    required String passengerToken,
    required String driverName,
    required String vehicleInfo,
  }) async {
    return await _sendFCMNotification(
      fcmToken: passengerToken,
      title: '🚗 ¡Tu conductor llegó!',
      body: '$driverName está esperándote en su $vehicleInfo',
      data: {
        'type': 'driver_arrived',
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
      },
      androidConfig: AndroidConfig(channelId: 'oasis_taxi_rides'),
    );
  }

  /// Estadísticas del servicio
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      final usersWithTokens = await _firebaseService.firestore
          .collection('users')
          .where('fcmToken', isNull: false)
          .count()
          .get();

      return {
        'status': 'active',
        'users_with_tokens': usersWithTokens.count,
        'api_version': 'V1',
        'last_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  void dispose() {
    _cachedAccessToken = null;
    _tokenExpiry = null;
  }

  // ===== MÉTODOS ESTÁTICOS =====

  static bool isValidFCMToken(String? token) {
    if (token == null || token.isEmpty) return false;
    return token.length > 50 && !token.contains(' ');
  }

  static Future<String?> getDeviceFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('✅ Token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error obteniendo token: $e');
      return null;
    }
  }

  static Future<bool> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Suscrito a: $topic');
      return true;
    } catch (e) {
      debugPrint('❌ Error suscripción: $e');
      return false;
    }
  }

  static Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Desuscrito de: $topic');
      return true;
    } catch (e) {
      debugPrint('❌ Error desuscripción: $e');
      return false;
    }
  }

  Future<bool> sendTripStatusNotification({
    required String userFcmToken,
    required String tripId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    return await sendTripStatusUpdate(
      userFcmToken: userFcmToken,
      tripId: tripId,
      status: status,
      customData: additionalData ?? {},
    );
  }
}

/// Configuración Android
class AndroidConfig {
  final String channelId;
  final String? color;
  final String? icon;

  AndroidConfig({
    required this.channelId,
    this.color,
    this.icon,
  });
}

/// Configuración iOS
class IOSConfig {
  final String? sound;
  final int? badge;
  final bool contentAvailable;

  IOSConfig({
    this.sound = 'default',
    this.badge,
    this.contentAvailable = false,
  });
}
