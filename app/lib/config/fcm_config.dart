/// Configuración de Firebase Cloud Messaging V1 API
///
/// ⚠️ IMPORTANTE: Cómo obtener el Service Account JSON:
/// 1. Ve a Firebase Console: https://console.firebase.google.com/u/5/project/app-oasis-taxi/settings/serviceaccounts/adminsdk
/// 2. En la pestaña "Cuentas de servicio", haz clic en "Generar nueva clave privada"
/// 3. Se descargará un archivo JSON (app-oasis-taxi-firebase-adminsdk-xxxxx.json)
/// 4. Guárdalo en: assets/service-account.json
/// 5. ⚠️ NUNCA subas este archivo a Git - ya está en .gitignore
///
/// DIFERENCIAS FCM V1 vs Legacy:
/// - V1 usa OAuth 2.0 con Service Account (más seguro)
/// - Legacy usaba Server Key (obsoleta desde junio 2023)
/// - V1 tiene mejor estructura de payload
/// - V1 es la única opción soportada actualmente
class FCMConfig {
  // Project ID de Firebase (visible en Firebase Console)
  static const String projectId = 'app-oasis-taxi';

  // Ruta al archivo Service Account JSON
  // ⚠️ Este archivo debe estar en .gitignore
  static const String serviceAccountPath = 'assets/service-account.json';

  // URL del endpoint de FCM V1 API
  static String get fcmEndpoint =>
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

  // Scopes de OAuth2 necesarios para FCM
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  // Headers base para las peticiones FCM V1 (se agregará el Bearer token dinámicamente)
  static Map<String, String> getHeaders(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  // Validar si la configuración está lista
  // En producción, validar que el archivo service-account.json existe
  static bool get isConfigured => projectId.isNotEmpty;
}
