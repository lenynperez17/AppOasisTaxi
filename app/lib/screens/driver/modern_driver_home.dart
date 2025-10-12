// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../models/price_negotiation_model.dart';

class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  _ModernDriverHomeScreenState createState() => _ModernDriverHomeScreenState();
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

  // Estadísticas del día
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  final double _acceptanceRate = 95.5;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 500),
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
      // En un app real, obtendrías el ID del conductor del usuario autenticado
      // Por ahora, usaremos un ID temporal hasta que esté integrado con auth
      _driverId = "driver_temp_id"; // Esto debe venir del usuario autenticado
      
      // Cargar estadísticas iniciales
      await _loadTodayStats();
    } catch (e) {
      print('Error inicializando conductor: $e');
    }
  }
  
  void _showDriverMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: ModernTheme.oasisGreen),
              title: Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/profile');
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: ModernTheme.oasisGreen),
              title: Text('Métricas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/metrics');
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: ModernTheme.oasisGreen),
              title: Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/transactions-history');
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: ModernTheme.error),
              title: Text('Cerrar Sesión'),
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

    _pulseController.dispose();
    _slideController.dispose();
    _requestsTimer?.cancel();
    _requestsTimer = null;
    super.dispose();
  }
  
  void _loadRealRequests() {
    // Cargar solicitudes reales desde Firebase
    if (_isOnline) {
      _loadRequestsFromFirebase();
    }
  }
  
  Future<void> _loadRequestsFromFirebase() async {
    try {
      // Implementación básica para cargar desde Firebase
      // Esto se conectará con el servicio de Firebase cuando esté disponible
      final mockRequests = <PriceNegotiation>[
        // Por ahora usar datos de prueba hasta que Firebase esté completamente configurado
      ];
      
      setState(() {
        _availableRequests = mockRequests;
        _updateMapMarkers();
      });
      
      // Configurar timer para actualizaciones periódicas
      _requestsTimer?.cancel();
      _requestsTimer = Timer.periodic(Duration(seconds: 30), (timer) {
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
      print('Error cargando solicitudes: $e');
      // En caso de error, mantener lista vacía
      setState(() {
        _availableRequests = [];
        _updateMapMarkers();
      });
    }
  }
  
  
  void _updateMapMarkers() {
    _markers.clear();
    for (var request in _availableRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: LatLng(request.pickup.latitude, request.pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _selectRequest(request),
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
      // Actualizar en Firebase
      await _firestore.collection('price_negotiations').doc(request.id).update({
        'status': 'accepted',
        'driverId': _driverId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Crear registro de viaje
      await _firestore.collection('rides').add({
        'passengerId': request.passengerId,
        'driverId': _driverId,
        'pickupAddress': request.pickup.address,
        'destinationAddress': request.destination.address,
        'fare': request.offeredPrice,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _availableRequests.remove(request);
        _showRequestDetails = false;
      });

      // Recargar estadísticas
      await _loadTodayStats();

      _showAcceptedDialog(request);
    } catch (e) {
      print('Error aceptando solicitud: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al aceptar el viaje'),
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
          ModeSwitchButton(compact: true),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.account_balance_wallet, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/driver/wallet'),
          ),
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => _showDriverMenu(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Panel superior con estadísticas
          SafeArea(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ModernTheme.cardShadow,
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
                          color: _isOnline ? ModernTheme.success : ModernTheme.textSecondary,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: (value) {
                          setState(() {
                            _isOnline = value;
                            if (value) {
                              _availableRequests = [];
                              _updateMapMarkers();
                            } else {
                              _availableRequests.clear();
                              _markers.clear();
                            }
                          });
                        },
                        thumbColor: WidgetStateProperty.all(ModernTheme.success),
                      ),
                    ],
                  ),
                  
                  if (_isOnline) ...[
                    Divider(),
                    // Estadísticas del día
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatistic('Ganancias', 'S/ ${_todayEarnings.toStringAsFixed(2)}', Icons.monetization_on),
                        _buildStatistic('Viajes', '$_todayTrips', Icons.directions_car),
                        _buildStatistic('Aceptación', '${_acceptanceRate.toStringAsFixed(1)}%', Icons.star),
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
                    
                    // Título con contador de solicitudes
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Solicitudes disponibles',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ModernTheme.textPrimary,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ModernTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_availableRequests.length}',
                                    style: TextStyle(
                                      color: Colors.white,
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
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _availableRequests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_availableRequests[index]);
                        },
                      ),
                    ),
                    SizedBox(height: 20),
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
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ModernTheme.textSecondary,
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
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: isUrgent 
            ? LinearGradient(
                colors: [ModernTheme.warning.withValues(alpha: 0.1), Colors.white],
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
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                          SizedBox(width: 2),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
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
                // Precio ofrecido
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'S/ ${request.offeredPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: ModernTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Información del viaje
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: ModernTheme.success),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.pickup.address,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: ModernTheme.error),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.destination.address,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            Spacer(),
            
            // Footer con distancia y tiempo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 14, color: ModernTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      '${request.distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.access_time, size: 14, color: ModernTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      '${request.estimatedTime} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Tiempo restante
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? ModernTheme.warning : ModernTheme.info,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
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
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.passengerName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                        SizedBox(width: 4),
                        Text(
                          request.passengerRating.toStringAsFixed(1),
                          style: TextStyle(color: ModernTheme.textSecondary),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          request.paymentMethod == PaymentMethod.cash 
                            ? Icons.money 
                            : Icons.credit_card,
                          size: 16,
                          color: ModernTheme.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          request.paymentMethod == PaymentMethod.cash 
                            ? 'Efectivo' 
                            : 'Tarjeta',
                          style: TextStyle(color: ModernTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Precio grande
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: ModernTheme.successGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'S/ ${request.offeredPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Detalles del viaje
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
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
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          Text(
                            request.pickup.address,
                            style: TextStyle(
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
                  padding: EdgeInsets.only(left: 5),
                  child: Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                ),
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
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          Text(
                            request.destination.address,
                            style: TextStyle(
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
          
          SizedBox(height: 16),
          
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
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: ModernTheme.info, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.notes!,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 24),
          
          // Botones de acción
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
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: ModernTheme.textSecondary),
                  ),
                  child: Text(
                    'Rechazar',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ModernTheme.textSecondary),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
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
      final endOfDay = startOfDay.add(Duration(days: 1));
      
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
      
      setState(() {
        _todayEarnings = totalEarnings;
        _todayTrips = tripCount;
      });
    } catch (e) {
      print('Error cargando estadísticas del día: $e');
      // En caso de error, mantener valores por defecto
      setState(() {
        _todayEarnings = 0.0;
        _todayTrips = 0;
      });
    }
  }
  
  void _showAcceptedDialog(PriceNegotiation request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: ModernTheme.success,
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '¡Viaje aceptado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Dirígete al punto de recogida',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
            SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Iniciar navegación',
              icon: Icons.navigation,
              onPressed: () {
                Navigator.of(context).pop();
                // Iniciar navegación
              },
            ),
          ],
        ),
      ),
    );
  }
}