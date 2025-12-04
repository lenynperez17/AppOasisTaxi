// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // ✅ NUEVO
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../models/price_negotiation_model.dart';
import '../../providers/auth_provider.dart';

import '../../utils/logger.dart';
class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  State<ModernDriverHomeScreen> createState() => _ModernDriverHomeScreenState();
}

class _ModernDriverHomeScreenState extends State<ModernDriverHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _driverId; // Se obtendrá del usuario autenticado

  // Controllers de animación
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Estado
  bool _isOnline = false;
  bool _showRequestDetails = false;
  List<PriceNegotiation> _availableRequests = [];
  PriceNegotiation? _selectedRequest;
  Timer? _requestsTimer;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // ✅ GPS TRACKING EN TIEMPO REAL
  Timer? _locationUpdateTimer;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  // ✅ LISTENER EN TIEMPO REAL PARA RIDES
  StreamSubscription<QuerySnapshot>? _ridesStreamSubscription;

  // Estadísticas del día
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _acceptanceRate = 0.0; // ✅ FIX: Calcular dinámicamente desde Firebase

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
    
    _pulseController.repeat(reverse: true);
    _initializeDriver();
    _loadRealRequests();
  }
  
  Future<void> _initializeDriver() async {
    try {
      // ✅ CORREGIDO: Obtener ID del usuario autenticado desde AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('⚠️ No hay usuario autenticado');
        return;
      }

      // ✅ CORREGIDO: Usar ID real del usuario (NO mock/placeholder)
      _driverId = currentUser.id;
      AppLogger.info('✅ Conductor inicializado: ${currentUser.fullName} (${currentUser.id})');
      // Cargar estadísticas iniciales
      await _loadTodayStats();
    } catch (e) {
      AppLogger.error('Error inicializando conductor: $e');
    }
  }
  
  void _showDriverMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: ModernTheme.oasisGreen),
              title: const Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: ModernTheme.oasisGreen),
              title: const Text('Métricas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/metrics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: ModernTheme.oasisGreen),
              title: const Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/transactions-history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: ModernTheme.error),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    // ✅ DETENER GPS TRACKING
    _stopLocationTracking();

    // ✅ DETENER LISTENER DE RIDES
    _stopRidesListener();

    // ✅ Liberar MapController para evitar ImageReader buffer warnings
    _mapController?.dispose();
    _mapController = null;

    _pulseController.dispose();
    _slideController.dispose();
    _requestsTimer?.cancel();
    _requestsTimer = null;
    super.dispose();
  }

  // ✅ NUEVO: Iniciar tracking GPS en tiempo real
  Future<void> _startLocationTracking() async {
    try {
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('⚠️ Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('❌ Permisos de ubicación denegados permanentemente');
        return;
      }

      // Obtener ubicación inicial
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _currentLocation = LatLng(initialPosition.latitude, initialPosition.longitude);
      });

      // Mover cámara a ubicación actual
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 16,
          ),
        ),
      );

      // Iniciar stream de actualizaciones de ubicación
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        if (_isDisposed || !mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = newLocation;
          _updateMapMarkers(); // ✅ Actualizar marcador del conductor en el mapa
        });

        // ✅ ACTUALIZAR ubicación en Firebase cada 10 segundos
        if (_driverId != null && _isOnline) {
          await _updateLocationInFirebase(newLocation);
        }

        AppLogger.debug('📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}');
      });

      AppLogger.info('✅ GPS tracking iniciado');
    } catch (e) {
      AppLogger.error('❌ Error iniciando GPS tracking: $e');
    }
  }

  // ✅ NUEVO: Detener tracking GPS
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    AppLogger.debug('🛑 GPS tracking detenido');
  }

  // ✅ NUEVO: Actualizar ubicación del conductor en Firebase
  Future<void> _updateLocationInFirebase(LatLng location) async {
    try {
      if (_driverId == null) return;

      await _firestore.collection('drivers').doc(_driverId).update({
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'isOnline': _isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // print('✅ Ubicación actualizada en Firebase'); // Comentado para reducir logs
    } catch (e) {
      AppLogger.warning('⚠️ Error actualizando ubicación en Firebase: $e');
    }
  }

  // ✅ NUEVO: Iniciar listener en tiempo real para rides
  void _startRidesListener() {
    try {
      if (_driverId == null) {
        AppLogger.warning('⚠️ No se puede iniciar listener de rides: driverId es null');
        return;
      }

      // ✅ Escuchar rides con status 'requested' o 'searching_driver' en tiempo real
      _ridesStreamSubscription = _firestore
          .collection('rides')
          .where('status', whereIn: ['requested', 'searching_driver'])
          .snapshots()
          .listen(
        (snapshot) async {
          // ✅ Verificar que no esté disposed ni desmontado
          if (_isDisposed || !mounted) return;

          List<PriceNegotiation> nearbyRides = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();

              // ✅ Filtrar rides cercanos a la ubicación actual del conductor
              if (_currentLocation != null) {
                // Obtener coordenadas del pickup del ride
                final pickupData = data['pickupLocation'];
                if (pickupData != null &&
                    pickupData['latitude'] != null &&
                    pickupData['longitude'] != null) {
                  final pickupLat = (pickupData['latitude'] as num).toDouble();
                  final pickupLng = (pickupData['longitude'] as num).toDouble();

                  // Calcular distancia entre conductor y punto de recogida
                  final distanceInMeters = Geolocator.distanceBetween(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                    pickupLat,
                    pickupLng,
                  );

                  // ✅ Solo mostrar rides dentro de un radio de 5km (5000 metros)
                  if (distanceInMeters <= 5000) {
                    // Convertir ride a PriceNegotiation para usar la UI existente
                    final negotiation = PriceNegotiation(
                      id: doc.id,
                      passengerId: data['passengerId'] as String? ?? '',
                      selectedDriverId: null, // Sin conductor asignado aún
                      pickup: LocationPoint(
                        latitude: pickupLat,
                        longitude: pickupLng,
                        address: data['pickupAddress'] as String? ?? 'Dirección no disponible',
                      ),
                      destination: LocationPoint(
                        latitude: (data['destinationLocation']?['latitude'] as num?)?.toDouble() ?? 0.0,
                        longitude: (data['destinationLocation']?['longitude'] as num?)?.toDouble() ?? 0.0,
                        address: data['destinationAddress'] as String? ?? 'Destino no disponible',
                      ),
                      status: NegotiationStatus.waiting,
                      suggestedPrice: (data['fare'] as num?)?.toDouble() ?? 0.0,
                      offeredPrice: (data['fare'] as num?)?.toDouble() ?? 0.0,
                      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
                      estimatedTime: (data['estimatedTime'] as num?)?.toInt() ?? 0,
                      passengerName: data['passengerName'] as String? ?? 'Pasajero',
                      passengerPhoto: data['passengerPhoto'] as String? ?? 'https://via.placeholder.com/150',
                      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
                      driverOffers: [], // Sin ofertas aún para nuevo ride
                      paymentMethod: data['paymentMethod'] == 'cash'
                          ? PaymentMethod.cash
                          : PaymentMethod.card,
                      notes: data['notes'] as String?,
                      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
                          DateTime.now().add(const Duration(minutes: 5)),
                    );

                    nearbyRides.add(negotiation);
                  }
                }
              }
            } catch (e) {
              AppLogger.error('Error procesando ride ${doc.id}: $e');
            }
          }

          // ✅ Actualizar lista de solicitudes disponibles
          if (!_isDisposed && mounted) {
            setState(() {
              // ✅ Combinar rides de la colección 'rides' con los existentes de 'negotiations'
              // Evitar duplicados usando un Set de IDs
              final existingIds = _availableRequests.map((r) => r.id).toSet();
              final newRides = nearbyRides.where((r) => !existingIds.contains(r.id)).toList();

              _availableRequests.addAll(newRides);
              _updateMapMarkers();
            });

            if (nearbyRides.isNotEmpty) {
              AppLogger.info('✅ ${nearbyRides.length} rides cercanos detectados en tiempo real');
            }
          }
        },
        onError: (error) {
          AppLogger.error('❌ Error en listener de rides: $error');
        },
      );

      AppLogger.info('✅ Listener de rides iniciado');
    } catch (e) {
      AppLogger.error('❌ Error iniciando listener de rides: $e');
    }
  }

  // ✅ NUEVO: Detener listener de rides
  void _stopRidesListener() {
    _ridesStreamSubscription?.cancel();
    _ridesStreamSubscription = null;
    AppLogger.debug('🛑 Listener de rides detenido');
  }
  
  void _loadRealRequests() {
    // ✅ CORREGIDO: Cargar solicitudes siempre (no solo cuando está online)
    // El conductor debe ver las solicitudes disponibles para poder ponerse online
    _loadRequestsFromFirebase();
  }
  
  Future<void> _loadRequestsFromFirebase() async {
    try {
      // ✅ Cargar solicitudes reales de 'negotiations' desde Firebase
      // ⚡ Este método trabaja EN CONJUNTO con _startRidesListener()
      // - Timer polling: Carga de 'negotiations' (negociaciones de precio estilo InDriver)
      // - Stream listener: Escucha 'rides' en tiempo real (viajes directos)
      if (_driverId == null) {
        AppLogger.warning('⚠️ No hay driverId configurado');
        return;
      }

      // ✅ CORREGIDO: Buscar en colección 'negotiations' donde el pasajero crea las solicitudes
      // Sin filtro de expiresAt en query (puede ser String o Timestamp en datos viejos)
      final requestsSnapshot = await _firestore
          .collection('negotiations')
          .where('status', isEqualTo: 'waiting')
          .limit(50)
          .get();

      AppLogger.info('📋 Encontradas ${requestsSnapshot.docs.length} solicitudes en Firestore');

      List<PriceNegotiation> loadedRequests = [];
      final now = DateTime.now();
      for (var doc in requestsSnapshot.docs) {
        try {
          final negotiation = PriceNegotiation.fromMap(doc.id, doc.data());
          // ✅ Filtrar expirados en el cliente (soporta String y Timestamp)
          if (negotiation.expiresAt.isAfter(now)) {
            loadedRequests.add(negotiation);
          }
        } catch (e) {
          AppLogger.error('Error parseando solicitud ${doc.id}: $e');
        }
      }

      AppLogger.info('✅ ${loadedRequests.length} solicitudes válidas (no expiradas)');

      if (!mounted) return;

      setState(() {
        // ✅ IMPORTANTE: Mantener rides del listener, solo actualizar negotiations
        // Filtrar para mantener solo los rides (de la colección 'rides')
        final ridesFromListener = _availableRequests.where((r) =>
          r.id.startsWith('rides/')).toList();

        _availableRequests = [...loadedRequests, ...ridesFromListener];
        _updateMapMarkers();
      });

      // ✅ Configurar timer para actualizaciones periódicas de 'negotiations'
      // El listener en tiempo real maneja automáticamente los rides
      _requestsTimer?.cancel();
      _requestsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        // ✅ TRIPLE VERIFICACIÓN para prevenir polling después de dispose
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_isOnline) {
          _loadRequestsFromFirebase();
        }
      });
    } catch (e) {
      AppLogger.error('Error cargando solicitudes: $e');
      // En caso de error, mantener lista vacía (conductor nuevo o sin solicitudes)
      if (!mounted) return;
      setState(() {
        _availableRequests = [];
        _updateMapMarkers();
      });
    }
  }
  
  
  void _updateMapMarkers() {
    _markers.clear();

    // ✅ NUEVO: Marcador de la ubicación actual del conductor
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
      );
    }

    // Marcadores de solicitudes disponibles
    for (var request in _availableRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: LatLng(request.pickup.latitude, request.pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _selectRequest(request),
          infoWindow: InfoWindow(
            title: 'Recoger: ${request.passengerName}',
            snippet: request.pickup.address,
          ),
        ),
      );
    }
  }
  
  void _selectRequest(PriceNegotiation request) {
    setState(() {
      _selectedRequest = request;
      _showRequestDetails = true;
    });
    _slideController.forward();
  }
  
  void _acceptRequest(PriceNegotiation request) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Generar código de verificación del pasajero
      String generateVerificationCode() {
        final random = DateTime.now().millisecondsSinceEpoch;
        return ((random % 9000) + 1000).toString();
      }

      final passengerCode = generateVerificationCode();
      final driverCode = generateVerificationCode();

      // ✅ CORRECCIÓN RACE CONDITION: Usar transaction para evitar que múltiples conductores acepten
      final rideId = await _firestore.runTransaction<String?>((transaction) async {
        final negotiationRef = _firestore.collection('negotiations').doc(request.id);
        final snapshot = await transaction.get(negotiationRef);

        if (!snapshot.exists) {
          throw Exception('La solicitud ya no existe');
        }

        final data = snapshot.data()!;

        // ✅ VALIDAR que no tenga conductor asignado (otro conductor ya aceptó)
        if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
          throw Exception('Otro conductor ya aceptó esta solicitud');
        }

        // ✅ CORREGIDO: Validar status correcto (waiting = esperando, negotiating = en negociación)
        final status = data['status'] as String?;
        if (status != 'waiting' && status != 'negotiating') {
          throw Exception('La solicitud ya no está disponible');
        }

        // Crear registro de viaje dentro de la transacción
        final rideRef = _firestore.collection('rides').doc();

        transaction.set(rideRef, {
          'userId': request.passengerId,
          'driverId': _driverId,
          'negotiationId': request.id,
          'pickupLocation': {
            'latitude': request.pickup.latitude,
            'longitude': request.pickup.longitude,
          },
          'destinationLocation': {
            'latitude': request.destination.latitude,
            'longitude': request.destination.longitude,
          },
          'pickupAddress': request.pickup.address,
          'destinationAddress': request.destination.address,
          'estimatedFare': request.offeredPrice,
          'finalFare': request.offeredPrice,
          'estimatedDistance': request.distance,
          'status': 'accepted',
          'paymentMethod': request.paymentMethod.name,
          'requestedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          // Códigos de verificación mutua
          'passengerVerificationCode': passengerCode,
          'driverVerificationCode': driverCode,
          'isPassengerVerified': false,
          'isDriverVerified': false,
          // ✅ CORREGIDO: Info del pasajero con nombre de campo correcto
          'vehicleInfo': {
            'passengerName': request.passengerName,
            'passengerPhoto': request.passengerPhoto,
            'passengerRating': request.passengerRating,
          },
          // ✅ NUEVO: Info del pasajero separada
          'passengerInfo': {
            'name': request.passengerName,
            'photo': request.passengerPhoto,
            'rating': request.passengerRating,
          },
          // ✅ NUEVO: Info del conductor (se cargará después)
          'driverInfo': {
            'driverId': _driverId,
          },
        });

        // ✅ ASIGNAR conductor atómicamente
        transaction.update(negotiationRef, {
          'status': 'accepted',
          'driverId': _driverId,
          'rideId': rideRef.id,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        return rideRef.id; // Retornar el ID del viaje
      });

      if (rideId != null) {
        setState(() {
          _availableRequests.remove(request);
          _showRequestDetails = false;
        });

        // Recargar estadísticas
        await _loadTodayStats();

        _showAcceptedDialog(request, rideId);
      }
    } on FirebaseException catch (e) {
      AppLogger.error('Error Firebase aceptando solicitud: ${e.code} - ${e.message}');
      if (!mounted) return;

      String errorMessage = 'Error al aceptar el viaje';
      if (e.code == 'failed-precondition') {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ModernTheme.error,
        ),
      );
    } catch (e) {
      AppLogger.error('Error aceptando solicitud: $e');
      if (!mounted) return;

      String errorMessage = 'Error al aceptar el viaje';
      if (e.toString().contains('ya aceptó')) {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      } else if (e.toString().contains('no está disponible')) {
        errorMessage = 'La solicitud ya no está disponible';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  // ✅ NUEVO: Diálogo para negociar precio con el pasajero
  void _showNegotiateDialog(PriceNegotiation request) {
    final priceController = TextEditingController(
      text: request.offeredPrice.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.price_change, color: ModernTheme.warning),
            const SizedBox(width: 8),
            const Text('Proponer precio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio del pasajero: S/ ${request.offeredPrice.toStringAsFixed(2)}',
              style: TextStyle(color: context.secondaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Precio sugerido: S/ ${request.suggestedPrice.toStringAsFixed(2)}',
              style: TextStyle(color: context.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu propuesta (S/)',
                prefixText: 'S/ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ModernTheme.warning, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'El pasajero recibirá tu oferta y podrá aceptar o rechazar.',
              style: TextStyle(fontSize: 12, color: context.secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: context.secondaryText)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final proposedPrice = double.tryParse(priceController.text);
              if (proposedPrice == null || proposedPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un precio válido'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await _sendCounterOffer(request, proposedPrice);
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar oferta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Enviar contraoferta al pasajero
  Future<void> _sendCounterOffer(PriceNegotiation request, double proposedPrice) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Obtener datos del conductor
      final driverDoc = await _firestore.collection('users').doc(_driverId).get();
      final driverData = driverDoc.data() ?? {};
      final vehicleInfo = driverData['vehicleInfo'] as Map<String, dynamic>? ?? {};

      // Crear la oferta del conductor
      // ✅ CORREGIDO: Usar DateTime.now() porque FieldValue.serverTimestamp() no funciona en arrayUnion
      final offer = {
        'driverId': _driverId,
        'driverName': driverData['fullName'] ?? 'Conductor',
        'driverPhoto': driverData['profilePhotoUrl'] ?? '',
        'driverRating': driverData['rating'] ?? 5.0,
        'vehicleModel': '${vehicleInfo['make'] ?? ''} ${vehicleInfo['model'] ?? ''}'.trim(),
        'vehiclePlate': vehicleInfo['plate'] ?? '',
        'vehicleColor': vehicleInfo['color'] ?? '',
        'acceptedPrice': proposedPrice,
        'estimatedArrival': 5,
        'offeredAt': DateTime.now().toIso8601String(),
        'status': 'pending',
        'completedTrips': driverData['totalTrips'] ?? 0,
        'acceptanceRate': 0.95,
      };

      // Actualizar la negociación en Firestore
      await _firestore.collection('negotiations').doc(request.id).update({
        'status': 'negotiating',
        'driverOffers': FieldValue.arrayUnion([offer]),
      });

      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Oferta de S/ ${proposedPrice.toStringAsFixed(2)} enviada'),
            ],
          ),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Recargar solicitudes
      _loadRequestsFromFirebase();
    } catch (e) {
      AppLogger.error('Error enviando contraoferta: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al enviar oferta: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OasisAppBar(
        title: 'Conductor - ${_isOnline ? "EN LÍNEA" : "DESCONECTADO"}',
        showBackButton: false,
        actions: [
          // ✅ NUEVO: Mostrar placa del vehículo
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final vehicleInfo = authProvider.currentUser?.vehicleInfo;
              final plate = vehicleInfo?['plate'] as String?;
              if (plate != null && plate.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ModernTheme.oasisGreen, width: 2),
                  ),
                  child: Text(
                    plate.toUpperCase(),
                    style: const TextStyle(
                      color: ModernTheme.oasisBlack,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const ModeSwitchButton(compact: true),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => Navigator.pushNamed(context, '/driver/wallet'),
          ),
          IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => _showDriverMenu(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // ✅ OPTIMIZACIONES: Reducir carga de renderizado y eliminar ImageReader warnings
            liteModeEnabled: false,  // Modo normal pero optimizado
            buildingsEnabled: false, // Deshabilitar edificios 3D
            indoorViewEnabled: false, // Deshabilitar vista interior
            trafficEnabled: false,   // Tráfico deshabilitado por defecto
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20), // Limitar zoom
          ),
          
          // Panel superior con estadísticas
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Switch online/offline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isOnline ? 'En línea' : 'Fuera de línea',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? ModernTheme.success : context.secondaryText,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: (value) {
                          setState(() {
                            _isOnline = value;
                            if (value) {
                              // ✅ INICIAR GPS TRACKING cuando va online
                              _startLocationTracking();
                              // ✅ INICIAR LISTENER DE RIDES en tiempo real
                              _startRidesListener();
                              _availableRequests = [];
                              _updateMapMarkers();
                            } else {
                              // ✅ DETENER GPS TRACKING cuando va offline
                              _stopLocationTracking();
                              // ✅ DETENER LISTENER DE RIDES
                              _stopRidesListener();
                              _availableRequests.clear();
                              _markers.clear();
                            }
                          });
                        },
                        thumbColor: const WidgetStatePropertyAll(ModernTheme.success),
                      ),
                    ],
                  ),

                  if (_isOnline) ...[
                    const Divider(),
                    // Estadísticas del día
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatistic('Ganancias', 'S/. ${_todayEarnings.toStringAsFixed(2)}', Icons.monetization_on),
                        _buildStatistic('Viajes', '$_todayTrips', Icons.directions_car),
                        _buildStatistic(
                          'Aceptación',
                          _acceptanceRate > 0 ? '${_acceptanceRate.toStringAsFixed(1)}%' : 'N/A',
                          Icons.star
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Lista de solicitudes activas
          if (_isOnline && _availableRequests.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: ModernTheme.getFloatingShadow(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Título con contador de solicitudes
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Solicitudes disponibles',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.primaryText,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ModernTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_availableRequests.length}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Lista horizontal de solicitudes
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _availableRequests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_availableRequests[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          
          // Detalle de solicitud seleccionada
          if (_showRequestDetails && _selectedRequest != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 500 * (1 - _slideAnimation.value)),
                    child: _buildRequestDetailSheet(_selectedRequest!),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatistic(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: ModernTheme.primaryOrange, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.secondaryText,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRequestCard(PriceNegotiation request) {
    final timeRemaining = request.timeRemaining;
    final isUrgent = timeRemaining.inMinutes < 2;
    
    return AnimatedElevatedCard(
      onTap: () => _selectRequest(request),
      borderRadius: 16,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: isUrgent
            ? LinearGradient(
                colors: [ModernTheme.warning.withValues(alpha: 0.1), Theme.of(context).colorScheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con foto y rating
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(request.passengerPhoto),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                          const SizedBox(width: 2),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio ofrecido
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ModernTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información del viaje
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: ModernTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.pickup.address,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 16, color: ModernTheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.destination.address,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Spacer(),
            
            // Footer con distancia y tiempo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 14, color: context.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      '${request.distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 14, color: context.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      '${request.estimatedTime} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
                // Tiempo restante
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? ModernTheme.warning : ModernTheme.info,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetailSheet(PriceNegotiation request) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.getFloatingShadow(context),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Información del pasajero
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(request.passengerPhoto),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.passengerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                        const SizedBox(width: 4),
                        Text(
                          request.passengerRating.toStringAsFixed(1),
                          style: TextStyle(color: context.secondaryText),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          request.paymentMethod == PaymentMethod.cash
                            ? Icons.money
                            : Icons.credit_card,
                          size: 16,
                          color: context.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          request.paymentMethod == PaymentMethod.cash
                            ? 'Efectivo'
                            : 'Tarjeta',
                          style: TextStyle(color: context.secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Precio grande
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: ModernTheme.successGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          // Detalles del viaje
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: ModernTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recogida',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.secondaryText,
                            ),
                          ),
                          Text(
                            request.pickup.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Container(
                    height: 30,
                    width: 1,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: ModernTheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destino',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.secondaryText,
                            ),
                          ),
                          Text(
                            request.destination.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Información adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(Icons.route, '${request.distance.toStringAsFixed(1)} km'),
              _buildInfoChip(Icons.access_time, '${request.estimatedTime} min'),
              _buildInfoChip(Icons.timer, '${request.timeRemaining.inMinutes}:${(request.timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}'),
            ],
          ),
          
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: ModernTheme.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Botones de acción - 3 opciones: Rechazar, Negociar, Aceptar
          Column(
            children: [
              // Fila superior: Rechazar y Negociar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showRequestDetails = false;
                          _selectedRequest = null;
                        });
                        _slideController.reverse();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: context.secondaryText),
                      ),
                      child: Text(
                        'Rechazar',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showNegotiateDialog(request),
                      icon: const Icon(Icons.price_change, size: 18),
                      label: const Text('Negociar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: ModernTheme.warning),
                        foregroundColor: ModernTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Fila inferior: Aceptar (ancho completo)
              SizedBox(
                width: double.infinity,
                child: AnimatedPulseButton(
                  text: 'Aceptar viaje',
                  icon: Icons.check,
                  color: ModernTheme.success,
                  onPressed: () => _acceptRequest(request),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.secondaryText),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _loadTodayStats() async {
    try {
      if (_driverId == null) return;

      // Obtener fecha de hoy
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Consultar viajes del conductor del día actual
      final tripsQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'completed')
          .get();

      double totalEarnings = 0.0;
      int tripCount = 0;

      for (var doc in tripsQuery.docs) {
        final data = doc.data();
        final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
        totalEarnings += fare;
        tripCount++;
      }

      // ✅ NUEVO: Calcular tasa de aceptación basada en 'negotiations'
      // Contar solicitudes aceptadas vs rechazadas del conductor
      final negotiationsQuery = await _firestore
          .collection('negotiations')
          .where('driverId', isEqualTo: _driverId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      int acceptedCount = 0;
      int totalOffered = 0;

      for (var doc in negotiationsQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String?;

        // Contar solicitudes que fueron ofrecidas a este conductor
        totalOffered++;

        // Contar las que aceptó
        if (status == 'accepted') {
          acceptedCount++;
        }
      }

      // Calcular porcentaje (si hay ofertas)
      double acceptanceRate = 0.0;
      if (totalOffered > 0) {
        acceptanceRate = (acceptedCount / totalOffered) * 100;
      }

      setState(() {
        _todayEarnings = totalEarnings;
        _todayTrips = tripCount;
        _acceptanceRate = acceptanceRate;
      });

      // Si no hay viajes, mostrar mensaje informativo
      if (tripCount == 0) {
        AppLogger.debug('ℹ️ No hay viajes completados hoy. Empieza a aceptar solicitudes!');
      }

      if (totalOffered == 0) {
        AppLogger.debug('ℹ️ No hay solicitudes recibidas hoy. Tasa de aceptación: N/A');
      }
    } catch (e) {
      // Detectar si es error de permisos (conductor nuevo) o error real
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
        AppLogger.debug('ℹ️ Conductor nuevo detectado. Sin historial de viajes aún.');
      } else {
        AppLogger.warning('⚠️ Error cargando estadísticas del día: $e');
      }

      // En todos los casos, mostrar valores en 0 (conductor nuevo o error)
      if (!_isDisposed && mounted) {
        setState(() {
          _todayEarnings = 0.0;
          _todayTrips = 0;
          _acceptanceRate = 0.0;
        });
      }
    }
  }
  
  void _showAcceptedDialog(PriceNegotiation request, String rideId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: ModernTheme.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Viaje aceptado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dirígete al punto de recogida',
              style: TextStyle(color: context.secondaryText),
            ),
            const SizedBox(height: 16),
            // Mostrar información del pasajero
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: request.passengerPhoto.isNotEmpty
                            ? NetworkImage(request.passengerPhoto)
                            : null,
                        child: request.passengerPhoto.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.passengerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(request.passengerRating.toStringAsFixed(1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: ModernTheme.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.pickup.address,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Ir al viaje',
              icon: Icons.navigation,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navegar a la pantalla de viaje activo
                Navigator.pushNamed(
                  context,
                  '/driver/active-trip',
                  arguments: {'tripId': rideId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}