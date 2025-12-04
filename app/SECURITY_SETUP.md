# 🔐 Configuración de Seguridad - Oasis Taxi App

## ⚡ Configuración Rápida (Solo 1 vez)

### 1. Configurar API Keys

```bash
# 1. Copia el archivo de ejemplo
cp .env.example .env

# 2. Edita .env y configura tu Google Maps API Key
# GOOGLE_MAPS_API_KEY=tu_api_key_aqui

# 3. ¡Listo! No necesitas recordar las keys ni pasarlas en cada comando
```

### 2. Ejecutar la App

```bash
# Simple - sin parámetros adicionales
flutter run
```

### 3. Build para Producción

```bash
# Todo funciona automáticamente
flutter build apk --release
flutter build appbundle --release
```

---

## 📋 ¿Qué Credenciales Necesito?

### ✅ Google Maps API Key (Requerida)

**Ubicación:** Archivo `.env` en la carpeta `app/`

```env
GOOGLE_MAPS_API_KEY=AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns
```

**Cómo obtenerla:**
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto o selecciona uno existente
3. Habilita las APIs: Maps SDK, Places, Directions, Geocoding
4. Crea una clave de API
5. Configura restricciones de seguridad (ver abajo)

### ✅ Firebase (Ya está configurado)

Las credenciales de Firebase ya están en:
- `android/app/google-services.json`
- `lib/firebase_options.dart`

**No necesitas configurar nada adicional.**

### ✅ OAuth (Google/Facebook) (Ya está configurado)

Los Client IDs de Google y Facebook ya están en:
- `lib/config/oauth_config.dart`

**No necesitas configurar nada adicional.**

El Facebook App Secret se configura en Firebase Console (backend), no en la app.

### ✅ MercadoPago (Ya está configurado)

Las credenciales de MercadoPago están en:
- `functions/.env` (Cloud Functions - backend)

**No necesitas configurar nada en la app.**

---

## 🛡️ Restricciones de Seguridad para Google Maps

### ⚠️ MUY IMPORTANTE

Una API Key sin restricciones puede ser usada por cualquiera y generar costos inesperados.

### Paso 1: Obtener tu SHA-1

#### Para desarrollo (Debug Keystore):

```bash
# En Linux/Mac:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# En Windows:
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copia el valor de `SHA1:` (ejemplo: `A1:B2:C3:D4:...`)

#### Para producción (Release Keystore):

```bash
keytool -list -v -keystore tu-keystore-release.jks -alias tu-alias
```

### Paso 2: Configurar Restricciones en Google Cloud

1. Ve a [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Selecciona tu API Key
3. En "Restricciones de aplicación":
   - Selecciona: **Aplicaciones Android**
   - Click en **Agregar un elemento**
   - Nombre del paquete: `com.oasistaxis.app`
   - Huella digital SHA-1: [Pega el SHA-1 que obtuviste]

4. En "Restricciones de API":
   - Selecciona: **Restringir clave**
   - Marca solo:
     - Maps SDK for Android
     - Places API
     - Directions API
     - Geocoding API

5. Click en **Guardar**

---

## 🔒 Archivos Protegidos en .gitignore

Los siguientes archivos **NUNCA** se suben a git:

```gitignore
# Variables de entorno - API Keys
.env
.env.*
!.env.example

# Keystores de firma
*.keystore
*.jks

# Credenciales de Firebase Admin
*-adminsdk-*.json
```

---

## ✅ Ventajas de Usar .env

### Antes (Solución anterior - ❌ Incómoda):

```bash
# Tenías que recordar y pasar la API Key en cada comando
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns

flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns
```

### Ahora (Solución actual - ✅ Automática):

```bash
# Configuras UNA SOLA VEZ en .env
echo "GOOGLE_MAPS_API_KEY=tu_key" > .env

# Y luego SIEMPRE funciona sin parámetros
flutter run
flutter build apk
flutter build appbundle
```

---

## 🔐 Mejores Prácticas

### ✅ Hacer:

1. ✅ Configurar restricciones en todas las API Keys
2. ✅ Usar diferentes keys para desarrollo y producción
3. ✅ Monitorear el uso en Google Cloud Console
4. ✅ Configurar alertas de presupuesto
5. ✅ Rotar las keys cada 6 meses
6. ✅ Mantener el archivo `.env` en tu máquina local únicamente

### ❌ NO Hacer:

1. ❌ Commitear el archivo `.env` a git
2. ❌ Compartir tus API Keys públicamente
3. ❌ Usar API Keys sin restricciones en producción
4. ❌ Usar la misma key para desarrollo y producción
5. ❌ Ignorar las alertas de uso de Google Cloud

---

## 🆘 En Caso de Exposición de Credenciales

Si una API Key se expone públicamente:

### 🚨 Acción Inmediata:

1. **Ve a Google Cloud Console**
2. **Revoca la key comprometida** inmediatamente
3. **Genera una nueva API Key**
4. **Configura restricciones** en la nueva key
5. **Actualiza tu archivo `.env` local** con la nueva key
6. **Ejecuta `flutter pub get`**
7. **Reinicia la app**

### 📊 Verificación:

1. Revisa los logs de uso de la key comprometida
2. Verifica si hubo uso no autorizado
3. Revisa los costos en Google Cloud Billing
4. Activa alertas de presupuesto

---

## 📚 Referencias

- [Google Maps - Mejores Prácticas de Seguridad](https://developers.google.com/maps/api-security-best-practices)
- [Flutter Dotenv - Documentación](https://pub.dev/packages/flutter_dotenv)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Firebase Console](https://console.firebase.google.com/)

---

**¡Tus credenciales están seguras y no tienes que recordarlas!** 🎉

**Última actualización:** 2025-01-20
