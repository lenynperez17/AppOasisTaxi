// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/oasis_app_bar.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  _UsersManagementScreenState createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'Todos';
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ CORREGIDO: Usar addPostFrameCallback para cargar después del primer frame
    // Esto garantiza que el widget tree esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsersFromFirebase();
    });
  }

  @override
  void dispose() {
    // ✅ Liberar el TextEditingController para prevenir memory leak
    _searchController.dispose();
    super.dispose();
  }

  // Cargar usuarios reales desde Firebase
  Future<void> _loadUsersFromFirebase() async {
    // ✅ CORREGIDO: Verificar mounted antes de obtener messenger
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // ✅ CORREGIDO: Verificar mounted antes de setState
      if (!mounted) return;
      setState(() => _isLoading = true);

      // Obtener usuarios desde Firebase
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final List<User> loadedUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Calcular número de viajes del usuario
        int tripCount = 0;
        double avgRating = 0.0;

        // Obtener estadísticas de viajes según el rol
        if (data['role'] == 'driver') {
          final tripsSnapshot = await _firestore
              .collection('rides')
              .where('driverId', isEqualTo: doc.id)
              .where('status', isEqualTo: 'completed')
              .get();
          tripCount = tripsSnapshot.size;

          // Calcular rating promedio
          if (tripsSnapshot.docs.isNotEmpty) {
            double totalRating = 0;
            int ratingCount = 0;
            for (var trip in tripsSnapshot.docs) {
              if (trip.data()['rating'] != null) {
                totalRating += trip.data()['rating'];
                ratingCount++;
              }
            }
            avgRating = ratingCount > 0 ? totalRating / ratingCount : 4.5;
          } else {
            avgRating = 4.5;
          }
        } else {
          final tripsSnapshot = await _firestore
              .collection('rides')
              .where('passengerId', isEqualTo: doc.id)
              .where('status', isEqualTo: 'completed')
              .get();
          tripCount = tripsSnapshot.size;
          avgRating = data['rating'] ?? 4.5;
        }

        loadedUsers.add(User(
          id: doc.id,
          name: data['name'] ?? 'Sin nombre',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          type: data['role'] == 'driver' ? 'Conductor' : 'Pasajero',
          status: data['isActive'] == true ? 'Activo' :
                  data['isSuspended'] == true ? 'Suspendido' : 'Inactivo',
          registrationDate: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
          trips: tripCount,
          rating: avgRating,
        ));
      }

      // ✅ CORREGIDO: Verificar mounted antes de setState
      if (!mounted) return;
      setState(() {
        _users = loadedUsers;
        _filteredUsers = loadedUsers;
        _isLoading = false;
      });

    } catch (e) {
      print('Error cargando usuarios: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al cargar usuarios: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _filterUsers(String query) {
    // ✅ CORREGIDO: Verificar mounted antes de setState
    if (!mounted) return;
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()) ||
            user.phone.contains(query);

        final matchesFilter = _selectedFilter == 'Todos' ||
            (_selectedFilter == 'Activos' && user.status == 'Activo') ||
            (_selectedFilter == 'Suspendidos' && user.status == 'Suspendido') ||
            (_selectedFilter == 'Inactivos' && user.status == 'Inactivo') ||
            (_selectedFilter == 'Pasajeros' && user.type == 'Pasajero') ||
            (_selectedFilter == 'Conductores' && user.type == 'Conductor');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Gestión de Usuarios',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Campo de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: ModernTheme.backgroundLight,
                  ),
                  onChanged: _filterUsers,
                ),
                SizedBox(height: 16),
                // Chips de filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Activos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Suspendidos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Inactivos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Pasajeros'),
                      SizedBox(width: 8),
                      _buildFilterChip('Conductores'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Estadísticas
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Total', _users.length.toString(), Icons.people, Colors.blue),
                _buildStatCard('Activos', _users.where((u) => u.status == 'Activo').length.toString(), Icons.check_circle, Colors.green),
                _buildStatCard('Suspendidos', _users.where((u) => u.status == 'Suspendido').length.toString(), Icons.warning, Colors.orange),
                _buildStatCard('Inactivos', _users.where((u) => u.status == 'Inactivo').length.toString(), Icons.cancel, Colors.grey),
              ],
            ),
          ),
          
          // Lista de usuarios con indicador de carga
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando usuarios desde Firebase...',
                          style: TextStyle(color: ModernTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 64,
                              color: ModernTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No se encontraron usuarios',
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadUsersFromFirebase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ModernTheme.oasisGreen,
                              ),
                              child: Text('Recargar'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsersFromFirebase,
                        color: ModernTheme.oasisGreen,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? label : 'Todos';
        });
        _filterUsers(_searchController.text);
      },
      selectedColor: ModernTheme.oasisGreen.withValues(alpha: 0.2),
      checkmarkColor: ModernTheme.oasisGreen,
      labelStyle: TextStyle(
        color: isSelected ? ModernTheme.oasisGreen : ModernTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
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
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: _getUserTypeColor(user.type).withValues(alpha: 0.2),
                child: Icon(
                  user.type == 'Conductor' ? Icons.directions_car : Icons.person,
                  color: _getUserTypeColor(user.type),
                ),
              ),
              SizedBox(width: 16),
              
              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getUserTypeColor(user.type).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.type,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getUserTypeColor(user.type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: ModernTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          user.phone,
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                        SizedBox(width: 4),
                        Text(
                          user.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.route, size: 14, color: ModernTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          '${user.trips} viajes',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Estado y acciones
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(user.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        color: _getStatusColor(user.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: ModernTheme.textSecondary),
                    onSelected: (value) => _handleUserAction(user, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 20),
                            SizedBox(width: 8),
                            Text('Ver detalles'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      if (user.status == 'Activo')
                        PopupMenuItem(
                          value: 'suspend',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Suspender'),
                            ],
                          ),
                        ),
                      if (user.status == 'Suspendido')
                        PopupMenuItem(
                          value: 'activate',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Activar'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUserTypeColor(String type) {
    switch (type) {
      case 'Conductor':
        return ModernTheme.primaryBlue;
      case 'Pasajero':
        return ModernTheme.primaryOrange;
      default:
        return ModernTheme.textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Activo':
        return ModernTheme.success;
      case 'Suspendido':
        return ModernTheme.warning;
      case 'Inactivo':
        return ModernTheme.textSecondary;
      default:
        return ModernTheme.textSecondary;
    }
  }

  void _handleUserAction(User user, String action) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'suspend':
        _confirmSuspendUser(user);
        break;
      case 'activate':
        _confirmActivateUser(user);
        break;
      case 'delete':
        _confirmDeleteUser(user);
        break;
    }
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getUserTypeColor(user.type).withValues(alpha: 0.2),
              child: Icon(
                user.type == 'Conductor' ? Icons.directions_car : Icons.person,
                color: _getUserTypeColor(user.type),
              ),
            ),
            SizedBox(width: 12),
            Text(user.name),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email, Icons.email),
              _buildDetailRow('Teléfono', user.phone, Icons.phone),
              _buildDetailRow('Tipo', user.type, Icons.person),
              _buildDetailRow('Estado', user.status, Icons.info),
              _buildDetailRow('Registro', _formatDate(user.registrationDate), Icons.calendar_today),
              _buildDetailRow('Último acceso', _formatDate(user.lastLogin), Icons.access_time),
              _buildDetailRow('Viajes', user.trips.toString(), Icons.route),
              _buildDetailRow('Calificación', '${user.rating} ⭐', Icons.star),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.textSecondary),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    // Implementar diálogo para agregar usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Función para agregar usuario'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }

  void _showEditUserDialog(User user) {
    // Implementar diálogo para editar usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editando a ${user.name}'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }

  void _confirmSuspendUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suspender Usuario'),
        content: Text('¿Está seguro de suspender a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              // Actualizar en Firebase
              try {
                await _firestore.collection('users').doc(user.id).update({
                  'isActive': false,
                  'isSuspended': true,
                  'suspendedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                setState(() {
                  user.status = 'Suspendido';
                });

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario suspendido correctamente'),
                    backgroundColor: ModernTheme.warning,
                  ),
                );

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al suspender usuario: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: Text('Suspender'),
          ),
        ],
      ),
    );
  }

  void _confirmActivateUser(User user) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Actualizar en Firebase
      await _firestore.collection('users').doc(user.id).update({
        'isActive': true,
        'isSuspended': false,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        user.status = 'Activo';
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Usuario activado correctamente'),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Recargar usuarios
      _loadUsersFromFirebase();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al activar usuario: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Usuario'),
        content: Text('¿Está seguro de eliminar a ${user.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              try {
                // Eliminar de Firebase
                await _firestore.collection('users').doc(user.id).delete();

                if (!mounted) return;

                // También eliminar sus viajes asociados (opcional, depende de la lógica de negocio)
                // final ridesSnapshot = await _firestore
                //     .collection('rides')
                //     .where(user.role == 'driver' ? 'driverId' : 'passengerId', isEqualTo: user.id)
                //     .get();
                //
                // for (var doc in ridesSnapshot.docs) {
                //   await doc.reference.delete();
                // }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario eliminado correctamente'),
                    backgroundColor: ModernTheme.error,
                  ),
                );

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar usuario: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String type;
  String status;
  final DateTime registrationDate;
  final DateTime lastLogin;
  final int trips;
  final double rating;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    required this.status,
    required this.registrationDate,
    required this.lastLogin,
    required this.trips,
    required this.rating,
  });
}