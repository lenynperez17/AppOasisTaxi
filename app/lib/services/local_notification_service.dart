import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../utils/logger.dart';
import '../utils/navigation_helper.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Inicializar notificaciones
  Future<void> initialize() async {
    // Inicializar timezone data
    tz_data.initializeTimeZones();
    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
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

    // Inicializar
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos en Android 13+
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  // Callback cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notificación tocada: ${response.payload}');
    
    // Navegar a pantalla específica según el payload
    final payload = response.payload;
    if (payload != null) {
      _handleNotificationNavigation(payload);
    }
  }

  // Manejar navegación basada en el payload de la notificación
  void _handleNotificationNavigation(String payload) {
    switch (payload) {
      case 'ride_request':
        NavigationHelper.navigateToRideRequest();
        break;
      case 'driver_found':
        NavigationHelper.navigateToTripTracking();
        break;
      case 'driver_arrived':
        NavigationHelper.navigateToTripTracking();
        break;
      case 'trip_completed':
        NavigationHelper.navigateToTripHistory();
        break;
      case 'payment_received':
        NavigationHelper.navigateToEarnings();
        break;
      default:
        AppLogger.warning('Payload de notificación no reconocido: $payload');
        NavigationHelper.navigateToHome();
    }
  }

  // Mostrar notificación simple
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'oasis_taxi_channel',
      'Oasis Taxi',
      channelDescription: 'Notificaciones de Oasis Taxi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Notificación de nueva solicitud de viaje (para conductores)
  Future<void> showRideRequestNotification({
    required String passengerName,
    required String pickupAddress,
    required String price,
  }) async {
    await showNotification(
      title: '🚗 Nueva solicitud de viaje',
      body: '$passengerName necesita un viaje desde $pickupAddress - S/. price',
      payload: 'ride_request',
    );
  }

  // Notificación de conductor encontrado (para pasajeros)
  Future<void> showDriverFoundNotification({
    required String driverName,
    required String vehicleInfo,
    required String estimatedTime,
  }) async {
    await showNotification(
      title: '✅ ¡Conductor encontrado!',
      body: '$driverName está en camino - $vehicleInfo - Llegará en $estimatedTime',
      payload: 'driver_found',
    );
  }

  // Notificación de conductor llegó
  Future<void> showDriverArrivedNotification() async {
    await showNotification(
      title: '🚗 Tu conductor ha llegado',
      body: 'Tu conductor está esperándote en el punto de recogida',
      payload: 'driver_arrived',
    );
  }

  // Notificación de viaje completado
  Future<void> showTripCompletedNotification({
    required String price,
  }) async {
    await showNotification(
      title: '✅ Viaje completado',
      body: 'El viaje ha finalizado. Total: S/. price',
      payload: 'trip_completed',
    );
  }

  // Notificación de pago recibido (para conductores)
  Future<void> showPaymentReceivedNotification({
    required String amount,
  }) async {
    await showNotification(
      title: '💰 Pago recibido',
      body: 'Has recibido S/. amount por el viaje completado',
      payload: 'payment_received',
    );
  }

  // Notificación con acciones
  Future<void> showNotificationWithActions({
    required String title,
    required String body,
    required List<AndroidNotificationAction> actions,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'oasis_taxi_actions',
      'Oasis Taxi Acciones',
      channelDescription: 'Notificaciones con acciones',
      importance: Importance.high,
      priority: Priority.high,
      actions: actions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // Cancelar notificación
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Programar notificación
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'oasis_taxi_scheduled',
      'Oasis Taxi Programadas',
      channelDescription: 'Notificaciones programadas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _notifications.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      AppLogger.info('Notificación programada para: $scheduledDate');
    } catch (e) {
      AppLogger.error('Error programando notificación', e);
      // Fallback: mostrar notificación inmediata
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    }
  }
}