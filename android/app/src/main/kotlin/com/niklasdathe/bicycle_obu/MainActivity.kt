package com.niklasdathe.bicycle_obu

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "org.bicycleobu/backgroundRide"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, RideForegroundService::class.java)
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "BACKGROUND_START_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                "stop" -> {
                    try {
                        stopService(Intent(this, RideForegroundService::class.java))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "BACKGROUND_STOP_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                "capability" -> result.success("foreground_service")
                else -> result.notImplemented()
            }
        }
    }
}
