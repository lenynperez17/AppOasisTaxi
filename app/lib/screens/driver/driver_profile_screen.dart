// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';

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
  
  void _loadProfile() async {
    // Simulate loading profile data
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      _profile = DriverProfile(
        id: 'DRV_001',
        name: '', // Se carga desde Firebase Auth
        email: '', // Se carga desde Firebase Auth
        phone: '', // Se carga desde Firebase Auth
        profileImageUrl: '',
        rating: 4.8,
        totalTrips: 1247,
        totalDistance: 15789.5,
        totalHours: 3240.5,
        totalEarnings: 25430.75,
        memberSince: DateTime(2022, 3, 15),
        bio: 'Conductor profesional con más de 5 años de experiencia. Me gusta brindar un servicio de calidad y mantener mi vehículo en excelentes condiciones.',
        emergencyContact: EmergencyContact(
          name: '', // Se carga desde perfil del conductor
          phone: '', // Se carga desde perfil del conductor
          relationship: '', // Se carga desde perfil del conductor
        ),
        preferences: DriverPreferences(
          acceptPets: true,
          acceptSmoking: false,
          musicPreference: 'Variada',
          languages: ['Español', 'Inglés'],
          maxTripDistance: 50.0,
          preferredZones: ['Lima Centro', 'Miraflores', 'San Isidro'],
        ),
        achievements: [
          Achievement(
            id: 'top_rated',
            name: 'Conductor Destacado',
            description: 'Mantiene una calificación superior a 4.8',
            iconUrl: '',
            unlockedDate: DateTime(2023, 6, 20),
          ),
          Achievement(
            id: 'safe_driver',
            name: 'Conductor Seguro',
            description: 'Sin incidentes reportados en 12 meses',
            iconUrl: '',
            unlockedDate: DateTime(2023, 12, 1),
          ),
          Achievement(
            id: 'thousand_trips',
            name: '1000 Viajes',
            description: 'Completó más de 1000 viajes exitosos',
            iconUrl: '',
            unlockedDate: DateTime(2023, 10, 15),
          ),
        ],
        vehicleInfo: VehicleInfo(
          make: 'Toyota',
          model: 'Yaris',
          year: 2020,
          color: 'Blanco',
          plate: '', // Se carga desde datos del vehículo registrado
          capacity: 4,
        ),
        workSchedule: WorkSchedule(
          mondayStart: '07:00',
          mondayEnd: '22:00',
          tuesdayStart: '07:00',
          tuesdayEnd: '22:00',
          wednesdayStart: '07:00',
          wednesdayEnd: '22:00',
          thursdayStart: '07:00',
          thursdayEnd: '22:00',
          fridayStart: '06:00',
          fridayEnd: '23:00',
          saturdayStart: '08:00',
          saturdayEnd: '20:00',
          sundayStart: '10:00',
          sundayEnd: '18:00',
        ),
      );
      _isLoading = false;
      
      // Initialize form controllers
      _nameController.text = _profile!.name;
      _phoneController.text = _profile!.phone;
      _emailController.text = _profile!.email;
      _emergencyContactController.text = _profile!.emergencyContact.name;
      _emergencyPhoneController.text = _profile!.emergencyContact.phone;
      _bioController.text = _profile!.bio;
    });
    
    _fadeController.forward();
    _slideController.forward();
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
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: _toggleEdit,
            ),
          if (_isEditing)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
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
                        image: _profile!.profileImageUrl.isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(_profile!.profileImageUrl)),
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
                    Text(
                      '${_profile!.rating} (${_profile!.totalTrips} viajes)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
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
              Icons.attach_money,
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
      ],
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
    );
  }
  
  Widget _buildScheduleRow(String day, String startTime, String endTime) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$startTime - $endTime',
            style: TextStyle(
              color: ModernTheme.textSecondary,
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
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
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
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
  
  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil actualizado exitosamente'),
          backgroundColor: ModernTheme.success,
        ),
      );
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