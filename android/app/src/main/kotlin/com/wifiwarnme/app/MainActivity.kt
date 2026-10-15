package com.wifiwarnme.app

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "wifiwarnme/monitor"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(MonitorService.snapshot(this))
                "start", "configure" -> {
                    val intent = Intent(this, MonitorService::class.java).apply {
                        action = MonitorService.START
                        putExtra("interval", call.argument<Int>("interval") ?: 2)
                        putExtra("maxLatency", call.argument<Int>("maxLatency") ?: 300)
                    }
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
                    }
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, MonitorService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
