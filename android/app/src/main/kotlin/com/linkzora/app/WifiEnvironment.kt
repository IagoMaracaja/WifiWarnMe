package com.linkzora.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.os.Build
import android.os.SystemClock
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Neighbour Wi-Fi networks and how much they overlap with the connected one.
 *
 * Android throttles scans (4 per 2 minutes in the foreground, 1 per 30 minutes in the
 * background), so a new scan is only requested on demand and at most every 30 s; otherwise,
 * or when the system refuses, the cached results are used and reported as such.
 */
object WifiEnvironment {
    private const val MIN_SCAN_GAP_MS = 30_000L

    @Volatile
    private var lastScanRequestAt = 0L

    @Suppress("DEPRECATION")
    fun read(context: Context, requestScan: Boolean, waitMs: Long = 6_000L): Map<String, Any?> {
        val app = context.applicationContext
        if (app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return mapOf("available" to false, "reason" to "permission")
        }
        if (!app.getSystemService(LocationManager::class.java).isLocationEnabled) {
            return mapOf("available" to false, "reason" to "location_off")
        }
        val wifi = app.getSystemService(WifiManager::class.java)
        var fresh = false
        val now = SystemClock.elapsedRealtime()
        if (requestScan && now - lastScanRequestAt >= MIN_SCAN_GAP_MS) {
            lastScanRequestAt = now
            val done = CountDownLatch(1)
            var updated = false
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    updated = intent.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false)
                    done.countDown()
                }
            }
            val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
            if (Build.VERSION.SDK_INT >= 33) {
                app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                app.registerReceiver(receiver, filter)
            }
            try {
                if (wifi.startScan()) {
                    done.await(waitMs, TimeUnit.MILLISECONDS)
                    fresh = updated
                }
            } catch (_: Exception) {
            } finally {
                try {
                    app.unregisterReceiver(receiver)
                } catch (_: Exception) {
                }
            }
        }

        val results: List<ScanResult> = try {
            wifi.scanResults ?: emptyList()
        } catch (_: SecurityException) {
            return mapOf("available" to false, "reason" to "permission")
        }
        val info = wifi.connectionInfo
        // Location granted only "while using the app" is denied in the background: Android then
        // hides the SSID and returns no scan results instead of throwing.
        if (results.isEmpty() && (info?.ssid == null || info.ssid == WifiManager.UNKNOWN_SSID)) {
            return mapOf("available" to false, "reason" to "no_access")
        }
        val myBssid = info?.bssid?.lowercase()
        val networks = results.map { it.toNetwork() }
        val myScan = networks.firstOrNull { it.bssid == myBssid }
        val frequency = info?.frequency?.takeIf { it > 0 } ?: myScan?.frequency ?: 0
        if (frequency == 0) return mapOf("available" to false, "reason" to "not_connected")
        val mine = WifiNetwork(
            ssid = info?.ssid?.removeSurrounding("\"") ?: "",
            bssid = myBssid ?: "",
            frequency = frequency,
            rssi = info?.rssi ?: myScan?.rssi ?: -100,
            widthMhz = myScan?.widthMhz ?: 20,
            centerFrequency = myScan?.centerFrequency ?: 0
        )
        val nowMicros = SystemClock.elapsedRealtime() * 1000L
        val newest = results.maxOfOrNull { it.timestamp } ?: 0L
        val others = networks.filter { it.bssid != mine.bssid }
        val score = WifiMath.interferenceScore(mine, others)
        val listed = others
            .map { it to WifiMath.overlap(mine, it) }
            .sortedWith(compareBy<Pair<WifiNetwork, String>>({ overlapRank(it.second) }, { -it.first.rssi }))
            .take(20)
        return mapOf(
            "available" to true,
            "fresh" to fresh,
            "ageSeconds" to if (newest > 0) ((nowMicros - newest) / 1_000_000L).coerceAtLeast(0L) else -1L,
            "ssid" to mine.ssid,
            "frequency" to mine.frequency,
            "band" to WifiMath.band(mine.frequency),
            "channel" to WifiMath.channel(mine.frequency),
            "widthMhz" to mine.widthMhz,
            "rssi" to mine.rssi,
            "linkSpeed" to (info?.linkSpeed ?: 0),
            "score" to score,
            "level" to WifiMath.interferenceLevel(score),
            "sameChannel" to others.count { WifiMath.overlap(mine, it) == "same" },
            "partialOverlap" to others.count { WifiMath.overlap(mine, it) == "partial" },
            "totalNetworks" to others.size,
            "suggestedChannel" to WifiMath.suggestedChannel(mine, others),
            "networks" to listed.map { (network, overlap) ->
                mapOf(
                    "ssid" to network.ssid.ifBlank { "(rede oculta)" },
                    "frequency" to network.frequency,
                    "band" to WifiMath.band(network.frequency),
                    "channel" to WifiMath.channel(network.frequency),
                    "rssi" to network.rssi,
                    "overlap" to overlap
                )
            }
        )
    }

    private fun overlapRank(overlap: String) = when (overlap) {
        "same" -> 0
        "partial" -> 1
        else -> 2
    }

    @Suppress("DEPRECATION")
    private fun ScanResult.toNetwork() = WifiNetwork(
        ssid = (if (Build.VERSION.SDK_INT >= 33) wifiSsid?.toString()?.removeSurrounding("\"") else SSID) ?: "",
        bssid = BSSID?.lowercase() ?: "",
        frequency = frequency,
        rssi = level,
        widthMhz = when (channelWidth) {
            ScanResult.CHANNEL_WIDTH_40MHZ -> 40
            ScanResult.CHANNEL_WIDTH_80MHZ -> 80
            ScanResult.CHANNEL_WIDTH_160MHZ, ScanResult.CHANNEL_WIDTH_80MHZ_PLUS_MHZ -> 160
            else -> if (channelWidth == 5) 320 else 20
        },
        centerFrequency = centerFreq0
    )
}
