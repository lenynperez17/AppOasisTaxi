import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/firebase_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

/// Provider de Viajes Real con Firebase
class RideProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FCMService _fcmService = FCMService();
  final NotificationService _notificationService = NotificationService();
  
  TripModel? _currentTrip;
  List<TripModel> _tripHistory = [];
  List<UserModel> _nearbyDrivers = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Estados del viaje
  TripStatus _tripStatus = TripStatus.none;
  
  // Getters
  TripModel? get currentTrip => _currentTrip;
  List<TripModel> get tripHistory => _tripHistory;
  List<UserModel> get nearbyDrivers => _nearbyDrivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TripStatus get tripStatus => _tripStatus;
  bool get hasActiveTrip => _currentTrip != null && 
    (_tripStatus == TripStatus.requested || 
     _tripStatus == TripStatus.accepted || 
     _tripStatus == TripStatus.driverArriving ||
     _tripStatus == TripStatus.inProgress);

  /// Buscar conductores cercanos
  Future<void> searchNearbyDrivers(LatLng userLocation, double radiusKm) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Calcular bounds aproximados
      double latRange = radiusKm / 111.0; // 1 grado ≈ 111 km
      double lngRange = radiusKm / (111.0 * cos(userLocation.latitude * pi / 180));

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('location.lat', isGreaterThan: userLocation.latitude - latRange)
          .where('location.lat', isLessThan: userLocation.latitude + latRange)
          .get();

      _nearbyDrivers = query.docs
          .map((doc) => UserModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .where((driver) {
            // Filtrar por longitud y distancia real
            if (driver.location == null) return false;
            
            double driverLng = driver.location!.longitude;
            if (driverLng < userLocation.longitude - lngRange ||
                driverLng > userLocation.longitude + lngRange) {
              return false;
            }
            
            double distance = _calculateDistance(userLocation, driver.location!);
            return distance <= radiusKm * 1000; // Convertir a metros
          })
          .toList();

      debugPrint('🚗 Conductores encontrados: ${_nearbyDrivers.length}');
      
      await _firebaseService.logEvent('drivers_searched', {
        'count': _nearbyDrivers.length,
        'radius_km': radiusKm,
      });

    } catch (e) {
      _errorMessage = 'Error buscando conductores: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Solicitar viaje
  Future<bool> requestRide({
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required String userId,
    String paymentMethod = 'cash', // Método de pago: 'cash', 'wallet', 'yape_external', 'plin_external'
    String? paymentMethodId, // ID opcional del método de pago
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Determinar si el pago es fuera de la app (modelo InDriver)
      final bool isPaidOutsideApp = paymentMethod == 'cash' ||
                                     paymentMethod == 'yape_external' ||
                                     paymentMethod == 'plin_external';

      // Crear documento del viaje
      final tripData = {
        'userId': userId,
        'pickupLocation': {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
        },
        'destinationLocation': {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': _calculateDistance(pickupLocation, destinationLocation),
        'estimatedFare': _calculateFare(pickupLocation, destinationLocation),
        'driverId': null,
        'vehicleInfo': null,
        // ✅ Campos de pago (modelo InDriver)
        'paymentMethod': paymentMethod,
        'isPaidOutsideApp': isPaidOutsideApp,
        'paymentMethodId': paymentMethodId,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('rides')
          .add(tripData);

      // Crear el modelo del viaje
      _currentTrip = TripModel.fromJson({
        'id': docRef.id,
        ...tripData,
        'requestedAt': DateTime.now().toIso8601String(),
      });

      _tripStatus = TripStatus.requested;

      // Notificar a conductores cercanos
      await _notifyNearbyDrivers(pickupLocation, docRef.id);

      // ✅ CORRECCIÓN: Timeout automático si no hay conductor en 5 minutos
      Future.delayed(const Duration(minutes: 5), () async {
        // Verificar si el viaje sigue en estado 'requested' (no aceptado)
        if (_currentTrip?.id == docRef.id && _tripStatus == TripStatus.requested) {
          try {
            // Auto-cancelar por timeout
            await FirebaseFirestore.instance
                .collection('rides')
                .doc(docRef.id)
                .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': 'system',
              'cancellationReason': 'No hay conductores disponibles en este momento',
            });

            _tripStatus = TripStatus.cancelled;
            _currentTrip = null;
            _errorMessage = 'No se encontraron conductores disponibles. Intenta de nuevo.';
            notifyListeners();

            // Notificar al pasajero
            await _notificationService.showNotification(
              title: 'Viaje cancelado',
              body: 'No hay conductores disponibles en este momento',
            );

            await _firebaseService.logEvent('ride_timeout', {
              'trip_id': docRef.id,
              'timeout_minutes': 5,
            });
          } catch (e) {
            debugPrint('❌ Error en timeout automático: $e');
          }
        }
      });

      await _firebaseService.logEvent('ride_requested', {
        'trip_id': docRef.id,
        'pickup_lat': pickupLocation.latitude,
        'pickup_lng': pickupLocation.longitude,
        'destination_lat': destinationLocation.latitude,
        'destination_lng': destinationLocation.longitude,
        'payment_method': paymentMethod,
        'is_paid_outside_app': isPaidOutsideApp,
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error solicitando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancelar viaje
  Future<bool> cancelRide() async {
    if (_currentTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(_currentTrip!.id)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'passenger',
      });

      await _firebaseService.logEvent('ride_cancelled', {
        'trip_id': _currentTrip!.id,
        'cancelled_by': 'passenger',
      });

      _currentTrip = null;
      _tripStatus = TripStatus.cancelled;
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error cancelando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Completar viaje
  /// Llamado por el conductor al finalizar el viaje
  /// Dispara el procesamiento automático de pagos en Cloud Function
  Future<bool> completeTrip({
    required String tripId,
    required double finalFare,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validar que el viaje existe y está en progreso
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .get();

      if (!rideDoc.exists) {
        throw Exception('Viaje no encontrado: $tripId');
      }

      final rideData = rideDoc.data();
      if (rideData == null) {
        throw Exception('Datos del viaje no disponibles');
      }

      final currentStatus = rideData['status'];
      if (currentStatus != 'in_progress') {
        throw Exception('El viaje no está en progreso (estado actual: $currentStatus)');
      }

      if (finalFare <= 0) {
        throw Exception('La tarifa final debe ser mayor a 0');
      }

      // Actualizar viaje a completado
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'finalFare': finalFare,
      });

      // ✅ Este cambio de status dispara onRideStatusUpdate en Cloud Function
      // que ejecuta processCompletedTripPayment() automáticamente

      debugPrint('✅ Viaje completado: $tripId con tarifa S/. ${finalFare.toStringAsFixed(2)}');

      // Actualizar estado local
      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
          finalFare: finalFare,
        );
        _tripStatus = TripStatus.completed;
      }

      // Log del evento
      await _firebaseService.logEvent('ride_completed', {
        'trip_id': tripId,
        'final_fare': finalFare,
        'payment_method': rideData['paymentMethod'] ?? 'unknown',
        'is_paid_outside_app': rideData['isPaidOutsideApp'] ?? false,
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error completando viaje: $e';
      debugPrint('❌ Error completando viaje: $e');
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calificar viaje
  Future<bool> rateTrip(String tripId, double rating, String? comment) async {
    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .update({
        'passengerRating': rating,
        'passengerComment': comment,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      await _firebaseService.logEvent('trip_rated', {
        'trip_id': tripId,
        'rating': rating,
        'has_comment': comment != null && comment.isNotEmpty,
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error calificando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener historial de viajes
  Future<void> loadTripHistory(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      _tripHistory = query.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      notifyListeners();

    } catch (e) {
      debugPrint('Error cargando historial: $e');
      await _firebaseService.recordError(e, null);
    }
  }

  /// Escuchar cambios del viaje actual
  StreamSubscription<DocumentSnapshot>? _tripSubscription;
  
  void listenToCurrentTrip() {
    if (_currentTrip == null) return;

    _tripSubscription?.cancel();
    _tripSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(_currentTrip!.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        _currentTrip = TripModel.fromJson({
          'id': snapshot.id,
          ...data,
        });

        _updateTripStatus(data['status']);
        notifyListeners();
      }
    });
  }

  /// Actualizar estado del viaje
  void _updateTripStatus(String status) {
    switch (status) {
      case 'requested':
        _tripStatus = TripStatus.requested;
        break;
      case 'accepted':
        _tripStatus = TripStatus.accepted;
        break;
      case 'driver_arriving':
        _tripStatus = TripStatus.driverArriving;
        break;
      case 'in_progress':
        _tripStatus = TripStatus.inProgress;
        break;
      case 'completed':
        _tripStatus = TripStatus.completed;
        break;
      case 'cancelled':
        _tripStatus = TripStatus.cancelled;
        break;
      default:
        _tripStatus = TripStatus.none;
    }
  }

  /// Calcular distancia entre dos puntos
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // metros
    double lat1Rad = start.latitude * pi / 180;
    double lat2Rad = end.latitude * pi / 180;
    double deltaLatRad = (end.latitude - start.latitude) * pi / 180;
    double deltaLngRad = (end.longitude - start.longitude) * pi / 180;

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcular tarifa estimada
  double _calculateFare(LatLng start, LatLng end) {
    double distanceKm = _calculateDistance(start, end) / 1000;
    
    // Tarifa base + por km
    double baseFare = 25.0; // MXN
    double perKmRate = 8.5; // MXN por km
    
    return baseFare + (distanceKm * perKmRate);
  }

  /// Notificar a conductores cercanos con FCM real
  Future<void> _notifyNearbyDrivers(LatLng location, String tripId) async {
    try {
      if (_nearbyDrivers.isEmpty) {
        debugPrint('⚠️ No hay conductores cercanos para notificar');
        return;
      }

      // Obtener información del viaje actual
      if (_currentTrip == null) {
        debugPrint('❌ No hay viaje actual para notificar');
        return;
      }

      // Filtrar conductores con token FCM válido
      final fcmService = FCMService();
      final validDrivers = _nearbyDrivers
          .where((driver) => driver.fcmToken != null && fcmService.isValidFCMToken(driver.fcmToken!))
          .toList();

      if (validDrivers.isEmpty) {
        debugPrint('⚠️ No hay conductores con tokens FCM válidos');
        return;
      }

      debugPrint('📧 Enviando notificaciones a ${validDrivers.length} conductores');

      // Enviar notificaciones en paralelo usando el servicio FCM
      final successfulTokens = await _fcmService.sendRideNotificationToMultipleDrivers(
        driverIds: validDrivers.map((d) => d.id).toList(),
        tripId: tripId,
        passengerName: await _getPassengerName(),
        origin: _currentTrip!.pickupAddress,
        destination: _currentTrip!.destinationAddress,
        estimatedFare: _currentTrip!.estimatedFare.toInt(),
      );

      // Registrar resultados
      final successCount = successfulTokens.values.where((v) => v).length;
      final failureCount = validDrivers.length - successCount;

      debugPrint('✅ Notificaciones enviadas: $successCount exitosas, $failureCount fallidas');

      // Actualizar métricas en Firebase
      await _updateNotificationMetrics(tripId, successCount, failureCount);

      // Crear notificación local para el pasajero
      await _createLocalNotificationForPassenger(successCount);

    } catch (e) {
      debugPrint('❌ Error enviando notificaciones a conductores: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generar código de verificación de 4 dígitos
  String _generateVerificationCode() {
    final random = Random();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  /// ✅ NUEVO: Crear viaje con código de verificación para el pasajero
  Future<TripModel?> createTripWithVerification({
    required String userId,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedDistance,
    required double estimatedFare,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // ✅ Generar código de verificación del pasajero (4 dígitos)
      final passengerVerificationCode = _generateVerificationCode();

      final tripData = {
        'userId': userId,
        'pickupLocation': {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
        },
        'destinationLocation': {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': estimatedDistance,
        'estimatedFare': estimatedFare,
        // ✅ VERIFICACIÓN MUTUA: Solo pasajero por ahora (conductor se genera al aceptar)
        'passengerVerificationCode': passengerVerificationCode,
        'driverVerificationCode': null, // Se genera cuando conductor acepta
        'isPassengerVerified': false,
        'isDriverVerified': false,
        'verificationCompletedAt': null,
        // Campos deprecados (compatibilidad)
        'verificationCode': passengerVerificationCode, // Por compatibilidad
        'isVerificationCodeUsed': false,
      };

      final docRef = await _firebaseService.firestore
          .collection('rides')
          .add(tripData);

      // Obtener el documento creado
      final doc = await docRef.get();
      final trip = TripModel.fromJson({
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
        'requestedAt': DateTime.now().toIso8601String(),
      });

      _currentTrip = trip;
      _tripStatus = TripStatus.requested;
      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Viaje creado con código de verificación del pasajero: $passengerVerificationCode');
      return trip;
    } catch (e) {
      _errorMessage = 'Error creando viaje: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error creando viaje: $e');
      return null;
    }
  }

  /// ✅ NUEVO: Generar código del conductor cuando acepta el viaje
  Future<bool> generateDriverCodeOnAccept(String tripId, String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Generar código del conductor
      final driverVerificationCode = _generateVerificationCode();

      await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .update({
        'driverVerificationCode': driverVerificationCode,
        'driverId': driverId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar trip local
      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          driverVerificationCode: driverVerificationCode,
          driverId: driverId,
          status: 'accepted',
          acceptedAt: DateTime.now(),
        );
        _tripStatus = TripStatus.accepted;
      }

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Código del conductor generado: $driverVerificationCode para viaje: $tripId');
      return true;
    } catch (e) {
      _errorMessage = 'Error generando código del conductor: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error generando código del conductor: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Conductor verifica el código del pasajero
  Future<bool> driverVerifiesPassengerCode(String tripId, String enteredCode) async {
    try {
      _isLoading = true;
      notifyListeners();

      final tripDoc = await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .get();

      if (!tripDoc.exists) {
        throw Exception('Viaje no encontrado');
      }

      final tripData = tripDoc.data() as Map<String, dynamic>;
      final correctCode = tripData['passengerVerificationCode'];

      if (enteredCode == correctCode) {
        // Código correcto - marcar que el conductor verificó al pasajero
        await _firebaseService.firestore
            .collection('rides')
            .doc(tripId)
            .update({
          'isPassengerVerified': true,
        });

        // Actualizar trip local
        if (_currentTrip?.id == tripId) {
          _currentTrip = _currentTrip!.copyWith(
            isPassengerVerified: true,
          );
        }

        _isLoading = false;
        notifyListeners();

        debugPrint('✅ Conductor verificó al pasajero correctamente: $tripId');
        return true;
      } else {
        _errorMessage = 'Código del pasajero incorrecto';
        _isLoading = false;
        notifyListeners();

        debugPrint('❌ Código del pasajero incorrecto: $tripId');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error verificando código del pasajero: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error verificando código del pasajero: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Pasajero verifica el código del conductor
  Future<bool> passengerVerifiesDriverCode(String tripId, String enteredCode) async {
    try {
      _isLoading = true;
      notifyListeners();

      final tripDoc = await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .get();

      if (!tripDoc.exists) {
        throw Exception('Viaje no encontrado');
      }

      final tripData = tripDoc.data() as Map<String, dynamic>;
      final correctCode = tripData['driverVerificationCode'];
      final isPassengerVerified = tripData['isPassengerVerified'] ?? false;

      if (enteredCode == correctCode) {
        // Código correcto - marcar que el pasajero verificó al conductor
        final Map<String, dynamic> updateData = {
          'isDriverVerified': true,
        };

        // Si ambos están verificados, marcar como completo y cambiar a 'in_progress'
        if (isPassengerVerified) {
          updateData['verificationCompletedAt'] = FieldValue.serverTimestamp();
          updateData['status'] = 'in_progress';
          updateData['startedAt'] = FieldValue.serverTimestamp();
          updateData['isVerificationCodeUsed'] = true; // Compatibilidad
        }

        await _firebaseService.firestore
            .collection('rides')
            .doc(tripId)
            .update(updateData);

        // Actualizar trip local
        if (_currentTrip?.id == tripId) {
          _currentTrip = _currentTrip!.copyWith(
            isDriverVerified: true,
            verificationCompletedAt: isPassengerVerified ? DateTime.now() : null,
            status: isPassengerVerified ? 'in_progress' : _currentTrip!.status,
            startedAt: isPassengerVerified ? DateTime.now() : _currentTrip!.startedAt,
            isVerificationCodeUsed: isPassengerVerified, // Compatibilidad
          );

          if (isPassengerVerified) {
            _tripStatus = TripStatus.inProgress;
          }
        }

        _isLoading = false;
        notifyListeners();

        if (isPassengerVerified) {
          debugPrint('✅ VERIFICACIÓN MUTUA COMPLETADA - Viaje iniciado: $tripId');
        } else {
          debugPrint('✅ Pasajero verificó al conductor - Esperando verificación del conductor: $tripId');
        }
        return true;
      } else {
        _errorMessage = 'Código del conductor incorrecto';
        _isLoading = false;
        notifyListeners();

        debugPrint('❌ Código del conductor incorrecto: $tripId');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error verificando código del conductor: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error verificando código del conductor: $e');
      return false;
    }
  }

  /// ⚠️ DEPRECADO: Usar driverVerifiesPassengerCode o passengerVerifiesDriverCode
  @Deprecated('Usar driverVerifiesPassengerCode o passengerVerifiesDriverCode según corresponda')
  Future<bool> verifyTripCode(String tripId, String enteredCode) async {
    // Por ahora delegamos al método del conductor para compatibilidad
    return driverVerifiesPassengerCode(tripId, enteredCode);
  }

  /// ✅ NUEVO: Obtener código de verificación del pasajero
  String? get passengerVerificationCode {
    return _currentTrip?.passengerVerificationCode;
  }

  /// ✅ NUEVO: Obtener código de verificación del conductor
  String? get driverVerificationCode {
    return _currentTrip?.driverVerificationCode;
  }

  /// ✅ NUEVO: Verificar si el conductor ya verificó al pasajero
  bool get isPassengerVerified {
    return _currentTrip?.isPassengerVerified ?? false;
  }

  /// ✅ NUEVO: Verificar si el pasajero ya verificó al conductor
  bool get isDriverVerified {
    return _currentTrip?.isDriverVerified ?? false;
  }

  /// ✅ NUEVO: Verificar si la verificación mutua está completa
  bool get isMutualVerificationComplete {
    return _currentTrip?.isMutualVerificationComplete ?? false;
  }

  /// ✅ NUEVO: Verificar si el viaje puede iniciar (ambos verificados)
  bool get canStartRide {
    return _currentTrip?.canStartRide ?? false;
  }

  /// ⚠️ DEPRECADO: Usar passengerVerificationCode en su lugar
  @Deprecated('Usar passengerVerificationCode en su lugar')
  String? get currentTripVerificationCode {
    return _currentTrip?.verificationCode;
  }

  /// ⚠️ DEPRECADO: Usar isMutualVerificationComplete en su lugar
  @Deprecated('Usar isMutualVerificationComplete en su lugar')
  bool get isCurrentTripCodeUsed {
    return _currentTrip?.isVerificationCodeUsed ?? false;
  }

  /// Actualizar estado del viaje cuando el conductor llega
  Future<void> markDriverArrived(String tripId) async {
    try {
      await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .update({
        'status': 'driver_arriving',
        'arrivedAt': FieldValue.serverTimestamp(),
      });

      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          status: 'driver_arriving',
        );
        _tripStatus = TripStatus.driverArriving;
        notifyListeners();
      }

      debugPrint('✅ Conductor marcado como llegado para viaje: $tripId');
    } catch (e) {
      debugPrint('❌ Error marcando conductor como llegado: $e');
    }
  }

  /// Obtener historial de viajes del usuario
  Future<List<TripModel>> getUserTripHistory(String userId) async {
    try {
      final query = await _firebaseService.firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      return query.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial de usuario: $e');
      return [];
    }
  }

  /// Obtener historial de viajes del conductor
  Future<List<TripModel>> getDriverTripHistory(
    String driverId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firebaseService.firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed');

      if (startDate != null) {
        query = query.where('completedAt', isGreaterThanOrEqualTo: startDate);
      }
      
      if (endDate != null) {
        query = query.where('completedAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial del conductor: $e');
      return [];
    }
  }

  /// Obtener nombre del pasajero actual
  Future<String> _getPassengerName() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final userDoc = await _firebaseService.firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          return userData['fullName'] ?? 'Pasajero';
        }
      }
      return 'Pasajero';
    } catch (e) {
      debugPrint('Error obteniendo nombre del pasajero: $e');
      return 'Pasajero';
    }
  }

  /// Actualizar métricas de notificaciones en Firebase
  Future<void> _updateNotificationMetrics(String tripId, int successCount, int failureCount) async {
    try {
      await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .update({
        'notificationMetrics': {
          'driversNotified': successCount + failureCount,
          'successfulNotifications': successCount,
          'failedNotifications': failureCount,
          'notifiedAt': FieldValue.serverTimestamp(),
        }
      });

      // Registrar evento para analytics
      await _firebaseService.logEvent('driver_notifications_sent', {
        'trip_id': tripId,
        'drivers_notified': successCount + failureCount,
        'successful': successCount,
        'failed': failureCount,
      });
    } catch (e) {
      debugPrint('Error actualizando métricas de notificaciones: $e');
    }
  }

  /// Crear notificación local para el pasajero
  Future<void> _createLocalNotificationForPassenger(int driversNotified) async {
    try {
      String message;
      if (driversNotified > 0) {
        message = driversNotified == 1 
            ? 'Se ha notificado a 1 conductor cercano'
            : 'Se ha notificado a $driversNotified conductores cercanos';
      } else {
        message = 'No se pudieron enviar notificaciones a conductores';
      }

      await _notificationService.showNotification(
        title: 'Buscando conductor...',
        body: message,
        payload: 'searching_driver',
      );
    } catch (e) {
      debugPrint('Error creando notificación local: $e');
    }
  }

  /// Enviar notificación de cambio de estado del viaje
  Future<void> sendTripStatusNotification({
    required String fcmToken,
    required String status,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentTrip == null) return;

    try {
      // Obtener userId desde el fcmToken (necesitamos buscarlo en Firebase)
      // Por ahora enviamos la notificación genérica
      await _fcmService.sendTripStatusNotification(
        userId: _currentTrip!.userId, // Usamos el ID del usuario (pasajero)
        tripId: _currentTrip!.id,
        status: status,
        message: additionalData?['message'],
      );
    } catch (e) {
      debugPrint('Error enviando notificación de estado: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Obtener estadísticas de notificaciones para un viaje
  Future<Map<String, int>?> getTripNotificationStats(String tripId) async {
    try {
      final tripDoc = await _firebaseService.firestore
          .collection('rides')
          .doc(tripId)
          .get();

      if (tripDoc.exists) {
        final data = tripDoc.data() as Map<String, dynamic>;
        final metrics = data['notificationMetrics'] as Map<String, dynamic>?;
        
        if (metrics != null) {
          return {
            'driversNotified': metrics['driversNotified'] ?? 0,
            'successfulNotifications': metrics['successfulNotifications'] ?? 0,
            'failedNotifications': metrics['failedNotifications'] ?? 0,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo estadísticas de notificaciones: $e');
      return null;
    }
  }

  /// Reenviar notificaciones a conductores (en caso de no recibir respuesta)
  Future<void> resendNotificationsToDrivers() async {
    if (_currentTrip == null || _tripStatus != TripStatus.requested) {
      debugPrint('No se puede reenviar notificaciones: no hay viaje activo');
      return;
    }

    try {
      debugPrint('🔄 Reenviando notificaciones a conductores...');
      
      // Buscar nuevos conductores cercanos si es necesario
      if (_nearbyDrivers.isEmpty) {
        final pickupLocation = LatLng(
          _currentTrip!.pickupLocation.latitude,
          _currentTrip!.pickupLocation.longitude,
        );
        await searchNearbyDrivers(pickupLocation, 5.0); // 5km radius
      }

      // Reenviar notificaciones
      await _notifyNearbyDrivers(
        LatLng(
          _currentTrip!.pickupLocation.latitude,
          _currentTrip!.pickupLocation.longitude,
        ),
        _currentTrip!.id,
      );

      await _firebaseService.logEvent('notifications_resent', {
        'trip_id': _currentTrip!.id,
        'drivers_count': _nearbyDrivers.length,
      });

    } catch (e) {
      debugPrint('Error reenviando notificaciones: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Limpiar tokens FCM inválidos (mantenimiento)
  Future<void> cleanupInvalidFCMTokens() async {
    try {
      await _fcmService.cleanupInvalidTokens();
    } catch (e) {
      debugPrint('Error limpiando tokens FCM: $e');
    }
  }

  /// Actualizar calificación del viaje
  Future<void> updateTripRating(String tripId, String userId, double rating, String comment, List<String> tags) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Actualizar calificación en Firebase
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .update({
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'ratingSubmittedAt': FieldValue.serverTimestamp(),
        'ratingSubmittedBy': userId,
      });

      // También crear registro en la subcolección de calificaciones
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .collection('ratings')
          .doc(userId)
          .set({
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Registrar evento para analytics
      await _firebaseService.logEvent('trip_rated', {
        'trip_id': tripId,
        'rating': rating,
        'has_comment': comment.isNotEmpty,
        'tags_count': tags.length,
      });

      // Actualizar trip en la lista local si está disponible
      final tripIndex = _tripHistory.indexWhere((trip) => trip.id == tripId);
      if (tripIndex != -1) {
        _tripHistory[tripIndex] = _tripHistory[tripIndex].copyWith(
          passengerRating: rating,
          passengerComment: comment,
        );
      }

      debugPrint('Calificación actualizada: $rating estrellas para viaje $tripId');
      
    } catch (e) {
      debugPrint('Error actualizando calificación: $e');
      _errorMessage = 'Error al guardar calificación: $e';
      await _firebaseService.recordError(e, StackTrace.current);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }
}

/// Estados del viaje
enum TripStatus {
  none,
  requested,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,
}