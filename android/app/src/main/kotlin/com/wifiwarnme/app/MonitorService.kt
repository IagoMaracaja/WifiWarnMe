package com.wifiwarnme.app

import android.app.*
import android.content.*
import android.net.*
import android.os.*
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

class MonitorService : Service() {
    companion object {
        const val START = "wifiwarnme.START"
        private const val CHANNEL = "wifiwarnme.monitor"
        private const val ID = 42
        private const val PREFS = "wifiwarnme_native"
        fun snapshot(context: Context): Map<String, Any> {
            val p = context.getSharedPreferences(PREFS, MODE_PRIVATE)
            return mapOf(
                "enabled" to p.getBoolean("enabled", false),
                "status" to (p.getString("status", "Aguardando") ?: "Aguardando"),
                "transport" to (p.getString("transport", "—") ?: "—"),
                "events" to (p.getString("events", "") ?: "").split("\n").filter { it.isNotBlank() }.take(50)
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var interval = 2
    private var maxLatency = 300
    private var running = false
    private var lastState = ""
    private var generation = 0
    private lateinit var cm: ConnectivityManager

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            checkConnection()
            handler.postDelayed(this, interval * 60_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Monitoramento de internet", NotificationManager.IMPORTANCE_LOW))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        interval = (intent?.getIntExtra("interval", 2) ?: 2).coerceIn(1, 60)
        maxLatency = (intent?.getIntExtra("maxLatency", 300) ?: 300).coerceIn(100, 2000)
        running = true
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("enabled", true).apply()
        startForeground(ID, notification("Monitorando conexão"))
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    private fun notification(message: String): Notification {
        val open = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("WifiWarnMe • Monitoramento ativo")
            .setContentText(message)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun checkConnection() {
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        val transport = when {
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "Wi-Fi"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Dados móveis"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
            else -> "Sem rede"
        }
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString("transport", transport).apply()
        val currentGeneration = ++generation
        worker.execute {
            var state = "offline"
            var latency = -1L
            if (network != null) {
                try {
                    val started = SystemClock.elapsedRealtime()
                    val conn = network.openConnection(URL("https://www.google.com/generate_204")) as HttpURLConnection
                    conn.connectTimeout = 5000
                    conn.readTimeout = 5000
                    conn.instanceFollowRedirects = false
                    conn.useCaches = false
                    try {
                        if (conn.responseCode == 204) {
                            latency = SystemClock.elapsedRealtime() - started
                            state = if (latency > maxLatency) "slow" else "online"
                        }
                    } finally { conn.disconnect() }
                } catch (_: Exception) { state = "offline" }
            }
            handler.post {
                if (!running || currentGeneration != generation) return@post
                val message = when (state) {
                    "online" -> "Conexão estável • $transport • ${latency}ms"
                    "slow" -> "Conexão lenta • $transport • ${latency}ms"
                    else -> "Internet indisponível • $transport"
                }
                val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
                prefs.edit().putString("status", message).apply()
                (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(ID, notification(message))
                if (state != lastState) {
                    val previous = lastState
                    lastState = state
                    val time = SimpleDateFormat("dd/MM HH:mm", Locale("pt", "BR")).format(Date())
                    val event = "$time • $message"
                    val previousEvents = prefs.getString("events", "") ?: ""
                    prefs.edit().putString("events", (event + "\n" + previousEvents).lines().take(50).joinToString("\n")).apply()
                    if (previous.isNotEmpty()) sendAlert(message)
                }
            }
        }
    }

    private fun sendAlert(message: String) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val alerts = "wifiwarnme.alerts"
        manager.createNotificationChannel(NotificationChannel(alerts, "Alertas de conectividade", NotificationManager.IMPORTANCE_HIGH))
        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            NotificationCompat.Builder(this, alerts)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setContentTitle("WifiWarnMe")
                .setContentText(message)
                .setAutoCancel(true)
                .build())
    }

    override fun onDestroy() {
        running = false
        generation++
        handler.removeCallbacks(tick)
        worker.shutdownNow()
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("enabled", false).putString("status", "Monitoramento desligado").apply()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
