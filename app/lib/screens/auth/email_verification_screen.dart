// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;
  Timer? _verificationTimer;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    _timer?.cancel();
    _timer = null;
    _verificationTimer?.cancel();
    _verificationTimer = null;
    super.dispose();
  }

  /// Iniciar contador para reenvío de email
  void _startResendCountdown() {
    _canResend = false;
    _resendCountdown = 60;

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir setState después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  /// Verificar periódicamente si el email fue verificado
  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      // ✅ TRIPLE VERIFICACIÓN para prevenir verificaciones después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      await _checkEmailVerified();
    });
  }

  /// Verificar si el email fue verificado
  Future<void> _checkEmailVerified() async {
    // ✅ Verificar mounted antes de operación asíncrona
    if (!mounted || _isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();

      // ✅ Verificar mounted después de operación asíncrona
      if (!mounted || _isDisposed) return;

      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser?.emailVerified ?? false) {
        _verificationTimer?.cancel();
        _verificationTimer = null;

        // Email verificado exitosamente
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Email verificado exitosamente'),
            backgroundColor: ModernTheme.oasisGreen,
            duration: Duration(seconds: 2),
          ),
        );

        // Esperar un momento y navegar al login
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    }
  }

  /// Reenviar email de verificación
  Future<void> _resendVerificationEmail() async {
    setState(() => _isVerifying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📧 Email de verificación enviado'),
              backgroundColor: ModernTheme.oasisGreen,
            ),
          );
        }

        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  /// Volver al login
  void _backToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ModernTheme.oasisGreen,
              ModernTheme.oasisGreen.withValues(alpha: 0.8),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícono animado
                  Container(
                    padding: EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: ModernTheme.floatingShadow,
                    ),
                    child: Icon(
                      Icons.mark_email_unread,
                      size: 80,
                      color: ModernTheme.oasisGreen,
                    ),
                  ),

                  SizedBox(height: 40),

                  // Título
                  Text(
                    '📧 Verifica tu email',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 16),

                  // Descripción
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Hemos enviado un correo de verificación a:',
                          style: TextStyle(
                            fontSize: 16,
                            color: ModernTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.email,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.oasisGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),
                        Text(
                          '1. Revisa tu bandeja de entrada\n'
                          '2. Haz clic en el enlace de verificación\n'
                          '3. Vuelve a esta pantalla',
                          style: TextStyle(
                            fontSize: 14,
                            color: ModernTheme.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Botón para reenviar email
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedPulseButton(
                      text: _canResend
                        ? 'Reenviar email'
                        : 'Espera $_resendCountdown segundos',
                      icon: Icons.refresh,
                      isLoading: _isVerifying,
                      onPressed: _canResend ? _resendVerificationEmail : () {},
                    ),
                  ),

                  SizedBox(height: 16),

                  // Botón para volver al login
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _backToLogin,
                      icon: Icon(Icons.arrow_back),
                      label: Text('Volver al login'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white, width: 2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Nota sobre spam
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿No ves el email? Revisa tu carpeta de spam',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
