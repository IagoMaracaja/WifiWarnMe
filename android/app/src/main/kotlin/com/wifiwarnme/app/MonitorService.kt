package com.wifiwarnme.app

import android.app.*
import android.content.*
import android.net.*
import android.net.wifi.WifiManager
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import androidx.core.graphics.drawable.toBitmap
import android.graphics.Typeface
import android.Manifest
import android.location.LocationManager
import android.os.*
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import androidx.core.app.NotificationCompat
import java.net.InetAddress
import java.net.InetSocketAddress
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors
import org.json.JSONObject

private data class TestServer(val id: String, val name: String, val address: String)

private val TEST_SERVERS = listOf(
    TestServer("cloudflare", "Cloudflare", "1.1.1.1"),
    TestServer("google", "Google", "8.8.8.8"),
    TestServer("quad9", "Quad9", "9.9.9.9")
)

private fun testServer(id: String?) =
    TEST_SERVERS.firstOrNull { it.id == id } ?: TEST_SERVERS.first()

private data class TestLocation(
    val id: String,
    val name: String,
    val address: String?
)

private val TEST_LOCATIONS = listOf(
    TestLocation("near", "Próximo", null),
    TestLocation("sao_paulo", "São Paulo", "s3.sa-east-1.amazonaws.com"),
    TestLocation("united_states", "Estados Unidos", "s3.us-east-1.amazonaws.com"),
    TestLocation("europe", "Europa", "s3.eu-west-1.amazonaws.com")
)

private fun testLocation(id: String?) =
    TEST_LOCATIONS.firstOrNull { it.id == id } ?: TEST_LOCATIONS.first()

private data class WifiDetails(
    val name: String,
    val signalLevel: Int = -1,
    val rssi: Int = 0,
    val linkSpeed: Int = 0
)

/** Everything one check produced, used for the status notification and alerts. */
private data class CheckReport(
    val state: String,
    val networkName: String,
    val transportType: String,
    val targetName: String,
    val result: LatencyResult,
    val diagnosis: DiagnosisCode,
    val signalLevel: Int,
    val checkedAt: Long
)

class MonitorService : Service() {
    companion object {
        const val START = "wifiwarnme.START"
        const val CHECK_NOW = "linkzora.CHECK_NOW"
        const val PAUSE = "linkzora.PAUSE"
        /** Re-renders the notification (and channel names) after the app language changed. */
        const val REFRESH = "linkzora.REFRESH"
        private const val TICK = "linkzora.TICK"
        @Volatile
        var active = false
            private set
        // Channel settings are immutable once created, so Live Update tuning needs a new id.
        private const val CHANNEL = "linkzora.live"
        private const val LEGACY_CHANNEL = "wifiwarnme.monitor"
        private const val ALERT_CHANNEL = "wifiwarnme.alerts"
        private const val ID = 42
        private const val ALERT_ID = 43
        private const val PREFS = "wifiwarnme_native"
        private const val RIBBON_HISTORY = 200

        @Volatile
        private var sharedStore: JsonLinesStore? = null

        @Volatile
        private var sharedEvents: EventLog? = null

        internal fun store(context: Context): JsonLinesStore =
            sharedStore ?: synchronized(this) {
                sharedStore ?: JsonLinesStore.measurements(context.applicationContext.filesDir).also {
                    migrateLegacyHistory(context, it)
                    sharedStore = it
                }
            }

        /** Events moved from a 50-line SharedPreferences string to files/events.jsonl (30 days, 2000 max). */
        private fun events(context: Context): EventLog =
            sharedEvents ?: synchronized(this) {
                sharedEvents ?: EventLog(JsonLinesStore.events(context.applicationContext.filesDir)).also { log ->
                    val prefs = context.getSharedPreferences(PREFS, MODE_PRIVATE)
                    prefs.getString("events", null)?.let { raw ->
                        log.importLegacy(raw, System.currentTimeMillis())
                        prefs.edit().remove("events").apply()
                    }
                    sharedEvents = log
                }
            }

        /** Older versions kept the history as a JSON array inside SharedPreferences. */
        private fun migrateLegacyHistory(context: Context, store: JsonLinesStore) {
            val prefs = context.getSharedPreferences(PREFS, MODE_PRIVATE)
            val raw = prefs.getString("measurements", null) ?: return
            try {
                val array = org.json.JSONArray(raw)
                for (index in 0 until array.length()) store.append(array.getJSONObject(index))
            } catch (_: Exception) {
            }
            prefs.edit().remove("measurements").apply()
        }

        private fun measurementHistory(context: Context): List<Map<String, Any>> =
            store(context).read().map { item ->
                mapOf(
                    "timestamp" to item.optLong("timestamp"),
                    "state" to item.optString("state", "offline"),
                    "latency" to item.optLong("latency", -1L),
                    "jitter" to item.optLong("jitter", -1L),
                    "failureRate" to item.optInt("failureRate", 100),
                    "transportType" to item.optString("transportType", "none"),
                    "targetName" to item.optString("targetName", ""),
                    "diagnosis" to item.optString("diagnosis", ""),
                    // Language-neutral cause for Flutter; older entries only had the Portuguese text.
                    "diagnosisCode" to (item.optString("diagnosisCode", "").takeIf { it.isNotEmpty() }
                        ?: DiagnosisCode.fromLegacyText(item.optString("diagnosis", ""))?.code ?: ""),
                    "signalLevel" to item.optInt("signalLevel", -1)
                )
            }

        /**
         * Current state for the Flutter UI. The history and events only change after a check,
         * so they are sent only when the caller's [knownCheckedAt] is out of date.
         */
        fun snapshot(context: Context, knownCheckedAt: Long? = null): Map<String, Any> {
            val p = context.getSharedPreferences(PREFS, MODE_PRIVATE)
            val lastCheckedAt = p.getLong("lastCheckedAt", 0L)
            val texts = NativeLocale.localized(context)
            val diagnosisCode = DiagnosisCode.from(p.getString("diagnosisCode", null))
            // Re-resolved from the code, so the current cause follows a language change at once.
            val diagnosis = diagnosisCode?.let {
                NativeText.diagnosis(context, it, NativeText.targetLabel(context,
                    targetName(p.getString("serverId", null), p.getString("locationId", null))))
            } ?: p.getString("diagnosis", null) ?: texts.getString(R.string.diagnosis_waiting)
            val values = mutableMapOf<String, Any>(
                "enabled" to p.getBoolean("enabled", false),
                "checking" to p.getBoolean("checking", false),
                "status" to (p.getString("status", null) ?: texts.getString(R.string.status_waiting)),
                "transport" to (p.getString("transport", "—") ?: "—"),
                "state" to (p.getString("state", "checking") ?: "checking"),
                "transportType" to (p.getString("transportType", "none") ?: "none"),
                "networkName" to (p.getString("networkName", null) ?: texts.getString(R.string.network_none)),
                "latency" to p.getLong("latency", -1L),
                "jitter" to p.getLong("jitter", -1L),
                "failureRate" to p.getInt("failureRate", 100),
                "successfulSamples" to p.getInt("successfulSamples", 0),
                "totalSamples" to p.getInt("totalSamples", 5),
                "serverId" to testServer(p.getString("serverId", null)).id,
                "serverName" to testServer(p.getString("serverId", null)).name,
                "locationId" to testLocation(p.getString("locationId", null)).id,
                "locationName" to testLocation(p.getString("locationId", null)).name,
                "notificationMode" to (p.getString("notificationMode", "changes") ?: "changes"),
                "lastCheckedAt" to lastCheckedAt,
                "nextCheckAt" to p.getLong("nextCheckAt", 0L),
                "diagnosis" to diagnosis,
                "diagnosisCode" to (diagnosisCode?.code ?: ""),
                "language" to NativeLocale.language(context),
                "signalLevel" to p.getInt("signalLevel", -1),
                "wifiRssi" to p.getInt("wifiRssi", 0),
                "linkSpeed" to p.getInt("linkSpeed", 0)
            )
            if (knownCheckedAt == null || knownCheckedAt != lastCheckedAt) {
                values["measurements"] = measurementHistory(context)
                values["events"] = events(context).recent()
            }
            return values
        }

        /** Canonical target name stored with each measurement (server for "near", else the region). */
        internal fun targetName(serverId: String?, locationId: String?): String {
            val location = testLocation(locationId)
            return if (location.id == "near") testServer(serverId).name else location.name
        }

        /** (target, state) of the stored checks, oldest first, for the widget ribbon. */
        internal fun ribbonEntries(context: Context, limit: Int = RIBBON_HISTORY): List<RibbonEntry> =
            store(context).read().takeLast(limit)
                .map { RibbonEntry(it.optString("targetName", ""), it.optString("state", "offline")) }

        /** True while the service runs continuous monitoring (not a one-shot probe). */
        fun monitoring(context: Context): Boolean =
            active && context.getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean("enabled", false)
    }

    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var interval = 2
    private var maxLatency = 300
    private var serverId = "cloudflare"
    private var locationId = "near"
    private var notificationMode = "changes"
    private var sessionAlertSent = false
    private var running = false
    private var stopAfterCheck = false
    private var lastState = ""
    private var problemSince = 0L
    private var lastTickAt = 0L
    private var generation = 0
    private var wakeLock: PowerManager.WakeLock? = null
    /** Latest published check, re-rendered when the app language changes. */
    private var lastReport: CheckReport? = null
    private lateinit var cm: ConnectivityManager
    // The small icon is always a monochrome mask, so the coloured brand icon goes in the large icon.
    // ic_launcher is an adaptive icon (XML) on API 26+, which BitmapFactory can't decode.
    private val brandIcon by lazy { getDrawable(R.mipmap.ic_launcher)?.toBitmap(192, 192) }

    private val intervalMs get() = interval * 60_000L

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            lastTickAt = SystemClock.elapsedRealtime()
            getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putLong("nextCheckAt", System.currentTimeMillis() + intervalMs)
                .apply()
            scheduleBackupAlarm()
            checkConnection()
            handler.removeCallbacks(this)
            handler.postDelayed(this, intervalMs)
        }
    }

    /**
     * Handler timers stop while the CPU sleeps (Doze), so an inexact idle-allowed alarm wakes
     * the service as a fallback. Whichever fires first runs the check; the other is skipped.
     */
    private fun scheduleBackupAlarm() {
        if (stopAfterCheck) return
        getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + intervalMs,
            tickIntent()
        )
    }

    private fun tickIntent() = PendingIntent.getService(
        this, 1, Intent(this, MonitorService::class.java).setAction(TICK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun serviceAction(action: String, requestCode: Int) = PendingIntent.getService(
        this, requestCode, Intent(this, MonitorService::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun openApp(requestCode: Int, tab: Int? = null): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)!!.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (tab != null) putExtra("tab", tab)
        }
        return PendingIntent.getActivity(this, requestCode, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    override fun onCreate() {
        super.onCreate()
        active = true
        cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        createChannels()
    }

    /** Also called after a language change: re-creating a channel updates its name and description. */
    private fun createChannels() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val monitorChannel = NotificationChannel(
            CHANNEL,
            str(R.string.channel_monitor_name),
            // Silent but not "low": many launchers hide low-importance notifications on the lock screen.
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = str(R.string.channel_monitor_description)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            setShowBadge(false)
        }
        val alertChannel = NotificationChannel(
            ALERT_CHANNEL,
            str(R.string.channel_alerts_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = str(R.string.channel_alerts_description)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.deleteNotificationChannel(LEGACY_CHANNEL)
        manager.createNotificationChannel(monitorChannel)
        manager.createNotificationChannel(alertChannel)
    }

    /** A string in the app language (see [NativeLocale]). */
    private fun str(id: Int, vararg args: Any): String = NativeLocale.localized(this).getString(id, *args)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        when (intent?.action) {
            TICK, CHECK_NOW -> if (running) {
                val due = SystemClock.elapsedRealtime() - lastTickAt >= intervalMs - 5_000L
                if (intent.action == CHECK_NOW || due) handler.post(tick)
                return START_STICKY
            } else if (!prefs.getBoolean("enabled", false)) {
                stopSelf()
                return START_NOT_STICKY
            }
            PAUSE -> {
                prefs.edit().putBoolean("enabled", false).apply()
                stopSelf()
                return START_NOT_STICKY
            }
            REFRESH -> {
                if (!running) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                refreshLanguage()
                return START_STICKY
            }
        }
        if (NativeLocale.setLanguage(this, intent?.getStringExtra("language"))) createChannels()
        val wasEnabled = prefs.getBoolean("enabled", false)
        stopAfterCheck = intent?.getBooleanExtra("oneShot", false) == true && !wasEnabled
        interval = (intent?.getIntExtra("interval", prefs.getInt("interval", 2))
            ?: prefs.getInt("interval", 2)).coerceIn(1, 60)
        maxLatency = ConnectionMath.clampMaxLatency(intent?.getIntExtra("maxLatency", prefs.getInt("maxLatency", 300))
            ?: prefs.getInt("maxLatency", 300))
        serverId = testServer(intent?.getStringExtra("serverId")
            ?: prefs.getString("serverId", "cloudflare")).id
        locationId = testLocation(intent?.getStringExtra("locationId")
            ?: prefs.getString("locationId", "near")).id
        notificationMode = (intent?.getStringExtra("notificationMode")
            ?: prefs.getString("notificationMode", "changes"))
            ?.takeIf { it in setOf("none", "once", "changes") } ?: "changes"
        if (intent?.getBooleanExtra("resetAlertSession", false) == true) {
            sessionAlertSent = false
        }
        running = true
        prefs.edit()
            .putBoolean("enabled", !stopAfterCheck || wasEnabled)
            .putInt("interval", interval)
            .putInt("maxLatency", maxLatency)
            .putString("serverId", serverId)
            .putString("locationId", locationId)
            .putString("notificationMode", notificationMode)
            .apply()
        val initial = statusNotification(null)
        if (Build.VERSION.SDK_INT >= 29) {
            var types = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
            if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                getSystemService(LocationManager::class.java).isLocationEnabled) {
                types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            }
            try {
                startForeground(ID, initial, types)
            } catch (e: RuntimeException) {
                // Android 14+ refuses the location type when the service is (re)started from the
                // background with "while in use" permission; monitoring still works without it.
                if (types and ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION == 0) throw e
                startForeground(ID, initial, types and ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION.inv())
            }
        } else {
            startForeground(ID, initial)
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        MonitorWidgets.update(this)
        return START_STICKY
    }

    /** New language: channel names, the persistent notification and the widgets follow at once. */
    private fun refreshLanguage() {
        createChannels()
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(ID, statusNotification(lastReport))
        MonitorWidgets.update(this)
    }

    private fun stateColor(state: String) = getColor(when (state) {
        "online" -> R.color.monitor_online
        "slow" -> R.color.monitor_slow
        "offline" -> R.color.monitor_offline
        else -> R.color.monitor_checking
    })

    private fun stateLabel(state: String) = str(when (state) {
        "online" -> R.string.state_label_online
        "slow" -> R.string.state_label_slow
        "offline" -> R.string.state_label_offline
        else -> R.string.state_label_checking
    })

    private fun transportLabel(transportType: String) = when (transportType) {
        "wifi" -> MonitorCardFormat.WIFI
        "cellular" -> str(R.string.transport_cellular)
        "ethernet" -> str(R.string.transport_ethernet)
        else -> str(R.string.transport_none)
    }

    private fun signalLabel(level: Int) = when (level) {
        0, 1 -> str(R.string.signal_weak)
        2 -> str(R.string.signal_fair)
        3, 4 -> str(R.string.signal_good)
        else -> null
    }

    /** Localized probable cause; the regional target is named in the app language. */
    private fun diagnosisText(report: CheckReport) =
        NativeText.diagnosis(this, report.diagnosis, NativeText.targetLabel(this, report.targetName))

    private fun clock(time: Long) = SimpleDateFormat("HH:mm", Locale("pt", "BR")).format(Date(time))

    /**
     * "Conexão estável · 74 ms" with the state in bold. The state colour comes from the tinted
     * small icon: several launchers drop colour spans from notification titles.
     */
    private fun headline(state: String, result: LatencyResult?, label: String = stateLabel(state)): CharSequence {
        val text = SpannableStringBuilder(label)
        text.setSpan(StyleSpan(Typeface.BOLD), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (result != null && result.latency >= 0) text.append(" · ${result.latency} ms")
        return text
    }

    /** Builds a line "Label value" with the label de-emphasised, for the expanded view. */
    private fun SpannableStringBuilder.detailLine(label: String, value: String): SpannableStringBuilder {
        if (isNotEmpty()) append("\n")
        val start = length
        append(label).append("  ")
        setSpan(StyleSpan(Typeface.BOLD), start, start + label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        append(value)
        return this
    }

    private fun currentTargetName(): String = targetName(serverId, locationId)

    /** Recent (server, state) pairs for the notification ribbon, loaded once from the store. */
    private var ribbonHistory: MutableList<RibbonEntry>? = null

    private fun ribbonHistory(): MutableList<RibbonEntry> = ribbonHistory ?: store(this).read()
        .map { RibbonEntry(it.optString("targetName", ""), it.optString("state", "offline")) }
        .takeLast(RIBBON_HISTORY)
        .toMutableList()
        .also { ribbonHistory = it }

    private fun rememberForRibbon(report: CheckReport) {
        val history = ribbonHistory()
        history.add(RibbonEntry(report.targetName, report.state))
        while (history.size > RIBBON_HISTORY) history.removeAt(0)
    }

    /** Builds the card shown below API 36; before the first result it shows "Verificando…". */
    private fun monitorCard(report: CheckReport?): MonitorCard {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val targetName = report?.targetName ?: currentTargetName()
        return MonitorCardFormat.card(
            state = report?.state ?: "checking",
            transportType = report?.transportType ?: (prefs.getString("transportType", "none") ?: "none"),
            networkName = report?.networkName ?: prefs.getString("networkName", null),
            diagnosis = report?.let { NativeText.cardDiagnosis(this, it.diagnosis, NativeText.targetLabel(this, it.targetName)) },
            latency = report?.result?.latency,
            jitter = report?.result?.jitter,
            failureRate = report?.result?.failureRate,
            lastCheck = report?.let { clock(it.checkedAt) }
                ?: prefs.getLong("lastCheckedAt", 0L).takeIf { it > 0 }?.let(::clock) ?: "—",
            ribbon = MonitorCardFormat.ribbon(ribbonHistory(), targetName),
            texts = NativeText.cardTexts(this)
        )
    }

    /**
     * The persistent notification. Below API 36 it is the custom dark card from the design
     * mockup (see [MonitorNotificationViews]). From API 36 on it keeps the standard template,
     * because Android 16 only promotes notifications without custom views to Live Updates
     * (status bar chip, lock screen and AOD).
     */
    private fun statusNotification(report: CheckReport?): Notification {
        val state = report?.state ?: "checking"
        val nextCheckAt = getSharedPreferences(PREFS, MODE_PRIVATE).getLong("nextCheckAt", 0L)
        val custom = MonitorNotificationViews.supported()
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_linkzora_notification)
            .setColor(stateColor(state))
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openApp(0))
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (custom) {
            val card = monitorCard(report)
            // Never a large icon here, including the first "Verificando…" card posted by
            // onStartCommand: Android 12+ draws it to the right of decorated custom views and
            // squeezes the card. Cleared explicitly so no builder default can bring it back.
            builder
                .setLargeIcon(null as android.graphics.Bitmap?)
                // The system header shows "Linkzora · <server> · countdown" above the card.
                .setSubText(NativeText.targetLabel(this, report?.targetName ?: currentTargetName()))
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(MonitorNotificationViews.collapsed(this, card))
                .setCustomBigContentView(MonitorNotificationViews.expanded(this, card))
                // Plain texts still feed accessibility, wearables and redacted lock screens.
                .setContentTitle(headline(state, report?.result))
                .setContentText("${card.networkName} · ${card.stateSubtitle}")
        } else {
            // Android 16 Live Update: shown on the lock screen, AOD and as a status bar chip. The
            // standard template keeps the brand icon; the custom card above never sets one.
            builder.setLargeIcon(brandIcon).setRequestPromotedOngoing(true)
        }

        if (report == null) {
            if (!custom) {
                builder
                    .setContentTitle(headline(state, null))
                    .setContentText(str(R.string.notification_first_check))
                    .setProgress(0, 0, true)
                    .setShortCriticalText("…")
            }
            return builder.setShowWhen(false).build()
        }

        val result = report.result
        if (!custom) {
            val transport = transportLabel(report.transportType)
            val target = NativeText.targetLabel(this, report.targetName)
            val network = if (report.transportType == "wifi" && report.networkName != MonitorCardFormat.WIFI) {
                report.networkName
            } else {
                transport
            }
            val metrics = if (result.successfulSamples == 0) {
                str(R.string.notification_no_response, result.totalSamples)
            } else {
                str(R.string.notification_metrics, result.latency, result.jitter, result.failureRate)
            }
            val expanded = SpannableStringBuilder()
                .detailLine(str(R.string.label_measurement), metrics)
                .detailLine(str(R.string.label_network), listOfNotNull(
                    network.takeIf { it != transport }, transport,
                    signalLabel(report.signalLevel).takeIf { report.transportType == "wifi" }
                ).joinToString(" · "))
                .detailLine(str(R.string.label_server), str(R.string.notification_server_at, target, clock(report.checkedAt)))
                .detailLine(str(R.string.label_diagnosis), diagnosisText(report))
            builder
                .setContentTitle(headline(state, result))
                .setContentText("$network · $target")
                .setStyle(NotificationCompat.BigTextStyle()
                    .setBigContentTitle(headline(state, result))
                    .bigText(expanded))
                .setShortCriticalText(if (state == "offline") "Off" else "${result.latency} ms")
        }
        builder
            .addAction(R.drawable.ic_action_refresh, str(R.string.action_check_now), serviceAction(CHECK_NOW, 2))
            .addAction(R.drawable.ic_action_pause, str(R.string.action_pause), serviceAction(PAUSE, 3))

        // Header countdown to the next check while monitoring continuously.
        if (!stopAfterCheck && nextCheckAt > System.currentTimeMillis()) {
            builder.setWhen(nextCheckAt).setShowWhen(true)
                .setUsesChronometer(true).setChronometerCountDown(true)
        } else {
            builder.setShowWhen(false)
        }
        return builder.build()
    }

    // getConnectionInfo remains available on older devices and returns the primary Wi-Fi SSID.
    // Never reuse a saved SSID: permission revocation or a network change must not show an old name.
    @Suppress("DEPRECATION")
    private fun wifiDetails(): WifiDetails {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return WifiDetails("Wi-Fi")
        return try {
            val info = applicationContext.getSystemService(WifiManager::class.java).connectionInfo
            val raw = info?.ssid
            val name = raw?.removeSurrounding("\"")?.takeIf {
                it.isNotBlank() && it != WifiManager.UNKNOWN_SSID && it != "0x"
            }
            val rssi = info?.rssi ?: 0
            val level = if (rssi != 0) WifiManager.calculateSignalLevel(rssi, 5) else -1
            WifiDetails(name ?: "Wi-Fi", level, rssi, info?.linkSpeed ?: 0)
        } catch (_: SecurityException) {
            WifiDetails("Wi-Fi")
        }
    }

    private fun appendMeasurement(report: CheckReport) {
        store(this).append(JSONObject().apply {
            put("timestamp", report.checkedAt)
            put("state", report.state)
            put("latency", report.result.latency)
            put("jitter", report.result.jitter)
            put("failureRate", report.result.failureRate)
            put("transportType", report.transportType)
            put("targetName", report.targetName)
            put("diagnosis", diagnosisText(report))
            put("diagnosisCode", report.diagnosis.code)
            put("signalLevel", report.signalLevel)
        })
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Linkzora:check")
            .apply { acquire(60_000L) }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun checkConnection() {
        // Keeps the CPU awake until the measurement finishes, even if the screen is off.
        acquireWakeLock()
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putBoolean("checking", true)
            .apply()
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        val wifi = if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) wifiDetails() else WifiDetails("Wi-Fi")
        val (transportType, networkName) = when {
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi" to wifi.name
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "cellular" to str(R.string.transport_cellular)
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "ethernet" to str(R.string.transport_ethernet)
            else -> "none" to str(R.string.network_none)
        }
        val validated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        val captivePortal = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL) == true
        val transport = when (transportType) {
            "wifi" -> if (networkName == MonitorCardFormat.WIFI) MonitorCardFormat.WIFI else "${MonitorCardFormat.WIFI} · $networkName"
            else -> transportLabel(transportType)
        }
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putString("transport", transport)
            .putString("transportType", transportType)
            .putString("networkName", networkName)
            .putInt("signalLevel", wifi.signalLevel)
            .putInt("wifiRssi", wifi.rssi)
            .putInt("linkSpeed", wifi.linkSpeed)
            .apply()
        val currentGeneration = ++generation
        val selectedServer = testServer(serverId)
        val selectedLocation = testLocation(locationId)
        val targetAddress = selectedLocation.address ?: selectedServer.address
        val targetName = currentTargetName()
        val limit = maxLatency
        worker.execute {
            var dnsFailed = false
            val result = if (network == null) {
                LatencyResult(-1, -1, 100, 0, 5)
            } else {
                val resolved = try {
                    network.getAllByName(targetAddress).first()
                } catch (_: Exception) {
                    dnsFailed = true
                    null
                }
                resolved?.let { measureLatency(network, it, limit) } ?: LatencyResult(-1, -1, 100, 0, 5)
            }
            val state = ConnectionMath.classify(result, limit)
            val diagnosis = ConnectionMath.diagnosis(DiagnosisInput(
                state = state,
                transportType = transportType,
                latency = result.latency,
                jitter = result.jitter,
                failureRate = result.failureRate,
                signalLevel = wifi.signalLevel,
                targetName = targetName,
                maxLatency = limit,
                regionalTarget = selectedLocation.id != "near",
                validated = validated,
                captivePortal = captivePortal,
                dnsFailed = dnsFailed
            ))
            handler.post {
                if (!running || currentGeneration != generation) return@post
                val report = CheckReport(state, networkName, transportType, targetName, result,
                    diagnosis, wifi.signalLevel, System.currentTimeMillis())
                publish(report, transport)
                // Gateway reference and the 15-min device inventory for the Rede tab.
                NetworkScanner.afterCheck(applicationContext, report.transportType)
                releaseWakeLock()
                if (stopAfterCheck) {
                    stopAfterCheck = false
                    stopSelf()
                }
            }
        }
    }

    private fun publish(report: CheckReport, transport: String) {
        val result = report.result
        val target = NativeText.targetLabel(this, report.targetName)
        // Same "title • detail • …" structure in every language; Flutter parses it.
        val message = when (report.state) {
            "online" -> "${stateLabel("online")} • $transport • $target • ${result.latency} ms • jitter ${result.jitter} ms"
            "slow" -> "${stateLabel("slow")} • $transport • $target • ${result.latency} ms • jitter ${result.jitter} ms • ${str(R.string.event_loss, result.failureRate)}"
            else -> "${stateLabel("offline")} • $transport"
        }
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.edit()
            .putString("status", message)
            .putString("state", report.state)
            .putLong("latency", result.latency)
            .putLong("jitter", result.jitter)
            .putInt("failureRate", result.failureRate)
            .putInt("successfulSamples", result.successfulSamples)
            .putInt("totalSamples", result.totalSamples)
            .putString("diagnosis", diagnosisText(report))
            .putString("diagnosisCode", report.diagnosis.code)
            .putBoolean("checking", false)
            .apply()
        appendMeasurement(report)
        rememberForRibbon(report)
        // Before lastCheckedAt, so the history the UI fetches for this check already has the event.
        // The last logged state is persisted: the service restarts on every app launch (one-shot
        // probe) and on updates, and an in-memory value would log the same state again each time.
        if (report.state != prefs.getString("lastEventState", null)) {
            events(this).append(report.checkedAt, message)
            prefs.edit().putString("lastEventState", report.state).apply()
        }
        // Written last: the UI treats a new lastCheckedAt as "history is ready".
        prefs.edit().putLong("lastCheckedAt", report.checkedAt).apply()
        lastReport = report
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(ID, statusNotification(report))
        MonitorWidgets.update(this)

        if (report.state == lastState) return
        val previous = lastState
        lastState = report.state

        val problemDuration = if (problemSince > 0) report.checkedAt - problemSince else 0L
        problemSince = when {
            report.state == "online" -> 0L
            problemSince == 0L -> report.checkedAt
            else -> problemSince
        }
        val shouldAlert = previous.isNotEmpty() && !stopAfterCheck && when (notificationMode) {
            "none" -> false
            "once" -> !sessionAlertSent
            else -> true
        }
        if (shouldAlert) {
            sendAlert(report, previous, problemDuration)
            sessionAlertSent = true
        }
    }

    private fun measureLatency(network: Network, address: InetAddress, maxLatency: Int): LatencyResult {
        // The warm-up absorbs one-time route, ARP and radio wake-up costs.
        tcpLatency(network, address, 2_500)

        val samples = mutableListOf<Long>()
        var attemptedSamples = 0

        fun collectSamples(amount: Int) {
            repeat(amount) { index ->
                if (Thread.currentThread().isInterrupted) return
                attemptedSamples++
                tcpLatency(network, address, 2_500)?.let(samples::add)
                if (index < amount - 1) {
                    try {
                        Thread.sleep(120)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return
                    }
                }
            }
        }

        collectSamples(5)
        if (ConnectionMath.needsConfirmation(samples, attemptedSamples, maxLatency) &&
            !Thread.currentThread().isInterrupted) {
            try {
                Thread.sleep(120)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            if (!Thread.currentThread().isInterrupted) collectSamples(5)
        }
        return ConnectionMath.summarize(samples, attemptedSamples.coerceAtLeast(5))
    }

    private fun tcpLatency(network: Network, address: InetAddress, timeoutMs: Int): Long? {
        return try {
            val socket = network.socketFactory.createSocket()
            try {
                val started = SystemClock.elapsedRealtimeNanos()
                socket.connect(InetSocketAddress(address, 443), timeoutMs)
                (SystemClock.elapsedRealtimeNanos() - started + 500_000L) / 1_000_000L
            } finally {
                socket.close()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun sendAlert(report: CheckReport, previous: String, problemDuration: Long) {
        val recovered = report.state == "online"
        val title = str(when {
            recovered -> R.string.alert_recovered
            report.state == "offline" -> R.string.alert_offline
            previous == "offline" -> R.string.alert_back_unstable
            else -> R.string.alert_unstable
        })
        val target = NativeText.targetLabel(this, report.targetName)
        val network = if (report.transportType == "wifi" && report.networkName != MonitorCardFormat.WIFI) {
            report.networkName
        } else {
            transportLabel(report.transportType)
        }
        val result = report.result
        val summary = if (result.successfulSamples == 0) {
            str(R.string.alert_no_response, network, target)
        } else {
            "$network · $target · ${result.latency} ms"
        }
        val expanded = SpannableStringBuilder(summary)
        if (recovered && problemDuration >= 60_000L) {
            expanded.detailLine(str(R.string.label_problem_duration), str(R.string.duration_minutes, problemDuration / 60_000L))
        }
        if (!recovered) {
            expanded.detailLine(str(R.string.label_probable_cause), diagnosisText(report))
            if (result.successfulSamples > 0) {
                expanded.detailLine(str(R.string.label_measurement), str(R.string.alert_metrics, result.jitter, result.failureRate))
            }
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        // A single id: a newer alert replaces the previous one instead of piling up.
        manager.notify(ALERT_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL)
                .setSmallIcon(R.drawable.ic_linkzora_notification)
                .setLargeIcon(brandIcon)
                .setColor(stateColor(report.state))
                .setContentTitle(headline(report.state, null, title))
                .setContentText(summary)
                .setStyle(NotificationCompat.BigTextStyle().bigText(expanded))
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setWhen(report.checkedAt)
                .setShowWhen(true)
                .setContentIntent(openApp(4))
                .addAction(R.drawable.ic_action_chart, str(R.string.action_view_monitoring), openApp(5, tab = 1))
                .setAutoCancel(true)
                .build())
    }

    override fun onDestroy() {
        running = false
        active = false
        generation++
        handler.removeCallbacks(tick)
        getSystemService(AlarmManager::class.java).cancel(tickIntent())
        releaseWakeLock()
        worker.shutdownNow()
        // "enabled" is left alone: Pausar and the app's switch clear it themselves, while a stop
        // decided by the system must not turn monitoring off (it resumes via START_STICKY/boot).
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.edit()
            .putBoolean("checking", false)
            .putLong("nextCheckAt", 0L)
            .apply {
                if (!prefs.getBoolean("enabled", false)) putString("status", str(R.string.status_monitoring_off))
            }
            .apply()
        MonitorWidgets.update(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
