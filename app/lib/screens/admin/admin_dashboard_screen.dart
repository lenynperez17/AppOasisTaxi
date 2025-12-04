import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../services/firebase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late FirebaseService _firebaseService;

  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDrivers': 0,
    'tripsToday': 0,
    'todayEarnings': 0.0,
    'activeUsers': 0,
    'onlineDrivers': 0,
    'availableDrivers': 0,
    'driversInTrip': 0,
  };

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      debugPrint('📊 Cargando datos del dashboard admin...');
      debugPrint('📅 Fecha actual: $now');
      debugPrint('🌅 Inicio del día: $todayStart');
      debugPrint('📆 Inicio del mes: $monthStart');

      // Consultas Firebase en paralelo para mejor performance
      QuerySnapshot<Map<String, dynamic>>? usersSnapshot;
      QuerySnapshot<Map<String, dynamic>>? driversSnapshot;
      QuerySnapshot<Map<String, dynamic>>? tripsSnapshot;
      QuerySnapshot<Map<String, dynamic>>? newUsersMonthSnapshot;
      QuerySnapshot<Map<String, dynamic>>? suspendedUsersSnapshot;
      QuerySnapshot<Map<String, dynamic>>? withdrawalsSnapshot;
      QuerySnapshot<Map<String, dynamic>>? disputesSnapshot;

      try {
        usersSnapshot = await _firebaseService.firestore.collection('users').get();
      } catch (e) {
        debugPrint('❌ Error cargando usuarios: $e');
      }

      try {
        // ✅ CORREGIDO: Buscar usuarios con userType 'driver' O 'dual'
        driversSnapshot = await _firebaseService.firestore
            .collection('users')
            .where('userType', whereIn: ['driver', 'dual'])
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando conductores: $e');
      }

      try {
        // ✅ CORREGIDO: Cambiar 'trips' a 'rides' (colección correcta)
        tripsSnapshot = await _firebaseService.firestore
            .collection('rides')
            .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando viajes: $e');
      }

      try {
        newUsersMonthSnapshot = await _firebaseService.firestore
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: monthStart)
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando usuarios nuevos: $e');
      }

      try {
        suspendedUsersSnapshot = await _firebaseService.firestore
            .collection('users')
            .where('isActive', isEqualTo: false)
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando usuarios suspendidos: $e');
      }

      try {
        withdrawalsSnapshot = await _firebaseService.firestore
            .collection('withdrawals')
            .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando retiros: $e');
      }

      try {
        disputesSnapshot = await _firebaseService.firestore
            .collection('disputes')
            .where('status', isEqualTo: 'open')
            .get();
      } catch (e) {
        debugPrint('❌ Error cargando disputas: $e');
      }

      debugPrint('✅ Resultados obtenidos:');
      debugPrint('   👥 Usuarios: ${usersSnapshot?.docs.length ?? 0}');
      debugPrint('   🚗 Conductores: ${driversSnapshot?.docs.length ?? 0}');
      debugPrint('   🚕 Viajes hoy: ${tripsSnapshot?.docs.length ?? 0}');

      double todayEarnings = 0.0;
      double totalPlatformCommission = 0.0;
      int activeUsers = 0;
      int onlineDrivers = 0;
      int availableDrivers = 0;
      int driversInTrip = 0;
      int completedTripsToday = 0;
      int pendingPayments = 0;
      double totalRating = 0.0;
      int ratedTrips = 0;

      // Calcular usuarios activos
      if (usersSnapshot != null) {
        for (var user in usersSnapshot.docs) {
          try {
            final userData = user.data() as Map<String, dynamic>?;
            if (userData != null && userData['isActive'] == true) activeUsers++;
          } catch (e) {
            debugPrint('⚠️ Error procesando usuario ${user.id}: $e');
          }
        }
      }

      // Calcular estados de conductores
      if (driversSnapshot != null) {
        for (var driver in driversSnapshot.docs) {
          try {
            final driverData = driver.data() as Map<String, dynamic>?;
            if (driverData != null) {
              if (driverData['isOnline'] == true) onlineDrivers++;
              if (driverData['isAvailable'] == true) availableDrivers++;
              if (driverData['status'] == 'in_trip') driversInTrip++;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando conductor ${driver.id}: $e');
          }
        }
      }

      // Calcular ingresos, comisiones y ratings del día
      if (tripsSnapshot != null) {
        for (var trip in tripsSnapshot.docs) {
          try {
            final tripData = trip.data() as Map<String, dynamic>?;
            if (tripData == null) continue;

            final status = tripData['status'];

            if (status == 'completed') {
              completedTripsToday++;
              final fare = (tripData['finalFare'] ?? 0.0).toDouble();
              final commission =
                  (tripData['platformCommission'] ?? 0.0).toDouble();
              todayEarnings += fare;
              totalPlatformCommission += commission;

              // Calcular rating promedio
              if (tripData['rating'] != null) {
                totalRating += (tripData['rating'] as num).toDouble();
                ratedTrips++;
              }
            } else if (status == 'pending_payment') {
              pendingPayments++;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando viaje ${trip.id}: $e');
          }
        }
      }

      final averageRating = ratedTrips > 0 ? totalRating / ratedTrips : 0.0;
      final conversionRate = (tripsSnapshot != null && tripsSnapshot.docs.isNotEmpty)
          ? (completedTripsToday / tripsSnapshot.docs.length * 100)
          : 0.0;

      debugPrint('💰 Ingresos hoy: S/. ${todayEarnings.toStringAsFixed(2)}');
      debugPrint('⭐ Rating promedio: ${averageRating.toStringAsFixed(1)}');
      debugPrint('📈 Tasa de conversión: ${conversionRate.toStringAsFixed(1)}%');

      // ✅ CORREGIDO: Verificar mounted antes de setState para evitar error de dispose
      if (!mounted) return;

      setState(() {
        _stats = {
          'totalUsers': usersSnapshot?.docs.length ?? 0,
          'totalDrivers': driversSnapshot?.docs.length ?? 0,
          'tripsToday': tripsSnapshot?.docs.length ?? 0,
          'todayEarnings': todayEarnings,
          'activeUsers': activeUsers,
          'onlineDrivers': onlineDrivers,
          'availableDrivers': availableDrivers,
          'driversInTrip': driversInTrip,
          'newUsersMonth': newUsersMonthSnapshot?.docs.length ?? 0,
          'suspendedUsers': suspendedUsersSnapshot?.docs.length ?? 0,
          'averageRating': averageRating,
          'conversionRate': conversionRate,
          'completedTripsToday': completedTripsToday,
          'pendingPayments': pendingPayments,
          'withdrawalsToday': withdrawalsSnapshot?.docs.length ?? 0,
          'openDisputes': disputesSnapshot?.docs.length ?? 0,
          'platformCommission': totalPlatformCommission,
        };
      });

      debugPrint('✅ Dashboard cargado exitosamente');
    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico loading dashboard: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el dashboard: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      icon: Icons.dashboard,
      title: 'Dashboard',
      subtitle: 'Vista general',
    ),
    AdminMenuItem(
      icon: Icons.people,
      title: 'Usuarios',
      subtitle: 'Gestión de usuarios',
    ),
    AdminMenuItem(
      icon: Icons.directions_car,
      title: 'Conductores',
      subtitle: 'Gestión de conductores',
    ),
    AdminMenuItem(
      icon: Icons.analytics,
      title: 'Analíticas',
      subtitle: 'Estadísticas y reportes',
    ),
    AdminMenuItem(
      icon: Icons.account_balance_wallet,
      title: 'Finanzas',
      subtitle: 'Gestión financiera',
    ),
    AdminMenuItem(
      icon: Icons.settings,
      title: 'Configuración',
      subtitle: 'Ajustes del sistema',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Panel Administrativo',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              Navigator.pushNamed(context, '/shared/notifications');
            },
            tooltip: 'Notificaciones',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Layout para desktop/tablet
            return Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _buildSidebar(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          } else {
            // Layout para móvil
            return Column(
              children: [
                SizedBox(
                  height: 60,
                  child: _buildMobileNav(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const OasisDrawerHeader(
            userType: 'admin',
            userName: 'Administrador',
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = index == _selectedIndex;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? ModernTheme.oasisGreen
                          : ModernTheme.textSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected
                            ? ModernTheme.oasisGreen
                            : ModernTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      // Navegar a las pantallas correspondientes
                      switch (index) {
                        case 1:
                          Navigator.pushNamed(context, '/admin/users-management');
                          break;
                        case 2:
                          Navigator.pushNamed(context, '/admin/drivers-management');
                          break;
                        case 3:
                          Navigator.pushNamed(context, '/admin/analytics');
                          break;
                        case 4:
                          Navigator.pushNamed(context, '/admin/financial');
                          break;
                        case 5:
                          Navigator.pushNamed(context, '/admin/settings');
                          break;
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNav() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final isSelected = index == _selectedIndex;
          
          return SizedBox(
            width: 80,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? ModernTheme.oasisGreen
                        : ModernTheme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected
                          ? ModernTheme.oasisGreen
                          : ModernTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _menuItems[_selectedIndex].title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _menuItems[_selectedIndex].subtitle,
            style: const TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildContentForIndex(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildDriversContent();
      case 3:
        return _buildAnalyticsContent();
      case 4:
        return _buildFinancesContent();
      case 5:
        return _buildSettingsContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
      children: [
        _buildStatsCard('Usuarios Totales', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
        _buildStatsCard('Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
        _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.orange),
        _buildStatsCard('Ingresos', 'S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.purple), // ✅ Moneda en Soles
      ],
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.getCardShadow(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de usuarios
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Total Usuarios', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
              _buildStatsCard('Activos', _stats['activeUsers'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Nuevos (Mes)', _stats['newUsersMonth'].toString(), Icons.person_add, Colors.orange),
              _buildStatsCard('Suspendidos', _stats['suspendedUsers'].toString(), Icons.block, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/users-management'),
            icon: const Icon(Icons.manage_accounts),
            label: const Text('Gestión Completa de Usuarios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de conductores
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Total Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
              _buildStatsCard('En Línea', _stats['onlineDrivers'].toString(), Icons.wifi, Colors.blue),
              _buildStatsCard('Disponibles', _stats['availableDrivers'].toString(), Icons.check, Colors.orange),
              _buildStatsCard('En Viaje', _stats['driversInTrip'].toString(), Icons.route, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/drivers-management'),
            icon: const Icon(Icons.drive_eta),
            label: const Text('Gestión Completa de Conductores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // KPIs principales
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.blue),
              _buildStatsCard('Ingresos Hoy', 'S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.green),
              _buildStatsCard('Rating Promedio', '${_stats['averageRating'].toStringAsFixed(1)}⭐', Icons.star, Colors.amber),
              _buildStatsCard('Tasa Conversión', '${_stats['conversionRate'].toStringAsFixed(0)}%', Icons.trending_up, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a analíticas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/analytics'),
            icon: const Icon(Icons.analytics),
            label: const Text('Ver Analíticas Completas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancesContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Resumen financiero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              children: [
                Text(
                  'Balance del Día',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'S/. ${_stats['todayEarnings'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Ingresos', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))),
                        Text('S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3)),
                    Column(
                      children: [
                        Text('Comisiones', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))),
                        Text('S/. ${_stats['platformCommission'].toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Estadísticas financieras
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildStatsCard('Pagos Pendientes', _stats['pendingPayments'].toString(), Icons.pending, Colors.orange),
              _buildStatsCard('Pagos Completados', _stats['completedTripsToday'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Retiros Hoy', _stats['withdrawalsToday'].toString(), Icons.account_balance, Colors.blue),
              _buildStatsCard('Disputas', _stats['openDisputes'].toString(), Icons.warning, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a finanzas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/financial'),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Gestión Financiera Completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Lista de configuraciones
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: ModernTheme.oasisGreen),
                  title: const Text('Tarifas y Precios'),
                  subtitle: const Text('Configurar tarifas base y comisiones'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map, color: ModernTheme.primaryBlue),
                  title: const Text('Zonas y Cobertura'),
                  subtitle: const Text('Gestionar áreas de servicio'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_offer, color: ModernTheme.primaryOrange),
                  title: const Text('Promociones'),
                  subtitle: const Text('Códigos y descuentos activos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications, color: ModernTheme.warning),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Configurar alertas y mensajes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/shared/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: ModernTheme.error),
                  title: const Text('Seguridad'),
                  subtitle: const Text('Políticas y permisos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Botón para ir a configuración completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/settings'),
            icon: const Icon(Icons.settings),
            label: const Text('Configuración Completa del Sistema'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;

  AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}