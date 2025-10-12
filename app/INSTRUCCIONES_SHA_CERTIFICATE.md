# 🔐 INSTRUCCIONES: Corregir INVALID_CERT_HASH para Phone Authentication

## ⚠️ ERROR DETECTADO EN CONSOLA

```
E/FirebaseAuth: [GetAuthDomainTask] Error getting project config. Failed with INVALID_CERT_HASH 400
E/zzb: Failed to get reCAPTCHA token with error [There was an error while trying to get your package certificate hash.]
E/FirebaseAuth: [SmsRetrieverHelper] SMS verification code request failed: unknown status code: 18002 Invalid PlayIntegrity token; app not Recognized by Play Store.
```

## 🎯 PROBLEMA

El SHA-1 y SHA-256 configurados en Firebase Console **NO coinciden** con los certificados de tu keystore actual. Esto bloquea:

- ✅ Firebase Phone Authentication
- ✅ reCAPTCHA v2 y Enterprise
- ✅ Google Play Integrity API
- ✅ SafetyNet Attestation

## 📋 SOLUCIÓN PASO A PASO

### PASO 1: Generar SHA-1 y SHA-256 de tu Debug Keystore

#### Para Windows (PowerShell o CMD):

```bash
cd C:\Users\Lenyn\.android

# Generar SHA-1 y SHA-256
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### Para Linux/Mac (Terminal):

```bash
cd ~/.android

# Generar SHA-1 y SHA-256
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### Para Release Keystore (Producción):

```bash
# Reemplaza con la ruta a tu keystore de producción
keytool -list -v -keystore /ruta/a/tu/release.keystore -alias tu-alias -storepass tu-password -keypass tu-password
```

### PASO 2: Copiar los Certificados

El comando anterior te mostrará algo como:

```
Certificate fingerprints:
	 SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
	 SHA256: 11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00
```

**COPIA AMBOS** valores (SHA1 y SHA256).

### PASO 3: Actualizar Firebase Console

1. **Abre Firebase Console**: https://console.firebase.google.com/project/app-oasis-taxi/settings/general

2. **Navega a Project Settings** → **General** (primer tab)

3. **Encuentra tu app Android**:
   - Package name: `com.oasistaxis.app`
   - Busca la sección "SHA certificate fingerprints"

4. **Agrega los certificados**:
   - Clic en **"Add fingerprint"**
   - Pega el valor de **SHA-1** (primer certificado)
   - Clic en **"Add fingerprint"** nuevamente
   - Pega el valor de **SHA-256** (segundo certificado)

5. **Guarda los cambios**

### PASO 4: Descargar google-services.json Actualizado

1. En la misma página de Firebase Console, baja hasta el final
2. Clic en **"Download google-services.json"**
3. Reemplaza el archivo existente en:
   ```
   app/android/app/google-services.json
   ```

### PASO 5: Rebuild de la App

```bash
# Limpia completamente el proyecto
flutter clean
cd android
./gradlew clean
cd ..

# Reinstala dependencias
flutter pub get

# Compila y ejecuta
flutter run -d chrome
```

## 🔍 VERIFICACIÓN

Después de hacer el rebuild, verifica en la consola que **NO aparezca**:

```
❌ E/FirebaseAuth: INVALID_CERT_HASH
❌ E/zzb: Failed to get reCAPTCHA token
❌ E/FirebaseAuth: Invalid PlayIntegrity token
```

## 📌 NOTAS IMPORTANTES

### Para Desarrollo (Debug Build):

- Usa el keystore de debug ubicado en: `~/.android/debug.keystore`
- Password por defecto: `android`
- Alias por defecto: `androiddebugkey`

### Para Producción (Release Build):

- Debes generar los SHA de tu keystore de **producción**
- **NO uses el debug keystore** para builds de producción
- Guarda los SHA de producción por separado en Firebase Console

### Múltiples Máquinas de Desarrollo:

Si desarrollas en múltiples computadoras, necesitas:

1. Generar SHA de **cada keystore de debug** en cada máquina
2. Agregar **todos los SHA** a Firebase Console
3. Firebase permite múltiples certificados por app

## ⚠️ ERRORES COMUNES

### Error: "keytool: command not found"

**Solución**: Instala Java JDK y agrega `keytool` al PATH:

```bash
# Windows
set PATH=%PATH%;C:\Program Files\Java\jdk-XX\bin

# Linux/Mac
export PATH=$PATH:/usr/lib/jvm/java-XX-openjdk/bin
```

### Error: "Keystore was tampered with"

**Solución**: Verifica que estás usando la contraseña correcta (`android` para debug).

### Error: "Alias does not exist"

**Solución**: Lista todos los alias disponibles:

```bash
keytool -list -keystore debug.keystore -storepass android
```

## 📖 RECURSOS ADICIONALES

- Firebase Console: https://console.firebase.google.com/project/app-oasis-taxi/settings/general
- Documentación oficial: https://firebase.google.com/docs/android/setup#add-config-file
- Guía de Phone Auth: https://firebase.google.com/docs/auth/android/phone-auth

## ✅ CHECKLIST FINAL

- [ ] SHA-1 generado y copiado
- [ ] SHA-256 generado y copiado
- [ ] Ambos certificados agregados a Firebase Console
- [ ] google-services.json descargado y reemplazado
- [ ] flutter clean ejecutado
- [ ] ./gradlew clean ejecutado
- [ ] flutter pub get ejecutado
- [ ] App reconstruida con flutter run
- [ ] Verificado que INVALID_CERT_HASH ya no aparece en consola

---

**Fecha de creación**: 2025-01-12
**Última actualización**: 2025-01-12
**Estado**: ⚠️ ACCIÓN REQUERIDA - Usuario debe ejecutar manualmente
