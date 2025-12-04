# 🚀 Guía de Configuración Rápida - Oasis Taxi

## ⚡ Configuración en 3 Pasos (5 minutos)

### 1️⃣ Configurar Google Maps API Key

```bash
# 1. Copia el archivo de ejemplo
cp .env.example .env

# 2. Edita el archivo .env con tu editor favorito
# Por ejemplo con notepad en Windows:
notepad .env

# 3. Reemplaza las X con tu API Key real:
# GOOGLE_MAPS_API_KEY=AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns
```

### 2️⃣ Instalar Dependencias

```bash
flutter pub get
```

### 3️⃣ Ejecutar la App

```bash
# ¡Así de simple! Sin parámetros adicionales
flutter run
```

---

## 📱 ¿Cómo Obtener una Google Maps API Key?

### Paso 1: Crear el Proyecto en Google Cloud

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Asegúrate de que la facturación esté habilitada (Google da $200 gratis al mes)

### Paso 2: Habilitar las APIs Necesarias

Habilita estas APIs en tu proyecto:
- ✅ Maps SDK for Android
- ✅ Places API
- ✅ Directions API
- ✅ Geocoding API

### Paso 3: Crear la API Key

1. Ve a **Credenciales** → **Crear credenciales** → **Clave de API**
2. Se creará tu API Key
3. Copia la key (ejemplo: `AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns`)

### Paso 4: Configurar Restricciones de Seguridad

⚠️ **MUY IMPORTANTE para evitar costos inesperados:**

#### Para desarrollo (Debug):

1. Obtén tu SHA-1 del keystore de debug:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

2. En Google Cloud Console → Tu API Key → Restricciones de aplicación:
   - Selecciona: **Aplicaciones Android**
   - Nombre del paquete: `com.oasistaxis.app`
   - Huella digital SHA-1: [Pega el SHA-1 que obtuviste]

#### Para producción (Release):

Usa el SHA-1 de tu keystore de release (el que usas para firmar el APK final).

---

## 🏗️ Comandos de Build

### Desarrollo Local

```bash
# Ejecutar en modo debug
flutter run

# Ejecutar en dispositivo específico
flutter run -d <device-id>

# Ver dispositivos disponibles
flutter devices
```

### Build para Producción

```bash
# APK (archivo directo para instalar)
flutter build apk --release

# App Bundle (recomendado para Google Play)
flutter build appbundle --release

# Los archivos se generan en:
# - APK: build/app/outputs/flutter-apk/app-release.apk
# - Bundle: build/app/outputs/bundle/release/app-release.aab
```

---

## 🔒 Seguridad de las Credenciales

### ✅ Lo que está seguro:

- El archivo `.env` **NUNCA** se sube a git (está en `.gitignore`)
- Tus API Keys solo están en tu computadora
- Cada desarrollador tiene su propio archivo `.env`

### ⚠️ NUNCA hagas esto:

- ❌ NO commitees el archivo `.env` a git
- ❌ NO compartas tu API Key públicamente
- ❌ NO uses API Keys sin restricciones en producción

### 📋 Checklist de Seguridad:

- ✅ API Key tiene restricciones de aplicación configuradas
- ✅ API Key tiene restricciones de API (solo las APIs necesarias)
- ✅ Monitoreo de uso habilitado en Google Cloud Console
- ✅ Alertas de presupuesto configuradas

---

## 🆘 Problemas Comunes

### Error: "Google Maps API Key no configurada"

**Solución:**
1. Verifica que el archivo `.env` existe en la carpeta `app/`
2. Verifica que tiene la variable `GOOGLE_MAPS_API_KEY=tu_key_aqui`
3. Ejecuta `flutter pub get` para recargar
4. Vuelve a ejecutar la app

### El mapa no se ve o sale en gris

**Posibles causas:**
1. **API Key incorrecta** → Verifica que copiaste bien la key
2. **APIs no habilitadas** → Habilita todas las APIs mencionadas arriba
3. **Restricciones mal configuradas** → Verifica el SHA-1 en Google Cloud Console
4. **Cuota excedida** → Revisa el uso en Google Cloud Console

### Error al compilar después de agregar .env

**Solución:**
```bash
# Limpia y reconstruye
flutter clean
flutter pub get
flutter run
```

---

## 📚 Recursos Útiles

- [Documentación de Google Maps Platform](https://developers.google.com/maps/documentation)
- [Mejores Prácticas de Seguridad](https://developers.google.com/maps/api-security-best-practices)
- [Precios de Google Maps](https://mapsplatform.google.com/pricing/)
- [Flutter Dotenv Docs](https://pub.dev/packages/flutter_dotenv)

---

## 🤝 Soporte

Si tienes problemas:
1. Revisa primero esta guía
2. Verifica los logs de la aplicación
3. Revisa el uso de la API en Google Cloud Console

---

**¡Listo! Ya puedes desarrollar sin preocuparte por las API Keys.** 🎉
