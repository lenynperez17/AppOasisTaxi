// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';
import '../shared/rating_dialog.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TripHistoryScreenState createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _statsAnimationController;
  
  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  List<TripModel> _trips = [];
  bool _isLoading = true;
  
  // Estadísticas
  Map<String, dynamic> get _stats {
    final completedTrips = _filteredTrips.where((t) => t.status == 'completed').toList();
    final totalSpent = completedTrips.fold<double>(0, (sum, trip) => sum + (trip.finalFare ?? trip.estimatedFare));
    final totalDistance = completedTrips.fold<double>(0, (sum, trip) => sum + trip.estimatedDistance);
    final avgRating = completedTrips.where((t) => t.passengerRating != null)
        .fold<double>(0, (sum, trip) => sum + (trip.passengerRating ?? 0)) / 
        completedTrips.where((t) => t.passengerRating != null).length;
    
    return {
      'totalTrips': completedTrips.length,
      'totalSpent': totalSpent,
      'totalDistance': totalDistance,
      'avgRating': avgRating.isNaN ? 0.0 : avgRating,
    };
  }
  
  List<TripModel> get _filteredTrips {
    var filtered = _trips;
    
    if (_selectedFilter != 'all') {
      filtered = filtered.where((trip) => trip.status == _selectedFilter).toList();
    }
    
    if (_dateRange != null) {
      filtered = filtered.where((trip) {
        return trip.requestedAt.isAfter(_dateRange!.start) &&
               trip.requestedAt.isBefore(_dateRange!.end.add(Duration(days: 1)));
      }).toList();
    }
    
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    
    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _loadTripsHistory();
  }

  Future<void> _loadTripsHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      try {
        final trips = await rideProvider.getUserTripHistory(authProvider.currentUser!.id);
        
        if (!mounted) return;
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
        _listAnimationController.forward();
        _statsAnimationController.forward();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('Error loading trip history: $e');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _statsAnimationController.dispose();
    super.dispose();
  }
  
  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.oasisGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Historial de Viajes',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Descargando historial...'),
                  backgroundColor: ModernTheme.oasisGreen,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Estadísticas
          AnimatedBuilder(
            animation: _statsAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _statsAnimationController.value)),
                child: Opacity(
                  opacity: _statsAnimationController.value,
                  child: _buildStatistics(),
                ),
              );
            },
          ),
          
          // Filtros
          _buildFilters(),
          
          // Lista de viajes
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: ModernTheme.oasisGreen))
                : _filteredTrips.isEmpty
                    ? _buildEmptyState()
                    : AnimatedBuilder(
                    animation: _listAnimationController,
                    builder: (context, child) {
                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _filteredTrips[index];
                          final delay = index * 0.1;
                          final animation = Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: _listAnimationController,
                              curve: Interval(
                                delay,
                                delay + 0.5,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          );
                          
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(50 * (1 - animation.value), 0),
                                child: Opacity(
                                  opacity: animation.value.clamp(0.0, 1.0),
                                  child: _buildTripCard(trip),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Resumen del Mes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.route,
                value: '${_stats['totalTrips']}',
                label: 'Viajes',
              ),
              _buildStatItem(
                icon: Icons.attach_money,
                value: _stats['totalSpent'].toCurrency(),
                label: 'Gastado',
              ),
              _buildStatItem(
                icon: Icons.map,
                value: '${_stats['totalDistance'].toStringAsFixed(1)} km',
                label: 'Distancia',
              ),
              _buildStatItem(
                icon: Icons.star,
                value: _stats['avgRating'].toStringAsFixed(1),
                label: 'Rating',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Chips de filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all'),
                SizedBox(width: 8),
                _buildFilterChip('Completados', 'completed'),
                SizedBox(width: 8),
                _buildFilterChip('Cancelados', 'cancelled'),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateRange == null
                        ? 'Fecha'
                        : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ModernTheme.oasisGreen,
                    side: BorderSide(color: ModernTheme.oasisGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_dateRange != null) ...[
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: ModernTheme.oasisGreen,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : ModernTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? ModernTheme.oasisGreen : Colors.grey.shade300,
        ),
      ),
    );
  }
  
  Widget _buildTripCard(TripModel trip) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showTripDetails(trip),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(trip.status).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(trip.status),
                          color: _getStatusColor(trip.status),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(trip.requestedAt),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTime(trip.requestedAt),
                            style: TextStyle(
                              color: ModernTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    (trip.finalFare ?? trip.estimatedFare).toCurrency(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.oasisGreen,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Ruta
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ModernTheme.oasisGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ModernTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.pickupAddress,
                          style: TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 20),
                        Text(
                          trip.destinationAddress,
                          style: TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Info adicional
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: ModernTheme.oasisGreen,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conductor',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.amber),
                                  Text(
                                    ' ${(trip.driverRating ?? 5.0).toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ModernTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (trip.status == 'completed' && trip.passengerRating != null) ...[
                    SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Tu calificación: ${trip.passengerRating?.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: ModernTheme.textSecondary.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16),
          Text(
            'No hay viajes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajusta los filtros para ver más resultados',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTripDetails(TripModel trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripDetailsModal(trip: trip),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return ModernTheme.success;
      case 'cancelled':
        return ModernTheme.error;
      default:
        return ModernTheme.textSecondary;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    if (difference < 7) return 'Hace $difference días';
    
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Modal de detalles del viaje
class TripDetailsModal extends StatefulWidget {
  final TripModel trip;
  
  const TripDetailsModal({super.key, required this.trip});
  
  @override
  // ignore: library_private_types_in_public_api
  _TripDetailsModalState createState() => _TripDetailsModalState();
}

class _TripDetailsModalState extends State<TripDetailsModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles del Viaje',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID y Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${widget.trip.id}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.trip.status == 'completed' 
                            ? ModernTheme.success.withValues(alpha: 0.1)
                            : ModernTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.trip.status == 'completed' ? 'Completado' : 'Cancelado',
                          style: TextStyle(
                            color: widget.trip.status == 'completed' 
                              ? ModernTheme.success
                              : ModernTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Información del viaje
                  _buildDetailSection(
                    'Ruta del Viaje',
                    [
                      _buildDetailRow(Icons.trip_origin, 'Origen', widget.trip.pickupAddress),
                      _buildDetailRow(Icons.location_on, 'Destino', widget.trip.destinationAddress),
                      _buildDetailRow(Icons.route, 'Distancia', '${widget.trip.estimatedDistance.toStringAsFixed(1)} km'),
                      _buildDetailRow(Icons.timer, 'Duración', widget.trip.tripDuration?.inMinutes.toString() ?? 'N/A min'),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Información del conductor
                  _buildDetailSection(
                    'Conductor',
                    [
                      _buildDetailRow(Icons.person, 'ID Conductor', widget.trip.driverId ?? 'N/A'),
                      _buildDetailRow(Icons.star, 'Calificación', '${widget.trip.driverRating ?? 'N/A'}'),
                      _buildDetailRow(Icons.directions_car, 'Vehículo', widget.trip.vehicleInfo?.toString() ?? 'N/A'),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Información de pago
                  _buildDetailSection(
                    'Pago',
                    [
                      _buildDetailRow(Icons.attach_money, 'Monto', (widget.trip.finalFare ?? widget.trip.estimatedFare).toCurrency()),
                      _buildDetailRow(Icons.payment, 'Método', 'Efectivo (predeterminado)'),
                    ],
                  ),
                  
                  if (widget.trip.status == 'completed' && widget.trip.passengerRating == null) ...[
                    SizedBox(height: 24),
                    AnimatedPulseButton(
                      text: 'Calificar Viaje',
                      icon: Icons.star,
                      onPressed: () {
                        Navigator.pop(context);
                        // Mostrar dialog de calificación
                        RatingDialog.show(
                          context: context,
                          driverName: widget.trip.driverId ?? 'Conductor',
                          driverPhoto: '', // Se obtiene del perfil del conductor desde Firebase
                          tripId: widget.trip.id,
                          onSubmit: (rating, comment, tags) async {
                            // Actualizar la calificación del viaje en Firebase
                            await _updateTripRating(widget.trip.id, rating.toDouble(), comment ?? '', tags);
                          },
                        );
                      },
                      color: ModernTheme.oasisGreen,
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.help_outline),
                          label: Text('Reportar problema'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.receipt),
                          label: Text('Ver recibo'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Actualizar calificación del viaje en Firebase
  Future<void> _updateTripRating(String tripId, double rating, String comment, List<String> tags) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      
      if (userId != null) {
        // Actualizar calificación en Firebase
        await Provider.of<RideProvider>(context, listen: false)
            .updateTripRating(tripId, userId, rating, comment, tags);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calificación enviada correctamente'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar calificación: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.textSecondary),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: ModernTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}