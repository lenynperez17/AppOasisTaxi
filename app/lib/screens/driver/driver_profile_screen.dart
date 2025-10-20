// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
// ✅ FIX: Removido dart:io - ya no necesario (usamos NetworkImage, no FileImage)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';
import 'documents_screen.dart';
import 'earnings_withdrawal_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  _DriverProfileScreenState createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Profile data
  DriverProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;

  // ✅ NUEVO: Documentos del conductor
  Map<String, String>? _documents;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _loadProfile();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  // ✅ Cargar perfil real desde Firebase
  void _loadProfile() async {
    try {
      // ✅ Obtener usuario actual de Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No hay usuario autenticado');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final userId = currentUser.uid;

      // ✅ Cargar datos del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('⚠️ Documento de usuario no existe: $userId');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final userData = userDoc.data()!;

      // ✅ Calcular estadísticas desde la colección rides
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalDistance = 0.0;
      double totalEarnings = 0.0;
      double totalHours = 0.0;

      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        if (data['distance'] != null) {
          totalDistance += (data['distance'] as num).toDouble();
        }
        if (data['fare'] != null) {
          totalEarnings += (data['fare'] as num).toDouble();
        }
        if (data['startedAt'] != null && data['completedAt'] != null) {
          final startedAt = (data['startedAt'] as Timestamp).toDate();
          final completedAt = (data['completedAt'] as Timestamp).toDate();
          final duration = completedAt.difference(startedAt);
          totalHours += duration.inMinutes / 60.0;
        }
      }

      // ✅ Extraer datos del perfil con valores por defecto seguros
      final emergencyContactData = userData['emergencyContact'] as Map<String, dynamic>?;
      final preferencesData = userData['preferences'] as Map<String, dynamic>?;
      final vehicleInfoData = userData['vehicleInfo'] as Map<String, dynamic>?;
      final workScheduleData = userData['workSchedule'] as Map<String, dynamic>?;

      // 🔍 DEBUG: Verificar si vehicleInfo existe en Firebase
      print('📊 DEBUG - Datos de vehículo desde Firebase:');
      print('   vehicleInfoData existe: ${vehicleInfoData != null}');
      if (vehicleInfoData != null) {
        print('   Marca: ${vehicleInfoData['make']}');
        print('   Modelo: ${vehicleInfoData['model']}');
        print('   Año: ${vehicleInfoData['year']}');
        print('   Color: ${vehicleInfoData['color']}');
        print('   Placa: ${vehicleInfoData['plate']}');
        print('   Capacidad: ${vehicleInfoData['capacity']}');
      } else {
        print('   ⚠️ vehicleInfo NO ENCONTRADO en Firebase para usuario: $userId');
      }

      // ✅ NUEVO: Cargar documentos del conductor
      final documentsData = userData['documents'] as Map<String, dynamic>?;
      _documents = documentsData?.map((key, value) => MapEntry(key, value.toString()));

      // 🔍 DEBUG: Verificar si documentos existen en Firebase
      print('📄 DEBUG - Datos de documentos desde Firebase:');
      print('   documentsData existe: ${documentsData != null}');
      if (documentsData != null) {
        print('   Documentos encontrados: ${documentsData.keys.join(', ')}');
        documentsData.forEach((key, value) {
          print('   - $key: $value');
        });
      } else {
        print('   ⚠️ documents NO ENCONTRADO en Firebase para usuario: $userId');
      }

      // ✅ Cargar logros desde colección achievements si existe
      List<Achievement> achievementsList = [];
      final achievementsSnapshot = await FirebaseFirestore.instance
          .collection('achievements')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in achievementsSnapshot.docs) {
        final data = doc.data();
        achievementsList.add(Achievement(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          iconUrl: data['iconUrl'] ?? '',
          unlockedDate: (data['unlockedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      if (mounted) {
        setState(() {
          _profile = DriverProfile(
            id: userId,
          name: userData['fullName'] ?? currentUser.displayName ?? '',
          email: userData['email'] ?? currentUser.email ?? '',
          phone: userData['phone'] ?? '',
          profileImageUrl: userData['profilePhotoUrl'] ?? currentUser.photoURL ?? '',
          rating: (userData['rating'] ?? 5.0).toDouble(),
          totalTrips: ridesSnapshot.docs.length,
          totalDistance: totalDistance,
          totalHours: totalHours,
          totalEarnings: totalEarnings,
          memberSince: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          bio: userData['bio'] ?? '',
          emergencyContact: EmergencyContact(
            name: emergencyContactData?['name'] ?? '',
            phone: emergencyContactData?['phone'] ?? '',
            relationship: emergencyContactData?['relationship'] ?? '',
          ),
          preferences: DriverPreferences(
            acceptPets: preferencesData?['acceptPets'] ?? false,
            acceptSmoking: preferencesData?['acceptSmoking'] ?? false,
            musicPreference: preferencesData?['musicPreference'] ?? '',
            languages: (preferencesData?['languages'] as List<dynamic>?)?.cast<String>() ?? [],
            // ✅ FIX: Asegurar que maxTripDistance esté en el rango válido (min: 5, max: 100)
            maxTripDistance: ((preferencesData?['maxTripDistance'] ?? 50.0) as num).toDouble().clamp(5.0, 100.0),
            preferredZones: (preferencesData?['preferredZones'] as List<dynamic>?)?.cast<String>() ?? [],
          ),
          achievements: achievementsList,
          vehicleInfo: VehicleInfo(
            make: vehicleInfoData?['make'] ?? '',
            model: vehicleInfoData?['model'] ?? '',
            year: vehicleInfoData?['year'] ?? 0,
            color: vehicleInfoData?['color'] ?? '',
            plate: vehicleInfoData?['plate'] ?? '',
            capacity: vehicleInfoData?['capacity'] ?? 4,
          ),
          workSchedule: WorkSchedule(
            mondayStart: workScheduleData?['mondayStart'] ?? '00:00',
            mondayEnd: workScheduleData?['mondayEnd'] ?? '00:00',
            tuesdayStart: workScheduleData?['tuesdayStart'] ?? '00:00',
            tuesdayEnd: workScheduleData?['tuesdayEnd'] ?? '00:00',
            wednesdayStart: workScheduleData?['wednesdayStart'] ?? '00:00',
            wednesdayEnd: workScheduleData?['wednesdayEnd'] ?? '00:00',
            thursdayStart: workScheduleData?['thursdayStart'] ?? '00:00',
            thursdayEnd: workScheduleData?['thursdayEnd'] ?? '00:00',
            fridayStart: workScheduleData?['fridayStart'] ?? '00:00',
            fridayEnd: workScheduleData?['fridayEnd'] ?? '00:00',
            saturdayStart: workScheduleData?['saturdayStart'] ?? '00:00',
            saturdayEnd: workScheduleData?['saturdayEnd'] ?? '00:00',
            sundayStart: workScheduleData?['sundayStart'] ?? '00:00',
            sundayEnd: workScheduleData?['sundayEnd'] ?? '00:00',
          ),
        );
        _isLoading = false;

        // Inicializar controladores del formulario con datos reales
        _nameController.text = _profile!.name;
        _phoneController.text = _profile!.phone;
        _emailController.text = _profile!.email;
        _emergencyContactController.text = _profile!.emergencyContact.name;
        _emergencyPhoneController.text = _profile!.emergencyContact.phone;
        _bioController.text = _profile!.bio;
        });
      }

      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      print('❌ Error al cargar perfil: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Cada sección tiene su propio botón de editar, no se necesita botón global
      ),
      body: _isLoading ? _buildLoadingState() : _buildProfile(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando perfil...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfile() {
    // ✅ CRÍTICO: Validar que _profile no sea null antes de renderizar
    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar el perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Por favor, intenta nuevamente',
              style: TextStyle(
                color: ModernTheme.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
              ),
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile header
                _buildProfileHeader(),

                // Stats overview
                _buildStatsOverview(),
                
                // Personal information
                _buildPersonalInfoSection(),
                
                // Vehicle information
                _buildVehicleInfoSection(),

                // ✅ NUEVO: Documentos del conductor
                if (_documents != null && _documents!.isNotEmpty)
                  _buildDocumentsSection(),

                // Métodos de retiro están en wallet_screen.dart

                // Achievements
                _buildAchievementsSection(),
                
                // Preferences
                _buildPreferencesSection(),
                
                // Work schedule
                _buildWorkScheduleSection(),
                
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProfileHeader() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(24),
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
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _profile!.profileImageUrl.isEmpty
                            ? LinearGradient(
                                colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)],
                              )
                            : null,
                        // ✅ FIX: Usar NetworkImage para URLs de Firebase Storage (NO FileImage)
                        image: _profile!.profileImageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_profile!.profileImageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: _profile!.profileImageUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _changeProfileImage,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: ModernTheme.oasisGreen, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: ModernTheme.oasisGreen,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  _profile!.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          size: 16,
                          color: index < _profile!.rating.floor()
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.3),
                        );
                      }),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${_profile!.rating} (${_profile!.totalTrips} viajes)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Miembro desde ${_formatMemberSince(_profile!.memberSince)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatsOverview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Viajes',
              '${_profile!.totalTrips}',
              Icons.directions_car,
              ModernTheme.primaryBlue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Kilómetros',
              '${(_profile!.totalDistance / 1000).toStringAsFixed(1)}K',
              Icons.straighten,
              ModernTheme.success,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ganancias',
              _profile!.totalEarnings.toCurrencyCompact(),
              Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
              ModernTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
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
  
  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        if (_isEditing) ...[
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu teléfono';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Ingresa un email válido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _bioController,
                  label: 'Descripción personal',
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 200) {
                      return 'Máximo 200 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          _buildInfoRow('Nombre', _profile!.name, Icons.person),
          _buildInfoRow('Teléfono', _profile!.phone, Icons.phone),
          _buildInfoRow('Email', _profile!.email, Icons.email),
          if (_profile!.bio.isNotEmpty)
            _buildInfoRow('Bio', _profile!.bio, Icons.description),
        ],
        
        SizedBox(height: 20),
        
        // Emergency contact
        Text(
          'Contacto de Emergencia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.error,
          ),
        ),
        SizedBox(height: 12),
        
        if (_isEditing) ...[
          _buildTextFormField(
            controller: _emergencyContactController,
            label: 'Nombre del contacto',
            icon: Icons.emergency,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el nombre del contacto';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          _buildTextFormField(
            controller: _emergencyPhoneController,
            label: 'Teléfono de emergencia',
            icon: Icons.phone_in_talk,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el teléfono de emergencia';
              }
              return null;
            },
          ),
        ] else ...[
          _buildInfoRow('Nombre', _profile!.emergencyContact.name, Icons.emergency),
          _buildInfoRow('Teléfono', _profile!.emergencyContact.phone, Icons.phone_in_talk),
          _buildInfoRow('Relación', _profile!.emergencyContact.relationship, Icons.family_restroom),
        ],

        // ✅ NUEVO: Botones de acción cuando está en modo edición
        if (_isEditing) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      // Restaurar valores originales
                      _nameController.text = _profile!.name;
                      _phoneController.text = _profile!.phone;
                      _emailController.text = _profile!.email;
                      _bioController.text = _profile!.bio;
                      _emergencyContactController.text = _profile!.emergencyContact.name;
                      _emergencyPhoneController.text = _profile!.emergencyContact.phone;
                    });
                  },
                  icon: Icon(Icons.cancel, color: ModernTheme.error),
                  label: Text('Cancelar', style: TextStyle(color: ModernTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ModernTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Text('Guardar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      onEdit: _isEditing ? null : () => _toggleEdit(),
    );
  }
  
  Widget _buildVehicleInfoSection() {
    return _buildSection(
      'Información del Vehículo',
      Icons.directions_car,
      ModernTheme.oasisGreen,
      [
        _buildInfoRow('Marca', _profile!.vehicleInfo.make, Icons.directions_car),
        _buildInfoRow('Modelo', _profile!.vehicleInfo.model, Icons.drive_eta),
        _buildInfoRow('Año', '${_profile!.vehicleInfo.year}', Icons.calendar_today),
        _buildInfoRow('Color', _profile!.vehicleInfo.color, Icons.palette),
        _buildInfoRow('Placa', _profile!.vehicleInfo.plate, Icons.confirmation_number),
        _buildInfoRow('Capacidad', '${_profile!.vehicleInfo.capacity} pasajeros', Icons.people),
      ],
      onEdit: () => _showEditVehicleDialog(),
    );
  }

  /// ✅ CORREGIDO: Mostrar diálogo para editar información del vehículo
  void _showEditVehicleDialog() {
    // ✅ Crear controllers con valores iniciales
    final makeController = TextEditingController(text: _profile!.vehicleInfo.make);
    final modelController = TextEditingController(text: _profile!.vehicleInfo.model);
    final yearController = TextEditingController(text: '${_profile!.vehicleInfo.year}');
    final colorController = TextEditingController(text: _profile!.vehicleInfo.color);
    final plateController = TextEditingController(text: _profile!.vehicleInfo.plate);
    final capacityController = TextEditingController(text: '${_profile!.vehicleInfo.capacity}');

    showDialog(
      context: context,
      barrierDismissible: false, // ✅ Prevenir cierre accidental
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async {
          // ✅ Limpiar controllers al cerrar con back button
          makeController.dispose();
          modelController.dispose();
          yearController.dispose();
          colorController.dispose();
          plateController.dispose();
          capacityController.dispose();
          return true;
        },
        child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.directions_car, color: ModernTheme.oasisGreen),
            SizedBox(width: 12),
            Expanded(
              child: Text('Editar Información del Vehículo'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextFormField(
                controller: makeController,
                label: 'Marca',
                icon: Icons.business,
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: modelController,
                label: 'Modelo',
                icon: Icons.drive_eta,
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: yearController,
                label: 'Año',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: colorController,
                label: 'Color',
                icon: Icons.palette,
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: plateController,
                label: 'Placa',
                icon: Icons.confirmation_number,
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: capacityController,
                label: 'Capacidad de pasajeros',
                icon: Icons.people,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ✅ Limpiar controllers antes de cerrar
              makeController.dispose();
              modelController.dispose();
              yearController.dispose();
              colorController.dispose();
              plateController.dispose();
              capacityController.dispose();
              Navigator.pop(dialogContext);
            },
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // ✅ Obtener valores ANTES de cualquier operación asíncrona
                final make = makeController.text.trim();
                final model = modelController.text.trim();
                final year = int.tryParse(yearController.text.trim()) ?? 0;
                final color = colorController.text.trim();
                final plate = plateController.text.trim().toUpperCase();
                final capacity = int.tryParse(capacityController.text.trim()) ?? 4;

                // ✅ Obtener userId actual
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) {
                  throw Exception('Usuario no autenticado');
                }

                // ✅ Actualizar en Firebase
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'vehicleInfo': {
                    'make': make,
                    'model': model,
                    'year': year,
                    'color': color,
                    'plate': plate,
                    'capacity': capacity,
                  },
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // ✅ Limpiar controllers ANTES de cerrar dialog
                makeController.dispose();
                modelController.dispose();
                yearController.dispose();
                colorController.dispose();
                plateController.dispose();
                capacityController.dispose();

                // ✅ Cerrar dialog usando el contexto correcto
                if (mounted) {
                  Navigator.pop(dialogContext);

                  // ✅ Recargar datos
                  _loadProfile();

                  // ✅ Mostrar mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Información del vehículo actualizada correctamente'),
                      backgroundColor: ModernTheme.oasisGreen,
                    ),
                  );
                }
              } catch (e) {
                // ✅ Limpiar controllers en caso de error
                makeController.dispose();
                modelController.dispose();
                yearController.dispose();
                colorController.dispose();
                plateController.dispose();
                capacityController.dispose();

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Sección de documentos del conductor
  Widget _buildDocumentsSection() {
    final documentLabels = {
      'dniPhoto': 'Documento de Identidad',
      'licensePhoto': 'Licencia de Conducir',
      'vehiclePhoto': 'Foto del Vehículo',
      'criminalRecordPhoto': 'Antecedentes Penales',
      'soatPhoto': 'SOAT',
      'technicalReviewPhoto': 'Revisión Técnica',
      'ownershipPhoto': 'Tarjeta de Propiedad',
    };

    final documentIcons = {
      'dniPhoto': Icons.badge,
      'licensePhoto': Icons.credit_card,
      'vehiclePhoto': Icons.directions_car,
      'criminalRecordPhoto': Icons.shield_outlined,
      'soatPhoto': Icons.verified_user_outlined,
      'technicalReviewPhoto': Icons.build_circle_outlined,
      'ownershipPhoto': Icons.article_outlined,
    };

    return _buildSection(
      'Documentos Subidos',
      Icons.folder_outlined,
      ModernTheme.warning,
      [
        ..._documents!.entries.map((entry) {
          final label = documentLabels[entry.key] ?? entry.key;
          final icon = documentIcons[entry.key] ?? Icons.insert_drive_file;
          final hasDocument = entry.value.isNotEmpty;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: ModernTheme.textSecondary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            hasDocument ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: hasDocument ? ModernTheme.success : ModernTheme.error,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              hasDocument ? 'Subido' : 'No subido',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasDocument ? ModernTheme.success : ModernTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasDocument)
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      icon: Icon(Icons.visibility, color: ModernTheme.primaryBlue, size: 20),
                      onPressed: () => _viewDocument(entry.key, entry.value),
                      tooltip: 'Ver documento',
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
      onEdit: () {
        // Navegar a la pantalla de documentos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DocumentsScreen(),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: Sección de configuración de métodos de retiro
  Widget _buildWithdrawalMethodsSection() {
    return _buildSection(
      'Métodos de Retiro',
      Icons.account_balance_wallet,
      ModernTheme.primaryBlue,
      [
        Text(
          'Configura tus métodos de retiro para recibir tus ganancias',
          style: TextStyle(
            fontSize: 14,
            color: ModernTheme.textSecondary,
          ),
        ),
        SizedBox(height: 16),

        // Cuenta bancaria
        _buildPaymentMethodCard(
          'Cuenta Bancaria',
          'Retiros en 1-2 días hábiles',
          Icons.account_balance,
          ModernTheme.success,
          () => _configurePaymentMethod('bank'),
        ),

        SizedBox(height: 12),

        // Tarjeta de débito
        _buildPaymentMethodCard(
          'Tarjeta de Débito',
          'Retiros instantáneos',
          Icons.credit_card,
          ModernTheme.warning,
          () => _configurePaymentMethod('card'),
        ),

        SizedBox(height: 12),

        // Efectivo en oficina
        _buildPaymentMethodCard(
          'Efectivo en Oficina',
          'Retiro inmediato en nuestras oficinas',
          Icons.store,
          ModernTheme.info,
          () => _configurePaymentMethod('cash'),
        ),
      ],
      onEdit: () {
        // Navegar a la pantalla de configuración de retiros
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EarningsWithdrawalScreen(driverId: userId),
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentMethodCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _viewDocument(String documentType, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ver Documento'),
        content: Text('URL del documento:\n\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ✅ REAL: Configurar método de retiro con formularios completos
  void _configurePaymentMethod(String method) async {
    if (method == 'bank') {
      _showBankAccountForm();
    } else if (method == 'card') {
      _showDebitCardForm();
    } else if (method == 'cash') {
      _showCashPickupInfo();
    }
  }

  // ✅ REAL: Formulario de cuenta bancaria
  void _showBankAccountForm() {
    final formKey = GlobalKey<FormState>(debugLabel: 'bankAccountForm');
    final accountTypeController = TextEditingController(text: 'savings');
    final accountNumberController = TextEditingController();
    final cciController = TextEditingController();
    final holderNameController = TextEditingController(text: _profile?.name ?? '');
    final holderDniController = TextEditingController();

    // Bancos de Perú
    final banks = [
      'BCP - Banco de Crédito del Perú',
      'BBVA',
      'Interbank',
      'Scotiabank',
      'Banco de la Nación',
      'Banco Pichincha',
      'BanBif',
      'Banco Falabella',
      'Banco Ripley',
      'Otro',
    ];
    String selectedBank = banks[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.account_balance, color: ModernTheme.success),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Cuenta Bancaria',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura tu cuenta bancaria para recibir retiros en 1-2 días hábiles',
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Banco
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Banco',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: banks.map((bank) {
                      return DropdownMenuItem(
                        value: bank,
                        child: Text(
                          bank,
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedBank = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Tipo de cuenta
                  DropdownButtonFormField<String>(
                    value: accountTypeController.text.isEmpty ||
                           (accountTypeController.text != 'savings' && accountTypeController.text != 'checking')
                        ? 'savings'
                        : accountTypeController.text,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Cuenta',
                      prefixIcon: Icon(Icons.account_box),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
                      DropdownMenuItem(value: 'checking', child: Text('Corriente')),
                    ],
                    onChanged: (value) {
                      setState(() => accountTypeController.text = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Número de cuenta
                  TextFormField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'Número de Cuenta',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el número de cuenta';
                      }
                      if (value.length < 10) {
                        return 'Mínimo 10 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // CCI
                  TextFormField(
                    controller: cciController,
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'CCI (Código de Cuenta Interbancaria)',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                      hintText: '20 dígitos',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el CCI';
                      }
                      if (value.length != 20) {
                        return 'El CCI debe tener 20 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Titular
                  TextFormField(
                    controller: holderNameController,
                    decoration: InputDecoration(
                      labelText: 'Titular de la Cuenta',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el nombre del titular';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // DNI del titular
                  TextFormField(
                    controller: holderDniController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: 'DNI del Titular',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el DNI';
                      }
                      if (value.length != 8) {
                        return 'El DNI debe tener 8 dígitos';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // ✅ GUARDAR en Firestore
                  try {
                    final userId = FirebaseAuth.instance.currentUser!.uid;
                    final paymentMethodData = {
                      'userId': userId,
                      'type': 'bank',
                      'status': 'pending_verification',
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'bankName': selectedBank,
                      'accountType': accountTypeController.text,
                      'accountNumber': accountNumberController.text,
                      'cci': cciController.text,
                      'accountHolderName': holderNameController.text,
                      'accountHolderDni': holderDniController.text,
                      'isDefault': true,
                    };

                    await FirebaseFirestore.instance
                        .collection('paymentMethods')
                        .add(paymentMethodData);

                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);

                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Cuenta bancaria guardada. Pendiente de verificación.'),
                          backgroundColor: ModernTheme.success,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    print('❌ Error al guardar cuenta bancaria: $e');
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar. Intenta nuevamente.'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.success,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ REAL: Formulario de tarjeta de débito
  void _showDebitCardForm() {
    final formKey = GlobalKey<FormState>(debugLabel: 'debitCardForm');
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController(text: _profile?.name ?? '');

    final banks = [
      'BCP - Banco de Crédito del Perú',
      'BBVA',
      'Interbank',
      'Scotiabank',
      'Banco de la Nación',
      'Otro',
    ];
    String selectedBank = banks[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.credit_card, color: ModernTheme.warning),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Tarjeta de Débito',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura tu tarjeta de débito para retiros instantáneos',
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Banco emisor
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Banco Emisor',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: banks.map((bank) {
                      return DropdownMenuItem(
                        value: bank,
                        child: Text(
                          bank,
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedBank = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Últimos 4 dígitos
                  TextFormField(
                    controller: cardNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Últimos 4 Dígitos de la Tarjeta',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                      hintText: '1234',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa los últimos 4 dígitos';
                      }
                      if (value.length != 4) {
                        return 'Deben ser 4 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Titular
                  TextFormField(
                    controller: cardHolderController,
                    decoration: InputDecoration(
                      labelText: 'Titular de la Tarjeta',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el nombre del titular';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: ModernTheme.info, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Por seguridad, solo guardamos los últimos 4 dígitos',
                            style: TextStyle(
                              fontSize: 11,
                              color: ModernTheme.info,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // ✅ GUARDAR en Firestore
                  try {
                    final userId = FirebaseAuth.instance.currentUser!.uid;
                    final paymentMethodData = {
                      'userId': userId,
                      'type': 'card',
                      'status': 'pending_verification',
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'cardNumber': cardNumberController.text, // Solo últimos 4 dígitos
                      'cardHolderName': cardHolderController.text,
                      'cardBank': selectedBank,
                      'isDefault': false,
                    };

                    await FirebaseFirestore.instance
                        .collection('paymentMethods')
                        .add(paymentMethodData);

                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);

                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Tarjeta de débito guardada. Pendiente de verificación.'),
                          backgroundColor: ModernTheme.success,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    print('❌ Error al guardar tarjeta: $e');
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar. Intenta nuevamente.'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.warning,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ REAL: Información de retiro en efectivo
  void _showCashPickupInfo() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.store, color: ModernTheme.info),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Efectivo en Oficina',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retira tus ganancias en efectivo en nuestras oficinas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoItem(Icons.location_on, 'Av. Principal 123, Lima'),
            _buildInfoItem(Icons.access_time, 'Lunes a Viernes: 9:00 AM - 6:00 PM'),
            _buildInfoItem(Icons.access_time, 'Sábados: 9:00 AM - 1:00 PM'),
            _buildInfoItem(Icons.badge, 'Presenta tu DNI al retirar'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: ModernTheme.success, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Retiro inmediato, sin comisiones',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // ✅ GUARDAR en Firestore
              try {
                final paymentMethodData = {
                  'userId': userId,
                  'type': 'cash',
                  'status': 'active', // Efectivo siempre está activo
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'isDefault': false,
                };

                await FirebaseFirestore.instance
                    .collection('paymentMethods')
                    .add(paymentMethodData);

                // ignore: use_build_context_synchronously
                Navigator.pop(context);

                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Método de efectivo activado'),
                      backgroundColor: ModernTheme.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                print('❌ Error al activar efectivo: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.info,
            ),
            child: Text('Activar Método'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ModernTheme.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.visible,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return _buildSection(
      'Logros y Reconocimientos',
      Icons.emoji_events,
      Colors.amber,
      [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: _profile!.achievements.length,
          itemBuilder: (context, index) {
            final achievement = _profile!.achievements[index];
            return _buildAchievementCard(achievement);
          },
        ),
      ],
    );
  }
  
  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            achievement.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            achievement.description,
            style: TextStyle(
              fontSize: 10,
              color: ModernTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias de Trabajo',
      Icons.settings,
      Colors.purple,
      [
        _buildPreferenceRow('Acepta mascotas', _profile!.preferences.acceptPets),
        _buildPreferenceRow('Permite fumar', _profile!.preferences.acceptSmoking),
        _buildInfoRow('Música preferida', _profile!.preferences.musicPreference, Icons.music_note),
        _buildInfoRow('Idiomas', _profile!.preferences.languages.join(', '), Icons.language),
        _buildInfoRow('Distancia máxima', '${_profile!.preferences.maxTripDistance} km', Icons.straighten),

        SizedBox(height: 12),
        Text(
          'Zonas preferidas:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: ModernTheme.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _profile!.preferences.preferredZones.map((zone) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                zone,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple,
                ),
              ),
            );
          }).toList(),
        ),
      ],
      onEdit: () => _editPreferences(), // ✅ Agregar callback de edición
    );
  }
  
  Widget _buildWorkScheduleSection() {
    return _buildSection(
      'Horario de Trabajo',
      Icons.schedule,
      Colors.orange,
      [
        _buildScheduleRow('Lunes', _profile!.workSchedule.mondayStart, _profile!.workSchedule.mondayEnd),
        _buildScheduleRow('Martes', _profile!.workSchedule.tuesdayStart, _profile!.workSchedule.tuesdayEnd),
        _buildScheduleRow('Miércoles', _profile!.workSchedule.wednesdayStart, _profile!.workSchedule.wednesdayEnd),
        _buildScheduleRow('Jueves', _profile!.workSchedule.thursdayStart, _profile!.workSchedule.thursdayEnd),
        _buildScheduleRow('Viernes', _profile!.workSchedule.fridayStart, _profile!.workSchedule.fridayEnd),
        _buildScheduleRow('Sábado', _profile!.workSchedule.saturdayStart, _profile!.workSchedule.saturdayEnd),
        _buildScheduleRow('Domingo', _profile!.workSchedule.sundayStart, _profile!.workSchedule.sundayEnd),
      ],
      onEdit: () => _editWorkSchedule(), // ✅ Agregar callback de edición
    );
  }
  
  Widget _buildScheduleRow(String day, String startTime, String endTime) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              '$startTime - $endTime',
              style: TextStyle(
                color: ModernTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreferenceRow(String label, bool value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? ModernTheme.success : ModernTheme.error,
            size: 20,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ModernTheme.textSecondary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children, {
    VoidCallback? onEdit, // ✅ Parámetro opcional para acción de edición
  }) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                // ✅ Mostrar botón de edición si se proporciona la función
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit, color: color, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
        ),
      ),
    );
  }
  
  String _formatMemberSince(DateTime date) {
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '${months[date.month - 1]} ${date.year}';
  }
  
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }
  
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Actualizar en Firebase
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          throw Exception('Usuario no autenticado');
        }

        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'bio': _bioController.text.trim(),
          'emergencyContact': {
            'name': _emergencyContactController.text.trim(),
            'phone': _emergencyPhoneController.text.trim(),
            'relationship': _profile!.emergencyContact.relationship,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar estado local
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            profileImageUrl: _profile!.profileImageUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _bioController.text,
            emergencyContact: EmergencyContact(
              name: _emergencyContactController.text,
              phone: _emergencyPhoneController.text,
              relationship: _profile!.emergencyContact.relationship,
            ),
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
          _isEditing = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil actualizado exitosamente en Firebase'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar perfil: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  void _changeProfileImage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: ModernTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: ModernTheme.oasisGreen,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  void _pickImageFromCamera() {
    // Simulate image picking from camera
    setState(() {
      _profile = DriverProfile(
        id: _profile!.id,
        name: _profile!.name,
        email: _profile!.email,
        phone: _profile!.phone,
        profileImageUrl: '', // URL real de Firebase Storage
        rating: _profile!.rating,
        totalTrips: _profile!.totalTrips,
        totalDistance: _profile!.totalDistance,
        totalHours: _profile!.totalHours,
        totalEarnings: _profile!.totalEarnings,
        memberSince: _profile!.memberSince,
        bio: _profile!.bio,
        emergencyContact: _profile!.emergencyContact,
        preferences: _profile!.preferences,
        achievements: _profile!.achievements,
        vehicleInfo: _profile!.vehicleInfo,
        workSchedule: _profile!.workSchedule,
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto actualizada desde cámara'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _pickImageFromGallery() {
    // Simulate image picking from gallery
    setState(() {
      _profile = DriverProfile(
        id: _profile!.id,
        name: _profile!.name,
        email: _profile!.email,
        phone: _profile!.phone,
        profileImageUrl: '', // URL real de Firebase Storage
        rating: _profile!.rating,
        totalTrips: _profile!.totalTrips,
        totalDistance: _profile!.totalDistance,
        totalHours: _profile!.totalHours,
        totalEarnings: _profile!.totalEarnings,
        memberSince: _profile!.memberSince,
        bio: _profile!.bio,
        emergencyContact: _profile!.emergencyContact,
        preferences: _profile!.preferences,
        achievements: _profile!.achievements,
        vehicleInfo: _profile!.vehicleInfo,
        workSchedule: _profile!.workSchedule,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto actualizada desde galería'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  // ✅ NUEVO: Método para editar preferencias de trabajo
  void _editPreferences() {
    // Valores iniciales desde Firebase o valores por defecto
    bool acceptPets = _profile?.preferences.acceptPets ?? false;
    bool acceptSmoking = _profile?.preferences.acceptSmoking ?? false;
    // ✅ CORREGIDO: Validar que la preferencia musical esté en la lista válida
    final validMusicOptions = ['Ninguna', 'Rock', 'Pop', 'Clásica', 'Jazz', 'Reggaeton', 'Salsa'];
    final prefMusic = _profile?.preferences.musicPreference;
    String musicPreference = (prefMusic == null || prefMusic.isEmpty || !validMusicOptions.contains(prefMusic))
        ? 'Ninguna'
        : prefMusic;
    List<String> languages = List<String>.from(_profile?.preferences.languages ?? ['Español']);
    // ✅ FIX: Asegurar que maxTripDistance esté en el rango válido del Slider (min: 5, max: 100)
    double maxTripDistance = (_profile?.preferences.maxTripDistance ?? 50.0).clamp(5.0, 100.0);
    List<String> preferredZones = List<String>.from(_profile?.preferences.preferredZones ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.tune, color: ModernTheme.oasisGreen),
                  SizedBox(width: 12),
                  Flexible(child: Text('Preferencias de Trabajo')),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Switch: Aceptar mascotas
                      SwitchListTile(
                        title: Text('Aceptar mascotas'),
                        subtitle: Text('Permitir pasajeros con mascotas'),
                        value: acceptPets,
                        activeColor: ModernTheme.oasisGreen,
                        onChanged: (value) {
                          setDialogState(() => acceptPets = value);
                        },
                      ),

                      // Switch: Permitir fumar
                      SwitchListTile(
                        title: Text('Permitir fumar'),
                        subtitle: Text('Permitir que los pasajeros fumen'),
                        value: acceptSmoking,
                        activeColor: ModernTheme.oasisGreen,
                        onChanged: (value) {
                          setDialogState(() => acceptSmoking = value);
                        },
                      ),

                      SizedBox(height: 16),

                      // Dropdown: Preferencia musical
                      Text('Preferencia Musical', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: musicPreference,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        // ✅ Usar la misma lista validada
                        items: validMusicOptions
                            .map((music) => DropdownMenuItem(value: music, child: Text(music)))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => musicPreference = value!);
                        },
                      ),

                      SizedBox(height: 16),

                      // Chips multiselect: Idiomas
                      Text('Idiomas que hablas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Español', 'Inglés', 'Francés', 'Alemán', 'Chino', 'Portugués'].map((lang) {
                          final isSelected = languages.contains(lang);
                          return FilterChip(
                            label: Text(lang),
                            selected: isSelected,
                            selectedColor: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                            checkmarkColor: ModernTheme.oasisGreen,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (!languages.contains(lang)) languages.add(lang);
                                } else {
                                  languages.remove(lang);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 16),

                      // Slider: Distancia máxima viaje
                      Text('Distancia máxima de viaje: ${maxTripDistance.toInt()} km',
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Slider(
                        value: maxTripDistance,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        activeColor: ModernTheme.oasisGreen,
                        label: '${maxTripDistance.toInt()} km',
                        onChanged: (value) {
                          setDialogState(() => maxTripDistance = value);
                        },
                      ),

                      SizedBox(height: 16),

                      // Chips multiselect: Zonas preferidas
                      Text('Zonas preferidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Centro', 'Norte', 'Sur', 'Este', 'Oeste', 'Aeropuerto', 'Playas'].map((zone) {
                          final isSelected = preferredZones.contains(zone);
                          return FilterChip(
                            label: Text(zone),
                            selected: isSelected,
                            selectedColor: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                            checkmarkColor: ModernTheme.oasisGreen,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (!preferredZones.contains(zone)) preferredZones.add(zone);
                                } else {
                                  preferredZones.remove(zone);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Guardar en Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .update({
                        'preferences': {
                          'acceptPets': acceptPets,
                          'acceptSmoking': acceptSmoking,
                          'musicPreference': musicPreference,
                          'languages': languages,
                          'maxTripDistance': maxTripDistance,
                          'preferredZones': preferredZones,
                        },
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Preferencias actualizadas correctamente'),
                            ],
                          ),
                          backgroundColor: ModernTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      // Recargar datos
                      _loadProfile();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar preferencias: $e'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ NUEVO: Método para editar horario de trabajo
  void _editWorkSchedule() {
    // Horarios iniciales desde Firebase o valores por defecto
    final schedule = _profile?.workSchedule;

    // Mapa para almacenar tiempos de inicio/fin y estado activo para cada día
    final Map<String, Map<String, dynamic>> weekSchedule = {
      'Lunes': {
        'start': TimeOfDay(hour: int.parse(schedule?.mondayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.mondayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.mondayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.mondayEnd.split(':')[1] ?? '00')),
        'active': schedule?.mondayStart != '00:00' || schedule?.mondayEnd != '00:00',
      },
      'Martes': {
        'start': TimeOfDay(hour: int.parse(schedule?.tuesdayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.tuesdayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.tuesdayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.tuesdayEnd.split(':')[1] ?? '00')),
        'active': schedule?.tuesdayStart != '00:00' || schedule?.tuesdayEnd != '00:00',
      },
      'Miércoles': {
        'start': TimeOfDay(hour: int.parse(schedule?.wednesdayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.wednesdayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.wednesdayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.wednesdayEnd.split(':')[1] ?? '00')),
        'active': schedule?.wednesdayStart != '00:00' || schedule?.wednesdayEnd != '00:00',
      },
      'Jueves': {
        'start': TimeOfDay(hour: int.parse(schedule?.thursdayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.thursdayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.thursdayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.thursdayEnd.split(':')[1] ?? '00')),
        'active': schedule?.thursdayStart != '00:00' || schedule?.thursdayEnd != '00:00',
      },
      'Viernes': {
        'start': TimeOfDay(hour: int.parse(schedule?.fridayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.fridayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.fridayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.fridayEnd.split(':')[1] ?? '00')),
        'active': schedule?.fridayStart != '00:00' || schedule?.fridayEnd != '00:00',
      },
      'Sábado': {
        'start': TimeOfDay(hour: int.parse(schedule?.saturdayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.saturdayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.saturdayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.saturdayEnd.split(':')[1] ?? '00')),
        'active': schedule?.saturdayStart != '00:00' || schedule?.saturdayEnd != '00:00',
      },
      'Domingo': {
        'start': TimeOfDay(hour: int.parse(schedule?.sundayStart.split(':')[0] ?? '08'), minute: int.parse(schedule?.sundayStart.split(':')[1] ?? '00')),
        'end': TimeOfDay(hour: int.parse(schedule?.sundayEnd.split(':')[0] ?? '18'), minute: int.parse(schedule?.sundayEnd.split(':')[1] ?? '00')),
        'active': schedule?.sundayStart != '00:00' || schedule?.sundayEnd != '00:00',
      },
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.schedule, color: ModernTheme.oasisGreen),
                  SizedBox(width: 12),
                  Flexible(child: Text('Horario de Trabajo')),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: weekSchedule.entries.map((entry) {
                      final day = entry.key;
                      final dayData = entry.value;

                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fila: Día + Switch activo/inactivo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(day, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Switch(
                                    value: dayData['active'],
                                    activeColor: ModernTheme.oasisGreen,
                                    onChanged: (value) {
                                      setDialogState(() => dayData['active'] = value);
                                    },
                                  ),
                                ],
                              ),

                              if (dayData['active']) ...[
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Hora de inicio
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: dayData['start'],
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context).copyWith(
                                                  colorScheme: ColorScheme.light(primary: ModernTheme.oasisGreen),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            setDialogState(() => dayData['start'] = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.access_time, size: 16, color: ModernTheme.oasisGreen),
                                              SizedBox(width: 8),
                                              Text('${dayData['start'].format(context)}'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.arrow_forward, size: 16),
                                    ),

                                    // Hora de fin
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: dayData['end'],
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context).copyWith(
                                                  colorScheme: ColorScheme.light(primary: ModernTheme.oasisGreen),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            setDialogState(() => dayData['end'] = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.access_time, size: 16, color: ModernTheme.oasisGreen),
                                              SizedBox(width: 8),
                                              Text('${dayData['end'].format(context)}'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Validar que hora fin > hora inicio para días activos
                      String? validationError;
                      for (var entry in weekSchedule.entries) {
                        final day = entry.key;
                        final dayData = entry.value;
                        if (dayData['active']) {
                          final start = dayData['start'] as TimeOfDay;
                          final end = dayData['end'] as TimeOfDay;
                          final startMinutes = start.hour * 60 + start.minute;
                          final endMinutes = end.hour * 60 + end.minute;

                          if (endMinutes <= startMinutes) {
                            validationError = 'La hora de fin debe ser mayor que la hora de inicio en $day';
                            break;
                          }
                        }
                      }

                      if (validationError != null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(validationError),
                            backgroundColor: ModernTheme.error,
                          ),
                        );
                        return;
                      }

                      // Formatear horarios para Firestore
                      String formatTime(TimeOfDay time) {
                        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }

                      // Guardar en Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .update({
                        'workSchedule': {
                          'mondayStart': weekSchedule['Lunes']!['active'] ? formatTime(weekSchedule['Lunes']!['start']) : '00:00',
                          'mondayEnd': weekSchedule['Lunes']!['active'] ? formatTime(weekSchedule['Lunes']!['end']) : '00:00',
                          'tuesdayStart': weekSchedule['Martes']!['active'] ? formatTime(weekSchedule['Martes']!['start']) : '00:00',
                          'tuesdayEnd': weekSchedule['Martes']!['active'] ? formatTime(weekSchedule['Martes']!['end']) : '00:00',
                          'wednesdayStart': weekSchedule['Miércoles']!['active'] ? formatTime(weekSchedule['Miércoles']!['start']) : '00:00',
                          'wednesdayEnd': weekSchedule['Miércoles']!['active'] ? formatTime(weekSchedule['Miércoles']!['end']) : '00:00',
                          'thursdayStart': weekSchedule['Jueves']!['active'] ? formatTime(weekSchedule['Jueves']!['start']) : '00:00',
                          'thursdayEnd': weekSchedule['Jueves']!['active'] ? formatTime(weekSchedule['Jueves']!['end']) : '00:00',
                          'fridayStart': weekSchedule['Viernes']!['active'] ? formatTime(weekSchedule['Viernes']!['start']) : '00:00',
                          'fridayEnd': weekSchedule['Viernes']!['active'] ? formatTime(weekSchedule['Viernes']!['end']) : '00:00',
                          'saturdayStart': weekSchedule['Sábado']!['active'] ? formatTime(weekSchedule['Sábado']!['start']) : '00:00',
                          'saturdayEnd': weekSchedule['Sábado']!['active'] ? formatTime(weekSchedule['Sábado']!['end']) : '00:00',
                          'sundayStart': weekSchedule['Domingo']!['active'] ? formatTime(weekSchedule['Domingo']!['start']) : '00:00',
                          'sundayEnd': weekSchedule['Domingo']!['active'] ? formatTime(weekSchedule['Domingo']!['end']) : '00:00',
                        },
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Horario actualizado correctamente'),
                            ],
                          ),
                          backgroundColor: ModernTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      // Recargar datos
                      _loadProfile();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar horario: $e'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Models
class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;
  final double rating;
  final int totalTrips;
  final double totalDistance;
  final double totalHours;
  final double totalEarnings;
  final DateTime memberSince;
  final String bio;
  final EmergencyContact emergencyContact;
  final DriverPreferences preferences;
  final List<Achievement> achievements;
  final VehicleInfo vehicleInfo;
  final WorkSchedule workSchedule;
  
  DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
    required this.rating,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalHours,
    required this.totalEarnings,
    required this.memberSince,
    required this.bio,
    required this.emergencyContact,
    required this.preferences,
    required this.achievements,
    required this.vehicleInfo,
    required this.workSchedule,
  });
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;
  
  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

class DriverPreferences {
  final bool acceptPets;
  final bool acceptSmoking;
  final String musicPreference;
  final List<String> languages;
  final double maxTripDistance;
  final List<String> preferredZones;
  
  DriverPreferences({
    required this.acceptPets,
    required this.acceptSmoking,
    required this.musicPreference,
    required this.languages,
    required this.maxTripDistance,
    required this.preferredZones,
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final DateTime unlockedDate;
  
  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.unlockedDate,
  });
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int capacity;
  
  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.capacity,
  });
}

class WorkSchedule {
  final String mondayStart;
  final String mondayEnd;
  final String tuesdayStart;
  final String tuesdayEnd;
  final String wednesdayStart;
  final String wednesdayEnd;
  final String thursdayStart;
  final String thursdayEnd;
  final String fridayStart;
  final String fridayEnd;
  final String saturdayStart;
  final String saturdayEnd;
  final String sundayStart;
  final String sundayEnd;
  
  WorkSchedule({
    required this.mondayStart,
    required this.mondayEnd,
    required this.tuesdayStart,
    required this.tuesdayEnd,
    required this.wednesdayStart,
    required this.wednesdayEnd,
    required this.thursdayStart,
    required this.thursdayEnd,
    required this.fridayStart,
    required this.fridayEnd,
    required this.saturdayStart,
    required this.saturdayEnd,
    required this.sundayStart,
    required this.sundayEnd,
  });
}