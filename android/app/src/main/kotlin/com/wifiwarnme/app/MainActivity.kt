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
    private var wifiPermissionResult: MethodChannel.Result? = null
    // Tab requested by a notification action, handed to Flutter once on the next status call.
    private var pendingTab: Int? = null

    private fun captureTab(intent: Intent?) {
        intent?.getIntExtra("tab", -1)?.takeIf { it >= 0 }?.let { pendingTab = it }
        intent?.removeExtra("tab")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureTab(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureTab(intent)
        val shouldResume = getSharedPreferences("wifiwarnme_native", MODE_PRIVATE)
            .getBoolean("enabled", false)
        if (shouldResume && !MonitorService.active) {
            val service = Intent(this, MonitorService::class.java).apply {
                action = MonitorService.START
            }
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(service) else startService(service)
        }
    }

    override fun onResume() {
        super.onResume()
        // A service started in the background has no location type (Android 14+); renew it now
        // that the app is visible so the Wi-Fi name can be read again.
        if (MonitorService.active) {
            try {
                startService(Intent(this, MonitorService::class.java).setAction(MonitorService.FOREGROUND))
            } catch (_: RuntimeException) {
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            wifiPermissionResult?.success(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED)
            wifiPermissionResult = null
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val known = call.argument<Number>("knownCheckedAt")?.toLong()
                    val snapshot = MonitorService.snapshot(this, known).toMutableMap()
                    pendingTab?.let { snapshot["launchTab"] = it }
                    pendingTab = null
                    result.success(snapshot)
                }
                "requestWifiName" -> {
                    if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (wifiPermissionResult != null) {
                        result.error("permission_pending", NativeLocale.localized(this).getString(R.string.error_permission_pending), null)
                    } else {
                        wifiPermissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 101)
                    }
                }
                "probe" -> {
                    val intent = Intent(this, MonitorService::class.java).apply {
                        action = MonitorService.START
                        putExtra("interval", call.argument<Int>("interval") ?: 2)
                        putExtra("maxLatency", call.argument<Int>("maxLatency") ?: 300)
                        putExtra("serverId", call.argument<String>("serverId") ?: "cloudflare")
                        putExtra("locationId", call.argument<String>("locationId") ?: "near")
                        putExtra("notificationMode", call.argument<String>("notificationMode") ?: "changes")
                        call.argument<String>("language")?.let { putExtra("language", it) }
                        putExtra("oneShot", true)
                    }
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    result.success(null)
                }
                "start", "configure" -> {
                    val intent = Intent(this, MonitorService::class.java).apply {
                        action = MonitorService.START
                        putExtra("interval", call.argument<Int>("interval") ?: 2)
                        putExtra("maxLatency", call.argument<Int>("maxLatency") ?: 300)
                        putExtra("serverId", call.argument<String>("serverId") ?: "cloudflare")
                        putExtra("locationId", call.argument<String>("locationId") ?: "near")
                        putExtra("notificationMode", call.argument<String>("notificationMode") ?: "changes")
                        call.argument<String>("language")?.let { putExtra("language", it) }
                        putExtra("resetAlertSession", call.method == "start")
                    }
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
                    }
                    result.success(null)
                }
                // Effective app language ('pt'|'es'|'en'); returns the language now in use.
                "setLanguage" -> {
                    if (NativeLocale.setLanguage(this, call.argument<String>("language"))) {
                        if (MonitorService.active) {
                            startService(Intent(this, MonitorService::class.java).setAction(MonitorService.REFRESH))
                        }
                        MonitorWidgets.update(this)
                    }
                    result.success(NativeLocale.language(this))
                }
                "checkNow" -> {
                    if (MonitorService.active) {
                        startService(Intent(this, MonitorService::class.java).setAction(MonitorService.CHECK_NOW))
                    }
                    result.success(MonitorService.active)
                }
                "stop" -> {
                    stopService(Intent(this, MonitorService::class.java))
                    getSharedPreferences("wifiwarnme_native", MODE_PRIVATE).edit()
                        .putBoolean("enabled", false)
                        .putLong("nextCheckAt", 0L)
                        .putString("status", NativeLocale.localized(this).getString(R.string.status_monitoring_off))
                        .apply()
                    result.success(null)
                }
                "scanNetwork", "scanProgress", "deviceHistory" -> NetworkScanner.handle(this, call, result)
                else -> result.notImplemented()
            }
        }
    }
}
