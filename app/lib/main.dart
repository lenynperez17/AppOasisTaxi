// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'firebase_messaging_handler.dart';

// Core
import 'core/theme/modern_theme.dart';

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
import 'models/trip_model.dart';

// Screens
import 'screens/auth/modern_splash_screen.dart';
import 'screens/auth/modern_login_screen.dart';
import 'screens/auth/modern_register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/phone_verification_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppLogger.separator('INICIANDO OASIS TAXI APP');
  AppLogger.info('Iniciando aplicación Oasis Taxi...');
  
  try {
    // Configurar orientación
    AppLogger.debug('Configurando orientación de pantalla');
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Configurar la barra de estado
    AppLogger.debug('Configurando barra de estado');
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Inicializar Firebase
    AppLogger.info('Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('✅ Firebase inicializado correctamente');
    
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
    
    AppLogger.separator('APP LISTA PARA PRODUCCIÓN');
    runApp(OasisTaxiApp());
    
  } catch (error, stackTrace) {
    AppLogger.error('Error crítico al inicializar la app', error, stackTrace);
    // Intentar iniciar la app incluso con errores
    runApp(OasisTaxiApp());
  }
}

class OasisTaxiApp extends StatelessWidget {
  const OasisTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => PriceNegotiationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      // ✅ DISMISS GLOBAL DEL TECLADO - Funciona en TODA la aplicación
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: () {
            // Cerrar teclado al hacer tap en cualquier parte de la app
            FocusManager.instance.primaryFocus?.unfocus();
          },
          behavior: HitTestBehavior.translucent, // No bloquear otros gestos
          child: MaterialApp(
            title: 'Oasis Taxi',
            debugShowCheckedModeBanner: false,
        
        // Configurar localizaciones
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        locale: Locale('es', 'ES'),
      
        // Tema moderno con gradientes y animaciones
        theme: ModernTheme.lightTheme,
        darkTheme: ModernTheme.darkTheme,
        themeMode: ThemeMode.light,
        
        // Tema antiguo (comentado para referencia)
        /*theme: ThemeData(
          primarySwatch: MaterialColor(0xFF00C800, {
            50: Color(0xFFE0F7E0),
            100: Color(0xFFB3E5B3),
            200: Color(0xFF80D280),
            300: Color(0xFF4DBF4D),
            400: Color(0xFF26B026),
            500: Color(0xFF00C800),
            600: Color(0xFF00A100),
            700: Color(0xFF008F00),
            800: Color(0xFF007D00),
            900: Color(0xFF006600),
          }),
          primaryColor: AppColors.oasisGreen,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.oasisGreen,
            primary: AppColors.oasisGreen,
            secondary: AppColors.oasisBlack,
            surface: AppColors.oasisWhite,
            onPrimary: AppColors.oasisWhite,
            onSecondary: AppColors.oasisWhite,
            onSurface: AppColors.oasisBlack,
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.backgroundLight,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.oasisGreen, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.oasisGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.oasisGreen,
            foregroundColor: AppColors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(
              color: AppColors.white,
            ),
          ),
        ),*/
        
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

          // Rutas de Pasajero
          '/passenger/home': (context) => ModernPassengerHomeScreen(),
          '/passenger/trip-history': (context) => TripHistoryScreen(),
          '/passenger/ratings-history': (context) => RatingsHistoryScreen(),
          '/passenger/payment-methods': (context) => PaymentMethodsScreen(),
          // '/passenger/payment-method-selection': Requiere argumentos - usar Navigator.push
          // '/passenger/emergency': Requiere argumentos - usar Navigator.push
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
          // '/driver/earnings-withdrawal': Requiere driverId - usar Navigator.push
          '/driver/negotiations': (context) => DriverNegotiationsScreen(),
          '/driver/documents': (context) => DocumentsScreen(),
          '/driver/profile': (context) => DriverProfileScreen(),
          '/driver/verification': (context) => DriverVerificationScreen(
            trip: ModalRoute.of(context)!.settings.arguments as TripModel,
          ),
          
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
          // '/shared/live-tracking-map': Requiere rideId, userType y userId - usar Navigator.push
          '/shared/emergency-details': (context) => EmergencyDetailsScreen(
            emergencyId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
          ),
          '/map-picker': (context) => MapPickerScreen(),
        },
          ), // Cierre de MaterialApp
        ), // Cierre de GestureDetector
      ), // Cierre de Builder
    ); // Cierre de MultiProvider
  }
}