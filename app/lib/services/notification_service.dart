// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Servicio de Notificaciones Real para Producción
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  
  // Stream controller para manejar notificaciones seleccionadas
  final StreamController<String> _notificationSelectedController = StreamController<String>.broadcast();
  
  /// Stream para escuchar notificaciones seleccionadas
  Stream<String>? get onNotificationSelected => _notificationSelectedController.stream;
  
  /// Canal de notificaciones para Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'oasis_taxi_channel',
    'Oasis Taxi Notifications',
    description: 'Notificaciones de Oasis Taxi',
    importance: Importance.max,
    playSound: true,
    enableLights: true,
    enableVibration: true,
  );

  /// Inicializar servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Configuración Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar plugin de notificaciones locales
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Crear canal de notificaciones Android (solo si no es web)
    if (!kIsWeb && Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Configurar handlers de Firebase Messaging
    await _setupFirebaseMessaging();

    _initialized = true;
    debugPrint('✅ Servicio de notificaciones inicializado');
  }

  /// Configurar Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Handler para mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Obtener mensaje inicial si la app se abrió desde una notificación
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // ✅ NOTA: El background handler se registra en main.dart con firebaseMessagingBackgroundHandler
    // No registrar aquí para evitar duplicación
  }

  /// Handler para mensajes en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Mensaje recibido en primer plano: ${message.messageId}');
    
    // Mostrar notificación local
    await showNotification(
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
    );
  }

  /// Handler para cuando se abre la app desde notificación
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 App abierta desde notificación: ${message.messageId}');
    _handleNotificationClick(message.data);
  }

  /// Mostrar notificación local
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'oasis_taxi_channel',
      'Oasis Taxi Notifications',
      channelDescription: 'Notificaciones de Oasis Taxi',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Mostrar notificación de viaje
  Future<void> showRideNotification({
    required String title,
    required String body,
    required Map<String, dynamic> rideData,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'ride',
        'data': rideData,
      }),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Mostrar notificación de chat
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await showNotification(
      title: senderName,
      body: message,
      payload: json.encode({
        'type': 'chat',
        'chatId': chatId,
      }),
      id: chatId.hashCode,
    );
  }

  /// Mostrar notificación de promoción
  Future<void> showPromoNotification({
    required String title,
    required String description,
    required String promoCode,
  }) async {
    await showNotification(
      title: title,
      body: '$description\nCódigo: $promoCode',
      payload: json.encode({
        'type': 'promo',
        'code': promoCode,
      }),
      id: promoCode.hashCode,
    );
  }

  /// Cancelar notificación
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Handler para respuesta a notificación
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('📱 Notificación clickeada: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _instance._handleNotificationClick(data);
      } catch (e) {
        debugPrint('Error procesando payload: $e');
      }
    }
  }

  /// Manejar click en notificación y emitir evento
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    
    // Emitir evento para que el NotificationHandler lo procese
    String payload = '';
    
    switch (type) {
      case 'ride':
        final rideId = data['data']['rideId'] ?? '';
        payload = 'ride:$rideId';
        debugPrint('Navegar a viaje: $rideId');
        break;
      case 'chat':
        payload = 'chat:${data['chatId']}';
        debugPrint('Navegar a chat: ${data['chatId']}');
        break;
      case 'promo':
        payload = 'promo:${data['code']}';
        debugPrint('Aplicar promo: ${data['code']}');
        break;
      case 'emergency':
        payload = 'emergency';
        debugPrint('Manejar emergencia');
        break;
      case 'price_negotiation':
        payload = 'price_negotiation';
        debugPrint('Nueva negociación de precio');
        break;
      case 'driver_found':
        payload = 'driver_found';
        break;
      case 'driver_arrived':
        payload = 'driver_arrived';
        break;
      case 'trip_completed':
        payload = 'trip_completed';
        break;
      case 'payment_received':
        payload = 'payment_received';
        break;
      case 'ride_request':
        payload = 'ride_request';
        break;
      default:
        payload = type;
        debugPrint('Tipo de notificación desconocido: $type');
    }
    
    // Emitir el payload al stream
    if (payload.isNotEmpty) {
      _notificationSelectedController.add(payload);
    }
  }

  /// Handler para notificaciones iOS en primer plano (legacy)
  static void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    debugPrint('iOS notificación recibida: $title');
  }

  /// Obtener detalles de notificación pendiente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Actualizar badge de la app (iOS)
  Future<void> updateBadge(int count) async {
    if (Platform.isIOS) {
      // Implementar actualización de badge para iOS
      debugPrint('Badge actualizado a: $count');
    }
  }
  
  /// Limpiar recursos
  void dispose() {
    _notificationSelectedController.close();
  }
}

// ✅ NOTA: El background handler está definido en firebase_messaging_handler.dart
// No duplicar aquí para evitar conflictos