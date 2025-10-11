// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async'; // Para TimeoutException
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';

class ModernRegisterScreen extends StatefulWidget {
  const ModernRegisterScreen({super.key});

  @override
  State<ModernRegisterScreen> createState() => _ModernRegisterScreenState();
}

class _ModernRegisterScreenState extends State<ModernRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _userType = 'passenger';
  bool _acceptTerms = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _formController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    // ✅ Dispose de FocusNodes
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  // Función de registro real con Firebase
  Future<void> _registerUser() async {
    print('🔍 ========================================');
    print('🔍 _registerUser INICIO');
    print('🔍 ========================================');

    print('🔍 PASO 1: Obteniendo AuthProvider...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    print('🔍 AuthProvider obtenido: $authProvider');

    try {
      print('🔍 PASO 2: Iniciando bloque try...');
      print('🔍 PASO 3: Setting _isLoading = true');
      setState(() => _isLoading = true);
      print('🔍 _isLoading ahora es: $_isLoading');

      // Usar el email ingresado por el usuario
      print('🔍 PASO 4: Preparando datos de usuario...');
      String email = _emailController.text.trim();
      print('🔍 Email: $email');
      print('🔍 Password length: ${_passwordController.text.length}');
      print('🔍 Full name: ${_nameController.text}');
      print('🔍 Phone: ${_phoneController.text}');
      print('🔍 User type: $_userType');

      // Registrar usuario en Firebase CON TIMEOUT DE 30 SEGUNDOS
      print('🔍 PASO 5: Llamando authProvider.register()...');
      print('🔍 ⏳ ESPERANDO RESPUESTA DE FIREBASE (timeout: 30s)...');
      final success = await authProvider.register(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        userType: _userType,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('🔍 ⏱️ TIMEOUT! Firebase no respondió en 30 segundos');
          throw TimeoutException('La conexión con Firebase tardó demasiado. Verifica tu conexión a internet e intenta nuevamente.');
        },
      );
      print('🔍 ✅ authProvider.register() COMPLETADO');
      print('🔍 Resultado success: $success (tipo: ${success.runtimeType})');

      // Verificar que el widget siga montado antes de usar context
      print('🔍 PASO 6: Verificando si widget está montado...');
      if (!mounted) {
        print('🔍 ⚠️ Widget NO MONTADO - terminando función');
        return;
      }
      print('🔍 ✅ Widget SÍ está montado');

      // Si el registro fue exitoso, navegar a la pantalla de verificación de email
      print('🔍 PASO 7: Evaluando resultado de success...');
      if (success) {
        print('🔍 ✅ SUCCESS ES TRUE - navegando a /email-verification');
        print('🔍 Email para verificación: $email');

        // MOSTRAR MENSAJE DE ÉXITO EN PANTALLA
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ REGISTRO EXITOSO! Redirigiendo...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/email-verification',
          arguments: email,
        );
        print('🔍 ✅ Navegación iniciada');
      } else {
        print('🔍 ❌ SUCCESS ES FALSE - registro falló sin excepción');

        // OBTENER EL ERROR ESPECÍFICO DE AUTHPROVIDER
        final errorMsg = authProvider.errorMessage ?? '❌ El registro falló. Intenta nuevamente.';
        print('🔍 Error del AuthProvider: $errorMsg');

        // MOSTRAR MENSAJE DE ERROR ESPECÍFICO EN PANTALLA
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      }

    } on TimeoutException catch (e) {
      print('🔍 ========================================');
      print('🔍 ⏱️⏱️⏱️ TIMEOUT EXCEPTION ⏱️⏱️⏱️');
      print('🔍 ========================================');
      print('🔍 Firebase no respondió en 30 segundos');
      print('🔍 Error: ${e.message}');
      print('🔍 ========================================');

      if (!mounted) {
        print('🔍 Widget no montado, no se puede mostrar SnackBar');
        return;
      }

      // MOSTRAR ERROR DE TIMEOUT EN PANTALLA
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ ${e.message}\n\n'
              'Posibles causas:\n'
              '• Conexión a internet lenta o inestable\n'
              '• Configuración de Firebase incorrecta\n'
              '• Problema con el servidor de Firebase'),
          backgroundColor: Colors.orange.shade800,
          duration: Duration(seconds: 8),
        ),
      );
    } catch (e, stackTrace) {
      print('🔍 ========================================');
      print('🔍 ❌❌❌ ERROR CAPTURADO EN CATCH ❌❌❌');
      print('🔍 ========================================');
      print('🔍 Error: ${e.toString()}');
      print('🔍 Error type: ${e.runtimeType}');
      print('🔍 Stack trace: $stackTrace');
      print('🔍 ========================================');

      if (!mounted) {
        print('🔍 Widget no montado, no se puede mostrar SnackBar');
        return;
      }

      // MOSTRAR ERROR EN PANTALLA
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      print('🔍 ========================================');
      print('🔍 BLOQUE FINALLY');
      print('🔍 ========================================');
      print('🔍 PASO 8: Setting _isLoading = false');
      setState(() => _isLoading = false);
      print('🔍 _isLoading ahora es: $_isLoading');
      print('🔍 ========================================');
      print('🔍 _registerUser FINALIZADO');
      print('🔍 ========================================');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernTheme.oasisGreen,
                      ModernTheme.oasisBlack,
                      ModernTheme.accentGray,
                    ],
                    transform: GradientRotation(
                      _backgroundController.value * 2 * math.pi
                    ),
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Form(
              key: _formKey,
              child: GestureDetector(
                onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera (Android compatible)
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              'Crear cuenta',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    
                    SizedBox(height: 20),
                    
                    // Progress indicator
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: List.generate(3, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index <= _currentStep 
                                  ? Colors.white 
                                  : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    SizedBox(height: 30),

                    // Form
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: ModernTheme.floatingShadow,
                          ),
                          child: _buildCurrentStep(),
                        ),
                      ],
                    ),
                  ),
                ), // SingleChildScrollView
              ), // GestureDetector
            ), // Form
          ), // SafeArea
        ],
      ),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildUserTypeStep();
      case 1:
        return _buildPersonalInfoStep();
      case 2:
        return _buildAccountStep();
      default:
        return Container();
    }
  }
  
  Widget _buildUserTypeStep() {
    return Column(
      children: [
        Text(
          '¿Cómo quieres usar Oasis Taxi?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 30),
        
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'passenger';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'passenger' 
            ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
            : null,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: ModernTheme.oasisGreen,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pasajero',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Solicita viajes y negocia precios',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'driver';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'driver' 
            ? ModernTheme.oasisBlack.withValues(alpha: 0.1)
            : null,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisBlack.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: ModernTheme.oasisBlack,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conductor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Acepta viajes y gana dinero',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        Text(
          'Información personal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24),

        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a teléfono
          onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(), // ✅ Avanza al campo de teléfono
          decoration: InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu nombre';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocusNode, // ✅ FocusNode configurado
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a email
          onFieldSubmitted: (_) => _emailFocusNode.requestFocus(), // ✅ Avanza al campo de email
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            prefixIcon: Icon(Icons.phone, color: ModernTheme.oasisGreen),
            prefixText: '+51 ',
            helperText: '9 dígitos',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu número';
            }
            // Validar formato peruano: 9 dígitos
            final phoneRegex = RegExp(r'^\d{9}$');
            if (!phoneRegex.hasMatch(value)) {
              return 'Debe tener exactamente 9 dígitos';
            }
            // Validar que empiece con 9 (típico de móviles en Perú)
            if (!value.startsWith('9')) {
              return 'Número móvil debe empezar con 9';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode, // ✅ FocusNode configurado
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
          onFieldSubmitted: (_) { // ✅ Valida y avanza al siguiente paso al presionar Done
            if (_formKey.currentState!.validate()) {
              setState(() => _currentStep = 2);
            }
          },
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu correo';
            }
            if (!value.contains('@')) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        
        SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep = 0);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Atrás'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AnimatedPulseButton(
                text: 'Continuar',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Column(
      children: [
        Text(
          'Crea tu contraseña',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24),

        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode, // ✅ FocusNode configurado
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a confirmar contraseña
          onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(), // ✅ Avanza al campo de confirmar contraseña
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            helperText: 'Mín. 8 caracteres: MAYÚSCULA, minúscula, número y especial (!@#\$%)',
            helperMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa una contraseña';
            }
            if (value.length < 8) {
              return 'Mínimo 8 caracteres';
            }
            if (!value.contains(RegExp(r'[A-Z]'))) {
              return 'Debe incluir al menos una MAYÚSCULA';
            }
            if (!value.contains(RegExp(r'[a-z]'))) {
              return 'Debe incluir al menos una minúscula';
            }
            if (!value.contains(RegExp(r'[0-9]'))) {
              return 'Debe incluir al menos un número';
            }
            if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
              return 'Debe incluir un carácter especial (!@#\$%^&*)';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode, // ✅ FocusNode configurado
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
          onFieldSubmitted: (_) async { // ✅ Valida y ejecuta registro al presionar Done
            if (_formKey.currentState!.validate() && _acceptTerms) {
              await _registerUser();
            }
          },
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
        
        SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: _acceptTerms
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _acceptTerms
                ? ModernTheme.oasisGreen.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) {
              print('🔍 Checkbox changed: $value');
              setState(() {
                _acceptTerms = value!;
                print('🔍 _acceptTerms ahora es: $_acceptTerms');
              });
            },
            title: Text(
              'Acepto los términos y condiciones',
              style: TextStyle(
                fontSize: 14,
                color: _acceptTerms ? Colors.black87 : Colors.red.shade700,
                fontWeight: _acceptTerms ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            subtitle: !_acceptTerms
              ? Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Debes aceptar los términos para continuar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                )
              : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: ModernTheme.oasisGreen,
          ),
        ),

        SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Atrás'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _acceptTerms ? () async {
                  print('🔍🔍🔍 ELEVATED BUTTON TAP!!!');
                  print('🔍 _acceptTerms: $_acceptTerms');
                  print('🔍 _isLoading: $_isLoading');
                  // MOSTRAR EN PANTALLA para que el usuario VEA que el botón detectó el click
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ BOTÓN PRESIONADO!'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  if (_formKey.currentState!.validate()) {
                    print('🔍 EJECUTANDO _registerUser()');
                    await _registerUser();
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('CREAR CUENTA', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}