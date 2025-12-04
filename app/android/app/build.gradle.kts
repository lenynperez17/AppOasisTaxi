import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ==================== CARGA DE CREDENCIALES DEL KEYSTORE DE PRODUCCIÓN ====================
// Cargar propiedades desde key.properties (contiene credenciales del keystore)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.oasistaxis.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ==================== CONFIGURACIÓN JAVA ====================
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // Suprimir warnings de Java en dependencias externas
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
    }

    defaultConfig {
        // ApplicationID para OasisTaxi app (debe coincidir con Firebase Console)
        applicationId = "com.oasistaxis.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Forzar Java 11 para evitar warnings de Java 8 obsoleto
        javaCompileOptions {
            annotationProcessorOptions {
                arguments["dagger.gradle.incremental"] = "true"
            }
        }
    }

    // ==================== CONFIGURACIÓN DE FIRMA DIGITAL (SIGNING) ====================
    signingConfigs {
        // Configuración de signing para RELEASE (producción)
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ✅ Usar keystore de PRODUCCIÓN para builds release
            // Este keystore tiene las SHA fingerprints registradas en Firebase Console:
            // SHA-1: B5:5F:33:AC:9F:23:93:B5:C8:4D:BC:F1:6A:80:E0:BD:50:E7:2F:D2
            // SHA-256: 8C:C2:57:66:02:85:04:6B:64:24:28:13:FC:8B:C1:41:00:DB:80:81:BE:BE:F8:22:C8:20:42:FA:80:B8:36:32
            signingConfig = signingConfigs.getByName("release")

            // Optimizaciones para producción
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }

        debug {
            // Debug sigue usando el keystore de debug por defecto
            // ⚠️ COMENTADO: applicationIdSuffix causa error con Firebase google-services.json
            // que solo tiene configurado "com.oasistaxis.app" sin el sufijo ".debug"
            // applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring - Versión más reciente 2025
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
