// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Para ocultar teclado en Android
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ NUEVO: Para reverse geocoding (coordenadas → dirección)
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math'; // Para funciones matemáticas: sin, cos, sqrt, atan2 (fórmula Haversine)
import '../../core/theme/modern_theme.dart';
import '../../core/widgets/custom_place_text_field.dart'; // ✅ NUEVO: Widget custom que resuelve problema del teclado
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../models/price_negotiation_model.dart' as models;
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../shared/settings_screen.dart';
import '../shared/about_screen.dart';
import '../../utils/logger.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

// Enum para tipos de servicio disponibles
enum ServiceType {
  standard,    // Taxi Estándar (1-4 pasajeros)
  xl,          // Taxi XL - Furgoneta (5-6 pasajeros)
  premium,     // Taxi Premium - Lujo (1-4 pasajeros)
  delivery,    // Delivery Express (paquetes)
  moto,        // Moto Taxi (1 pasajero, rápido)
}

// Google Maps API Key para Directions API y Places API
const String _googleMapsApiKey = 'AIzaSyDhivA5K3FD5Qeom96dkJ-NsdmWVrqFWmo';

// Estilo de mapa limpio - Oculta POIs, etiquetas y distracciones visuales
// Solo muestra calles principales y geografía básica para mejor enfoque en la ruta
const String _cleanMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit.station",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.neighborhood",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';

class ModernPassengerHomeScreen extends StatefulWidget {
  const ModernPassengerHomeScreen({super.key});

  @override
  State<ModernPassengerHomeScreen> createState() =>
      _ModernPassengerHomeScreenState();
}

class _ModernPassengerHomeScreenState extends State<ModernPassengerHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); // Para entrada manual de precio

  // FocusNode para controlar el teclado del campo de precio
  final FocusNode _priceFocusNode = FocusNode();

  // ✅ Flag para prevenir uso de controllers después de dispose
  bool _isDisposed = false;

  // Animation controllers
  late AnimationController _bottomSheetController;
  late AnimationController _searchBarController;
  late Animation<double> _bottomSheetAnimation;
  late Animation<double> _searchBarAnimation;
  
  // Estados
  bool _isSearchingDestination = false;
  bool _showPriceNegotiation = false;
  bool _showDriverOffers = false;
  double _offeredPrice = 15.0;
  bool _locationPermissionGranted = false; // Para habilitar myLocation en Maps
  bool _isManualPriceEntry = false; // true cuando el usuario quiere digitar el precio manualmente
  ServiceType _selectedServiceType = ServiceType.standard; // Tipo de servicio seleccionado (default: Standard)
  String _selectedPaymentMethod = 'Efectivo'; // Método de pago seleccionado (default: Efectivo)
  bool _isSelectingLocation = false; // ✅ true cuando el usuario está ingresando/seleccionando direcciones
  bool _showContinueButton = false; // ✅ true solo cuando el teclado está cerrado y campos están llenos
  Timer? _buttonDelayTimer; // Timer para delay del botón después de cerrar teclado
  bool _isAdjustingPickup = false; // ✅ NUEVO: true cuando se muestra el marcador fijo para ajustar ubicación moviendo el mapa

  // Coordenadas de lugares seleccionados con Google Places
  LatLng? _pickupCoordinates;
  LatLng? _destinationCoordinates;

  // Cálculos reales de la ruta (sin placeholders)
  double? _calculatedDistance; // Distancia real en km usando Haversine
  int? _estimatedTime; // Tiempo estimado real en minutos
  double? _suggestedPrice; // Precio sugerido real basado en distancia

  // Negociación actual
  models.PriceNegotiation? _currentNegotiation;
  Timer? _negotiationTimer;

  // ==================== CONSTANTES UI - PRINCIPIO DRY ====================
  // Border Radius
  static const double _kBorderRadiusXLarge = 30.0;
  static const double _kBorderRadiusLarge = 20.0;
  static const double _kBorderRadiusMedium = 16.0;
  static const double _kBorderRadiusSmall = 12.0;
  static const double _kBorderRadiusTiny = 2.0;

  // Padding
  static const EdgeInsets _kPaddingAll20 = EdgeInsets.all(20);
  static const EdgeInsets _kPaddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets _kPaddingAll12 = EdgeInsets.all(12);
  static const EdgeInsets _kPaddingAll8 = EdgeInsets.all(8);
  static const EdgeInsets _kPaddingHorizontal20Vertical8 = EdgeInsets.symmetric(horizontal: 20, vertical: 8);
  static const EdgeInsets _kPaddingHorizontal16Vertical8 = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets _kPaddingVertical8 = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets _kPaddingVertical12 = EdgeInsets.symmetric(vertical: 12);
  static const EdgeInsets _kPaddingHorizontal16 = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets _kPaddingHorizontal20 = EdgeInsets.symmetric(horizontal: 20);

  // Spacing (SizedBox)
  static const double _kSpacingXLarge = 24.0;
  static const double _kSpacingLarge = 20.0;
  static const double _kSpacingMedium = 16.0;
  static const double _kSpacingSmall = 12.0;
  static const double _kSpacingXSmall = 8.0;
  static const double _kSpacingTiny = 6.0;
  static const double _kSpacingMicro = 4.0;
  static const double _kSpacingNano = 3.0;
  static const double _kSpacingPico = 2.0;

  // Font Sizes
  static const double _kFontSizeXXLarge = 24.0;
  static const double _kFontSizeXLarge = 20.0;
  static const double _kFontSizeLarge = 18.0;
  static const double _kFontSizeMedium = 16.0;
  static const double _kFontSizeSmall = 14.0;
  static const double _kFontSizeXSmall = 12.0;
  static const double _kFontSizeTiny = 10.0;
  static const double _kFontSizeMicro = 9.0;

  // Icon Sizes
  static const double _kIconSizeXLarge = 32.0;
  static const double _kIconSizeLarge = 28.0;
  static const double _kIconSizeMedium = 20.0;
  static const double _kIconSizeSmall = 16.0;
  static const double _kIconSizeXSmall = 14.0;

  // Marker Circle Size
  static const double _kMarkerCircleSize = 10.0;

  // Handle/Divider Sizes
  static const double _kHandleWidth = 40.0;
  static const double _kHandleHeight = 4.0;

  // Map Zoom Levels
  static const double _kZoomLevelClose = 16.0; // Muy cerca para ver detalles
  static const double _kZoomLevelMedium = 15.0; // Suficiente para ver la zona claramente
  static const double _kMapBoundsPadding = 100.0; // Padding para LatLngBounds

  // Service Card Size
  static const double _kServiceCardWidth = 100.0;
  // ======================================================================

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernPassengerHomeScreen', 'initState');

    _bottomSheetController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _searchBarController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    );

    _searchBarAnimation = CurvedAnimation(
      parent: _searchBarController,
      curve: Curves.easeInOut,
    );

    _bottomSheetController.forward();
    _searchBarController.forward();

    // ✅ REMOVIDOS: Listeners problemáticos que impedían actualización de UI
    // La lógica de show/hide de UI ahora se maneja directamente en onTap y onPlaceSelected
    // para permitir actualización correcta cuando el usuario cambia direcciones

    // Listener para cambios en el estado del viaje
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRideProviderListener();
      _requestLocationPermission(); // Solicitar permisos de ubicación al iniciar
    });
  }
  
  void _setupRideProviderListener() {
    if (!mounted) return;
    
    AppLogger.debug('Configurando listener del RideProvider');
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      // Escuchar cambios en el viaje actual
      rideProvider.addListener(_onRideProviderChanged);
      AppLogger.debug('Listener del RideProvider configurado exitosamente');
    } catch (e) {
      AppLogger.error('Error configurando listener del RideProvider', e);
    }
  }
  
  void _onRideProviderChanged() {
    if (!mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null) {
      // Navegar al código de verificación cuando el conductor sea asignado
      if (currentTrip.status == 'accepted' || currentTrip.status == 'driver_arriving') {
        if (currentTrip.verificationCode != null) {
          Navigator.pushNamed(
            context,
            '/passenger/verification-code',
            arguments: currentTrip,
          );
        }
      }
    }
  }

  /// Solicitar permisos de ubicación al iniciar la app
  Future<void> _requestLocationPermission() async {
    if (!mounted) return;

    try {
      AppLogger.info('Solicitando permisos de ubicación para Google Maps');

      // Verificar permisos actuales
      LocationPermission permission = await Geolocator.checkPermission();

      // Si están denegados, solicitarlos
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Actualizar estado según resultado
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (!mounted) return;
        setState(() {
          _locationPermissionGranted = true;
        });
        AppLogger.info('Permisos de ubicación otorgados - MyLocation habilitado en Maps');
      } else {
        AppLogger.warning('Permisos de ubicación denegados - MyLocation deshabilitado en Maps');
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error solicitando permisos de ubicación', e, stackTrace);
    }
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar cualquier recurso
    _isDisposed = true;

    // Cancelar timers INMEDIATAMENTE para prevenir callbacks pendientes
    _negotiationTimer?.cancel();
    _negotiationTimer = null;
    _buttonDelayTimer?.cancel();
    _buttonDelayTimer = null;

    // Remover listener antes de dispose para evitar "widget deactivated" error
    try {
      if (mounted) {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.removeListener(_onRideProviderChanged);
      }
    } catch (e) {
      // Ignorar errores si el context ya no está disponible
      AppLogger.debug('Error removiendo listener en dispose: $e');
    }

    _bottomSheetController.dispose();
    _searchBarController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  /// ✅ Agregar marcador para ubicación seleccionada y hacer zoom
  /// Coloca un marcador en el mapa (verde para origen, rojo para destino)
  /// y centra el mapa en esa ubicación con zoom apropiado
  Future<void> _addMarkerAndZoom(LatLng position, String markerId, bool isPickup) async {
    // Crear marcador con color apropiado
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
      ),
      infoWindow: InfoWindow(
        title: isPickup ? 'Origen' : 'Destino',
      ),
    );

    if (!mounted) return;
    setState(() {
      // Remover marcador anterior con el mismo ID si existe
      _markers.removeWhere((m) => m.markerId.value == markerId);
      // Agregar nuevo marcador
      _markers.add(marker);
      // Activar modo de selección de ubicación
      _isSelectingLocation = true;
    });

    // Hacer zoom a la ubicación
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, _kZoomLevelMedium), // ✅ Constante: suficiente para ver la zona claramente
      );
      AppLogger.info('Zoom a ${isPickup ? "origen" : "destino"}: ${position.latitude}, ${position.longitude}');
    }

    // Si ambas ubicaciones están disponibles, hacer zoom para mostrar ambas
    if (_pickupCoordinates != null && _destinationCoordinates != null) {
      await _zoomToShowBothLocations();
    }
  }

  /// ✅ NUEVO: Activar modo de ajuste de ubicación de recogida
  /// Muestra un marcador fijo en el centro del mapa y permite al usuario
  /// mover el mapa debajo del marcador para ajustar la ubicación exacta
  void _startPickupAdjustment() {
    if (_pickupCoordinates == null) return;

    if (!mounted) return;
    setState(() {
      _isAdjustingPickup = true;
      // Ocultar todos los marcadores mientras se ajusta
      _markers.clear();
      // Ocultar la ruta mientras se ajusta
      _polylines.clear();
    });

    // Centrar el mapa en la ubicación de pickup
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupCoordinates!, _kZoomLevelClose),
      );
    }

    AppLogger.info('Modo de ajuste de pickup activado - mapa centrado en: ${_pickupCoordinates!.latitude}, ${_pickupCoordinates!.longitude}');
  }

  /// ✅ NUEVO: Confirmar la ubicación de recogida ajustada
  /// Obtiene las coordenadas del centro del mapa y las establece como punto de recogida
  Future<void> _confirmPickupLocation() async {
    if (_mapController == null || !mounted) return;

    try {
      // Obtener la posición central del mapa (donde está el marcador fijo)
      final LatLngBounds bounds = await _mapController!.getVisibleRegion();
      final LatLng center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      AppLogger.info('Ubicación de pickup confirmada: ${center.latitude}, ${center.longitude}');

      // Actualizar coordenadas de pickup
      setState(() {
        _pickupCoordinates = center;
      });

      // Hacer reverse geocoding para actualizar el campo de texto
      final newAddress = await _reverseGeocode(center);
      if (newAddress != null && mounted) {
        setState(() {
          _pickupController.text = newAddress;
        });
        AppLogger.info('Dirección actualizada: $newAddress');
      }

      // Restaurar marcadores y ruta
      await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
      if (_destinationCoordinates != null) {
        await _addMarkerAndZoom(_destinationCoordinates!, 'destination_marker', false);
        await _updateRoutePolyline();

        // Recalcular valores con la nueva ubicación
        final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
        final time = _estimateTime(distance);
        final price = _calculatePrice(distance);

        if (!mounted) return;
        setState(() {
          _calculatedDistance = distance;
          _estimatedTime = time;
          _suggestedPrice = price;
        });
        AppLogger.info('Ruta recalculada: $distance km, $time min, S/ ${price.toStringAsFixed(2)}');
      }

      // Salir del modo de ajuste
      if (!mounted) return;
      setState(() {
        _isAdjustingPickup = false;
      });

    } catch (e, stackTrace) {
      AppLogger.error('Error confirmando ubicación de pickup', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _isAdjustingPickup = false;
      });
    }
  }

  /// ✅ Hacer zoom para mostrar ambas ubicaciones (origen y destino)
  /// Calcula los límites (bounds) que incluyen ambos puntos y ajusta el zoom automáticamente
  Future<void> _zoomToShowBothLocations() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) return;
    if (_mapController == null) return;

    // Calcular límites que incluyan ambos puntos
    double southWestLat = min(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double southWestLng = min(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);
    double northEastLat = max(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double northEastLng = max(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    // Animar cámara para mostrar ambos puntos con padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _kMapBoundsPadding), // ✅ Constante: padding para LatLngBounds
    );

    AppLogger.info('Zoom ajustado para mostrar origen y destino');
  }

  void _startNegotiation() async {
    // Validar que se hayan ingresado origen y destino
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes ingresar origen y destino'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Usuario no autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _showPriceNegotiation = true;
      });

      // Obtener ubicación real del GPS del dispositivo
      LatLng? currentLocation = await _getCurrentLocation();
      if (currentLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación actual. Verifica los permisos GPS.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Geocoding real para destino (si no se proporcionó coordenadas específicas)
      LatLng? destinationLocation = await _getDestinationLocation();
      if (destinationLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo encontrar la dirección de destino'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Crear solicitud de viaje REAL usando ubicaciones reales
      await rideProvider.requestRide(
        pickupLocation: currentLocation, // UBICACIÓN GPS REAL
        destinationLocation: destinationLocation, // DESTINO REAL GEOCODIFICADO
        pickupAddress: _pickupController.text.isEmpty ? 'Mi ubicación actual' : _pickupController.text,
        destinationAddress: _destinationController.text,
        userId: user.id,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Buscando conductores disponibles...'),
          backgroundColor: ModernTheme.oasisGreen,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _showPriceNegotiation = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar viaje: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ FIX: Método para cancelar la negociación de precio y limpiar todo
  /// Permite al usuario volver atrás y empezar de nuevo
  void _cancelPriceNegotiation() {
    AppLogger.info('Cancelando negociación de precio - limpiando estado');

    if (!mounted) return;
    setState(() {
      // Ocultar price negotiation sheet
      _showPriceNegotiation = false;

      // Limpiar la ruta del mapa
      _polylines.clear();

      // Limpiar marcadores
      _markers.clear();

      // Resetear coordenadas
      _pickupCoordinates = null;
      _destinationCoordinates = null;

      // Limpiar campos de texto
      _pickupController.clear();
      _destinationController.clear();
      _priceController.clear();

      // Resetear estados
      _isSelectingLocation = false;
      _isManualPriceEntry = false;
      _calculatedDistance = null;
      _estimatedTime = null;
      _suggestedPrice = null;
      _offeredPrice = 15.0; // Valor por defecto
      _showContinueButton = false; // ✅ Resetear estado del botón
      _isAdjustingPickup = false; // ✅ Salir del modo de ajuste
    });

    // ✅ Cancelar timer del botón si existe
    _buttonDelayTimer?.cancel();

    AppLogger.info('Estado reseteado completamente - usuario puede comenzar de nuevo');
  }

  void _simulateDriverOffers() {
    _negotiationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir uso después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentNegotiation != null &&
          _currentNegotiation!.driverOffers.length < 5) {
        setState(() {
          final newOffer = models.DriverOffer(
            driverId: 'driver${_currentNegotiation!.driverOffers.length}',
            driverName: 'Conductor ${_currentNegotiation!.driverOffers.length + 1}',
            driverPhoto: '', // Se obtiene del perfil del conductor desde Firebase
            driverRating: 4.5 + (_currentNegotiation!.driverOffers.length * 0.1),
            vehicleModel: ['Toyota Corolla', 'Nissan Sentra', 'Hyundai Accent'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            vehiclePlate: 'ABC-${100 + _currentNegotiation!.driverOffers.length}',
            vehicleColor: ['Blanco', 'Negro', 'Gris'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            acceptedPrice: _offeredPrice - (_currentNegotiation!.driverOffers.length * 0.5),
            estimatedArrival: 3 + _currentNegotiation!.driverOffers.length,
            offeredAt: DateTime.now(),
            status: models.OfferStatus.pending,
            completedTrips: 500 + (_currentNegotiation!.driverOffers.length * 100),
            acceptanceRate: 90.0 + _currentNegotiation!.driverOffers.length,
          );
          
          _currentNegotiation = _currentNegotiation!.copyWith(
            driverOffers: [..._currentNegotiation!.driverOffers, newOffer],
            status: models.NegotiationStatus.negotiating,
          );
          
          _showDriverOffers = true;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OasisAppBar(
        title: 'Oasis Taxi',
        showBackButton: false,
        actions: [
          ModeSwitchButton(compact: true),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/shared/notifications'),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: GestureDetector(
        onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera de los campos (Android compatible)
        child: Stack(
          children: [
            // Mapa con estilo limpio (sin POIs ni distracciones)
            GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller, // ✅ Habilitado para controlar zoom y cámara
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: _locationPermissionGranted, // Solo habilitar si hay permisos
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _cleanMapStyle, // ✅ Aplica estilo limpio que oculta POIs y etiquetas
          ),

          // ✅ NUEVO: Marcador fijo en el centro del mapa (solo visible en modo de ajuste)
          if (_isAdjustingPickup)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Marcador azul fijo en el centro
                  Icon(
                    Icons.location_on,
                    size: 48,
                    color: Colors.blue,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  // Texto descriptivo
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Mueve el mapa para ajustar tu ubicación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ NUEVO: Botón de confirmar ubicación (solo visible en modo de ajuste)
          if (_isAdjustingPickup)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: AnimatedPulseButton(
                text: 'Confirmar ubicación',
                icon: Icons.check,
                onPressed: () async {
                  await _confirmPickupLocation();
                  // Después de confirmar, mostrar la negociación de precio
                  if (!mounted) return;
                  setState(() {
                    _showPriceNegotiation = true;
                  });
                },
              ),
            ),

          // Barra de búsqueda superior
          // ✅ Ocultar cuando está ajustando pickup
          if (!_isAdjustingPickup)
            SafeArea(
              child: AnimatedBuilder(
                animation: _searchBarAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -100 * (1 - _searchBarAnimation.value)),
                    child: Opacity(
                      opacity: _searchBarAnimation.value,
                      child: _buildSearchBar(),
                    ),
                  );
                },
              ),
            ),

          // Selector de tipo de servicio (debajo de la barra de búsqueda)
          // ✅ Ocultar cuando el usuario está seleccionando ubicaciones o ajustando pickup
          if (!_isSelectingLocation && !_isAdjustingPickup)
            Positioned(
              top: 160, // Debajo de la barra de búsqueda
              left: 0,
              right: 0,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _searchBarAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -100 * (1 - _searchBarAnimation.value)),
                      child: Opacity(
                        opacity: _searchBarAnimation.value,
                        child: _buildServiceSelector(),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Bottom sheet con negociación de precio
          // ✅ Ocultar cuando está ajustando pickup
          if (!_isAdjustingPickup)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7, // Limitar altura máxima a 70% de pantalla
                child: AnimatedBuilder(
                  animation: _bottomSheetAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 400 * (1 - _bottomSheetAnimation.value)),
                      child: _showDriverOffers
                          ? _buildDriverOffersSheet()
                          : _showPriceNegotiation
                              ? _buildPriceNegotiationSheet()
                              : _buildDestinationSheet(),
                    );
                  },
                ),
              ),
            ),


          // Botón de ubicación actual
          // ✅ Ocultar cuando está ajustando pickup
          if (!_isAdjustingPickup)
            Positioned(
              right: 16,
              bottom: _showPriceNegotiation ? 420 : 320,
              child: _buildLocationButton(),
            ),
        ], // Stack children
      ), // Stack
      ), // GestureDetector
    ); // Scaffold
  }
  
  /// ✅ Widget reutilizable para campos de dirección (DRY - elimina duplicación)
  /// ✅ SOLUCIÓN DEFINITIVA: Usa CustomPlaceTextField con flutter_typeahead
  /// Resuelve el problema del teclado (borrado letra por letra) porque NO recrea el TextField
  Widget _buildAddressField({
    required TextEditingController controller,
    required String hintText,
    required Color markerColor,
    required bool isPickup,
  }) {
    return CustomPlaceTextField(
      controller: controller,
      hintText: hintText,
      googleApiKey: _googleMapsApiKey,
      onTap: () {
        // ✅ FIX: Siempre activar modo de selección cuando el usuario toca el campo
        // Esto asegura que los bloques se oculten correctamente incluso cuando
        // el usuario regresa de la negociación de precio
        if (mounted) {
          setState(() {
            _isSelectingLocation = true;
          });
          AppLogger.info('Usuario tocó campo ${isPickup ? "origen" : "destino"} - UI ocultada');
        }
      },
      onPlaceSelected: (PlacePrediction prediction) async {
        // Cuando se selecciona un lugar con coordenadas
        if (prediction.lat != null && prediction.lng != null) {
          final coords = LatLng(prediction.lat!, prediction.lng!);

          if (!mounted) return;
          setState(() {
            if (isPickup) {
              _pickupCoordinates = coords;
            } else {
              _destinationCoordinates = coords;
            }

            // Marcar que está buscando destino (solo para destination field)
            if (!isPickup) {
              _isSearchingDestination = true;
            }
          });

          AppLogger.info('${isPickup ? "Pickup" : "Destination"} coordinates guardadas: ${coords.latitude}, ${coords.longitude}');

          // Agregar marcador (verde para origen, rojo para destino) y hacer zoom
          await _addMarkerAndZoom(
            coords,
            isPickup ? 'pickup_marker' : 'destination_marker',
            isPickup,
          );

          // ✅ NUEVO: Si ambas coordenadas existen, actualizar polyline automáticamente
          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            AppLogger.info('Ambas coordenadas disponibles - actualizando polyline automáticamente');
            await _updateRoutePolyline();

            // ✅ Después de actualizar polyline, resetear _isSelectingLocation para mostrar UI
            if (!mounted) return;
            setState(() {
              _isSelectingLocation = false;
            });
            AppLogger.info('Polyline actualizado - UI normal restaurada');
          }
        }
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo de recogida - ✅ Refactorizado con widget reutilizable (DRY)
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                // Círculo verde de marcador de origen
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: ModernTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                // Campo de autocompletado de dirección
                Expanded(
                  child: _buildAddressField(
                    controller: _pickupController,
                    hintText: '¿Dónde estás?',
                    markerColor: ModernTheme.success,
                    isPickup: true,
                  ),
                ),
                // ✅ Botón para usar ubicación actual (GPS con reverse geocoding)
                IconButton(
                  icon: Icon(Icons.my_location, color: ModernTheme.primaryOrange),
                  onPressed: () async {
                    // ✅ NUEVO: Mostrar indicador de carga mientras obtiene ubicación
                    _pickupController.text = 'Obteniendo ubicación...';

                    // Obtener coordenadas GPS reales
                    final currentLocation = await _getCurrentLocation();
                    if (currentLocation != null && mounted) {
                      // ✅ NUEVO: Hacer reverse geocoding para obtener dirección legible
                      final address = await _reverseGeocode(currentLocation);

                      if (!mounted) return;
                      setState(() {
                        _pickupCoordinates = currentLocation;
                        // Mostrar dirección real si está disponible, sino mostrar "Mi ubicación actual"
                        _pickupController.text = address ?? 'Mi ubicación actual';
                      });
                      _addMarkerAndZoom(currentLocation, 'pickup_marker', true);

                      AppLogger.info('Ubicación GPS con dirección: $address');
                    } else {
                      // Si no se pudo obtener ubicación, limpiar el campo
                      if (!mounted) return;
                      setState(() {
                        _pickupController.text = '';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Campo de destino - ✅ Refactorizado con widget reutilizable (DRY)
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                // Círculo rojo de marcador de destino
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: ModernTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                // Campo de autocompletado de dirección
                Expanded(
                  child: _buildAddressField(
                    controller: _destinationController,
                    hintText: '¿A dónde vas?',
                    markerColor: ModernTheme.error,
                    isPickup: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDestinationSheet() {
    // ✅ Detectar si el teclado está abierto
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Verificar si ambos campos están llenos
    final bool canContinue = _pickupController.text.isNotEmpty &&
                             _destinationController.text.isNotEmpty;

    // ✅ FIX CRÍTICO: Usar WidgetsBinding.addPostFrameCallback para evitar setState durante build
    // Si ambos campos están llenos Y el teclado está cerrado, iniciar timer
    if (canContinue && !isKeyboardOpen && !_showContinueButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Cancelar timer anterior si existe
        _buttonDelayTimer?.cancel();
        // Esperar 300ms después de que el teclado se cierre para mostrar botón
        _buttonDelayTimer = Timer(Duration(milliseconds: 300), () {
          if (mounted && canContinue && !isKeyboardOpen) {
            setState(() {
              _showContinueButton = true;
            });
          }
        });
      });
    } else if (!canContinue || isKeyboardOpen) {
      // Si los campos no están llenos o el teclado está abierto, ocultar botón
      if (_showContinueButton) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buttonDelayTimer?.cancel();
          if (mounted) {
            setState(() {
              _showContinueButton = false;
            });
          }
        });
      }
    }

    // DraggableScrollableSheet para permitir arrastrar con el dedo
    // ✅ Tamaños condicionales:
    // - Seleccionando ubicación: 8% (solo handle visible)
    // - Con botón "Continuar": 50% (expandido para mostrar botón completo)
    // - Sin botón "Continuar": 35% (tamaño normal)
    return DraggableScrollableSheet(
      initialChildSize: _isSelectingLocation ? 0.08 : (_showContinueButton ? 0.50 : 0.35), // ✅ 50% cuando hay botón VISIBLE
      minChildSize: _isSelectingLocation ? 0.08 : 0.2,      // 8% cuando selecciona, 20% normal
      maxChildSize: 0.65,     // Máximo 65% (sin cubrir todo el mapa)
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_kBorderRadiusXLarge)),
            boxShadow: ModernTheme.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual para indicar que es draggable
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(_kBorderRadiusTiny),
                ),
              ),

              // Contenido con scroll (CRÍTICO: pasar scrollController aquí)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController, // ¡IMPORTANTE! Para que drag y scroll trabajen juntos
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Ocultar favoritos y recientes cuando está seleccionando ubicaciones (mapa limpio)
                      if (!_isSelectingLocation) ...[
                        // Lugares favoritos
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lugares favoritos',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildFavoritePlace(Icons.home, 'Casa'),
                                  _buildFavoritePlace(Icons.work, 'Trabajo'),
                                  _buildFavoritePlace(Icons.school, 'Universidad'),
                                  _buildFavoritePlace(Icons.add, 'Agregar'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Divider(height: 1),

                        // Destinos recientes
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recientes',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 12),
                              _buildRecentPlace('Centro Comercial Plaza', 'Av. Principal 123'),
                              _buildRecentPlace('Aeropuerto Internacional', 'Terminal 1'),
                              _buildRecentPlace('Parque Central', 'Calle Principal s/n'),
                            ],
                          ),
                        ),
                      ],

                      // ✅ FIX OVERFLOW + DELAY: Botón Continuar DENTRO del scrollable (solo visible después de cerrar teclado)
                      if (_showContinueButton)
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: AnimatedPulseButton(
                            text: 'Continuar',
                            icon: Icons.arrow_forward,
                            onPressed: () async {
                              if (!mounted) return;

                              // ✅ Resetear estado del botón inmediatamente al presionar
                              setState(() {
                                _showContinueButton = false;
                              });
                              _buttonDelayTimer?.cancel();

                              // ✅ Capturar ScaffoldMessenger ANTES de cualquier await para evitar warnings
                              final scaffoldMessenger = ScaffoldMessenger.of(context);

                              // ✅ Si no hay coordenadas de origen, obtener ubicación GPS actual automáticamente
                              if (_pickupCoordinates == null) {
                                AppLogger.info('No hay origen seleccionado, obteniendo ubicación GPS actual...');
                                final currentLocation = await _getCurrentLocation();
                                if (!mounted) return;

                                if (currentLocation != null) {
                                  setState(() {
                                    _pickupCoordinates = currentLocation;
                                  });
                                  AppLogger.info('Origen establecido a ubicación GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');
                                } else {
                                  AppLogger.warning('No se pudo obtener ubicación GPS');
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('No se pudo obtener tu ubicación actual')),
                                  );
                                  return;
                                }
                              }

                              // CALCULAR VALORES REALES con coordenadas reales
                              if (_pickupCoordinates != null && _destinationCoordinates != null) {
                                final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
                                final time = _estimateTime(distance);
                                final price = _calculatePrice(distance);

                                // ✅ Verificar mounted antes de setState
                                if (!mounted) return;
                                setState(() {
                                  _calculatedDistance = distance;
                                  _estimatedTime = time;
                                  _suggestedPrice = price;
                                  _offeredPrice = price; // Inicializar precio ofertado con el sugerido
                                  _isSelectingLocation = false; // ✅ Desactivar modo de selección para mostrar UI normal
                                });

                                // Dibujar línea de ruta REAL en el mapa (siguiendo calles)
                                await _updateRoutePolyline();
                                if (!mounted) return;

                                AppLogger.info('Ruta calculada con coordenadas REALES: $distance km, $time min, S/ ${price.toStringAsFixed(2)}');

                                // ✅ NUEVO: Activar modo de ajuste de pickup en lugar de ir directo a negociación
                                _startPickupAdjustment();
                              } else {
                                // Si aún no hay destino, mostrar advertencia
                                AppLogger.warning('Falta seleccionar destino');
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Por favor selecciona un destino')),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPriceNegotiationSheet() {
    // Calcular valores reales si tenemos coordenadas
    String distanceTimeText = 'Calculando ruta...';
    String suggestedPriceText = 'Calculando precio...';

    if (_calculatedDistance != null && _estimatedTime != null && _suggestedPrice != null) {
      // Usar valores calculados REALES
      distanceTimeText = '${_calculatedDistance!.toStringAsFixed(1)} km • $_estimatedTime min';
      suggestedPriceText = 'Precio sugerido: S/ ${_suggestedPrice!.toStringAsFixed(2)}';
    } else if (_pickupCoordinates != null && _destinationCoordinates != null) {
      // Calcular ahora si aún no se ha hecho
      final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
      final time = _estimateTime(distance);
      final price = _calculatePrice(distance);

      distanceTimeText = '${distance.toStringAsFixed(1)} km • $time min';
      suggestedPriceText = 'Precio sugerido: S/ ${price.toStringAsFixed(2)}';
    }

    // NotificationListener para detectar cuando el usuario arrastra el sheet y ocultar el teclado
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        // ✅ Ocultar teclado cuando el usuario empieza a arrastrar el sheet (Android compatible)
        _hideKeyboard();
        if (mounted) {
          setState(() => _isManualPriceEntry = false);
        }
        return false; // No consumir la notificación (permitir que se propague)
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6, // ✅ FIX OVERFLOW: 60% de la pantalla (aumentado de 0.5 para eliminar overflow de 51px)
        minChildSize: 0.3,     // Mínimo 30%
        maxChildSize: 0.85,    // Máximo 85%
        builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_kBorderRadiusXLarge)),
            boxShadow: ModernTheme.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual para indicar que es draggable
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(_kBorderRadiusTiny),
                ),
              ),

              // ✅ FIX: Header con botón cancelar para volver atrás
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Botón para cancelar y volver atrás
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: ModernTheme.textPrimary),
                      onPressed: _cancelPriceNegotiation,
                      tooltip: 'Volver',
                    ),
                    // Título centrado
                    Expanded(
                      child: Center(
                        child: Text(
                          'Ofrece tu precio',
                          style: TextStyle(
                            fontSize: _kFontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // SizedBox para balancear el IconButton y mantener el título centrado
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // Contenido con scroll
              Expanded(
                child: GestureDetector(
                  // ✅ Ocultar teclado al hacer tap fuera del TextField (Android compatible)
                  onTap: () {
                    _hideKeyboard();
                    if (!mounted) return;
                    setState(() => _isManualPriceEntry = false);
                  },
                  child: SingleChildScrollView(
                    controller: scrollController, // CRÍTICO: Para que drag y scroll trabajen juntos
                    child: Padding(
                      padding: EdgeInsets.all(8), // ✅ Reducido de 14 a 8 (ahorra 12px adicionales)
                      child: Column(
                        children: [
                        // ✅ Texto descriptivo (el título ya está en el header)
                        Text(
                          'Los conductores cercanos verán tu oferta',
                          style: TextStyle(
                            fontSize: 14,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Información del viaje CON VALORES REALES (sin placeholders)
                        Container(
                          padding: EdgeInsets.all(10), // ✅ Reducido de 14 a 10 (ahorra 4px adicionales)
                          decoration: BoxDecoration(
                            color: ModernTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.route, color: ModernTheme.primaryBlue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      distanceTimeText, // VALOR REAL CALCULADO
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      suggestedPriceText, // VALOR REAL CALCULADO
                                      style: TextStyle(
                                        color: ModernTheme.success,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Opciones de precio sugeridas (3-4 botones con diferentes precios en S/)
                        Text(
                          'Selecciona tu precio:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ModernTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6), // ✅ Reducido de 10 a 6 (ahorra 4px adicionales)

                        // Botones de sugerencia de precio
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 0.9), // -10%
                            _buildPriceSuggestionButton(_suggestedPrice ?? 15.0), // Precio sugerido (destacado)
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.1), // +10%
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.2), // +20%
                          ],
                        ),
                        SizedBox(height: 8), // ✅ Reducido de 12 a 8 (ahorra 4px adicionales)

                        // TextField para entrada manual de precio
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: ModernTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
                            border: Border.all(
                              color: _isManualPriceEntry ? ModernTheme.primaryOrange : Colors.grey.shade300,
                              width: _isManualPriceEntry ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'S/',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.w600,
                                  color: ModernTheme.textPrimary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _priceController,
                                  focusNode: _priceFocusNode,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    fontSize: _kFontSizeLarge,
                                    fontWeight: FontWeight.w600,
                                    color: ModernTheme.primaryOrange,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ingresa tu precio',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() => _isManualPriceEntry = true);
                                  },
                                  onChanged: (value) {
                                    final price = double.tryParse(value);
                                    if (price != null && mounted) {
                                      setState(() => _offeredPrice = price);
                                    }
                                  },
                                  onSubmitted: (_) {
                                    // ✅ Ocultar teclado al presionar Enter (Android compatible)
                                    _hideKeyboard();
                                    if (!mounted) return;
                                    setState(() => _isManualPriceEntry = false);
                                  },
                                ),
                              ),
                              if (_priceController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    _priceController.clear();
                                    _hideKeyboard(); // ✅ Ocultar teclado (Android compatible)
                                    if (!mounted) return;
                                    setState(() {
                                      _isManualPriceEntry = false;
                                      _offeredPrice = _suggestedPrice ?? 15.0;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Métodos de pago - Usar Wrap para evitar overflow
                        Wrap(
                          spacing: 12, // Espacio horizontal entre elementos
                          runSpacing: 12, // Espacio vertical si hay salto de línea
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPaymentMethod(Icons.money, 'Efectivo', _selectedPaymentMethod == 'Efectivo'),
                            _buildPaymentMethod(Icons.credit_card, 'Tarjeta', _selectedPaymentMethod == 'Tarjeta'),
                            _buildPaymentMethod(Icons.account_balance_wallet, 'Billetera', _selectedPaymentMethod == 'Billetera'),
                          ],
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Botón de buscar conductor
                        AnimatedPulseButton(
                          text: 'Buscar conductor',
                          icon: Icons.search,
                          onPressed: _startNegotiation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ), // Cierre del Expanded
          ],
          ),
        );
      },
    ),
    );  // Cierre del NotificationListener
  }

  Widget _buildDriverOffersSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título con contador
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ofertas de conductores',
                      style: TextStyle(
                        fontSize: _kFontSizeXLarge,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_currentNegotiation?.driverOffers.length ?? 0} conductores interesados',
                      style: TextStyle(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Timer countdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: ModernTheme.warning),
                      SizedBox(width: 4),
                      Text(
                        '${_currentNegotiation?.timeRemaining.inMinutes ?? 0}:${(_currentNegotiation?.timeRemaining.inSeconds ?? 0) % 60}',
                        style: TextStyle(
                          color: ModernTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de ofertas
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: _currentNegotiation?.driverOffers.length ?? 0,
              itemBuilder: (context, index) {
                final offer = _currentNegotiation!.driverOffers[index];
                return _buildDriverOfferCard(offer);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverOfferCard(models.DriverOffer offer) {
    return AnimatedElevatedCard(
      onTap: () {
        // Aceptar oferta
        _showDriverAcceptedDialog(offer);
      },
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // Foto del conductor
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(offer.driverPhoto),
            ),
            SizedBox(width: 12),
            
            // Información del conductor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        offer.driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: ModernTheme.info),
                      SizedBox(width: 4),
                      Text(
                        '${offer.estimatedArrival} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.info,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.directions_car, size: 14, color: ModernTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        '${offer.completedTrips} viajes',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Precio ofertado
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
              ),
              child: Text(
                'S/ ${offer.acceptedPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: ModernTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFavoritePlace(IconData icon, String label) {
    return InkWell(
      onTap: () {
        if (label != 'Agregar') {
          _destinationController.text = label;
          if (!mounted) return;
          setState(() => _showPriceNegotiation = true);
        }
      },
      borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ModernTheme.primaryOrange),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentPlace(String title, String subtitle) {
    return InkWell(
      onTap: () {
        _destinationController.text = title;
        if (!mounted) return;
        setState(() => _showPriceNegotiation = true);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: ModernTheme.textSecondary,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: ModernTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethod(IconData icon, String label, bool selected) {
    return InkWell(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedPaymentMethod = label;
        });
        AppLogger.info('Método de pago seleccionado: $label');
      },
      borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ModernTheme.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? ModernTheme.primaryOrange : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? ModernTheme.primaryOrange : ModernTheme.textSecondary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? ModernTheme.primaryOrange : ModernTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir botón de sugerencia de precio
  /// Muestra un precio específico en soles (S/) y lo resalta si es el precio actualmente ofertado
  Widget _buildPriceSuggestionButton(double price) {
    // Verificar si este precio es el actualmente seleccionado (con tolerancia de 0.01 para comparación de doubles)
    final bool isSelected = (_offeredPrice - price).abs() < 0.01;

    return InkWell(
      onTap: () {
        if (!mounted) return;

        // ✅ Ocultar teclado si está abierto (Android compatible)
        _hideKeyboard();

        setState(() {
          // Actualizar precio ofertado
          _offeredPrice = price;
          // Actualizar el TextField con el valor seleccionado
          _priceController.text = price.toStringAsFixed(2);
          // Marcar que NO es entrada manual (es selección de botón)
          _isManualPriceEntry = false;
        });

        AppLogger.info('Precio seleccionado desde botón: S/ ${price.toStringAsFixed(2)}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
            ? ModernTheme.primaryOrange
            : ModernTheme.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
              ? ModernTheme.primaryOrange
              : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ModernTheme.primaryOrange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ]
            : null,
        ),
        child: Text(
          'S/ ${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : ModernTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Construir selector de tipo de servicio (horizontal)
  Widget _buildServiceSelector() {
    return Container(
      height: 120,
      margin: EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildServiceTypeCard(
            type: ServiceType.standard,
            icon: Icons.local_taxi,
            name: 'Taxi\nEstándar',
            description: '1-4 pasajeros',
            priceMultiplier: '1.0x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.xl,
            icon: Icons.airport_shuttle,
            name: 'Taxi\nXL',
            description: '5-6 pasajeros',
            priceMultiplier: '1.5x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.premium,
            icon: Icons.drive_eta,
            name: 'Taxi\nPremium',
            description: 'Lujo, 1-4 pax',
            priceMultiplier: '2.0x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.delivery,
            icon: Icons.local_shipping,
            name: 'Delivery\nExpress',
            description: 'Solo paquetes',
            priceMultiplier: '0.8x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.moto,
            icon: Icons.two_wheeler,
            name: 'Moto\nTaxi',
            description: '1 pasajero',
            priceMultiplier: '0.7x',
          ),
        ],
      ),
    );
  }

  /// Construir tarjeta de tipo de servicio individual
  Widget _buildServiceTypeCard({
    required ServiceType type,
    required IconData icon,
    required String name,
    required String description,
    required String priceMultiplier,
  }) {
    final bool isSelected = _selectedServiceType == type;

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedServiceType = type;
          // Recalcular precio si ya hay coordenadas
          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
            final price = _calculatePrice(distance);
            _suggestedPrice = price;
            _offeredPrice = price;
            AppLogger.info('Tipo de servicio cambiado a: $type, nuevo precio: S/ ${price.toStringAsFixed(2)}');
          }
        });
        // Actualizar polyline si cambia el tipo de servicio (mantener la ruta visible)
        _updateRoutePolyline(); // No necesita await aquí (fire and forget)
      },
      child: Container(
        width: _kServiceCardWidth,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.primaryOrange : Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
          border: Border.all(
            color: isSelected ? ModernTheme.primaryOrange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ModernTheme.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : ModernTheme.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.all(8), // Reducido de 12 a 8 (ahorra 8px verticales)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28, // Reducido de 32 a 28 (ahorra 4px)
                color: isSelected ? Colors.white : ModernTheme.primaryOrange,
              ),
              SizedBox(height: 6), // Reducido de 8 a 6 (ahorra 2px)
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : ModernTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 3), // Reducido de 4 a 3 (ahorra 1px)
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : ModernTheme.textSecondary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                priceMultiplier,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : ModernTheme.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Botón flotante para centrar el mapa en la ubicación GPS actual
  Widget _buildLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.cardShadow,
      ),
      child: IconButton(
        icon: Icon(Icons.my_location, color: ModernTheme.primaryOrange),
        onPressed: () async {
          // Obtener ubicación GPS actual
          final currentLocation = await _getCurrentLocation();
          if (currentLocation != null && _mapController != null && mounted) {
            // Centrar el mapa en la ubicación actual con zoom apropiado
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(currentLocation, _kZoomLevelClose), // ✅ Constante: muy cerca para ver detalles
            );
            AppLogger.info('Mapa centrado en ubicación GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');
          }
        },
      ),
    );
  }
  
  void _showDriverAcceptedDialog(models.DriverOffer offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: ModernTheme.success),
            SizedBox(height: 20),
            Text(
              '¡Conductor encontrado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${offer.driverName} está en camino',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
            SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Ver detalles',
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a pantalla de seguimiento
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header del drawer unificado
            OasisDrawerHeader(
              userType: 'passenger',
              userName: 'Usuario Pasajero',
            ),
            
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Historial de Viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.star,
                    title: 'Mis Calificaciones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/ratings-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Métodos de Pago',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/payment-methods');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.favorite,
                    title: 'Lugares Favoritos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/favorites');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_offer,
                    title: 'Promociones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/promotions');
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Mi Perfil',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/profile');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Ayuda',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AboutScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Cerrar Sesión',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    color: ModernTheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? ModernTheme.oasisGreen,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? ModernTheme.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Obtener ubicación GPS REAL del dispositivo
  Future<LatLng?> _getCurrentLocation() async {
    try {
      AppLogger.info('Obteniendo ubicación GPS real del dispositivo');

      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Permisos de ubicación denegados permanentemente');
        return null;
      }

      // Obtener ubicación actual real
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final LatLng currentLocation = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación GPS real obtenida: ${position.latitude}, ${position.longitude}');

      return currentLocation;

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación GPS real', e, stackTrace);
      return null;
    }
  }

  /// ✅ NUEVO: Obtener dirección legible desde coordenadas GPS (Reverse Geocoding)
  /// Convierte LatLng a dirección de calle legible para el usuario
  Future<String?> _reverseGeocode(LatLng coordinates) async {
    try {
      AppLogger.info('Realizando reverse geocoding para: ${coordinates.latitude}, ${coordinates.longitude}');

      // Obtener placemarks (lugares) desde las coordenadas
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isEmpty) {
        AppLogger.warning('No se encontraron resultados de reverse geocoding');
        return null;
      }

      // Tomar el primer resultado (el más relevante)
      final Placemark place = placemarks.first;

      // Construir dirección legible
      // Formato: "Calle, Número, Distrito, Ciudad"
      List<String> addressParts = [];

      if (place.street != null && place.street!.isNotEmpty) {
        addressParts.add(place.street!);
      }
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        addressParts.add(place.subLocality!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        addressParts.add(place.locality!);
      }

      final String address = addressParts.join(', ');

      if (address.isEmpty) {
        AppLogger.warning('Dirección vacía después de reverse geocoding');
        return 'Ubicación encontrada (${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)})';
      }

      AppLogger.info('Reverse geocoding exitoso: $address');
      return address;

    } catch (e, stackTrace) {
      AppLogger.error('Error en reverse geocoding', e, stackTrace);
      return null;
    }
  }

  /// Obtener ubicación de destino REAL desde Google Places autocomplete
  Future<LatLng?> _getDestinationLocation() async {
    if (_destinationController.text.trim().isEmpty) {
      AppLogger.warning('Dirección de destino vacía');
      return null;
    }

    try {
      // Usar coordenadas obtenidas de Google Places autocomplete
      if (_destinationCoordinates != null) {
        AppLogger.info('Usando coordenadas de Google Places: ${_destinationCoordinates!.latitude}, ${_destinationCoordinates!.longitude}');
        return _destinationCoordinates;
      }

      // Si no hay coordenadas (usuario escribió pero no seleccionó de la lista)
      AppLogger.warning('Usuario escribió dirección pero no seleccionó de autocomplete. Coordenadas no disponibles.');

      // Fallback: usar coordenadas del centro de Lima
      final fallbackCoordinates = LatLng(-12.0464, -77.0428);
      AppLogger.warning('Usando coordenadas fallback (centro de Lima): ${fallbackCoordinates.latitude}, ${fallbackCoordinates.longitude}');
      return fallbackCoordinates;

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación de destino', e, stackTrace);
      return null;
    }
  }

  /// Calcular distancia REAL entre dos coordenadas usando fórmula Haversine
  /// Retorna la distancia en kilómetros
  double _calculateDistance(LatLng start, LatLng end) {
    // Radio de la Tierra en km
    const double earthRadiusKm = 6371.0;

    // Convertir grados a radianes
    final double lat1Rad = start.latitude * (3.141592653589793 / 180.0);
    final double lat2Rad = end.latitude * (3.141592653589793 / 180.0);
    final double deltaLatRad = (end.latitude - start.latitude) * (3.141592653589793 / 180.0);
    final double deltaLonRad = (end.longitude - start.longitude) * (3.141592653589793 / 180.0);

    // Fórmula Haversine
    final double a = (sin(deltaLatRad / 2) * sin(deltaLatRad / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distanceKm = earthRadiusKm * c;

    AppLogger.info('Distancia calculada (Haversine): ${distanceKm.toStringAsFixed(2)} km');
    return distanceKm;
  }

  /// Calcular tiempo estimado REAL basado en distancia
  /// Usa velocidad promedio de Lima en tráfico: ~20 km/h
  /// Retorna el tiempo en minutos
  int _estimateTime(double distanceKm) {
    // Velocidad promedio en Lima considerando tráfico
    const double averageSpeedKmh = 20.0;

    // Tiempo = distancia / velocidad (en horas), luego convertir a minutos
    final double timeHours = distanceKm / averageSpeedKmh;
    final int timeMinutes = (timeHours * 60).round();

    AppLogger.info('Tiempo estimado: $timeMinutes minutos (${distanceKm.toStringAsFixed(2)} km a $averageSpeedKmh km/h)');
    return timeMinutes;
  }

  /// Calcular precio sugerido REAL basado en distancia y tipo de servicio
  /// Fórmula: (Tarifa base + (distancia * tarifa por km)) * multiplicador de servicio
  /// Retorna el precio en soles (S/)
  double _calculatePrice(double distanceKm) {
    // Tarifas base de Oasis Taxi
    const double baseFare = 5.0; // Tarifa base en soles
    const double ratePerKm = 2.0; // Tarifa por kilómetro en soles

    // Multiplicadores por tipo de servicio
    double serviceMultiplier;
    String serviceName;

    switch (_selectedServiceType) {
      case ServiceType.standard:
        serviceMultiplier = 1.0; // Precio estándar
        serviceName = 'Taxi Estándar';
        break;
      case ServiceType.xl:
        serviceMultiplier = 1.5; // 50% más caro (vehículo grande)
        serviceName = 'Taxi XL';
        break;
      case ServiceType.premium:
        serviceMultiplier = 2.0; // Doble del precio (vehículo de lujo)
        serviceName = 'Taxi Premium';
        break;
      case ServiceType.delivery:
        serviceMultiplier = 0.8; // 20% más barato (solo paquetes, no pasajeros)
        serviceName = 'Delivery Express';
        break;
      case ServiceType.moto:
        serviceMultiplier = 0.7; // 30% más barato (moto, solo 1 pasajero)
        serviceName = 'Moto Taxi';
        break;
    }

    // Cálculo: (base + (distancia * tarifa)) * multiplicador
    final double basePrice = baseFare + (distanceKm * ratePerKm);
    final double totalPrice = basePrice * serviceMultiplier;

    AppLogger.info('Precio calculado: S/ ${totalPrice.toStringAsFixed(2)} ($serviceName x$serviceMultiplier: base S/ $baseFare + ${distanceKm.toStringAsFixed(2)} km × S/ $ratePerKm/km)');
    return totalPrice;
  }

  /// Obtener puntos de la ruta REAL desde Google Directions API
  /// Retorna lista de LatLng que forman la ruta siguiendo las calles
  Future<List<LatLng>> _getRoutePolylinePoints(LatLng origin, LatLng destination) async {
    try {
      AppLogger.info('Obteniendo ruta real desde Google Directions API: ${origin.latitude},${origin.longitude} → ${destination.latitude},${destination.longitude}');

      // Inicializar PolylinePoints con la API key
      PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleMapsApiKey);

      // Solicitar la ruta desde la Directions API
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving, // Modo de conducción
        ),
      );

      // Verificar si la solicitud fue exitosa
      if (result.points.isNotEmpty) {
        // Convertir los puntos de PointLatLng a LatLng de Google Maps
        List<LatLng> polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        AppLogger.info('Ruta real obtenida con ${polylineCoordinates.length} puntos desde Directions API');
        return polylineCoordinates;
      } else {
        // Si no hay puntos, mostrar el error
        AppLogger.warning('No se pudo obtener ruta desde Directions API. Error: ${result.errorMessage}');

        // Fallback: retornar línea recta si falla la API
        AppLogger.info('Usando fallback: línea recta entre origen y destino');
        return [origin, destination];
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ruta desde Directions API', e, stackTrace);

      // Fallback: retornar línea recta en caso de error
      AppLogger.info('Usando fallback por error: línea recta entre origen y destino');
      return [origin, destination];
    }
  }

  /// Actualizar la polilínea de ruta en el mapa
  /// Dibuja una línea naranja siguiendo la ruta REAL de las calles (no línea recta)
  Future<void> _updateRoutePolyline() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) {
      // Si no hay coordenadas, limpiar la polilínea
      if (!mounted) return;
      setState(() {
        _polylines.clear();
      });
      AppLogger.info('Polilínea limpiada - no hay coordenadas');
      return;
    }

    // Obtener los puntos de la ruta REAL desde Google Directions API
    final List<LatLng> routePoints = await _getRoutePolylinePoints(
      _pickupCoordinates!,
      _destinationCoordinates!,
    );

    // Crear polilínea con TODOS los puntos de la ruta real (no solo 2 puntos)
    final Polyline routePolyline = Polyline(
      polylineId: PolylineId('route'),
      points: routePoints, // ✅ AHORA USA RUTA REAL CON MÚLTIPLES PUNTOS
      color: ModernTheme.primaryOrange,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    if (!mounted) return;
    setState(() {
      _polylines.clear(); // Limpiar polilíneas anteriores
      _polylines.add(routePolyline); // Agregar la nueva polilínea con ruta real
    });

    AppLogger.info('Polilínea de ruta REAL dibujada con ${routePoints.length} puntos: ${_pickupCoordinates!.latitude},${_pickupCoordinates!.longitude} → ${_destinationCoordinates!.latitude},${_destinationCoordinates!.longitude}');
  }
}