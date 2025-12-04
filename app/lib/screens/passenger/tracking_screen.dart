// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/animated/modern_animated_widgets.dart';
import '../shared/chat_screen.dart';
import '../../utils/logger.dart';

class TrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final String driverPhoto;
  final String vehicleInfo;
  final double driverRating;
  final String estimatedTime;
  final String pickupAddress;
  final String destinationAddress;
  final double tripPrice;
  
  const TrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverPhoto,
    required this.vehicleInfo,
    required this.driverRating,
    required this.estimatedTime,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.tripPrice,
  });
  
  @override
  _TrackingScreenState createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Animaciones
  late AnimationController _bottomSheetController;
  late AnimationController _pulseController;
  late AnimationController _etaController;

  // Estado del viaje
  String _tripStatus = 'arriving'; // arriving, arrived, ontrip, completed
  int _minutesRemaining = 5;
  double _distanceRemaining = 2.5;

  // Posiciones reales del viaje
  LatLng _driverPosition = LatLng(-12.0851, -76.9770);
  LatLng _passengerPosition = LatLng(-12.0951, -76.9870);
  LatLng _destinationPosition = LatLng(-12.1051, -77.0070);

  // ✅ StreamSubscriptions para tracking en tiempo real
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  // Driver ID para obtener ubicación
  String? _driverId;
  
  @override
  void initState() {
    super.initState();

    _bottomSheetController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _etaController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _setupMap();
    // ✅ Reemplazar _startTracking() con tracking en tiempo real
    _setupRealTimeTracking();
  }
  
  @override
  void dispose() {
    // ✅ Liberar MapController para evitar ImageReader buffer warnings
    _mapController?.dispose();
    _mapController = null;

    // ✅ Cancelar subscripciones de Firestore
    _rideSubscription?.cancel();
    _locationSubscription?.cancel();

    _bottomSheetController.dispose();
    _pulseController.dispose();
    _etaController.dispose();
    super.dispose();
  }
  
  void _setupMap() {
    // Configurar marcadores
    _markers.add(
      Marker(
        markerId: MarkerId('driver'),
        position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: widget.driverName,
          snippet: widget.vehicleInfo,
        ),
      ),
    );
    
    _markers.add(
      Marker(
        markerId: MarkerId('passenger'),
        position: _passengerPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
        infoWindow: InfoWindow(
          title: 'Tu ubicación',
          snippet: widget.pickupAddress,
        ),
      ),
    );
    
    if (_tripStatus == 'ontrip') {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: _destinationPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: widget.destinationAddress,
          ),
        ),
      );
    }
    
    // Configurar ruta
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: [_driverPosition, _passengerPosition],
        color: ModernTheme.oasisGreen,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }
  
  /// ✅ TRACKING EN TIEMPO REAL CON FIRESTORE
  void _setupRealTimeTracking() {
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. LISTENER DEL VIAJE (estado, ETA, distancia, driverId)
      _rideSubscription = firestore
          .collection('rides')
          .doc(widget.tripId)
          .snapshots()
          .listen(
        (snapshot) {
          if (!mounted || !snapshot.exists) {
            AppLogger.warning('⚠️ Viaje no encontrado o widget desmontado: ${widget.tripId}');
            return;
          }

          try {
            final data = snapshot.data()!;

            // Obtener posiciones desde Firestore
            if (data['pickup'] != null) {
              _passengerPosition = LatLng(
                (data['pickup']['lat'] ?? _passengerPosition.latitude).toDouble(),
                (data['pickup']['lng'] ?? _passengerPosition.longitude).toDouble(),
              );
            }

            if (data['destination'] != null) {
              _destinationPosition = LatLng(
                (data['destination']['lat'] ?? _destinationPosition.latitude).toDouble(),
                (data['destination']['lng'] ?? _destinationPosition.longitude).toDouble(),
              );
            }

            setState(() {
              _tripStatus = data['status'] ?? 'arriving';
              _minutesRemaining = data['estimatedTimeMinutes'] ?? 5;
              _distanceRemaining = (data['distanceRemainingKm'] ?? 2.5).toDouble();
              _driverId = data['driverId'];

              // Si estado cambió a 'arrived', mostrar notificación
              if (_tripStatus == 'arrived') {
                _showArrivedNotification();
              } else if (_tripStatus == 'completed') {
                _showCompletedNotification();
              }

              // Actualizar polilínea según estado
              _updatePolyline();
            });

            // 2. LISTENER DE UBICACIÓN DEL CONDUCTOR (solo si tenemos driverId)
            if (_driverId != null && _locationSubscription == null) {
              _setupDriverLocationTracking(_driverId!);
            }
          } catch (e) {
            AppLogger.error('❌ Error al procesar datos del viaje: $e');
          }
        },
        onError: (error) {
          AppLogger.error('❌ Error en stream del viaje: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al rastrear viaje'),
                backgroundColor: ModernTheme.error,
              ),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.error('❌ Error al configurar tracking: $e');
    }
  }

  /// ✅ LISTENER DE UBICACIÓN DEL CONDUCTOR EN TIEMPO REAL
  void _setupDriverLocationTracking(String driverId) {
    final firestore = FirebaseFirestore.instance;

    _locationSubscription = firestore
        .collection('locations')
        .doc(driverId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) return;

        try {
          final data = snapshot.data()!;

          // Verificar que la ubicación no sea demasiado antigua (> 30 segundos)
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final age = DateTime.now().difference(timestamp.toDate());
            if (age.inSeconds > 30) {
              AppLogger.warning('⚠️ Ubicación del conductor desactualizada: ${age.inSeconds}s');
            }
          }

          final newPosition = LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );

          setState(() {
            _driverPosition = newPosition;

            // Actualizar marcador del conductor
            _markers.removeWhere((m) => m.markerId.value == 'driver');
            _markers.add(
              Marker(
                markerId: MarkerId('driver'),
                position: _driverPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                rotation: (data['bearing'] ?? 0.0).toDouble(),
                infoWindow: InfoWindow(
                  title: widget.driverName,
                  snippet: widget.vehicleInfo,
                ),
              ),
            );

            // Actualizar polilínea
            _updatePolyline();

            // Centrar cámara en la ruta
            _centerMapOnRoute();
          });
        } catch (e) {
          AppLogger.error('❌ Error al procesar ubicación del conductor: $e');
        }
      },
      onError: (error) {
        AppLogger.error('❌ Error en stream de ubicación: $error');
      },
    );
  }

  /// ✅ ACTUALIZAR POLILÍNEA SEGÚN ESTADO DEL VIAJE
  void _updatePolyline() {
    _polylines.clear();

    List<LatLng> points;
    if (_tripStatus == 'arriving' || _tripStatus == 'arrived') {
      // Ruta: conductor → pasajero
      points = [_driverPosition, _passengerPosition];
    } else {
      // Ruta: posición actual → destino
      points = [_driverPosition, _destinationPosition];
    }

    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: points,
        color: ModernTheme.oasisGreen,
        width: 5,
        patterns: _tripStatus == 'arriving' || _tripStatus == 'arrived'
            ? [PatternItem.dash(20), PatternItem.gap(10)]
            : [],
      ),
    );
  }

  /// ✅ CENTRAR MAPA EN LA RUTA
  void _centerMapOnRoute() {
    try {
      final bounds = _calculateBounds();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      AppLogger.error('❌ Error al centrar mapa: $e');
    }
  }

  /// ✅ CALCULAR BOUNDS PARA CENTRAR MAPA
  LatLngBounds _calculateBounds() {
    List<LatLng> positions = [_driverPosition, _passengerPosition];
    if (_tripStatus != 'arriving' && _tripStatus != 'arrived') {
      positions.add(_destinationPosition);
    }

    double minLat = positions.map((p) => p.latitude).reduce(math.min);
    double maxLat = positions.map((p) => p.latitude).reduce(math.max);
    double minLng = positions.map((p) => p.longitude).reduce(math.min);
    double maxLng = positions.map((p) => p.longitude).reduce(math.max);

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// ✅ NOTIFICACIÓN DE CONDUCTOR LLEGADO
  void _showArrivedNotification() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 28),
            SizedBox(width: 12),
            Text('¡El conductor ha llegado!'),
          ],
        ),
        content: Text(
          'Tu conductor está esperándote en el punto de recogida. Verifica la placa del vehículo antes de abordar.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
            ),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// ✅ NOTIFICACIÓN DE VIAJE COMPLETADO
  void _showCompletedNotification() {
    if (!mounted) return;

    // Navegar a pantalla de calificación
    Navigator.pushReplacementNamed(
      context,
      '/trip-completed',
      arguments: widget.tripId,
    );
  }
  
  /// ✅ Calcular distancia entre dos puntos (útil para validaciones)
  double _calculateDistance(LatLng pos1, LatLng pos2) {
    return math.sqrt(
      math.pow(pos1.latitude - pos2.latitude, 2) +
      math.pow(pos1.longitude - pos2.longitude, 2),
    );
  }

  /// ✅ Calcular bounds que incluyan conductor, pasajero y destino
  LatLngBounds _getBounds() {
    final positions = [_driverPosition, _passengerPosition, _destinationPosition];

    double minLat = positions.map((p) => p.latitude).reduce(math.min);
    double maxLat = positions.map((p) => p.latitude).reduce(math.max);
    double minLng = positions.map((p) => p.longitude).reduce(math.min);
    double maxLng = positions.map((p) => p.longitude).reduce(math.max);

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa con tracking
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Centrar en los marcadores
              Future.delayed(Duration(milliseconds: 500), () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(_getBounds(), 100),
                );
              });
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // ✅ OPTIMIZACIONES: Reducir carga de renderizado y eliminar ImageReader warnings
            liteModeEnabled: false,  // Modo normal pero optimizado
            buildingsEnabled: false, // Deshabilitar edificios 3D
            indoorViewEnabled: false, // Deshabilitar vista interior
            trafficEnabled: false,   // Tráfico deshabilitado por defecto
            minMaxZoomPreference: MinMaxZoomPreference(10, 20), // Limitar zoom
          ),
          
          // Indicador de posición del conductor con pulso
          if (_tripStatus == 'arriving' || _tripStatus == 'ontrip')
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.45,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60 + (20 * _pulseController.value),
                    height: 60 + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ModernTheme.oasisGreen.withValues(alpha: 
                        0.3 * (1 - _pulseController.value),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Header con información del viaje
          SafeArea(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ModernTheme.getFloatingShadow(context),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _etaController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1 + (0.1 * _etaController.value),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_minutesRemaining min • $_distanceRemaining km',
                                  style: TextStyle(
                                    color: ModernTheme.oasisGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_location),
                    onPressed: _shareLocation,
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom sheet con información del conductor
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _bottomSheetController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 300 * (1 - _bottomSheetController.value)),
                  child: _buildDriverInfoSheet(),
                );
              },
            ),
          ),
          
          // Botón de emergencia
          Positioned(
            right: 16,
            bottom: 320,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: ModernTheme.error,
              onPressed: _showEmergencyOptions,
              child: Icon(Icons.warning, color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverInfoSheet() {
    return Container(
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
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Estado del viaje
          if (_tripStatus == 'arrived')
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ModernTheme.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: ModernTheme.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu conductor te está esperando',
                      style: TextStyle(
                        color: ModernTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _tripStatus = 'ontrip');
                    },
                    child: Text('Iniciar viaje'),
                  ),
                ],
              ),
            ),
          
          // Información del conductor
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Foto del conductor
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ModernTheme.oasisGreen,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: NetworkImage(widget.driverPhoto),
                      ),
                    ),
                    SizedBox(width: 16),
                    
                    // Datos del conductor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.driverName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      widget.driverRating.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.vehicleInfo,
                            style: TextStyle(
                              color: context.secondaryText,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ABC-123',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Botones de acción
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.call,
                              color: ModernTheme.oasisGreen,
                            ),
                            onPressed: _callDriver,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.message,
                              color: ModernTheme.primaryBlue,
                            ),
                            onPressed: _openChat,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Detalles del viaje
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Origen
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ModernTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12),
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
                                  widget.pickupAddress,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Línea conectora
                      Container(
                        margin: EdgeInsets.only(left: 4, top: 4, bottom: 4),
                        width: 2,
                        height: 20,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      
                      // Destino
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ModernTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12),
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
                                  widget.destinationAddress,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      Divider(height: 24),
                      
                      // Precio y método de pago
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
                                color: ModernTheme.oasisGreen,
                                size: 20,
                              ),
                              Text(
                                'S/. ${widget.tripPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.oasisGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.money,
                                  size: 16,
                                  color: context.secondaryText,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Efectivo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.secondaryText,
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
                
                if (_tripStatus == 'ontrip') ...[
                  SizedBox(height: 16),
                  AnimatedPulseButton(
                    text: 'Finalizar Viaje',
                    icon: Icons.check_circle,
                    onPressed: _completeTrip,
                    color: ModernTheme.success,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStatusText() {
    switch (_tripStatus) {
      case 'arriving':
        return 'Tu conductor está en camino';
      case 'arrived':
        return 'Tu conductor ha llegado';
      case 'ontrip':
        return 'En viaje hacia tu destino';
      case 'completed':
        return 'Viaje completado';
      default:
        return '';
    }
  }
  
  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo ubicación en tiempo real...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _callDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Llamando a ${widget.driverName}...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }
  
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: 'Conductor',
          otherUserRole: 'driver',
          rideId: widget.tripId,
        ),
      ),
    );
  }
  
  void _showEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Opciones de Emergencia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.error,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.call, color: ModernTheme.error),
              title: Text('Llamar al 911'),
              onTap: () {
                Navigator.pop(context);
                // Llamar emergencia
              },
            ),
            ListTile(
              leading: Icon(Icons.share_location, color: ModernTheme.warning),
              title: Text('Compartir ubicación con contactos'),
              onTap: () {
                Navigator.pop(context);
                // Compartir ubicación
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.orange),
              title: Text('Reportar problema'),
              onTap: () {
                Navigator.pop(context);
                // Reportar
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: context.secondaryText),
              title: Text('Cancelar viaje'),
              onTap: () {
                Navigator.pop(context);
                _cancelTrip();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _cancelTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Cancelar Viaje'),
        content: Text(
          '¿Estás seguro de que deseas cancelar el viaje? Se aplicará una tarifa de cancelación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viaje cancelado'),
                  backgroundColor: ModernTheme.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _completeTrip() {
    setState(() => _tripStatus = 'completed');
    Navigator.pop(context);
    // Mostrar dialog de calificación
  }
}