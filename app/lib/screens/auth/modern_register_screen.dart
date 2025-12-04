// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async'; // Para TimeoutException
import 'package:provider/provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';

import '../../utils/logger.dart';
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
    AppLogger.debug('🔍 ========================================');
    AppLogger.debug('🔍 _registerUser INICIO');
    AppLogger.debug('🔍 ========================================');
    AppLogger.debug('🔍 PASO 1: Obteniendo AuthProvider...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    AppLogger.debug('🔍 AuthProvider obtenido: $authProvider');
    try {
      AppLogger.debug('🔍 PASO 2: Iniciando bloque try...');
      AppLogger.debug('🔍 PASO 3: Setting _isLoading = true');
      setState(() => _isLoading = true);
      AppLogger.debug('🔍 _isLoading ahora es: $_isLoading');
      // Usar el email ingresado por el usuario
      AppLogger.debug('🔍 PASO 4: Preparando datos de usuario...');
      String email = _emailController.text.trim();
      AppLogger.debug('🔍 Email: $email');
      AppLogger.debug('🔍 Password length: ${_passwordController.text.length}');
      AppLogger.debug('🔍 Full name: ${_nameController.text}');
      AppLogger.debug('🔍 Phone: ${_phoneController.text}');
      AppLogger.debug('🔍 User type: $_userType');
      // ✅ NUEVO: Verificar primero si el email ya existe
      AppLogger.debug('🔍 PASO 4.5: Verificando si email ya está registrado...');
      final emailCheck = await authProvider.checkEmailExists(email);
      AppLogger.debug('🔍 Resultado de verificación email: $emailCheck');
      if (emailCheck['exists'] == true) {
        AppLogger.debug('🔍 ⚠️ EMAIL YA EXISTE');
        final userType = emailCheck['userType'];

        if (!mounted) return;

        // Mostrar diálogo profesional
        final appLocalizations = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(appLocalizations.emailAlreadyRegistered),
            content: Text(
              appLocalizations.emailAlreadyRegisteredMessage(email, userType)
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(appLocalizations.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(appLocalizations.goToLoginButton),
              ),
            ],
          ),
        );
        return;
      }

      AppLogger.debug('🔍 ✅ Email disponible');
      // ✅ NUEVO: Verificar si el teléfono ya existe
      AppLogger.debug('🔍 PASO 4.6: Verificando si teléfono ya está registrado...');
      final phoneCheck = await authProvider.checkPhoneExists(_phoneController.text);
      AppLogger.debug('🔍 Resultado de verificación teléfono: $phoneCheck');
      if (phoneCheck['exists'] == true) {
        AppLogger.debug('🔍 ⚠️ TELÉFONO YA EXISTE');
        final existingEmail = phoneCheck['email'];
        final userType = phoneCheck['userType'];

        if (!mounted) return;

        // Mostrar diálogo profesional
        final appLocalizations = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(appLocalizations.phoneAlreadyRegistered),
            content: Text(
              appLocalizations.phoneAlreadyRegisteredMessage(_phoneController.text, existingEmail, userType)
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(appLocalizations.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(appLocalizations.goToLoginButton),
              ),
            ],
          ),
        );
        return;
      }

      // Email Y Teléfono disponibles - continuar con registro
      AppLogger.debug('🔍 ✅ Email y teléfono disponibles, continuando con registro...');
      // Registrar usuario en Firebase CON TIMEOUT DE 30 SEGUNDOS
      AppLogger.debug('🔍 PASO 5: Llamando authProvider.register()...');
      AppLogger.debug('🔍 ⏳ ESPERANDO RESPUESTA DE FIREBASE (timeout: 30s)...');
      final success = await authProvider.register(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        userType: _userType,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          AppLogger.debug('🔍 ⏱️ TIMEOUT! Firebase no respondió en 30 segundos');
          throw TimeoutException('La conexión con Firebase tardó demasiado. Verifica tu conexión a internet e intenta nuevamente.');
        },
      );
      AppLogger.debug('🔍 ✅ authProvider.register() COMPLETADO');
      AppLogger.debug('🔍 Resultado success: $success (tipo: ${success.runtimeType})');
      // Verificar que el widget siga montado antes de usar context
      AppLogger.debug('🔍 PASO 6: Verificando si widget está montado...');
      if (!mounted) {
        AppLogger.debug('🔍 ⚠️ Widget NO MONTADO - terminando función');
        return;
      }
      AppLogger.debug('🔍 ✅ Widget SÍ está montado');
      // Si el registro fue exitoso, navegar a la pantalla de verificación de email
      AppLogger.debug('🔍 PASO 7: Evaluando resultado de success...');
      if (success) {
        AppLogger.debug('🔍 ✅ SUCCESS ES TRUE - navegando a /email-verification');
        AppLogger.debug('🔍 Email para verificación: $email');
        // MOSTRAR MENSAJE DE ÉXITO EN PANTALLA
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.registrationSuccess),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/email-verification',
          arguments: email,
        );
        AppLogger.debug('🔍 ✅ Navegación iniciada');
      } else {
        AppLogger.debug('🔍 ❌ SUCCESS ES FALSE - registro falló sin excepción');
        // OBTENER EL ERROR ESPECÍFICO DE AUTHPROVIDER
        final errorMsg = authProvider.errorMessage ?? '❌ El registro falló. Intenta nuevamente.';
        AppLogger.debug('🔍 Error del AuthProvider: $errorMsg');
        // MOSTRAR MENSAJE DE ERROR ESPECÍFICO EN PANTALLA
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: ModernTheme.warning,
            duration: Duration(seconds: 6),
          ),
        );
      }

    } on TimeoutException catch (e) {
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 ⏱️⏱️⏱️ TIMEOUT EXCEPTION ⏱️⏱️⏱️');
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 Firebase no respondió en 30 segundos');
      AppLogger.debug('🔍 Error: ${e.message}');
      AppLogger.debug('🔍 ========================================');
      if (!mounted) {
        AppLogger.debug('🔍 Widget no montado, no se puede mostrar SnackBar');
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
          backgroundColor: ModernTheme.warning,
          duration: Duration(seconds: 8),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 ❌❌❌ ERROR CAPTURADO EN CATCH ❌❌❌');
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 Error: ${e.toString()}');
      AppLogger.debug('🔍 Error type: ${e.runtimeType}');
      AppLogger.debug('🔍 Stack trace: $stackTrace');
      AppLogger.debug('🔍 ========================================');
      if (!mounted) {
        AppLogger.debug('🔍 Widget no montado, no se puede mostrar SnackBar');
        return;
      }

      // MOSTRAR ERROR EN PANTALLA
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: ${e.toString()}'),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 BLOQUE FINALLY');
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 PASO 8: Setting _isLoading = false');
      setState(() => _isLoading = false);
      AppLogger.debug('🔍 _isLoading ahora es: $_isLoading');
      AppLogger.debug('🔍 ========================================');
      AppLogger.debug('🔍 _registerUser FINALIZADO');
      AppLogger.debug('🔍 ========================================');
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
                              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              AppLocalizations.of(context)!.createAccount,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
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
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
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
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
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
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: ModernTheme.getFloatingShadow(context),
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
    final appLocalizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          appLocalizations.howToUseOasis,
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
                        appLocalizations.passenger,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        appLocalizations.requestTrips,
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
                        appLocalizations.driver,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        appLocalizations.acceptTrips,
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
    final appLocalizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          appLocalizations.personalInfo,
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
            labelText: appLocalizations.fullName,
            prefixIcon: Icon(Icons.person_outline, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.enterName;
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
            labelText: appLocalizations.phoneNumber,
            prefixIcon: Icon(Icons.phone, color: ModernTheme.oasisGreen),
            prefixText: '+51 ',
            helperText: appLocalizations.nineDigits,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.enterPhoneNumberShort;
            }
            // Validar formato peruano: 9 dígitos
            final phoneRegex = RegExp(r'^\d{9}$');
            if (!phoneRegex.hasMatch(value)) {
              return appLocalizations.mustBeNineDigits;
            }
            // Validar que empiece con 9 (típico de móviles en Perú)
            if (!value.startsWith('9')) {
              return appLocalizations.mustStartWith9;
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
            labelText: appLocalizations.email,
            prefixIcon: Icon(Icons.email_outlined, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.enterEmail;
            }
            if (!value.contains('@')) {
              return appLocalizations.enterValidEmail;
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
                child: Text(appLocalizations.back),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AnimatedPulseButton(
                text: appLocalizations.continueButton,
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
    final appLocalizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          appLocalizations.createPassword,
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
            labelText: appLocalizations.password,
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            helperText: appLocalizations.passwordRequirements,
            helperMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.enterPasswordShort;
            }
            if (value.length < 8) {
              return appLocalizations.minimumEightChars;
            }
            if (!value.contains(RegExp(r'[A-Z]'))) {
              return appLocalizations.mustIncludeUppercase;
            }
            if (!value.contains(RegExp(r'[a-z]'))) {
              return appLocalizations.mustIncludeLowercase;
            }
            if (!value.contains(RegExp(r'[0-9]'))) {
              return appLocalizations.mustIncludeNumber;
            }
            if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
              return appLocalizations.mustIncludeSpecialChar;
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
            labelText: appLocalizations.confirmPassword,
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return appLocalizations.passwordsDoNotMatch;
            }
            return null;
          },
        ),

        SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: _acceptTerms
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : ModernTheme.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _acceptTerms
                ? ModernTheme.oasisGreen.withValues(alpha: 0.3)
                : ModernTheme.error.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) {
              AppLogger.debug('🔍 Checkbox changed: $value');
              setState(() {
                _acceptTerms = value!;
                AppLogger.debug('🔍 _acceptTerms ahora es: $_acceptTerms');
              });
            },
            title: Text(
              appLocalizations.acceptTerms,
              style: TextStyle(
                fontSize: 14,
                color: _acceptTerms ? context.primaryText : ModernTheme.error,
                fontWeight: _acceptTerms ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            subtitle: !_acceptTerms
              ? Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    appLocalizations.mustAcceptTerms,
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.error,
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
                child: Text(appLocalizations.back),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _acceptTerms ? () async {
                  AppLogger.debug('🔍🔍🔍 ELEVATED BUTTON TAP!!!');
                  AppLogger.debug('🔍 _acceptTerms: $_acceptTerms');
                  AppLogger.debug('🔍 _isLoading: $_isLoading');
                  // MOSTRAR EN PANTALLA para que el usuario VEA que el botón detectó el click
                  final appLocalizations = AppLocalizations.of(context)!;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.buttonPressed),
                      backgroundColor: ModernTheme.info,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  if (_formKey.currentState!.validate()) {
                    AppLogger.debug('🔍 EJECUTANDO _registerUser()');
                    await _registerUser();
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ModernTheme.success,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2)
                    : Text(appLocalizations.createAccountButton, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}