// ignore_for_file: use_build_context_synchronously
// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../core/theme/modern_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId; // Se obtendrá del usuario actual
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emergencyNameFocusNode = FocusNode();
  final FocusNode _emergencyPhoneFocusNode = FocusNode();

  // User data
  String _profileImagePath = '';
  String _birthDate = '';
  String _gender = 'Masculino';
  String _documentType = 'DNI';
  String _documentNumber = '';
  bool _notificationsEnabled = true;
  bool _smsEnabled = false;
  bool _emailPromotions = true;
  bool _locationSharing = true;
  
  // Form state
  bool _isLoading = false;
  bool _hasChanges = false;
  
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
    
    _loadUserData();
    _fadeController.forward();
    _slideController.forward();
    
    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emergencyNameController.addListener(_onFieldChanged);
    _emergencyPhoneController.addListener(_onFieldChanged);
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    // ✅ Dispose de FocusNodes
    _nameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emergencyNameFocusNode.dispose();
    _emergencyPhoneFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }
  
  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      
      // Por ahora usar un userId de ejemplo
      // En producción, esto vendría del usuario autenticado
      _userId = 'test_user_id';
      
      // Cargar datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _nameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _birthDate = data['birthDate'] ?? '';
          _gender = data['gender'] ?? 'Masculino';
          _documentType = data['documentType'] ?? 'DNI';
          _documentNumber = data['documentNumber'] ?? '';
          _emergencyNameController.text = data['emergencyContactName'] ?? '';
          _emergencyPhoneController.text = data['emergencyContactPhone'] ?? '';
          _profileImagePath = data['profileImage'] ?? '';
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _smsEnabled = data['smsEnabled'] ?? false;
          _emailPromotions = data['emailPromotions'] ?? true;
          _locationSharing = data['locationSharing'] ?? true;
        });
      } else {
        // Si no existe el documento, mostrar campos vacíos (sin crear datos por defecto)
        setState(() {
          // Los campos ya están vacíos por defecto
        });
      }
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (!mounted) return;
        if (shouldPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: ModernTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: ModernTheme.oasisGreen,
          elevation: 0,
          title: Text(
            'Editar Perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
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
        body: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Form(
                key: _formKey,
                child: GestureDetector(
                  onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera (Android compatible)
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                      // Profile image section
                      _buildProfileImageSection(),
                      
                      SizedBox(height: 32),
                      
                      // Personal information
                      _buildPersonalInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Contact information
                      _buildContactInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Document information
                      _buildDocumentInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Emergency contact
                      _buildEmergencyContactSection(),
                      
                      SizedBox(height: 24),
                      
                      // Preferences
                      _buildPreferencesSection(),
                      
                      SizedBox(height: 32),
                      
                      // Save button
                      _buildSaveButton(),
                      
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ), // Scaffold
  ); // PopScope
}
  
  Widget _buildProfileImageSection() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _profileImagePath.isEmpty
                          ? LinearGradient(
                              colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.7)],
                            )
                          : null,
                      image: _profileImagePath.isNotEmpty
                          ? DecorationImage(
                              image: FileImage(File(_profileImagePath)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _profileImagePath.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Toca para cambiar foto',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _nameController,
                label: 'Nombres',
                icon: Icons.person_outline,
                focusNode: _nameFocusNode, // ✅ FocusNode configurado
                textInputAction: TextInputAction.next, // ✅ Botón Next para ir a apellido
                onFieldSubmitted: (_) => _lastNameFocusNode.requestFocus(), // ✅ Avanza al campo de apellido
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu nombre';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildTextFormField(
                controller: _lastNameController,
                label: 'Apellidos',
                icon: Icons.person_outline,
                focusNode: _lastNameFocusNode, // ✅ FocusNode configurado
                textInputAction: TextInputAction.next, // ✅ Botón Next para ir a email
                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(), // ✅ Avanza al campo de email
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tus apellidos';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _selectBirthDate,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: ModernTheme.textSecondary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthDate.isEmpty ? 'Fecha de nacimiento' : _birthDate,
                    style: TextStyle(
                      color: _birthDate.isEmpty ? ModernTheme.textSecondary : ModernTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: ModernTheme.textSecondary),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            labelText: 'Género',
            prefixIcon: Icon(Icons.wc),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir'].map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _gender = value!;
              _hasChanges = true;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildContactInfoSection() {
    return _buildSection(
      'Información de Contacto',
      Icons.contact_phone,
      ModernTheme.oasisGreen,
      [
        _buildTextFormField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          focusNode: _emailFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a teléfono
          onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(), // ✅ Avanza al campo de teléfono
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
          controller: _phoneController,
          label: 'Número de teléfono',
          icon: Icons.phone_outlined,
          focusNode: _phoneFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a contacto de emergencia
          onFieldSubmitted: (_) => _emergencyNameFocusNode.requestFocus(), // ✅ Avanza al nombre de contacto de emergencia
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu teléfono';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildDocumentInfoSection() {
    return _buildSection(
      'Documento de Identidad',
      Icons.badge,
      Colors.orange,
      [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _documentType,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.assignment_ind),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['DNI', 'Pasaporte', 'Carné de Extranjería'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _documentType = value!;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: TextEditingController(text: _documentNumber),
                decoration: InputDecoration(
                  labelText: 'Número',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
                onChanged: (value) {
                  _documentNumber = value;
                  _onFieldChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildEmergencyContactSection() {
    return _buildSection(
      'Contacto de Emergencia',
      Icons.emergency,
      ModernTheme.error,
      [
        _buildTextFormField(
          controller: _emergencyNameController,
          label: 'Nombre completo',
          icon: Icons.person_pin,
          focusNode: _emergencyNameFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a teléfono de emergencia
          onFieldSubmitted: (_) => _emergencyPhoneFocusNode.requestFocus(), // ✅ Avanza al teléfono de emergencia
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
          focusNode: _emergencyPhoneFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado (último campo)
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(), // ✅ Cierra teclado al presionar Done
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el teléfono de emergencia';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias',
      Icons.settings,
      Colors.purple,
      [
        SwitchListTile(
          title: Text('Notificaciones push'),
          subtitle: Text('Recibir notificaciones en el dispositivo'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Notificaciones SMS'),
          subtitle: Text('Recibir actualizaciones por mensaje de texto'),
          value: _smsEnabled,
          onChanged: (value) {
            setState(() {
              _smsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Promociones por email'),
          subtitle: Text('Recibir ofertas y descuentos por correo'),
          value: _emailPromotions,
          onChanged: (value) {
            setState(() {
              _emailPromotions = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
        SwitchListTile(
          title: Text('Compartir ubicación'),
          subtitle: Text('Permitir compartir ubicación durante viajes'),
          value: _locationSharing,
          onChanged: (value) {
            setState(() {
              _locationSharing = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
        ),
      ],
    );
  }
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
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
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode, // ✅ FocusNode para navegación
    TextInputAction? textInputAction, // ✅ Acción del teclado (next/done)
    ValueChanged<String>? onFieldSubmitted, // ✅ Callback al presionar Enter/Done
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // ✅ FocusNode configurado
      textInputAction: textInputAction, // ✅ Botón del teclado configurado
      onFieldSubmitted: onFieldSubmitted, // ✅ Callback configurado
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
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
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: ModernTheme.oasisGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Guardar Cambios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
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
                if (_profileImagePath.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ModernTheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: ModernTheme.error,
                            size: 32,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Eliminar'),
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
      _profileImagePath = '/mock/camera/image.jpg';
      _hasChanges = true;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto tomada desde la cámara'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _pickImageFromGallery() {
    // Simulate image picking from gallery
    setState(() {
      _profileImagePath = '/mock/gallery/image.jpg';
      _hasChanges = true;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imagen seleccionada de la galería'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _removeProfileImage() {
    setState(() {
      _profileImagePath = '';
      _hasChanges = true;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto de perfil eliminada'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
  
  void _selectBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(Duration(days: 365 * 18)), // Minimum 18 years
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
    
    if (selectedDate != null && mounted) {
      setState(() {
        _birthDate = '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
        _hasChanges = true;
      });
    }
  }
  
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Descartar cambios?'),
        content: Text('Tienes cambios sin guardar. ¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Descartar'),
          ),
        ],
      ),
    );
    
    return shouldDiscard ?? false;
  }
  
  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Guardar datos en Firestore
      await _firestore.collection('users').doc(_userId).update({
        'firstName': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'birthDate': _birthDate,
        'gender': _gender,
        'documentType': _documentType,
        'documentNumber': _documentNumber,
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'profileImage': _profileImagePath,
        'notificationsEnabled': _notificationsEnabled,
        'smsEnabled': _smsEnabled,
        'emailPromotions': _emailPromotions,
        'locationSharing': _locationSharing,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: ModernTheme.success,
            action: SnackBarAction(
              label: 'Ver perfil',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error guardando perfil: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
}