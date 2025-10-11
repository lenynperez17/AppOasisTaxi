import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import '../config/oauth_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider de Autenticación Profesional Enterprise con Firebase
/// Incluye validación completa, seguridad avanzada y autenticación multifactor
class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  // final SecurityLogger _securityLogger = SecurityLogger(); // Removido: archivo no existe
  
  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Control de seguridad y rate limiting
  int _loginAttempts = 0;
  bool _isAccountLocked = false;
  DateTime? _lockedUntil;
  
  // Verificación de email y teléfono
  bool _emailVerified = false;
  bool _phoneVerified = false;
  String? _verificationId; // Para OTP de teléfono
  String? _pendingPhoneNumber;
  
  // Configuración de seguridad
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 30;
  static const int minPasswordLength = 8;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated && _emailVerified;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAccountLocked => _isAccountLocked;
  bool get emailVerified => _emailVerified;
  bool get phoneVerified => _phoneVerified;
  int get remainingAttempts => maxLoginAttempts - _loginAttempts;
  String? get verificationId => _verificationId;
  
  AuthProvider() {
    AppLogger.state('AuthProvider', 'Constructor iniciado');
    _initializeAuth();
  }

  /// Inicializar autenticación con verificación completa
  void _initializeAuth() {
    AppLogger.state('AuthProvider', 'Inicializando autenticación profesional');
    _loadSecurityState();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        AppLogger.state('AuthProvider', 'Usuario detectado', {
          'uid': user.uid, 
          'email': user.email,
          'emailVerified': user.emailVerified
        });
        
        // Verificar estado de verificación de email
        _emailVerified = user.emailVerified;
        
        if (!_emailVerified) {
          AppLogger.warning('Email no verificado', {'email': user.email});
          _errorMessage = 'Por favor verifica tu email antes de continuar';
        }
        
        await _loadUserData(user.uid);
      } else {
        AppLogger.state('AuthProvider', 'Sin usuario autenticado');
        _resetAuthState();
      }
    });
  }
  
  /// Resetear estado de autenticación
  void _resetAuthState() {
    _currentUser = null;
    _isAuthenticated = false;
    _emailVerified = false;
    _phoneVerified = false;
    _verificationId = null;
    notifyListeners();
  }

  /// Cargar datos del usuario desde Firestore
  Future<void> _loadUserData(String uid) async {
    AppLogger.state('AuthProvider', 'Cargando datos del usuario', {'uid': uid});
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        AppLogger.state('AuthProvider', 'Documento de usuario encontrado');
        _currentUser = UserModel.fromFirestore(doc.data()!, uid);
        _isAuthenticated = true;
        AppLogger.state('AuthProvider', 'Usuario autenticado correctamente', {
          'userType': _currentUser?.userType,
          'email': _currentUser?.email,
        });
      } else {
        AppLogger.warning('Documento de usuario no existe en Firestore', {'uid': uid});
      }
    } catch (e) {
      AppLogger.error('Error cargando datos del usuario', e);
      _errorMessage = 'Error al cargar datos del usuario';
    }
    notifyListeners();
  }

  /// Iniciar sesión con email y contraseña con validación profesional
  Future<bool> login(String email, String password) async {
    // Verificar bloqueo de cuenta
    if (await _checkAccountLock()) {
      _errorMessage = 'Cuenta bloqueada. Intenta de nuevo en ${_getRemainingLockTime()} minutos';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validar formato de email
      if (!_validateEmail(email)) {
        _errorMessage = 'Email inválido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Validar contraseña
      if (!_validatePassword(password)) {
        _errorMessage = 'Contraseña no cumple con los requisitos mínimos';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Verificar si el email está verificado
        if (!credential.user!.emailVerified) {
          await credential.user!.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          _errorMessage = 'Email no verificado. Se ha enviado un nuevo correo de verificación.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        // Resetear intentos de login
        _loginAttempts = 0;
        await _saveSecurityState();
        
        await _loadUserData(credential.user!.uid);
        
        // Registrar evento en analytics con información de seguridad
        await _firebaseService.logEvent('login_success', {
          'method': 'email',
          'user_type': _currentUser?.userType,
          'device_id': await _getDeviceId(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Log de seguridad profesional
        // await _securityLogger.logLoginSuccess(credential.user!.uid, 'email');
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      _incrementLoginAttempts();
      // await _securityLogger.logLoginFailure(email, e.code);
    } catch (e) {
      _errorMessage = 'Error inesperado: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Registrar nuevo usuario con validación profesional completa
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validaciones profesionales
      if (!_validateEmail(email)) {
        _errorMessage = 'Email inválido o no permitido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      if (!_validatePasswordStrength(password)) {
        _errorMessage = 'La contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas, números y un carácter especial';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      if (!_validatePhoneNumber(phone)) {
        _errorMessage = 'Número de teléfono inválido. Debe ser un número peruano válido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      if (!_validateFullName(fullName)) {
        _errorMessage = 'Nombre completo inválido. Debe contener al menos nombre y apellido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificar si el email ya está registrado en Firestore
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
          
      if (existingUser.docs.isNotEmpty) {
        _errorMessage = 'Este email ya está registrado';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificar si el teléfono ya está registrado
      final existingPhone = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();
          
      if (existingPhone.docs.isNotEmpty) {
        _errorMessage = 'Este número de teléfono ya está registrado';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Crear cuenta en Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Actualizar perfil
        await credential.user!.updateDisplayName(fullName);
        
        // Hash del teléfono para privacidad
        final phoneHash = _hashPhone(phone);
        
        // Crear documento en Firestore con datos completos
        final userData = {
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'phoneHash': phoneHash,
          'userType': userType,
          'profilePhotoUrl': '',
          'isActive': true,
          'isVerified': false,
          'emailVerified': false,
          'phoneVerified': false,
          'twoFactorEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': null,
          'rating': 5.0,
          'totalTrips': 0,
          'balance': 0.0,
          'securitySettings': {
            'loginAttempts': 0,
            'lastPasswordChange': FieldValue.serverTimestamp(),
            'passwordHistory': [], // Para evitar reutilización de contraseñas
          },
          'deviceInfo': {
            'lastDeviceId': await _getDeviceId(),
            'trustedDevices': [],
          },
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData);

        // Enviar email de verificación
        await credential.user!.sendEmailVerification();
        
        // Log de seguridad para nuevo registro
        await _logSecurityEvent('USER_REGISTERED', {
          'user_id': credential.user!.uid,
          'email': email,
          'user_type': userType,
        });
        
        // Registrar evento
        await _firebaseService.logEvent('sign_up_success', {
          'method': 'email',
          'user_type': userType,
        });

        _isLoading = false;
        _errorMessage = 'Registro exitoso. Por favor verifica tu email para continuar.';
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      await _logSecurityEvent('REGISTRATION_FAILED', {
        'email': email,
        'error': e.code,
      });
    } catch (e) {
      _errorMessage = 'Error al registrar: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Cerrar sesión
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signOut();
      _currentUser = null;
      _isAuthenticated = false;
      
      await _firebaseService.logEvent('logout', null);
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Recuperar contraseña
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      await _firebaseService.logEvent('password_reset_request', {
        'email': email,
      });
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _errorMessage = 'Error al enviar email: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Actualizar perfil del usuario
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar localmente
      _currentUser = UserModel.fromJson({
        ..._currentUser!.toJson(),
        ...updates,
      });

      await _firebaseService.logEvent('profile_update', updates);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar perfil: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Cambiar contraseña
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Usuario no autenticado');
      }

      // Re-autenticar
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(newPassword);
      
      await _firebaseService.logEvent('password_change', null);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _errorMessage = 'Error al cambiar contraseña: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Verificar email
  Future<bool> verifyEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
    } catch (e) {
      debugPrint('Error verificando email: $e');
      await _firebaseService.recordError(e, null);
    }
    return false;
  }

  /// Manejar errores de autenticación con mensajes detallados
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No existe una cuenta con este email';
        break;
      case 'wrong-password':
        _errorMessage = 'Contraseña incorrecta. Te quedan $remainingAttempts intentos';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Este email ya está registrado. ¿Olvidaste tu contraseña?';
        break;
      case 'invalid-email':
        _errorMessage = 'El formato del email no es válido';
        break;
      case 'weak-password':
        _errorMessage = 'La contraseña no cumple con los requisitos de seguridad';
        break;
      case 'network-request-failed':
        _errorMessage = 'Error de conexión. Verifica tu internet';
        break;
      case 'too-many-requests':
        _errorMessage = 'Demasiados intentos. Por favor espera unos minutos';
        break;
      case 'user-disabled':
        _errorMessage = 'Esta cuenta ha sido deshabilitada. Contacta soporte';
        break;
      case 'operation-not-allowed':
        _errorMessage = 'Esta operación no está permitida';
        break;
      default:
        _errorMessage = 'Error de autenticación: ${e.message}';
    }
  }

  /// Iniciar sesión con Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signInWithGoogle();
      if (user != null) {
        await _loadUserData(user.uid);
        _isAuthenticated = true;
        
        await _firebaseService.logEvent('google_login_success', {
          'user_id': user.uid,
          'method': 'google',
        });
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión con Google: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Iniciar sesión con Facebook
  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signInWithFacebook();
      if (user != null) {
        await _loadUserData(user.uid);
        _isAuthenticated = true;
        
        await _firebaseService.logEvent('facebook_login_success', {
          'user_id': user.uid,
          'method': 'facebook',
        });
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión con Facebook: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Iniciar sesión con Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signInWithApple();
      if (user != null) {
        await _loadUserData(user.uid);
        _isAuthenticated = true;
        
        await _firebaseService.logEvent('apple_login_success', {
          'user_id': user.uid,
          'method': 'apple',
        });
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión con Apple: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Limpiar mensajes de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // ==================== MÉTODOS DE VALIDACIÓN PROFESIONAL ====================
  
  /// Validar email con formato correcto y dominios permitidos
  bool _validateEmail(String email) {
    if (!EmailValidator.validate(email)) return false;
    
    // Lista de dominios no permitidos (emails temporales)
    final blockedDomains = [
      'tempmail.com', 'guerrillamail.com', '10minutemail.com',
      'mailinator.com', 'throwaway.email', 'yopmail.com'
    ];
    
    final domain = email.split('@').last.toLowerCase();
    return !blockedDomains.contains(domain);
  }
  
  /// Validar contraseña básica
  bool _validatePassword(String password) {
    return password.length >= minPasswordLength;
  }
  
  /// Validar fortaleza de contraseña (para registro)
  bool _validatePasswordStrength(String password) {
    // Mínimo 8 caracteres
    if (password.length < minPasswordLength) return false;
    
    // Debe contener mayúsculas
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // Debe contener minúsculas
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    
    // Debe contener números
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    
    // Debe contener caracteres especiales
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    
    return true;
  }
  
  /// Validar número de teléfono peruano - VALIDACIÓN ESTRICTA OBLIGATORIA
  bool _validatePhoneNumber(String phone) {
    // CRÍTICO: Usar validación centralizada de ValidationPatterns
    // NO permitir bypass bajo NINGUNA circunstancia
    return ValidationPatterns.isValidPeruMobile(phone);
  }
  
  /// Validar nombre completo
  bool _validateFullName(String name) {
    // Debe tener al menos 2 palabras (nombre y apellido)
    final parts = name.trim().split(' ');
    if (parts.length < 2) return false;
    
    // Cada parte debe tener al menos 2 caracteres
    for (final part in parts) {
      if (part.length < 2) return false;
    }
    
    // Solo letras y espacios permitidos
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    return nameRegex.hasMatch(name);
  }
  
  // ==================== MÉTODOS DE SEGURIDAD ====================
  
  /// Verificar bloqueo de cuenta
  Future<bool> _checkAccountLock() async {
    if (_isAccountLocked && _lockedUntil != null) {
      if (DateTime.now().isBefore(_lockedUntil!)) {
        return true;
      } else {
        // Desbloquear cuenta
        _isAccountLocked = false;
        _lockedUntil = null;
        _loginAttempts = 0;
        await _saveSecurityState();
      }
    }
    return false;
  }
  
  /// Incrementar intentos de login
  void _incrementLoginAttempts() async {
    _loginAttempts++;
    
    if (_loginAttempts >= maxLoginAttempts) {
      _isAccountLocked = true;
      _lockedUntil = DateTime.now().add(Duration(minutes: lockoutDurationMinutes));
      _errorMessage = 'Cuenta bloqueada por $lockoutDurationMinutes minutos debido a múltiples intentos fallidos';
      
      // Log crítico de bloqueo de cuenta
      // await _securityLogger.logAccountLocked(
      //   _currentUser?.id ?? 'unknown', 
      //   'Excedido límite de intentos de login: $_loginAttempts'
      // );
    }
    
    await _saveSecurityState();
    notifyListeners();
  }
  
  /// Obtener tiempo restante de bloqueo
  int _getRemainingLockTime() {
    if (_lockedUntil == null) return 0;
    final remaining = _lockedUntil!.difference(DateTime.now());
    return remaining.inMinutes;
  }
  
  /// Guardar estado de seguridad
  Future<void> _saveSecurityState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('login_attempts', _loginAttempts);
    await prefs.setBool('account_locked', _isAccountLocked);
    if (_lockedUntil != null) {
      await prefs.setString('locked_until', _lockedUntil!.toIso8601String());
    }
  }
  
  /// Cargar estado de seguridad
  Future<void> _loadSecurityState() async {
    final prefs = await SharedPreferences.getInstance();
    _loginAttempts = prefs.getInt('login_attempts') ?? 0;
    _isAccountLocked = prefs.getBool('account_locked') ?? false;
    final lockedUntilStr = prefs.getString('locked_until');
    if (lockedUntilStr != null) {
      _lockedUntil = DateTime.parse(lockedUntilStr);
    }
  }
  
  /// Obtener ID del dispositivo
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generar nuevo ID de dispositivo
      final random = math.Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      deviceId = base64Url.encode(values);
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
  
  /// Hash del teléfono para privacidad
  String _hashPhone(String phone) {
    final bytes = utf8.encode(phone);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Registrar evento de seguridad
  Future<void> _logSecurityEvent(String eventType, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('security_logs').add({
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'device_id': await _getDeviceId(),
        'data': data,
      });
    } catch (e) {
      AppLogger.error('Error al registrar evento de seguridad', e);
    }
  }
  
  // ==================== AUTENTICACIÓN CON TELÉFONO ====================
  
  /// Iniciar verificación con teléfono - SISTEMA ANTI-BYPASS
  Future<bool> startPhoneVerification(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // VALIDACIÓN CRÍTICA: Triple verificación obligatoria
      if (!_validatePhoneNumber(phoneNumber)) {
        _errorMessage = 'Número de teléfono peruano inválido. Debe ser 9XXXXXXXX';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificación adicional con patrón directo (redundancia de seguridad)
      if (!RegExp(r'^9[0-9]{8}$').hasMatch(phoneNumber)) {
        _errorMessage = 'Formato de número incorrecto. Use formato: 9XXXXXXXX';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificación de operador móvil válido
      final operatorCode = phoneNumber.substring(0, 2);
      final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
      if (!validOperators.contains(operatorCode)) {
        _errorMessage = 'Operador móvil no válido. Use un número de Claro, Movistar o Entel';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      _pendingPhoneNumber = phoneNumber;
      final fullPhoneNumber = ValidationPatterns.formatForFirebaseAuth(phoneNumber);
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación en Android
          await _signInWithPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = 'Error de verificación: ${e.message}';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: Duration(seconds: 60),
      );
      
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar código: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Verificar código OTP
  Future<bool> verifyOTP(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'No hay verificación pendiente';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      return await _signInWithPhoneCredential(credential);
    } catch (e) {
      _errorMessage = 'Código inválido';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Iniciar sesión con credencial de teléfono
  Future<bool> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        _phoneVerified = true;
        
        // Verificar si el usuario existe en Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (!doc.exists) {
          // Crear perfil básico si no existe
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'phone': _pendingPhoneNumber,
            'phoneVerified': true,
            'userType': 'passenger',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Actualizar estado de verificación de teléfono
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({
            'phoneVerified': true,
            'lastPhoneVerification': FieldValue.serverTimestamp(),
          });
        }
        
        await _loadUserData(userCredential.user!.uid);
        
        // Log de seguridad
        await _logSecurityEvent('PHONE_LOGIN_SUCCESS', {
          'user_id': userCredential.user!.uid,
          'phone': _pendingPhoneNumber,
        });
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _errorMessage = 'Error al verificar teléfono: $e';
      await _firebaseService.recordError(e, null);
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Reenviar código OTP
  Future<bool> resendOTP() async {
    if (_pendingPhoneNumber == null) {
      _errorMessage = 'No hay número pendiente de verificación';
      notifyListeners();
      return false;
    }
    
    return await startPhoneVerification(_pendingPhoneNumber!);
  }
}