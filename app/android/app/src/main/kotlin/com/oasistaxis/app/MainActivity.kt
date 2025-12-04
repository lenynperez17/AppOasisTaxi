package com.oasistaxis.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // ✅ ANDROID 15: Habilitar Edge-to-Edge para compatibilidad con Android 15+
        // Esto soluciona los warnings de Play Console sobre APIs obsoletas
        WindowCompat.setDecorFitsSystemWindows(window, false)

        super.onCreate(savedInstanceState)
    }
}
