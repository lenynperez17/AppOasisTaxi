package com.oasistaxis.app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // ✅ FACEBOOK SDK: Inicializar ANTES de super.onCreate()
        // Los plugins de Flutter se registran DURANTE super.onCreate(), por lo que
        // facebook_flutter_auth necesita que el SDK ya esté inicializado en ese momento
        try {
            FacebookSdk.sdkInitialize(applicationContext)
            AppEventsLogger.activateApp(application)
            println("✅ Facebook SDK initialized successfully")
        } catch (e: Exception) {
            // Log del error pero no fallar la app si Facebook no está configurado
            println("⚠️ Facebook SDK initialization failed: ${e.message}")
        }

        // Ahora sí llamamos a super.onCreate(), que registrará los plugins de Flutter
        super.onCreate(savedInstanceState)
    }
}
