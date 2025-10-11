// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:email_validator/email_validator.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../config/oauth_config.dart'; // Para validación estricta
import 'phone_verification_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  _ModernLoginScreenState createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _logoController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _floatAnimation;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _userType = 'passenger';
  bool _usePhoneLogin = true; // Toggle entre teléfono y email
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  @override
  void initState() {
    super.initState();
    
    
    _backgroundController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _formController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _logoController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    );
    
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.elasticOut,
    );
    
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.bounceOut,
    );
    
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    _formController.forward();
    _logoController.forward();
    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _logoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // ✅ Dispose de FocusNodes
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // Verificar intentos fallidos (rate limiting)
      if (_failedAttempts >= 5 && _lastFailedAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(_lastFailedAttempt!);
        if (timeSinceLastAttempt.inMinutes < 30) {
          final remainingTime = 30 - timeSinceLastAttempt.inMinutes;
          _showErrorMessage(
            'Demasiados intentos fallidos. Intenta de nuevo en $remainingTime minutos.',
          );
          return;
        } else {
          _failedAttempts = 0; // Reset después de 30 minutos
        }
      }
      
      setState(() => _isLoading = true);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      try {
        bool success = false;
        
        if (_usePhoneLogin) {
          // Login con teléfono - VALIDACIÓN ESTRICTA OBLIGATORIA
          final phone = _phoneController.text.trim();
          
          // CRÍTICO: Usar validación centralizada y estricta
          if (!ValidationPatterns.isValidPeruMobile(phone)) {
            _showErrorMessage(
              'Número inválido. Debe ser peruano móvil: 9XXXXXXXX\n'
              'Operadores válidos: Claro, Movistar, Entel'
            );
            setState(() => _isLoading = false);
            return;
          }
          
          // Verificación adicional de operador móvil
          final operatorCode = phone.substring(0, 2);
          final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
          if (!validOperators.contains(operatorCode)) {
            _showErrorMessage('Operador móvil no reconocido. Use números de Claro, Movistar o Entel.');
            setState(() => _isLoading = false);
            return;
          }
          
          // Navegar a pantalla de verificación OTP
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationScreen(
                phoneNumber: phone,
                isRegistration: false,
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        } else {
          // Login con email
          final email = _emailController.text.trim();
          
          // Validar email profesional
          if (!EmailValidator.validate(email)) {
            _showErrorMessage('Email inválido');
            setState(() => _isLoading = false);
            return;
          }
          
          success = await authProvider.login(email, _passwordController.text);
        }
        
        if (!mounted) return;
        
        if (success) {
          // Reset intentos fallidos
          _failedAttempts = 0;
          _lastFailedAttempt = null;
          
          // Vibración de éxito
          HapticFeedback.mediumImpact();
          
          // Verificar si el email está verificado
          if (!authProvider.emailVerified && !_usePhoneLogin) {
            _showErrorMessage(
              'Por favor verifica tu email antes de continuar. Revisa tu bandeja de entrada.',
            );
            setState(() => _isLoading = false);
            return;
          }
          
          // Navegar según el tipo de usuario
          if (_userType == 'passenger') {
            Navigator.pushReplacementNamed(context, '/passenger/home');
          } else if (_userType == 'driver') {
            Navigator.pushReplacementNamed(context, '/driver/home');
          } else if (_userType == 'admin') {
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          }
        } else {
          // Incrementar intentos fallidos
          _failedAttempts++;
          _lastFailedAttempt = DateTime.now();
          
          // Vibración de error
          HapticFeedback.heavyImpact();
          
          // Mostrar mensaje de error específico
          final errorMsg = authProvider.errorMessage ?? 'Error al iniciar sesión';
          _showErrorMessage(errorMsg);
          
          // Si la cuenta está bloqueada
          if (authProvider.isAccountLocked) {
            _showErrorMessage(
              'Tu cuenta ha sido bloqueada temporalmente por seguridad. '
              'Intenta de nuevo más tarde o contacta soporte.',
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        _showErrorMessage('Error inesperado: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isGoogleConfigured) {
      _showErrorMessage(
        'Google Sign-In no configurado.\n'
        'Contacta al administrador del sistema.'
      );
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();
      
      final success = await authProvider.signInWithGoogle();
      
      if (!mounted) return;
      
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(
          authProvider.errorMessage ?? 
          'Error al iniciar sesión con Google. Intenta nuevamente.'
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error con Google Sign-In: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithFacebook() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isFacebookConfigured) {
      _showErrorMessage(
        'Facebook Login no configurado.\n'
        'Contacta al administrador del sistema.'
      );
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();
      
      final success = await authProvider.signInWithFacebook();
      
      if (!mounted) return;
      
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(
          authProvider.errorMessage ?? 
          'Error al iniciar sesión con Facebook. Intenta nuevamente.'
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al iniciar sesión con Facebook: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithApple() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isAppleConfigured) {
      _showErrorMessage(
        'Apple Sign-In no configurado.\n'
        'Contacta al administrador del sistema.'
      );
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();
      
      final success = await authProvider.signInWithApple();
      
      if (!mounted) return;
      
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(
          authProvider.errorMessage ?? 
          'Error al iniciar sesión con Apple. Intenta nuevamente.'
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al iniciar sesión con Apple: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado con gradiente
          AnimatedBuilder(
            animation: _backgroundAnimation,
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
                    transform: GradientRotation(_backgroundAnimation.value * 2 * math.pi),
                  ),
                ),
              );
            },
          ),
          
          // Burbujas flotantes animadas
          ...List.generate(5, (index) {
            return AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                final size = 50.0 + (index * 30);
                final speed = 1 + (index * 0.2);
                return Positioned(
                  left: MediaQuery.of(context).size.width * 
                    math.sin((_backgroundAnimation.value * speed + index) * 2 * math.pi),
                  top: MediaQuery.of(context).size.height * 
                    ((_backgroundAnimation.value * speed + index) % 1),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                );
              },
            );
          }),
          
          // Contenido principal con GestureDetector para cerrar teclado al tocar fuera
          SafeArea(
            child: GestureDetector(
              onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera (Android compatible)
              child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(height: 40),
                    
                    // Logo animado
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, math.sin(_floatAnimation.value * math.pi) * 10),
                          child: ScaleTransition(
                            scale: _logoAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 25,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(15),
                              child: Image.asset(
                                'assets/images/logo_oasis_taxi.png',
                                width: 90,
                                height: 90,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback al ícono si la imagen no carga
                                  return Icon(
                                    Icons.local_taxi,
                                    size: 60,
                                    color: ModernTheme.oasisGreen,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Título
                    Text(
                      'OASIS TAXI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    Text(
                      'Tu viaje, tu precio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Formulario con animación
                    AnimatedBuilder(
                      animation: _formAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _formAnimation.value,
                          child: Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: ModernTheme.floatingShadow,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Selector de tipo de usuario
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ModernTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => _userType = 'passenger'),
                                                child: AnimatedContainer(
                                                  duration: Duration(milliseconds: 300),
                                                  padding: EdgeInsets.symmetric(vertical: 16),
                                                  decoration: BoxDecoration(
                                                    color: _userType == 'passenger' 
                                                      ? ModernTheme.oasisGreen 
                                                      : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.person,
                                                        color: _userType == 'passenger' 
                                                          ? Colors.white 
                                                          : ModernTheme.textSecondary,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Pasajero',
                                                        style: TextStyle(
                                                          color: _userType == 'passenger' 
                                                            ? Colors.white 
                                                            : ModernTheme.textSecondary,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => _userType = 'driver'),
                                                child: AnimatedContainer(
                                                  duration: Duration(milliseconds: 300),
                                                  padding: EdgeInsets.symmetric(vertical: 16),
                                                  decoration: BoxDecoration(
                                                    color: _userType == 'driver' 
                                                      ? ModernTheme.oasisGreen 
                                                      : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.directions_car,
                                                        color: _userType == 'driver' 
                                                          ? Colors.white 
                                                          : ModernTheme.textSecondary,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Conductor',
                                                        style: TextStyle(
                                                          color: _userType == 'driver' 
                                                            ? Colors.white 
                                                            : ModernTheme.textSecondary,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Opción de Administrador
                                        GestureDetector(
                                          onTap: () => setState(() => _userType = 'admin'),
                                          child: AnimatedContainer(
                                            duration: Duration(milliseconds: 300),
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                              color: _userType == 'admin' 
                                                ? ModernTheme.oasisGreen 
                                                : Colors.transparent,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.admin_panel_settings,
                                                  color: _userType == 'admin' 
                                                    ? Colors.white 
                                                    : ModernTheme.textSecondary,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Administrador',
                                                  style: TextStyle(
                                                    color: _userType == 'admin' 
                                                      ? Colors.white 
                                                      : ModernTheme.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Toggle entre teléfono y email
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ModernTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _usePhoneLogin = true),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _usePhoneLogin
                                                  ? ModernTheme.oasisGreen
                                                  : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.phone_android,
                                                    color: _usePhoneLogin
                                                      ? Colors.white
                                                      : ModernTheme.textSecondary,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Teléfono',
                                                    style: TextStyle(
                                                      color: _usePhoneLogin
                                                        ? Colors.white
                                                        : ModernTheme.textSecondary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _usePhoneLogin = false),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: !_usePhoneLogin
                                                  ? ModernTheme.oasisGreen
                                                  : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.email,
                                                    color: !_usePhoneLogin
                                                      ? Colors.white
                                                      : ModernTheme.textSecondary,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Email',
                                                    style: TextStyle(
                                                      color: !_usePhoneLogin
                                                        ? Colors.white
                                                        : ModernTheme.textSecondary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Campo de teléfono o email según selección
                                  if (_usePhoneLogin)
                                    TextFormField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocusNode, // ✅ FocusNode configurado
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
                                      onFieldSubmitted: (_) => _login(), // ✅ Ejecuta login al presionar Done
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(9),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Número de teléfono',
                                        hintText: '999 999 999',
                                        prefixIcon: Icon(Icons.phone, color: ModernTheme.primaryOrange),
                                        prefixText: '+51 ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu número de teléfono';
                                        }
                                        
                                        // VALIDACIÓN ESTRICTA OBLIGATORIA
                                        if (!ValidationPatterns.isValidPeruMobile(value)) {
                                          return 'Número peruano inválido\nFormato: 9XXXXXXXX';
                                        }
                                        
                                        // Verificar operador móvil válido
                                        if (value.length == 9) {
                                          final operatorCode = value.substring(0, 2);
                                          final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
                                          if (!validOperators.contains(operatorCode)) {
                                            return 'Operador no válido\nUse Claro, Movistar o Entel';
                                          }
                                        }
                                        
                                        return null;
                                      },
                                    )
                                  else
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode, // ✅ FocusNode configurado
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next, // ✅ Botón Next para ir a contraseña
                                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(), // ✅ Avanza al campo de contraseña
                                      autocorrect: false,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'correo@ejemplo.com',
                                        prefixIcon: Icon(Icons.email, color: ModernTheme.primaryOrange),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu email';
                                        }
                                        if (!EmailValidator.validate(value)) {
                                          return 'Email inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                  
                                  SizedBox(height: 16),
                                  
                                  // Campo de contraseña (solo para login con email)
                                  if (!_usePhoneLogin)
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode, // ✅ FocusNode configurado
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
                                      onFieldSubmitted: (_) => _login(), // ✅ Ejecuta login al presionar Done
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        hintText: 'Mínimo 8 caracteres',
                                        prefixIcon: Icon(Icons.lock, color: ModernTheme.primaryOrange),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                            color: ModernTheme.textSecondary,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (!_usePhoneLogin) {
                                          if (value == null || value.isEmpty) {
                                            return 'Ingresa tu contraseña';
                                          }
                                          if (value.length < 8) {
                                            return 'La contraseña debe tener al menos 8 caracteres';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  
                                  SizedBox(height: 12),
                                  
                                  // Olvidé mi contraseña
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/forgot-password');
                                      },
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(
                                          color: ModernTheme.oasisBlack,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Botón de inicio de sesión
                                  AnimatedPulseButton(
                                    text: 'Iniciar Sesión',
                                    icon: Icons.arrow_forward,
                                    isLoading: _isLoading,
                                    onPressed: _login,
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Divider con texto
                                  Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'O continúa con',
                                          style: TextStyle(color: ModernTheme.textSecondary),
                                        ),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Botones de redes sociales
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildSocialButton(
                                        icon: Icons.g_mobiledata,
                                        color: Color(0xFFDB4437),
                                        onPressed: _loginWithGoogle,
                                      ),
                                      _buildSocialButton(
                                        icon: Icons.facebook,
                                        color: Color(0xFF1877F2),
                                        onPressed: _loginWithFacebook,
                                      ),
                                      _buildSocialButton(
                                        icon: Icons.apple,
                                        color: Colors.black,
                                        onPressed: _loginWithApple,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: Text(
                            'Regístrate',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ), // SingleScrollView
          ), // GestureDetector
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}