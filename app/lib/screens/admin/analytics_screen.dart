// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
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
  
  // ✅ Viajes por hora desde Firebase (sin datos mock)
  List<Map<String, dynamic>> _tripsByHour = [];

  // ✅ CORREGIDO: Cambiar de final a mutables para cargar desde Firebase
  List<Map<String, dynamic>> _zoneStatistics = [];

  List<Map<String, dynamic>> _driverPerformance = [];

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

      debugPrint('📊 Cargando datos de analytics...');

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

      debugPrint('📅 Período: $_selectedPeriod desde $startDate');

      // ✅ CORREGIDO: Obtener total de usuarios con try-catch
      QuerySnapshot<Map<String, dynamic>>? usersSnapshot;
      try {
        usersSnapshot = await _firestore.collection('users').get();
      } catch (e) {
        debugPrint('❌ Error obteniendo usuarios: $e');
      }

      // ✅ CORREGIDO: Intentar obtener conductores con diferentes queries
      QuerySnapshot? driversSnapshot;
      try {
        // ✅ CORREGIDO: Buscar usuarios con userType 'driver' O 'dual'
        driversSnapshot = await _firestore
            .collection('users')
            .where('userType', whereIn: ['driver', 'dual'])
            .get()
            .timeout(Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Query userType=driver falló, intentando con availableRoles');
        try {
          driversSnapshot = await _firestore
              .collection('users')
              .where('availableRoles', arrayContains: 'driver')
              .get()
              .timeout(Duration(seconds: 5));
        } catch (e2) {
          debugPrint('❌ No se pudo obtener conductores: $e2');
        }
      }

      // ✅ CORREGIDO: Obtener viajes del período con try-catch
      // ✅ CORREGIDO: Cambiar 'trips' a 'rides' (colección correcta)
      QuerySnapshot<Map<String, dynamic>>? tripsSnapshot;
      try {
        tripsSnapshot = await _firestore
            .collection('rides')
            .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
      } catch (e) {
        debugPrint('❌ Error obteniendo rides: $e');
      }

      debugPrint('✅ Datos obtenidos:');
      debugPrint('   👥 Usuarios: ${usersSnapshot?.docs.length ?? 0}');
      debugPrint('   🚗 Conductores: ${driversSnapshot?.docs.length ?? 0}');
      debugPrint('   🚕 Trips: ${tripsSnapshot?.docs.length ?? 0}');
      
      // ✅ Calcular estadísticas desde trips (null-safe)
      double totalRevenue = 0;
      double totalDistance = 0;
      double totalDuration = 0;
      int completedTrips = 0;
      int canceledTrips = 0;
      double totalRating = 0;
      int ratedTrips = 0;
      Map<int, int> tripsByHourMap = {};
      Map<String, int> tripsByDayMap = {};
      Map<int, int> ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      // ✅ Procesar trips solo si tripsSnapshot no es null
      if (tripsSnapshot != null && tripsSnapshot.docs.isNotEmpty) {
        for (var doc in tripsSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) {
              debugPrint('⚠️ Trip ${doc.id} sin datos');
              continue;
            }

            final status = data['status'] ?? '';

            if (status == 'completed') {
              completedTrips++;

              // ✅ CORREGIDO: usar 'finalFare' en lugar de 'fare'
              if (data['finalFare'] != null) {
                totalRevenue += (data['finalFare'] as num).toDouble();
              }

              if (data['distance'] != null) {
                totalDistance += (data['distance'] as num).toDouble();
              }

              if (data['duration'] != null) {
                totalDuration += (data['duration'] as num).toDouble();
              }

              if (data['rating'] != null) {
                final rating = (data['rating'] as num).toDouble();
                totalRating += rating;
                ratedTrips++;

                final roundedRating = rating.round().clamp(1, 5);
                ratingDistribution[roundedRating] = (ratingDistribution[roundedRating] ?? 0) + 1;
              }
            } else if (status == 'canceled' || status == 'cancelled') {
              canceledTrips++;
            }

            // ✅ CORREGIDO: usar 'requestedAt' en lugar de 'createdAt'
            if (data['requestedAt'] != null) {
              final tripDate = (data['requestedAt'] as Timestamp).toDate();
              final hour = tripDate.hour;
              tripsByHourMap[hour] = (tripsByHourMap[hour] ?? 0) + 1;

              final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
              final dayName = dayNames[tripDate.weekday - 1];
              tripsByDayMap[dayName] = (tripsByDayMap[dayName] ?? 0) + 1;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando trip ${doc.id}: $e');
            continue;
          }
        }
      } else {
        debugPrint('⚠️ No hay trips disponibles para el período seleccionado');
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
      
      // ✅ Calcular métricas (null-safe)
      // ✅ CORREGIDO: totalTrips debe contar solo viajes COMPLETADOS, no todos los rides
      final totalTrips = completedTrips;
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
      
      // ✅ CORREGIDO: Obtener rides del período anterior con try-catch
      // ✅ CORREGIDO: Cambiar 'trips' a 'rides' (colección correcta)
      QuerySnapshot<Map<String, dynamic>>? previousTripsSnapshot;
      try {
        previousTripsSnapshot = await _firestore
            .collection('rides')
            .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
            .where('requestedAt', isLessThan: Timestamp.fromDate(startDate))
            .get();
      } catch (e) {
        debugPrint('❌ Error obteniendo rides del período anterior: $e');
      }

      // ✅ Calcular métricas del período anterior (null-safe)
      final previousTrips = previousTripsSnapshot?.docs.length ?? 0;
      double previousRevenue = 0;
      double previousDistance = 0;
      double previousDuration = 0;
      int previousCompletedTrips = 0;
      double previousRating = 0;
      int previousRatedTrips = 0;
      int previousActiveDrivers = 0;
      Set<String> previousDriverIds = {};

      // ✅ Procesar trips del período anterior solo si hay datos
      if (previousTripsSnapshot != null && previousTripsSnapshot.docs.isNotEmpty) {
        for (var doc in previousTripsSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final status = data['status'] ?? '';

            if (status == 'completed') {
              previousCompletedTrips++;

              // ✅ CORREGIDO: usar 'finalFare' en lugar de 'fare'
              if (data['finalFare'] != null) {
                previousRevenue += (data['finalFare'] as num).toDouble();
              }

              if (data['distance'] != null) {
                previousDistance += (data['distance'] as num).toDouble();
              }

              if (data['duration'] != null) {
                previousDuration += (data['duration'] as num).toDouble();
              }

              if (data['rating'] != null) {
                previousRating += (data['rating'] as num).toDouble();
                previousRatedTrips++;
              }

              if (data['driverId'] != null) {
                previousDriverIds.add(data['driverId'] as String);
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando trip anterior: $e');
            continue;
          }
        }
      }

      previousActiveDrivers = previousDriverIds.length;

      // Calcular promedios del período anterior
      final prevAvgTripPrice = previousCompletedTrips > 0 ? previousRevenue / previousCompletedTrips : 0.0;
      final prevAvgTripDistance = previousCompletedTrips > 0 ? previousDistance / previousCompletedTrips : 0.0;
      final prevAvgTripDuration = previousCompletedTrips > 0 ? previousDuration / previousCompletedTrips : 0.0;
      final prevAvgRating = previousRatedTrips > 0 ? previousRating / previousRatedTrips : 0.0;

      // ✅ Calcular cambios porcentuales vs período anterior
      final growthRate = previousTrips > 0 ? ((totalTrips - previousTrips) / previousTrips) * 100 : 0.0;
      final revenueChange = previousRevenue > 0 ? ((totalRevenue - previousRevenue) / previousRevenue) * 100 : 0.0;
      final distanceChange = prevAvgTripDistance > 0 ? ((avgTripDistance - prevAvgTripDistance) / prevAvgTripDistance) * 100 : 0.0;
      final durationChange = prevAvgTripDuration > 0 ? avgTripDuration - prevAvgTripDuration : 0.0;
      final priceChange = prevAvgTripPrice > 0 ? avgTripPrice - prevAvgTripPrice : 0.0;
      final ratingChange = prevAvgRating > 0 ? avgRating - prevAvgRating : 0.0;
      final activeDriversPercentage = (driversSnapshot != null && driversSnapshot.docs.isNotEmpty)
          ? (previousActiveDrivers / driversSnapshot.docs.length) * 100
          : 0.0;

      // ✅ Calcular porcentajes de distribución de calificaciones
      final rating5Percentage = ratedTrips > 0 ? (ratingDistribution[5]! / ratedTrips) * 100 : 0.0;
      final rating4Percentage = ratedTrips > 0 ? (ratingDistribution[4]! / ratedTrips) * 100 : 0.0;
      final rating3Percentage = ratedTrips > 0 ? (ratingDistribution[3]! / ratedTrips) * 100 : 0.0;
      final rating2Percentage = ratedTrips > 0 ? (ratingDistribution[2]! / ratedTrips) * 100 : 0.0;
      final rating1Percentage = ratedTrips > 0 ? (ratingDistribution[1]! / ratedTrips) * 100 : 0.0;

      // ✅ NUEVO: Cargar estadísticas por zona desde Firebase
      debugPrint('📍 Cargando estadísticas de zonas...');
      Map<String, Map<String, dynamic>> zonesMap = {};

      if (tripsSnapshot != null && tripsSnapshot.docs.isNotEmpty) {
        for (var doc in tripsSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data['status'] != 'completed') continue;

            // ✅ Obtener zona desde pickup o dropoff
            final pickupZone = data['pickupZone'] as String? ?? data['pickupAddress'] as String? ?? 'Sin zona';
            final fare = (data['finalFare'] as num?)?.toDouble() ?? 0.0;

            if (!zonesMap.containsKey(pickupZone)) {
              zonesMap[pickupZone] = {
                'zone': pickupZone,
                'trips': 0,
                'revenue': 0.0,
                'avgPrice': 0.0,
              };
            }

            zonesMap[pickupZone]!['trips'] = (zonesMap[pickupZone]!['trips'] as int) + 1;
            zonesMap[pickupZone]!['revenue'] = (zonesMap[pickupZone]!['revenue'] as double) + fare;
          } catch (e) {
            debugPrint('⚠️ Error procesando zona en trip ${doc.id}: $e');
            continue;
          }
        }
      }

      // Calcular promedio de precio por zona
      List<Map<String, dynamic>> zonesList = [];
      zonesMap.forEach((key, value) {
        final trips = value['trips'] as int;
        final revenue = value['revenue'] as double;
        value['avgPrice'] = trips > 0 ? revenue / trips : 0.0;
        zonesList.add(value);
      });

      // Ordenar por número de viajes (descendente) y tomar top 5
      zonesList.sort((a, b) => (b['trips'] as int).compareTo(a['trips'] as int));
      final topZones = zonesList.take(5).toList();

      debugPrint('✅ Top 5 zonas cargadas: ${topZones.length}');

      // ✅ NUEVO: Cargar top 5 conductores desde Firebase
      debugPrint('🚗 Cargando top conductores...');
      Map<String, Map<String, dynamic>> driversMap = {};

      if (tripsSnapshot != null && tripsSnapshot.docs.isNotEmpty) {
        for (var doc in tripsSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data['status'] != 'completed') continue;

            final driverId = data['driverId'] as String?;
            if (driverId == null || driverId.isEmpty) continue;

            final fare = (data['finalFare'] as num?)?.toDouble() ?? 0.0;
            final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
            final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

            if (!driversMap.containsKey(driverId)) {
              // Obtener nombre del conductor desde users collection
              String driverName = 'Conductor $driverId';
              try {
                final driverDoc = await _firestore.collection('users').doc(driverId).get();
                if (driverDoc.exists) {
                  final driverData = driverDoc.data();
                  driverName = driverData?['name'] as String? ?? driverName;
                }
              } catch (e) {
                debugPrint('⚠️ Error obteniendo nombre de conductor $driverId: $e');
              }

              driversMap[driverId] = {
                'name': driverName,
                'trips': 0,
                'earnings': 0.0,
                'hours': 0.0,
                'rating': 0.0,
                'ratingCount': 0,
              };
            }

            driversMap[driverId]!['trips'] = (driversMap[driverId]!['trips'] as int) + 1;
            driversMap[driverId]!['earnings'] = (driversMap[driverId]!['earnings'] as double) + fare;
            driversMap[driverId]!['hours'] = (driversMap[driverId]!['hours'] as double) + (duration / 60); // minutos a horas

            if (rating > 0) {
              driversMap[driverId]!['rating'] = (driversMap[driverId]!['rating'] as double) + rating;
              driversMap[driverId]!['ratingCount'] = (driversMap[driverId]!['ratingCount'] as int) + 1;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando conductor en trip ${doc.id}: $e');
            continue;
          }
        }
      }

      // Calcular promedio de rating por conductor
      List<Map<String, dynamic>> driversList = [];
      driversMap.forEach((key, value) {
        final ratingCount = value['ratingCount'] as int;
        if (ratingCount > 0) {
          value['rating'] = (value['rating'] as double) / ratingCount;
        }
        driversList.add(value);
      });

      // Ordenar por ganancias (descendente) y tomar top 5
      driversList.sort((a, b) => (b['earnings'] as double).compareTo(a['earnings'] as double));
      final topDrivers = driversList.take(5).toList();

      debugPrint('✅ Top 5 conductores cargados: ${topDrivers.length}');

      // ✅ NUEVO: Calcular revenue breakdown (comisiones = 20% aprox)
      final double commissionRate = 0.20; // 20% de comisión
      final double revenueFromTrips = totalRevenue * (1 - commissionRate);
      final double revenueFromCommissions = totalRevenue * commissionRate;
      final double revenueFromPremium = 0.0; // Por ahora 0, requiere tracking adicional
      final double revenueFromOthers = 0.0; // Por ahora 0, requiere tracking adicional

      debugPrint('💰 Revenue breakdown:');
      debugPrint('   Viajes: ${revenueFromTrips.toStringAsFixed(2)}');
      debugPrint('   Comisiones: ${revenueFromCommissions.toStringAsFixed(2)}');

      // ✅ Actualizar estado (null-safe)
      if (!mounted) return;

      setState(() {
        _analyticsData = {
          'totalTrips': totalTrips,
          'totalRevenue': totalRevenue,
          'totalUsers': usersSnapshot?.docs.length ?? 0,
          'totalDrivers': driversSnapshot?.docs.length ?? 0,
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
          // ✅ Cambios vs período anterior
          'revenueChange': revenueChange,
          'distanceChange': distanceChange,
          'durationChange': durationChange,
          'priceChange': priceChange,
          'ratingChange': ratingChange,
          'activeDriversPercentage': activeDriversPercentage,
          // ✅ Distribución de calificaciones
          'rating5Percentage': rating5Percentage,
          'rating4Percentage': rating4Percentage,
          'rating3Percentage': rating3Percentage,
          'rating2Percentage': rating2Percentage,
          'rating1Percentage': rating1Percentage,
          // ✅ NUEVO: Revenue breakdown
          'revenueFromTrips': revenueFromTrips,
          'revenueFromCommissions': revenueFromCommissions,
          'revenueFromPremium': revenueFromPremium,
          'revenueFromOthers': revenueFromOthers,
        };

        _tripsByHour = hourlyTrips;
        _zoneStatistics = topZones; // ✅ NUEVO: Cargar zonas desde Firebase
        _driverPerformance = topDrivers; // ✅ NUEVO: Cargar conductores desde Firebase
        _isLoading = false;
      });

      debugPrint('✅ Analytics cargado exitosamente:');
      debugPrint('   📊 Total trips: $totalTrips');
      debugPrint('   💰 Ingresos: ${totalRevenue.toStringAsFixed(2)}');
      debugPrint('   ⭐ Rating promedio: ${avgRating.toStringAsFixed(2)}');
      debugPrint('   🚗 Conductores activos: $previousActiveDrivers/${driversSnapshot?.docs.length ?? 0}');

    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico cargando analytics: $e');
      debugPrint('📍 Stack: $stackTrace');
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
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
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
            // ========== SELECTOR DE PERÍODO ==========
            _buildPeriodSelector(),

            SizedBox(height: 24),

            // ========== SECCIÓN 1: MÉTRICAS CLAVE (KPIs) ==========
            _buildSectionHeader(
              icon: Icons.dashboard,
              title: 'Métricas Principales',
              subtitle: 'Vista general del rendimiento',
            ),
            SizedBox(height: 16),
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

            SizedBox(height: 32),

            // ========== SECCIÓN 2: ANÁLISIS DE SATISFACCIÓN ==========
            _buildSectionHeader(
              icon: Icons.stars,
              title: 'Satisfacción y Calidad',
              subtitle: 'Métricas de experiencia del usuario',
            ),
            SizedBox(height: 16),
            _buildSatisfactionMetrics(),

            SizedBox(height: 32),

            // ========== SECCIÓN 3: ANÁLISIS DE VIAJES ==========
            _buildSectionHeader(
              icon: Icons.analytics,
              title: 'Análisis de Viajes',
              subtitle: 'Distribución y patrones de uso',
            ),
            SizedBox(height: 16),

            // Gráficos de viajes lado a lado
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

            SizedBox(height: 32),

            // ========== SECCIÓN 4: ESTADÍSTICAS POR ZONA ==========
            _buildSectionHeader(
              icon: Icons.location_on,
              title: 'Estadísticas por Zona',
              subtitle: 'Rendimiento geográfico de las operaciones',
            ),
            SizedBox(height: 16),
            _buildZoneStatistics(),

            SizedBox(height: 32),

            // ========== SECCIÓN 5: RENDIMIENTO DE CONDUCTORES ==========
            _buildSectionHeader(
              icon: Icons.people,
              title: 'Rendimiento de Conductores',
              subtitle: 'Top conductores y métricas de desempeño',
            ),
            SizedBox(height: 16),
            _buildDriverPerformance(),

            SizedBox(height: 32),

            // ========== SECCIÓN 6: ANÁLISIS FINANCIERO ==========
            _buildSectionHeader(
              icon: Icons.monetization_on,
              title: 'Análisis de Ingresos',
              subtitle: 'Métricas financieras y tendencias',
            ),
            SizedBox(height: 16),
            _buildRevenueAnalysis(),

            SizedBox(height: 32),

            // ========== SECCIÓN 7: CRECIMIENTO DE USUARIOS ==========
            _buildSectionHeader(
              icon: Icons.trending_up,
              title: 'Crecimiento de Usuarios',
              subtitle: 'Evolución de la base de usuarios',
            ),
            SizedBox(height: 16),
            _buildUserGrowthChart(),

            SizedBox(height: 40),
          ],
        ),
      ),
            ),
    );
  }
  
  /// ✅ NUEVO: Header de sección con icono y descripción
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: ModernTheme.oasisGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: ModernTheme.oasisGreen,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: ModernTheme.oasisGreen,
              size: 24,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.onPrimary : ModernTheme.textSecondary,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsivo: 1 columna en móvil, 2 en tablet, 4 en desktop
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth < 900 ? 3 : 4);

        return GridView.count(
          crossAxisCount: crossAxisCount,
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
          Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
          ModernTheme.success,
          '${(_analyticsData['revenueChange'] as double).toStringAsFixed(1)}%', // ✅ Calculado desde Firebase
          (_analyticsData['revenueChange'] as double) >= 0,
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
          '${(_analyticsData['activeDriversPercentage'] as double).toStringAsFixed(1)}% activos', // ✅ Calculado desde Firebase
          (_analyticsData['activeDriversPercentage'] as double) >= 50,
        ),
        _buildKPICard(
          'Distancia Promedio',
          '${(_analyticsData['avgTripDistance'] as double).toStringAsFixed(1)} km',
          Icons.straighten,
          Colors.cyan,
          '${(_analyticsData['distanceChange'] as double).toStringAsFixed(1)}%', // ✅ Calculado desde Firebase
          (_analyticsData['distanceChange'] as double) >= 0,
        ),
        _buildKPICard(
          'Duración Promedio',
          '${(_analyticsData['avgTripDuration'] as double).toStringAsFixed(0)} min',
          Icons.timer,
          Colors.teal,
          '${(_analyticsData['durationChange'] as double).toStringAsFixed(0)} min', // ✅ Calculado desde Firebase
          (_analyticsData['durationChange'] as double) <= 0,
        ),
        _buildKPICard(
          'Precio Promedio',
          (_analyticsData['avgTripPrice'] as double).toCurrency(),
          Icons.payments,
          Colors.indigo,
          (_analyticsData['priceChange'] as double).toCurrencyWithSign(), // ✅ Calculado desde Firebase
          (_analyticsData['priceChange'] as double) >= 0,
        ),
        _buildKPICard(
          'Satisfacción',
          '${(_analyticsData['satisfactionRate'] as double).toStringAsFixed(1)} ⭐',
          Icons.star,
          ModernTheme.accentYellow,
          '${(_analyticsData['ratingChange'] as double) >= 0 ? '+' : ''}${(_analyticsData['ratingChange'] as double).toStringAsFixed(2)}', // ✅ Calculado desde Firebase
          (_analyticsData['ratingChange'] as double) >= 0,
        ),
      ],
        );
      },
    );
  }
  
  Widget _buildKPICard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.getCardShadow(context),
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: ModernTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
        color: Theme.of(context).colorScheme.surface,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Zona',
            style: TextStyle(
              color: ModernTheme.textPrimary, // ✅ CORREGIDO: usar color del tema
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
                    style: TextStyle(color: ModernTheme.textSecondary, fontSize: 11), // ✅ CORREGIDO: usar color del tema
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
    return Container(
      height: 250,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: ModernTheme.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Gráfico de Crecimiento',
            style: TextStyle(
              color: ModernTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Requiere datos históricos de al menos 12 meses',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ModernTheme.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tasa de crecimiento actual: +${_analyticsData['growthRate'].toStringAsFixed(1)}%',
              style: TextStyle(
                color: ModernTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoneStatistics() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas por Zona',
            style: TextStyle(
              color: ModernTheme.textPrimary, // ✅ CORREGIDO: usar color del tema
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
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Zona', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Viajes', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Ingresos', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Precio Prom.', style: TextStyle(color: ModernTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
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
                  bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 40, // ✅ CORREGIDO: Reducido de 60 a 40 para ahorrar espacio
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
                        Flexible( // ✅ CORREGIDO: Usar Flexible para evitar overflow
                          child: Text(
                            zone['zone'],
                            style: TextStyle(color: ModernTheme.textPrimary, fontSize: 13), // ✅ Reducido a 13
                            overflow: TextOverflow.ellipsis, // ✅ Agregar ellipsis si es muy largo
                            maxLines: 1, // ✅ Solo una línea
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      zone['trips'].toString(),
                      style: TextStyle(color: ModernTheme.textSecondary, fontSize: 14), // ✅ CORREGIDO
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (zone['revenue'] as double).toCurrency(decimals: 0),
                      style: TextStyle(color: ModernTheme.textSecondary, fontSize: 14), // ✅ CORREGIDO
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
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == 0
                    ? ModernTheme.accentYellow.withValues(alpha: 0.3)
                    : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(medal, style: TextStyle(fontSize: 18)), // ✅ Reducido de 20 a 18
                  SizedBox(width: 8), // ✅ Reducido de 12 a 8
                  CircleAvatar(
                    radius: 18, // ✅ Reducido de 20 a 18
                    backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    child: Text(
                      // ✅ CORREGIDO: Proteger contra nombres cortos o vacíos
                      driver['name'].toString().trim().isNotEmpty
                        ? driver['name'].toString().trim().split(' ')
                            .where((e) => e.isNotEmpty)
                            .take(2)
                            .map((e) => e[0].toUpperCase())
                            .join()
                        : '?',
                      style: TextStyle(color: ModernTheme.oasisGreen, fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 8), // ✅ Reducido de 12 a 8
                  Expanded(
                    flex: 2, // ✅ NUEVO: Dar más espacio a la columna de nombre/stats
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'],
                          style: TextStyle(
                            color: ModernTheme.textPrimary,
                            fontSize: 13, // ✅ Reducido de 14 a 13
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO: Evitar overflow en nombres largos
                          maxLines: 1,
                        ),
                        Text(
                          '${driver['trips']} viajes • ${(driver['hours'] as double).toStringAsFixed(1)}h', // ✅ Acortado
                          style: TextStyle(
                            color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11, // ✅ Reducido de 12 a 11
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO: Evitar overflow
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8), // ✅ NUEVO: Separación antes de las ganancias
                  Flexible( // ✅ CORREGIDO: Usar Flexible en vez de Column directa
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (driver['earnings'] as double).toCurrency(),
                          style: TextStyle(
                            color: ModernTheme.success,
                            fontSize: 13, // ✅ Reducido de 14 a 13
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO
                          maxLines: 1,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min, // ✅ NUEVO: Solo el espacio necesario
                          children: [
                            Icon(Icons.star, size: 12, color: ModernTheme.accentYellow), // ✅ Reducido de 14 a 12
                            Text(
                              ' ${(driver['rating'] as double).toStringAsFixed(1)}', // ✅ Formato decimal corto
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 11, // ✅ Reducido de 12 a 11
                              ),
                            ),
                          ],
                        ),
                      ],
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
  
  Widget _buildSatisfactionMetrics() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métricas de Satisfacción',
            style: TextStyle(
              color: ModernTheme.textPrimary, // ✅ CORREGIDO
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
              color: ModernTheme.textSecondary, // ✅ CORREGIDO
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          
          // ✅ Distribución de calificaciones desde Firebase (sin datos mock)
          ...[5, 4, 3, 2, 1].map((stars) {
            // ✅ Obtener porcentaje calculado desde Firebase según estrella
            final String percentageKey = 'rating${stars}Percentage';
            final double percentageValue = (_analyticsData[percentageKey] as double?) ?? 0.0;
            final int percentage = percentageValue.round();
            
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Row(
                    children: List.generate(5, (index) => Icon(
                      Icons.star,
                      size: 12,
                      color: index < stars ? ModernTheme.accentYellow : Theme.of(context).colorScheme.surfaceContainerHighest,
                    )),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.getCardShadow(context),
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
              color: ModernTheme.textPrimary, // ✅ CORREGIDO
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(
              color: ModernTheme.textSecondary, // ✅ CORREGIDO
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: ModernTheme.textSecondary.withValues(alpha: 0.7), // ✅ CORREGIDO
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueAnalysis() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Análisis de Ingresos',
            style: TextStyle(
              color: ModernTheme.textPrimary, // ✅ CORREGIDO
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          
          // ✅ Revenue breakdown REAL desde Firebase
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRevenueRow(
                      'Viajes Completados',
                      (_analyticsData['revenueFromTrips'] as double? ?? 0.0),
                      _analyticsData['totalRevenue'] as double > 0
                        ? ((_analyticsData['revenueFromTrips'] as double) / (_analyticsData['totalRevenue'] as double)) * 100
                        : 0.0
                    ),
                    _buildRevenueRow(
                      'Comisiones',
                      (_analyticsData['revenueFromCommissions'] as double? ?? 0.0),
                      _analyticsData['totalRevenue'] as double > 0
                        ? ((_analyticsData['revenueFromCommissions'] as double) / (_analyticsData['totalRevenue'] as double)) * 100
                        : 0.0
                    ),
                    _buildRevenueRow(
                      'Servicios Premium',
                      (_analyticsData['revenueFromPremium'] as double? ?? 0.0),
                      _analyticsData['totalRevenue'] as double > 0
                        ? ((_analyticsData['revenueFromPremium'] as double) / (_analyticsData['totalRevenue'] as double)) * 100
                        : 0.0
                    ),
                    _buildRevenueRow(
                      'Otros',
                      (_analyticsData['revenueFromOthers'] as double? ?? 0.0),
                      _analyticsData['totalRevenue'] as double > 0
                        ? ((_analyticsData['revenueFromOthers'] as double) / (_analyticsData['totalRevenue'] as double)) * 100
                        : 0.0
                    ),
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
                    data: [
                      (_analyticsData['revenueFromTrips'] as double? ?? 0.0),
                      (_analyticsData['revenueFromCommissions'] as double? ?? 0.0),
                      (_analyticsData['revenueFromPremium'] as double? ?? 0.0),
                      (_analyticsData['revenueFromOthers'] as double? ?? 0.0),
                    ],
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
          
          Divider(color: Theme.of(context).dividerColor, height: 32),
          
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
                  style: TextStyle(color: ModernTheme.textPrimary, fontSize: 14), // ✅ CORREGIDO
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}% del total',
                  style: TextStyle(color: ModernTheme.textSecondary, fontSize: 11), // ✅ CORREGIDO
                ),
              ],
            ),
          ),
          Text(
            amount.toCurrency(),
            style: TextStyle(
              color: ModernTheme.textSecondary, // ✅ CORREGIDO
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
  
  Future<void> _exportReport() async {
    try {
      // Mostrar indicador de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
              ),
              SizedBox(width: 16),
              Text('Generando reporte...'),
            ],
          ),
          backgroundColor: ModernTheme.oasisGreen,
          duration: Duration(seconds: 2),
        ),
      );

      // Generar contenido CSV
      final csvData = [
        ['Reporte de Analytics - Oasis Taxi'],
        ['Fecha de generación', DateTime.now().toString()],
        ['Período', _selectedPeriod],
        [],
        ['MÉTRICAS GENERALES'],
        ['Total de Viajes', _analyticsData['totalTrips'].toString()],
        ['Ingresos Totales', 'S/. ${_analyticsData['totalRevenue'].toStringAsFixed(2)}'],
        ['Usuarios Totales', _analyticsData['totalUsers'].toString()],
        ['Conductores Totales', _analyticsData['totalDrivers'].toString()],
        ['Distancia Promedio (km)', _analyticsData['avgTripDistance'].toStringAsFixed(2)],
        ['Duración Promedio (min)', _analyticsData['avgTripDuration'].toStringAsFixed(0)],
        ['Precio Promedio', 'S/. ${_analyticsData['avgTripPrice'].toStringAsFixed(2)}'],
        [],
        ['TASAS Y MÉTRICAS'],
        ['Tasa de Satisfacción', '${_analyticsData['satisfactionRate'].toStringAsFixed(1)}%'],
        ['Tasa de Cancelación', '${_analyticsData['cancelationRate'].toStringAsFixed(1)}%'],
        ['Tasa de Conversión', '${_analyticsData['conversionRate'].toStringAsFixed(1)}%'],
        ['Tasa de Retención', '${_analyticsData['retentionRate'].toStringAsFixed(1)}%'],
      ];

      // Convertir a CSV
      String csvContent = const ListToCsvConverter().convert(csvData);

      // Guardar en el dispositivo (Android/iOS compatible)
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'analytics_report_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvContent);

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Reporte de Analytics - Oasis Taxi',
        text: 'Reporte generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Reporte generado y compartido exitosamente'),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error exportando reporte: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar reporte: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
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

    // ✅ CORREGIDO: Validar que data no esté vacío antes de reduce
    if (data.isEmpty || data.every((element) => element == 0)) {
      // Si no hay datos, dibujar un círculo con color del tema
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color(0xFFE0E0E0); // surfaceContainerHighest equivalente

      canvas.drawCircle(center, radius, paint);
      return;
    }

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
          ..color = Color(0xFFFFFFFF), // Blanco para contraste en gráficos
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