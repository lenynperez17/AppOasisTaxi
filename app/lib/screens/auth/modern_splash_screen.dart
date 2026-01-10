import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider; // ✅ Para verificar proveedores
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ NUEVO: Para sincronizar currentMode
import 'dart:math' as math;
import '../../generated/l10n/app_localizations.dart';
import '../../core/theme/modern_theme.dart';
import '../../utils/logger.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de splash con animaciones modernas
///
/// Muestra el logo de Oasis Taxi con animaciones mientras
/// se inicializa el AuthProvider y determina la ruta inicial
class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _rippleController;
  late AnimationController _carController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernSplashScreen', 'initState');
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _carController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    
    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _carAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimations();
  }
  
  Future<void> _startAnimations() async {
    AppLogger.info('Iniciando animaciones del Splash Screen');
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
    _rippleController.repeat();
    _carController.repeat();

    AppLogger.info('Esperando a que AuthProvider se inicialice...');

    // Esperar a que AuthProvider termine de inicializar (máximo 10 segundos)
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final startTime = DateTime.now();
    const maxWaitTime = Duration(seconds: 10);

    // Esperar a que isInitializing sea false
    while (authProvider.isInitializing &&
           DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Esperar al menos 2 segundos totales para mostrar el splash
    final elapsedTime = DateTime.now().difference(startTime);
    if (elapsedTime < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsedTime);
    }

    AppLogger.info('AuthProvider listo. Navegando...', {
      'tiempoEspera': DateTime.now().difference(startTime).inMilliseconds,
      'isAuthenticated': authProvider.isAuthenticated,
      'hasUser': authProvider.currentUser != null,
    });

    _navigateToHome();
  }

  /// Navegar a pantalla correspondiente según estado de autenticación y modo
  ///
  /// Implementa navegación inteligente estilo InDriver:
  /// - Usuario sin perfil completo → /auth/complete-profile
  /// - Usuario dual con currentMode='passenger' → /passenger/home
  /// - Usuario dual con currentMode='driver' → /driver/home
  /// - Usuario passenger (puro) → /passenger/home
  /// - Usuario driver (puro) → /driver/home
  /// - Usuario admin → /admin/dashboard
  /// - Sin autenticación → /login
  Future<void> _navigateToHome() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Verificar si hay usuario autenticado
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      final user = authProvider.currentUser!;

      AppLogger.info('Usuario autenticado detectado', {
        'userId': user.id,
        'userType': user.userType,
        'currentMode': user.currentMode,
        'isDualAccount': user.isDualAccount,
      });

      // ✅ NUEVO: Verificar si necesita completar perfil ANTES de navegar a home
      if (authProvider.needsProfileCompletion()) {
        // Determinar método de login basado en proveedores vinculados
        String loginMethod = 'email';
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          for (final provider in firebaseUser.providerData) {
            if (provider.providerId == 'google.com') {
              loginMethod = 'google';
              break;
            } else if (provider.providerId == 'facebook.com') {
              loginMethod = 'facebook';
              break;
            } else if (provider.providerId == 'apple.com') {
              loginMethod = 'apple';
              break;
            }
          }
        }

        AppLogger.navigation('ModernSplashScreen', '/auth/complete-profile', {
          'reason': 'Perfil incompleto - falta teléfono o contraseña',
          'loginMethod': loginMethod,
        });
        Navigator.pushReplacementNamed(
          context,
          '/auth/complete-profile',
          arguments: {'loginMethod': loginMethod},
        );
        return;
      }

      // Determinar ruta según tipo y modo
      String route;

      if (user.isAdmin) {
        // Admin siempre va al dashboard
        route = '/admin/dashboard';
        AppLogger.navigation('ModernSplashScreen', route, {'reason': 'Usuario admin'});
      } else {
        // Usuario dual o single: usar currentMode o activeMode
        final mode = user.activeMode; // Usa currentMode si existe, sino userType

        if (mode == 'driver') {
          // Verificar si el conductor tiene documentos aprobados
          if (user.documentVerified) {
            route = '/driver/home';
            AppLogger.navigation('ModernSplashScreen', route, {
              'reason': 'Conductor aprobado',
              'isDual': user.isDualAccount,
            });
          } else {
            // Conductor sin documentos aprobados
            // Verificar si ya envió documentos (pending_approval) o es nuevo
            final driverStatus = user.driverStatus ?? 'pending_documents';

            // ✅ FIX BUG ROL: Sincronizar currentMode con la pantalla real
            // Si el usuario está en modo 'driver' pero NO tiene documentos verificados,
            // actualizar currentMode a 'passenger' para evitar inconsistencia visual
            if (user.currentMode == 'driver') {
              AppLogger.info('🔄 Sincronizando currentMode a passenger (documentos no verificados)');
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id)
                    .update({'currentMode': 'passenger'});
                // Refrescar datos del usuario en memoria
                await authProvider.refreshUserData();
              } catch (e) {
                AppLogger.warning('Error sincronizando currentMode: $e');
              }
              // ✅ FIX: Verificar mounted después de operaciones async
              if (!mounted) return;
            }

            if (driverStatus == 'pending_approval') {
              // Ya envió documentos, puede usar como pasajero mientras espera
              route = '/passenger/home';
              AppLogger.navigation('ModernSplashScreen', route, {
                'reason': 'Conductor esperando aprobación - usando como pasajero',
                'driverStatus': driverStatus,
              });
            } else {
              // Conductor nuevo, debe subir documentos
              route = '/upgrade-to-driver';
              AppLogger.navigation('ModernSplashScreen', route, {
                'reason': 'Conductor nuevo - debe subir documentos',
                'driverStatus': driverStatus,
              });
            }
          }
        } else {
          // Default: modo pasajero (passenger o cualquier otro)
          route = '/passenger/home';
          AppLogger.navigation('ModernSplashScreen', route, {
            'reason': 'Usuario en modo pasajero',
            'isDual': user.isDualAccount,
          });
        }
      }

      Navigator.pushReplacementNamed(context, route);
    } else {
      // Sin autenticación → Login
      AppLogger.navigation('ModernSplashScreen', '/login', {'reason': 'Sin autenticación'});
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _rippleController.dispose();
    _carController.dispose();
    super.dispose();
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
              ModernTheme.primaryOrange,
              ModernTheme.primaryBlue,
              ModernTheme.darkBlue,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Patrón de fondo animado
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final delay = index * 0.3;
                  final animValue = (_rippleAnimation.value - delay).clamp(0.0, 1.0);
                  return Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 2 * animValue,
                      height: MediaQuery.of(context).size.width * 2 * animValue,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2 * (1 - animValue)),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            
            // Carros animados en el fondo
            AnimatedBuilder(
              animation: _carAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 50,
                  left: MediaQuery.of(context).size.width * _carAnimation.value,
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(
                      Icons.directions_car,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                );
              },
            ),

            AnimatedBuilder(
              animation: _carAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 100,
                  right: MediaQuery.of(context).size.width * _carAnimation.value,
                  child: Opacity(
                    opacity: 0.3,
                    child: Transform.flip(
                      flipX: true,
                      child: Icon(
                        Icons.directions_car,
                        size: 30,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Contenido principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animado
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoScaleAnimation, _logoRotateAnimation]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotateAnimation.value,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Logo real de Oasis Taxi
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Image.asset(
                                    'assets/images/logo_oasis_taxi.png',
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback al ícono si la imagen no carga
                                      return const Icon(
                                        Icons.local_taxi,
                                        size: 80,
                                        color: ModernTheme.primaryOrange,
                                      );
                                    },
                                  ),
                                ),
                                // Efecto de brillo
                                Positioned(
                                  top: 30,
                                  right: 30,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.surface,
                                          blurRadius: 10,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),

                  // Texto animado
                  AnimatedBuilder(
                    animation: Listenable.merge([_textFadeAnimation, _textSlideAnimation]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.oasisTaxi,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                      offset: const Offset(2, 2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.tagline,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 80),
                  
                  // Indicador de carga
                  AnimatedBuilder(
                    animation: _textFadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              AppLocalizations.of(context)!.preparingExperience,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Versión en la parte inferior
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textFadeAnimation.value,
                    child: Text(
                      AppLocalizations.of(context)!.appVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}