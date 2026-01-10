// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, unused_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🔐 NUEVO: Cargar variables de entorno desde .env
import 'generated/l10n/app_localizations.dart'; // ✅ NUEVO: Localizaciones generadas
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // ✅ NUEVO: Analytics
import 'package:firebase_app_check/firebase_app_check.dart'; // ✅ NUEVO: App Check con Play Integrity
import 'firebase_options.dart';
import 'firebase_messaging_handler.dart';

// Core
import 'core/theme/modern_theme.dart';
import 'core/widgets/notification_handler_widget.dart'; // ✅ NUEVO: Handler de clicks en notificaciones

// Services
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

// Utils
import 'utils/logger.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/price_negotiation_provider.dart';
import 'providers/locale_provider.dart'; // ✅ NUEVO: Provider para cambio de idioma
import 'providers/preferences_provider.dart'; // ✅ NUEVO: Provider para Dark Mode y preferencias
import 'providers/wallet_provider.dart'; // ✅ FIX: Provider para créditos de servicio
import 'providers/document_provider.dart'; // ✅ FIX: Provider para documentos de conductor
import 'models/trip_model.dart';

// Screens
import 'screens/auth/modern_splash_screen.dart';
import 'screens/auth/modern_login_screen.dart';
import 'screens/auth/modern_register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/phone_verification_screen.dart';
import 'screens/auth/complete_profile_screen.dart'; // ✅ NUEVO: Pantalla obligatoria para login social
import 'screens/passenger/modern_passenger_home.dart';
import 'screens/passenger/trip_history_screen.dart';
import 'screens/passenger/ratings_history_screen.dart';
import 'screens/passenger/payment_methods_screen.dart';
import 'screens/passenger/favorites_screen.dart';
import 'screens/passenger/promotions_screen.dart';
import 'screens/passenger/profile_screen.dart';
import 'screens/passenger/profile_edit_screen.dart';
import 'screens/passenger/passenger_negotiations_screen.dart';
// Screens with complex constructors temporarily disabled
import 'screens/driver/modern_driver_home.dart';
import 'screens/driver/wallet_screen.dart';
import 'screens/driver/navigation_screen.dart';
import 'screens/driver/communication_screen.dart';
import 'screens/driver/metrics_screen.dart';
import 'screens/driver/vehicle_management_screen.dart';
import 'screens/driver/transactions_history_screen.dart';
import 'screens/driver/earnings_details_screen.dart';
// import 'screens/driver/earnings_withdrawal_screen.dart'; // No usado - ruta comentada
import 'screens/driver/documents_screen.dart';
import 'screens/driver/driver_profile_screen.dart';
import 'screens/driver/driver_negotiations_screen.dart';
import 'screens/driver/recharge_credits_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/users_management_screen.dart';
import 'screens/admin/drivers_management_screen.dart';
import 'screens/admin/financial_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/admin/settings_admin_screen.dart';
import 'screens/shared/help_center_screen.dart';
import 'screens/shared/settings_screen.dart';
import 'screens/shared/about_screen.dart';
import 'screens/shared/support_screen.dart';
import 'screens/shared/notifications_screen.dart';
// import 'screens/shared/live_tracking_map_screen.dart'; // No usado - ruta comentada
import 'screens/shared/emergency_details_screen.dart';
import 'screens/passenger/trip_verification_code_screen.dart';
import 'screens/driver/driver_verification_screen.dart';
import 'screens/shared/trip_details_screen.dart';
import 'screens/shared/trip_tracking_screen.dart';
import 'screens/shared/chat_screen.dart';
import 'screens/shared/map_picker_screen.dart';
import 'screens/shared/upgrade_to_driver_screen.dart';
import 'screens/shared/change_phone_number_screen.dart';
import 'screens/driver/active_trip_screen.dart'; // Pantalla de viaje activo para conductor
import 'screens/passenger/trip_completed_screen.dart'; // Pantalla de viaje completado para pasajero

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.separator('INICIANDO OASIS TAXI APP');
  AppLogger.info('Iniciando aplicación Oasis Taxi...');

  try {
    // 🔐 Cargar variables de entorno desde archivo .env
    AppLogger.debug('Cargando variables de entorno desde .env');
    await dotenv.load(fileName: '.env');
    AppLogger.info('✅ Variables de entorno cargadas correctamente');

    // Configurar orientación
    AppLogger.debug('Configurando orientación de pantalla');
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // ✅ ANDROID 15: Configurar la barra de estado para Edge-to-Edge
    AppLogger.debug('Configurando barra de estado para Edge-to-Edge');
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // ✅ Transparente para edge-to-edge
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent, // ✅ Navegación también transparente
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Inicializar Firebase
    AppLogger.info('Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('✅ Firebase inicializado correctamente');

    // ✅ NUEVO: Inicializar Firebase Analytics
    AppLogger.info('Inicializando Firebase Analytics...');
    final analytics = FirebaseAnalytics.instance;
    await analytics.logAppOpen(); // Log de apertura de app
    AppLogger.info('✅ Firebase Analytics inicializado');

    // ✅ DESARROLLO: Firebase App Check DESHABILITADO temporalmente
    // El App Check con Play Integrity no funciona con builds debug (no firmados)
    // Para producción, cambiar a AndroidProvider.playIntegrity
    AppLogger.info('Firebase App Check deshabilitado para desarrollo...');
    // NO activar App Check en desarrollo para evitar problemas de permisos
    // await FirebaseAppCheck.instance.activate(
    //   androidProvider: AndroidProvider.playIntegrity,
    //   webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    // );
    AppLogger.info('⚠️ Firebase App Check omitido (modo desarrollo)');

    // Inicializar servicio Firebase
    AppLogger.info('Inicializando servicios de Firebase...');
    await FirebaseService().initialize();
    AppLogger.info('✅ Servicios de Firebase iniciados');
    
    // Configurar Firebase Messaging
    AppLogger.info('Configurando Firebase Messaging...');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AppLogger.info('✅ Firebase Messaging configurado');
    
    // Inicializar servicio de notificaciones
    AppLogger.info('Inicializando servicio de notificaciones...');
    await NotificationService().initialize();
    AppLogger.info('✅ Servicio de notificaciones iniciado');

    // ✅ NUEVO: Inicializar PreferencesProvider para cargar modo oscuro y otras preferencias
    AppLogger.info('Inicializando preferencias de usuario...');
    final preferencesProvider = PreferencesProvider();
    await preferencesProvider.init();
    AppLogger.info('✅ Preferencias de usuario cargadas');

    AppLogger.separator('APP LISTA PARA PRODUCCIÓN');
    runApp(OasisTaxiApp(preferencesProvider: preferencesProvider));
    
  } catch (error, stackTrace) {
    AppLogger.error('Error crítico al inicializar la app', error, stackTrace);
    // Intentar iniciar la app incluso con errores, con provider por defecto
    final fallbackProvider = PreferencesProvider();
    runApp(OasisTaxiApp(preferencesProvider: fallbackProvider));
  }
}

class OasisTaxiApp extends StatelessWidget {
  final PreferencesProvider preferencesProvider;

  const OasisTaxiApp({super.key, required this.preferencesProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()), // ✅ NUEVO: Provider de idioma
        ChangeNotifierProvider.value(value: preferencesProvider), // ✅ MODIFICADO: Usar provider ya inicializado
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => PriceNegotiationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()), // ✅ FIX: Provider para créditos de servicio
        ChangeNotifierProvider(create: (_) => DocumentProvider()), // ✅ FIX: Provider para documentos de conductor
      ],
      // ✅ HANDLER DE NOTIFICACIONES - Procesa clicks en notificaciones
      child: NotificationHandlerWidget(
        // ✅ DISMISS GLOBAL DEL TECLADO - Funciona en TODA la aplicación
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () {
              // Cerrar teclado al hacer tap en cualquier parte de la app
              FocusManager.instance.primaryFocus?.unfocus();
            },
            behavior: HitTestBehavior.translucent, // No bloquear otros gestos
            // ✅ CORREGIDO: Usar MaterialApp directo con animación de tema
            child: _ThemedMaterialApp(),
          ),
        ),
      ),
    );
  }
}

// ✅ SOLUCIÓN DEFINITIVA: Usar Consumer para garantizar rebuild cuando cambia darkMode
class _ThemedMaterialApp extends StatelessWidget {
  const _ThemedMaterialApp();

  @override
  Widget build(BuildContext context) {
    // ✅ Usar Consumer para garantizar que el widget se reconstruya cuando cambie darkMode
    return Consumer<PreferencesProvider>(
      builder: (context, prefsProvider, child) {
        final locale = context.select<LocaleProvider, Locale>((provider) => provider.locale);
        final darkMode = prefsProvider.darkMode;
        final themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;

        // 🔍 DEBUG: Verificar rebuild
        print('🎨 _ThemedMaterialApp rebuild - darkMode: $darkMode, themeMode: $themeMode');

        return MaterialApp(
      title: 'Oasis Taxi',
      debugShowCheckedModeBanner: false,

      // Configurar localizaciones
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: locale,

      // Tema moderno con gradientes y animaciones
      theme: ModernTheme.lightTheme,
      darkTheme: ModernTheme.darkTheme,
      themeMode: themeMode,

      // Ruta inicial
      initialRoute: '/',

      // Rutas
      routes: {
        '/': (context) => ModernSplashScreen(),
        '/login': (context) => ModernLoginScreen(),
        '/register': (context) => ModernRegisterScreen(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/email-verification': (context) => EmailVerificationScreen(
          email: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/phone-verification': (context) => PhoneVerificationScreen(
          phoneNumber: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/auth/complete-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return CompleteProfileScreen(
            loginMethod: args?['loginMethod'] as String? ?? 'google',
          );
        },

        // Rutas de Pasajero
        '/passenger/home': (context) => ModernPassengerHomeScreen(),
        '/passenger/trip-history': (context) => TripHistoryScreen(),
        '/passenger/ratings-history': (context) => RatingsHistoryScreen(),
        '/passenger/payment-methods': (context) => PaymentMethodsScreen(),
        '/passenger/negotiations': (context) => PassengerNegotiationsScreen(),
        '/passenger/favorites': (context) => FavoritesScreen(),
        '/passenger/promotions': (context) => PromotionsScreen(),
        '/passenger/profile': (context) => ProfileScreen(),
        '/passenger/profile-edit': (context) => ProfileEditScreen(),
        '/passenger/trip-details': (context) => TripDetailsScreen(
          tripId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/passenger/tracking': (context) => TripTrackingScreen(
          rideId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/passenger/verification-code': (context) => TripVerificationCodeScreen(
          trip: ModalRoute.of(context)!.settings.arguments as TripModel,
        ),

        // Rutas de Conductor
        '/driver/home': (context) => ModernDriverHomeScreen(),
        '/driver/wallet': (context) => WalletScreen(),
        '/driver/navigation': (context) => NavigationScreen(),
        '/driver/communication': (context) => CommunicationScreen(),
        '/driver/metrics': (context) => MetricsScreen(),
        '/driver/vehicle-management': (context) => VehicleManagementScreen(),
        '/driver/transactions-history': (context) => TransactionsHistoryScreen(),
        '/driver/earnings-details': (context) => EarningsDetailsScreen(),
        '/driver/negotiations': (context) => DriverNegotiationsScreen(),
        '/driver/documents': (context) => DocumentsScreen(),
        '/driver/profile': (context) => DriverProfileScreen(),
        '/driver/recharge-credits': (context) => RechargeCreditsScreen(),
        '/driver/verification': (context) => DriverVerificationScreen(
          trip: ModalRoute.of(context)!.settings.arguments as TripModel,
        ),
        '/driver/active-trip': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return ActiveTripScreen(
            tripId: args?['tripId'] as String? ?? '',
          );
        },

        // Rutas de Admin
        '/admin/login': (context) => AdminLoginScreen(),
        '/admin/dashboard': (context) => AdminDashboardScreen(),
        '/admin/users-management': (context) => UsersManagementScreen(),
        '/admin/drivers-management': (context) => DriversManagementScreen(),
        '/admin/financial': (context) => FinancialScreen(),
        '/admin/analytics': (context) => AnalyticsScreen(),
        '/admin/settings': (context) => SettingsAdminScreen(),

        // Rutas Compartidas
        '/shared/chat': (context) => ChatScreen(
          rideId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
          otherUserName: 'Usuario',
          otherUserRole: 'user',
        ),
        '/shared/trip-details': (context) => TripDetailsScreen(
          tripId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/shared/trip-tracking': (context) => TripTrackingScreen(
          rideId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/shared/help-center': (context) => HelpCenterScreen(),
        '/shared/settings': (context) => SettingsScreen(),
        '/shared/about': (context) => AboutScreen(),
        '/shared/support': (context) => SupportScreen(),
        '/shared/notifications': (context) => NotificationsScreen(),
        '/shared/emergency-details': (context) => EmergencyDetailsScreen(
          emergencyId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/shared/upgrade-to-driver': (context) => UpgradeToDriverScreen(),
        '/upgrade-to-driver': (context) => UpgradeToDriverScreen(), // Alias corto
        '/map-picker': (context) => MapPickerScreen(),
        '/change-phone-number': (context) => ChangePhoneNumberScreen(
          currentPhoneNumber: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/trip-tracking': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return TripTrackingScreen(
            rideId: args?['rideId'] as String? ?? '',
          );
        },
        '/trip-completed': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return TripCompletedScreen(
            tripId: args?['tripId'] as String? ?? '',
          );
        },
      },
    );
      },  // Cierra builder del Consumer
    );    // Cierra Consumer
  }
}