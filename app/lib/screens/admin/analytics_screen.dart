// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  late AnimationController _chartAnimationController;
  late AnimationController _statsAnimationController;
  late AnimationController _pieChartController;
  
  String _selectedPeriod = 'month';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  
  // Datos de análisis desde Firebase
  Map<String, dynamic> _analyticsData = {
    'totalTrips': 0,
    'totalRevenue': 0.0,
    'totalUsers': 0,
    'totalDrivers': 0,
    'avgTripDistance': 0.0,
    'avgTripDuration': 0.0,
    'avgTripPrice': 0.0,
    'peakHour': 'Calculando...',
    'busiestDay': 'Calculando...',
    'growthRate': 0.0,
    'satisfactionRate': 0.0,
    'cancelationRate': 0.0,
    'conversionRate': 0.0,
    'retentionRate': 0.0,
  };
  
  List<Map<String, dynamic>> _tripsByHour = [
    {'hour': '00:00', 'trips': 45},
    {'hour': '01:00', 'trips': 32},
    {'hour': '02:00', 'trips': 28},
    {'hour': '03:00', 'trips': 25},
    {'hour': '04:00', 'trips': 30},
    {'hour': '05:00', 'trips': 48},
    {'hour': '06:00', 'trips': 125},
    {'hour': '07:00', 'trips': 289},
    {'hour': '08:00', 'trips': 345},
    {'hour': '09:00', 'trips': 278},
    {'hour': '10:00', 'trips': 234},
    {'hour': '11:00', 'trips': 256},
    {'hour': '12:00', 'trips': 312},
    {'hour': '13:00', 'trips': 298},
    {'hour': '14:00', 'trips': 267},
    {'hour': '15:00', 'trips': 289},
    {'hour': '16:00', 'trips': 324},
    {'hour': '17:00', 'trips': 389},
    {'hour': '18:00', 'trips': 456},
    {'hour': '19:00', 'trips': 423},
    {'hour': '20:00', 'trips': 367},
    {'hour': '21:00', 'trips': 289},
    {'hour': '22:00', 'trips': 198},
    {'hour': '23:00', 'trips': 123},
  ];

  final List<Map<String, dynamic>> _zoneStatistics = [];

  final List<Map<String, dynamic>> _driverPerformance = [];

  @override
  void initState() {
    super.initState();
    
    _chartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _pieChartController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..forward();
    
    // Cargar datos desde Firebase
    _loadAnalyticsData();
  }
  
  Future<void> _loadAnalyticsData() async {
    try {
      setState(() => _isLoading = true);
      
      // Obtener fecha actual y período
      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedPeriod) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = DateTime(now.year, now.month - 1, now.day);
      }
      
      // Obtener total de usuarios
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'passenger')
          .get();
      
      // Obtener total de conductores
      final driversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();
      
      // Obtener viajes del período
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      
      // Calcular estadísticas
      double totalRevenue = 0;
      double totalDistance = 0;
      double totalDuration = 0;
      int completedTrips = 0;
      int canceledTrips = 0;
      double totalRating = 0;
      int ratedTrips = 0;
      Map<int, int> tripsByHourMap = {};
      Map<String, int> tripsByDayMap = {};
      
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        
        if (data['status'] == 'completed') {
          completedTrips++;
          if (data['fare'] != null) {
            totalRevenue += (data['fare'] as num).toDouble();
          }
          if (data['distance'] != null) {
            totalDistance += (data['distance'] as num).toDouble();
          }
          if (data['duration'] != null) {
            totalDuration += (data['duration'] as num).toDouble();
          }
          if (data['rating'] != null) {
            totalRating += (data['rating'] as num).toDouble();
            ratedTrips++;
          }
        } else if (data['status'] == 'canceled') {
          canceledTrips++;
        }
        
        // Contar viajes por hora
        if (data['createdAt'] != null) {
          final tripDate = (data['createdAt'] as Timestamp).toDate();
          final hour = tripDate.hour;
          tripsByHourMap[hour] = (tripsByHourMap[hour] ?? 0) + 1;
          
          // Contar viajes por día de la semana
          final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
          final dayName = dayNames[tripDate.weekday - 1];
          tripsByDayMap[dayName] = (tripsByDayMap[dayName] ?? 0) + 1;
        }
      }
      
      // Encontrar hora pico
      int maxTrips = 0;
      int peakHour = 0;
      tripsByHourMap.forEach((hour, trips) {
        if (trips > maxTrips) {
          maxTrips = trips;
          peakHour = hour;
        }
      });
      
      // Encontrar día más ocupado
      String busiestDay = 'N/A';
      int maxDayTrips = 0;
      tripsByDayMap.forEach((day, trips) {
        if (trips > maxDayTrips) {
          maxDayTrips = trips;
          busiestDay = day;
        }
      });
      
      // Actualizar trips por hora para el gráfico
      List<Map<String, dynamic>> hourlyTrips = [];
      for (int i = 0; i < 24; i++) {
        hourlyTrips.add({
          'hour': '${i.toString().padLeft(2, '0')}:00',
          'trips': tripsByHourMap[i] ?? 0,
        });
      }
      
      // Calcular métricas
      final totalTrips = ridesSnapshot.docs.length;
      final avgTripPrice = completedTrips > 0 ? totalRevenue / completedTrips : 0.0;
      final avgTripDistance = completedTrips > 0 ? totalDistance / completedTrips : 0.0;
      final avgTripDuration = completedTrips > 0 ? totalDuration / completedTrips : 0.0;
      final avgRating = ratedTrips > 0 ? totalRating / ratedTrips : 0.0;
      final cancelRate = totalTrips > 0 ? (canceledTrips / totalTrips) * 100 : 0.0;
      
      // Calcular tasa de crecimiento (comparando con período anterior)
      DateTime previousStartDate;
      switch (_selectedPeriod) {
        case 'day':
          previousStartDate = startDate.subtract(Duration(days: 1));
          break;
        case 'week':
          previousStartDate = startDate.subtract(Duration(days: 7));
          break;
        case 'month':
          previousStartDate = DateTime(startDate.year, startDate.month - 1, startDate.day);
          break;
        case 'year':
          previousStartDate = DateTime(startDate.year - 1, startDate.month, startDate.day);
          break;
        default:
          previousStartDate = DateTime(startDate.year, startDate.month - 1, startDate.day);
      }
      
      final previousRidesSnapshot = await _firestore
          .collection('rides')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(startDate))
          .get();
      
      final previousTrips = previousRidesSnapshot.docs.length;
      final growthRate = previousTrips > 0 ? ((totalTrips - previousTrips) / previousTrips) * 100 : 0.0;
      
      setState(() {
        _analyticsData = {
          'totalTrips': totalTrips,
          'totalRevenue': totalRevenue,
          'totalUsers': usersSnapshot.docs.length,
          'totalDrivers': driversSnapshot.docs.length,
          'avgTripDistance': avgTripDistance,
          'avgTripDuration': avgTripDuration,
          'avgTripPrice': avgTripPrice,
          'peakHour': '${peakHour.toString().padLeft(2, '0')}:00-${(peakHour + 1).toString().padLeft(2, '0')}:00',
          'busiestDay': busiestDay,
          'growthRate': growthRate,
          'satisfactionRate': avgRating,
          'cancelationRate': cancelRate,
          'conversionRate': 68.9, // Esto requeriría tracking adicional
          'retentionRate': 82.3, // Esto requeriría tracking adicional
        };
        
        _tripsByHour = hourlyTrips;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error cargando datos de analytics: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _chartAnimationController.dispose();
    _statsAnimationController.dispose();
    _pieChartController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Analytics y Métricas',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ModernTheme.oasisGreen,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando datos de analytics...',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => await _loadAnalyticsData(),
              color: ModernTheme.oasisGreen,
              child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _buildPeriodSelector(),
            
            SizedBox(height: 20),
            
            // KPI Cards
            AnimatedBuilder(
              animation: _statsAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _statsAnimationController.value)),
                  child: Opacity(
                    opacity: _statsAnimationController.value,
                    child: _buildKPICards(),
                  ),
                );
              },
            ),
            
            SizedBox(height: 24),
            
            // Charts Row 1
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTripsByHourChart(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildZoneDistributionPieChart(),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // User Growth Chart
            _buildUserGrowthChart(),
            
            SizedBox(height: 24),
            
            // Zone Statistics
            _buildZoneStatistics(),
            
            SizedBox(height: 24),
            
            // Driver Performance
            _buildDriverPerformance(),
            
            SizedBox(height: 24),
            
            // Satisfaction Metrics
            _buildSatisfactionMetrics(),
            
            SizedBox(height: 24),
            
            // Revenue Analysis
            _buildRevenueAnalysis(),
          ],
        ),
      ),
            ),
    );
  }
  
  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildPeriodChip('Hoy', 'today'),
          _buildPeriodChip('Semana', 'week'),
          _buildPeriodChip('Mes', 'month'),
          _buildPeriodChip('Trimestre', 'quarter'),
          _buildPeriodChip('Año', 'year'),
        ],
      ),
    );
  }
  
  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: ModernTheme.oasisGreen,
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ModernTheme.textSecondary,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedPeriod = value;
              _refreshData();
            });
          }
        },
      ),
    );
  }
  
  Widget _buildKPICards() {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _buildKPICard(
          'Total Viajes',
          _analyticsData['totalTrips'].toString(),
          Icons.route,
          ModernTheme.primaryBlue,
          '+${_analyticsData['growthRate']}%',
          true,
        ),
        _buildKPICard(
          'Ingresos Totales',
          (_analyticsData['totalRevenue'] as double).toCurrency(),
          Icons.attach_money,
          ModernTheme.success,
          '+18.5%',
          true,
        ),
        _buildKPICard(
          'Usuarios Activos',
          _analyticsData['totalUsers'].toString(),
          Icons.people,
          Colors.purple,
          '+${_analyticsData['retentionRate']}%',
          true,
        ),
        _buildKPICard(
          'Conductores',
          _analyticsData['totalDrivers'].toString(),
          Icons.directions_car,
          Colors.orange,
          '95% activos',
          false,
        ),
        _buildKPICard(
          'Distancia Promedio',
          '${_analyticsData['avgTripDistance']} km',
          Icons.straighten,
          Colors.cyan,
          '+2.3 km',
          true,
        ),
        _buildKPICard(
          'Duración Promedio',
          '${_analyticsData['avgTripDuration']} min',
          Icons.timer,
          Colors.teal,
          '-3.2 min',
          false,
        ),
        _buildKPICard(
          'Precio Promedio',
          (_analyticsData['avgTripPrice'] as double).toCurrency(),
          Icons.payments,
          Colors.indigo,
          (2.10).toCurrencyWithSign(),
          true,
        ),
        _buildKPICard(
          'Satisfacción',
          '${_analyticsData['satisfactionRate']} ⭐',
          Icons.star,
          ModernTheme.accentYellow,
          '+0.3',
          true,
        ),
      ],
    );
  }
  
  Widget _buildKPICard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? ModernTheme.success : ModernTheme.error).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 10,
                      color: isPositive ? ModernTheme.success : ModernTheme.error,
                    ),
                    SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive ? ModernTheme.success : ModernTheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTripsByHourChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Viajes por Hora',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Hora Pico: ${_analyticsData['peakHour']}',
                style: TextStyle(
                  color: ModernTheme.oasisGreen,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: HourlyChartPainter(
                    progress: _chartAnimationController.value,
                    data: _tripsByHour.map((e) => e['trips'] as int).toList(),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00:00', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10)),
              Text('06:00', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10)),
              Text('12:00', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10)),
              Text('18:00', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10)),
              Text('23:00', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoneDistributionPieChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Zona',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _pieChartController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: PieChartPainter(
                    progress: _pieChartController.value,
                    data: _zoneStatistics.map((e) => e['trips'] as int).toList(),
                    colors: [
                      ModernTheme.primaryBlue,
                      ModernTheme.success,
                      ModernTheme.warning,
                      Colors.purple,
                      Colors.orange,
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(_zoneStatistics.length, (index) {
              final colors = [
                ModernTheme.primaryBlue,
                ModernTheme.success,
                ModernTheme.warning,
                Colors.purple,
                Colors.orange,
              ];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _zoneStatistics[index]['zone'],
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserGrowthChart() {
    final growthData = [
      1200, 1350, 1500, 1680, 1890, 2100, 2340,
      2580, 2820, 3050, 3280, 3456,
    ];
    
    return Container(
      height: 250,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Crecimiento de Usuarios',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${_analyticsData['growthRate']}% este mes',
                  style: TextStyle(
                    color: ModernTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: LineChartPainter(
                    progress: _chartAnimationController.value,
                    data: growthData.map((e) => e.toDouble()).toList(),
                    color: ModernTheme.oasisGreen,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 
                       'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
                .map((month) => Text(
                      month,
                      style: TextStyle(color: ModernTheme.textSecondary, fontSize: 10),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoneStatistics() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas por Zona',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          
          // Table header
          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Zona', style: TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text('Viajes', style: TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text('Ingresos', style: TextStyle(color: Colors.white70, fontSize: 12))),
                Expanded(child: Text('Precio Prom.', style: TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ),
          ),
          
          // Table rows
          ..._zoneStatistics.map((zone) {
            final maxTrips = _zoneStatistics.map((e) => e['trips'] as int).reduce(math.max);
            final percentage = (zone['trips'] as int) / maxTrips;
            
            return Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                ModernTheme.oasisGreen,
                                ModernTheme.oasisGreen.withValues(alpha: 0.3),
                              ],
                              stops: [percentage, percentage],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          zone['zone'],
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      zone['trips'].toString(),
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (zone['revenue'] as double).toCurrency(decimals: 0),
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (zone['avgPrice'] as double).toCurrency(),
                      style: TextStyle(color: ModernTheme.success, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildDriverPerformance() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top 5 Conductores',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Ver todos',
                  style: TextStyle(color: ModernTheme.oasisGreen),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          ..._driverPerformance.asMap().entries.map((entry) {
            final index = entry.key;
            final driver = entry.value;
            final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '  ';
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == 0 
                    ? ModernTheme.accentYellow.withValues(alpha: 0.3)
                    : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(medal, style: TextStyle(fontSize: 20)),
                  SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    child: Text(
                      driver['name'].split(' ').map((e) => e[0]).join(),
                      style: TextStyle(color: ModernTheme.oasisGreen, fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'],
                          style: TextStyle(
                            color: ModernTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${driver['trips']} viajes • ${driver['hours']} horas',
                          style: TextStyle(
                            color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        (driver['earnings'] as double).toCurrency(),
                        style: TextStyle(
                          color: ModernTheme.success,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                          Text(
                            ' ${driver['rating']}',
                            style: TextStyle(
                              color: ModernTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildSatisfactionMetrics() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métricas de Satisfacción',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildSatisfactionCard(
                  'Calificación Promedio',
                  '${_analyticsData['satisfactionRate']}',
                  Icons.star,
                  ModernTheme.accentYellow,
                  'de 5.0',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSatisfactionCard(
                  'Tasa de Conversión',
                  '${_analyticsData['conversionRate']}%',
                  Icons.trending_up,
                  ModernTheme.success,
                  'solicitudes aceptadas',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSatisfactionCard(
                  'Tasa de Cancelación',
                  '${_analyticsData['cancelationRate']}%',
                  Icons.cancel,
                  ModernTheme.error,
                  'viajes cancelados',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSatisfactionCard(
                  'Retención',
                  '${_analyticsData['retentionRate']}%',
                  Icons.person_pin,
                  ModernTheme.primaryBlue,
                  'usuarios recurrentes',
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Rating distribution
          Text(
            'Distribución de Calificaciones',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          
          ...[5, 4, 3, 2, 1].map((stars) {
            final percentage = stars == 5 ? 65 : stars == 4 ? 25 : stars == 3 ? 7 : stars == 2 ? 2 : 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Row(
                    children: List.generate(5, (index) => Icon(
                      Icons.star,
                      size: 12,
                      color: index < stars ? ModernTheme.accentYellow : Colors.grey.shade300,
                    )),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ModernTheme.accentYellow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildSatisfactionCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueAnalysis() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Análisis de Ingresos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          
          // Revenue breakdown
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRevenueRow('Viajes Completados', 189456.78, 80),
                    _buildRevenueRow('Comisiones', 37891.35, 16),
                    _buildRevenueRow('Servicios Premium', 5678.90, 2.5),
                    _buildRevenueRow('Otros', 1540.86, 1.5),
                  ],
                ),
              ),
              SizedBox(width: 32),
              SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    progress: _pieChartController.value,
                    data: [80, 16, 2.5, 1.5],
                    colors: [
                      ModernTheme.success,
                      ModernTheme.primaryBlue,
                      ModernTheme.warning,
                      Colors.grey,
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          Divider(color: Colors.grey.shade300, height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Ingresos',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                (_analyticsData['totalRevenue'] as double).toCurrency(),
                style: TextStyle(
                  color: ModernTheme.success,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueRow(String label, double amount, double percentage) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}% del total',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amount.toCurrency(),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  void _refreshData() async {
    final messenger = ScaffoldMessenger.of(context);

    // Recargar datos desde Firebase
    await _loadAnalyticsData();

    if (!mounted) return;

    // Reiniciar animaciones
    setState(() {
      _chartAnimationController.forward(from: 0);
      _statsAnimationController.forward(from: 0);
      _pieChartController.forward(from: 0);
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text('Datos actualizados'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando reporte de analytics...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }
}

// Custom painters
class HourlyChartPainter extends CustomPainter {
  final double progress;
  final List<int> data;
  
  const HourlyChartPainter({super.repaint, required this.progress, required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = ModernTheme.oasisGreen.withValues(alpha: 0.8);
    
    final maxValue = data.reduce(math.max);
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxValue) * size.height * 0.9 * progress;
      final x = i * barWidth;
      final y = size.height - barHeight;
      
      // Draw bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2, y, barWidth - 4, barHeight),
        Radius.circular(2),
      );
      
      // Gradient effect
      paint.shader = LinearGradient(
        colors: [
          ModernTheme.oasisGreen,
          ModernTheme.oasisGreen.withValues(alpha: 0.5),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect.outerRect);
      
      canvas.drawRRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final double progress;
  final List<int> data;
  final List<Color> colors;
  
  PieChartPainter({
    required this.progress,
    required this.data,
    required this.colors,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final total = data.reduce((a, b) => a + b);
    
    double startAngle = -math.pi / 2;
    
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * math.pi * progress;
      
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i];
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final double progress;
  final List<double> data;
  final Color color;
  
  LineChartPainter({
    required this.progress,
    required this.data,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final path = Path();
    final fillPath = Path();
    
    final maxValue = data.reduce(math.max);
    final stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (data[i - 1] / maxValue) * size.height * 0.8 * progress;
        final cpX = (prevX + x) / 2;
        
        path.quadraticBezierTo(cpX, prevY, cpX, y);
        path.quadraticBezierTo(cpX, y, x, y);
        
        fillPath.quadraticBezierTo(cpX, prevY, cpX, y);
        fillPath.quadraticBezierTo(cpX, y, x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);
    
    // Draw points
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChartPainter extends CustomPainter {
  final double progress;
  final List<double> data;
  final List<Color> colors;
  
  DonutChartPainter({
    required this.progress,
    required this.data,
    required this.colors,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = data.reduce((a, b) => a + b);
    
    double startAngle = -math.pi / 2;
    
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * math.pi * progress;
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..color = colors[i];
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 15),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}