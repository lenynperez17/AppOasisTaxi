// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentStep = 0; // 0: phone, 1: code, 2: new password
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _verificationCode = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    // ✅ Dispose de FocusNodes
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  void _sendVerificationCode() async {
    if (_phoneController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingrese su número de teléfono'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simular envío de código
    await Future.delayed(Duration(seconds: 2));

    // Generar código de 6 dígitos
    _verificationCode = (100000 + math.Random().nextInt(900000)).toString();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    }

    // En producción, enviar SMS real
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código enviado: $_verificationCode (Demo)'),
        backgroundColor: ModernTheme.success,
        duration: Duration(seconds: 5),
      ),
    );

    _animationController.reset();
    _animationController.forward();
  }

  void _verifyCode() async {
    if (_codeController.text != _verificationCode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código incorrecto'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _currentStep = 2;
      });
    }

    _animationController.reset();
    _animationController.forward();
  }

  void _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simular reset de contraseña
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ModernTheme.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: ModernTheme.success,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '¡Contraseña Actualizada!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Tu contraseña ha sido actualizada exitosamente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Ir al Login'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ModernTheme.oasisGreen,
              ModernTheme.oasisGreen.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Recuperar Contraseña',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // Progress indicator
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildStepIndicator(0, 'Teléfono'),
                    _buildStepConnector(0),
                    _buildStepIndicator(1, 'Verificar'),
                    _buildStepConnector(1),
                    _buildStepIndicator(2, 'Nueva'),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera (Android compatible)
                    child: SingleChildScrollView(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? ModernTheme.oasisGreen : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : ModernTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color:
                  isActive ? ModernTheme.oasisGreen : ModernTheme.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.only(bottom: 28),
        color: isActive ? ModernTheme.oasisGreen : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildPasswordStep();
      default:
        return _buildPhoneStep();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Image.asset(
            'assets/images/logo_oasis_taxi.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 30),

        Text(
          'Ingresa tu número de teléfono',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Te enviaremos un código de verificación por SMS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 30),

        // Phone input
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
          onFieldSubmitted: (_) =>
              _sendVerificationCode(), // ✅ Ejecuta envío de código al presionar Done
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            prefixIcon: Icon(Icons.phone, color: ModernTheme.oasisGreen),
            prefixText: '+51 ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
            ),
          ),
        ),
        SizedBox(height: 30),

        // Send button
        AnimatedPulseButton(
          text: 'Enviar Código',
          icon: Icons.send,
          onPressed: _isLoading ? () {} : _sendVerificationCode,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        Icon(
          Icons.sms,
          size: 80,
          color: ModernTheme.oasisGreen,
        ),
        SizedBox(height: 30),

        Text(
          'Verificación por SMS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Ingresa el código de 6 dígitos enviado a\n+51 ${_phoneController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 30),

        // Code input
        TextFormField(
          controller: _codeController,
          focusNode: _codeFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
          onFieldSubmitted: (_) =>
              _verifyCode(), // ✅ Ejecuta verificación al presionar Done
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 10,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
            ),
          ),
        ),
        SizedBox(height: 20),

        // Resend button
        TextButton(
          onPressed: _sendVerificationCode,
          child: Text(
            'Reenviar código',
            style: TextStyle(color: ModernTheme.primaryBlue),
          ),
        ),
        SizedBox(height: 20),

        // Verify button
        AnimatedPulseButton(
          text: 'Verificar',
          icon: Icons.check,
          onPressed: _verifyCode,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Icon(
            Icons.lock_reset,
            size: 80,
            color: ModernTheme.oasisGreen,
          ),
          SizedBox(height: 30),

          Text(
            'Crear Nueva Contraseña',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Ingresa tu nueva contraseña segura',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 30),

          // New password
          TextFormField(
            controller: _newPasswordController,
            focusNode: _newPasswordFocusNode, // ✅ FocusNode configurado
            textInputAction: TextInputAction
                .next, // ✅ Botón Next para ir a confirmar contraseña
            onFieldSubmitted: (_) => _confirmPasswordFocusNode
                .requestFocus(), // ✅ Avanza al campo de confirmar contraseña
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: Icon(Icons.lock, color: ModernTheme.oasisGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  color: ModernTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese una contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          SizedBox(height: 20),

          // Confirm password
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode, // ✅ FocusNode configurado
            textInputAction:
                TextInputAction.done, // ✅ Botón Done en teclado (último campo)
            onFieldSubmitted: (_) {
              // ✅ Valida y ejecuta reset al presionar Done
              if (_formKey.currentState!.validate()) {
                _resetPassword();
              }
            },
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon:
                  Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: ModernTheme.textSecondary,
                ),
                onPressed: () {
                  setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.oasisGreen, width: 2),
              ),
            ),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          SizedBox(height: 30),

          // Reset button
          AnimatedPulseButton(
            text: 'Actualizar Contraseña',
            icon: Icons.check_circle,
            onPressed: _isLoading ? () {} : _resetPassword,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
