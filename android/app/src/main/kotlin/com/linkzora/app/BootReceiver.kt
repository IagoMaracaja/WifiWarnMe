package com.linkzora.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Resumes continuous monitoring after the phone restarts or the app is updated, when the user
 * had it on. Both broadcasts are exempt from the background foreground-service start limits.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val enabled = context.getSharedPreferences("wifiwarnme_native", Context.MODE_PRIVATE)
            .getBoolean("enabled", false)
        if (!enabled || MonitorService.active) return
        val service = Intent(context, MonitorService::class.java).setAction(MonitorService.START)
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
        } catch (e: RuntimeException) {
            // Never crash at boot; monitoring resumes the next time the app is opened.
            Log.w("LinkzoraBoot", "could not resume monitoring", e)
        }
    }
}
