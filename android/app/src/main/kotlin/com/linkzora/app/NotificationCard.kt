package com.linkzora.app

import kotlin.math.max

/**
 * The persistent notification redesigned in design/notificacao (notificacao-redesign.png):
 * state and latency first, the last checks as a bar chart against the limit, then the details.
 * Pure model, free of Android types; [MonitorNotificationViews] renders it (custom card below
 * API 36, system ProgressStyle from API 36 on).
 */
data class NotificationCard(
    /** "online", "slow", "offline" or "checking". */
    val state: String,
    val transportType: String,
    val networkName: String,
    /** "Wi-Fi 5 GHz · sinal bom", "Wi-Fi 5 GHz · conectado sem internet", "Dados móveis"… */
    val subtitle: String,
    /** Short state for the pill: "Estável", "Instável", "Sem resposta". */
    val pill: String,
    /** Big number ("81") or [MonitorCardFormat.NO_VALUE] when nothing answered. */
    val latency: String,
    /** "latência · limite 300 ms" or "0 de 5 conexões · limite 300 ms". */
    val caption: String,
    val jitter: String,
    val jitterColor: Int,
    val loss: String,
    val lossColor: Int,
    val signal: String,
    /** Probable cause written for people, with its kind for the icon. */
    val diagnosis: String,
    val diagnosisKind: DiagnosisKind,
    /** "HH:mm" of the check. */
    val measuredAt: String,
    /** The recent checks of the current server, oldest first, always [MonitorCardFormat.RIBBON_SIZE]. */
    val bars: List<ChartBar>,
    /** "−24 min", the age of the oldest bar ("" when there is no history yet). */
    val axisStart: String
)

enum class DiagnosisKind { OK, WARN, OFF, INFO }

/** One check in the chart: its state colour and latency (-1 when it did not answer). */
data class ChartBar(val state: String, val latency: Long)

/** Words of the redesigned card, resolved from the string resources by [NativeText]. */
data class NotificationTexts(
    val pillOnline: String,
    val pillSlow: String,
    val pillOffline: String,
    val pillChecking: String,
    /** "latência · limite %1$d ms". */
    val latencyCaption: String,
    /** "%1$d de %2$d conexões · limite %3$d ms". */
    val noResponseCaption: String,
    /** "Wi-Fi %1$s GHz". */
    val band: String,
    val signalWeak: String,
    val signalFair: String,
    val signalGood: String,
    val connectedNoInternet: String,
    val cellular: String,
    val ethernet: String,
    val noConnection: String,
    /** "Internet estável. Nenhum problema nas últimas %1$d min." */
    val stableWindow: String,
    val stable: String,
    /** "%1$s há %2$d min." */
    val problemSince: String,
    val firstCheck: String,
    /** "−%1$d min". */
    val axisStart: String
)

/** What a published check contributes to the card. */
data class NotificationInput(
    val state: String,
    val transportType: String,
    val networkName: String?,
    /** Wi-Fi frequency in MHz (0 when unknown). */
    val frequencyMhz: Int,
    val signalLevel: Int,
    val rssi: Int,
    /** Wi-Fi joined but Android could not validate internet access. */
    val validated: Boolean,
    val latency: Long,
    val jitter: Long,
    val failureRate: Int,
    val successfulSamples: Int,
    val totalSamples: Int,
    val maxLatency: Int,
    /** Localized probable cause, or null when there is no anomaly. */
    val diagnosis: String?,
    /** Milliseconds the current problem has lasted (0 when online). */
    val problemFor: Long,
    val measuredAt: String,
    /** Recent checks of the current server, oldest first, including this one. */
    val history: List<HistoryEntry>,
    val now: Long
)

/** One stored check of the measurement history. */
data class HistoryEntry(val targetName: String, val state: String, val latency: Long, val timestamp: Long)

object NotificationFormat {
    private const val MINUTE = 60_000L

    fun pill(state: String, t: NotificationTexts) = when (state) {
        "online" -> t.pillOnline
        "slow" -> t.pillSlow
        "offline" -> t.pillOffline
        else -> t.pillChecking
    }

    /** "5" for 5 GHz Wi-Fi, "2.4" for 2.4 GHz, "6" for 6 GHz; null when unknown. */
    fun band(frequencyMhz: Int): String? = when (frequencyMhz) {
        in 2400..2500 -> "2.4"
        in 4900..5900 -> "5"
        in 5925..7125 -> "6"
        else -> null
    }

    fun signal(level: Int, t: NotificationTexts): String? = when (level) {
        0, 1 -> t.signalWeak
        2 -> t.signalFair
        3, 4 -> t.signalGood
        else -> null
    }

    fun subtitle(input: NotificationInput, t: NotificationTexts): String = when (input.transportType) {
        "wifi" -> {
            val kind = band(input.frequencyMhz)?.let { String.format(t.band, it) } ?: MonitorCardFormat.WIFI
            val detail = if (input.state == "offline" && !input.validated) t.connectedNoInternet else signal(input.signalLevel, t)
            listOfNotNull(kind, detail).joinToString(" · ")
        }
        "cellular" -> t.cellular
        "ethernet" -> t.ethernet
        // The title already says "Sem conexão"; the cause below explains it.
        else -> ""
    }

    fun diagnosisKind(state: String) = when (state) {
        "online" -> DiagnosisKind.OK
        "slow" -> DiagnosisKind.WARN
        "offline" -> DiagnosisKind.OFF
        else -> DiagnosisKind.INFO
    }

    /** The cause in a sentence: how long the network has been fine, or how long a drop has lasted. */
    fun diagnosis(input: NotificationInput, t: NotificationTexts): String = when (input.state) {
        "online" -> {
            val window = cleanWindowMinutes(input.history, input.now)
            if (window >= 1) String.format(t.stableWindow, window) else t.stable
        }
        "slow" -> sentence(input.diagnosis ?: t.pillSlow)
        "offline" -> {
            val cause = input.diagnosis ?: t.pillOffline
            val minutes = input.problemFor / MINUTE
            if (minutes >= 1) String.format(t.problemSince, cause, minutes) else sentence(cause)
        }
        else -> t.firstCheck
    }

    private fun sentence(text: String) = if (text.endsWith(".")) text else "$text."

    /** Minutes since the oldest check in [history] when every check in it was online. */
    fun cleanWindowMinutes(history: List<HistoryEntry>, now: Long): Long {
        if (history.isEmpty() || history.any { it.state != "online" }) return 0
        return (now - history.first().timestamp) / MINUTE
    }

    /** The last [size] checks against [targetName], padded at the start with empty bars. */
    fun bars(history: List<HistoryEntry>, size: Int = MonitorCardFormat.RIBBON_SIZE): List<ChartBar> {
        val recent = history.takeLast(size).map {
            ChartBar(it.state.takeIf { s -> s in setOf("online", "slow", "offline") } ?: "offline", it.latency)
        }
        return List(size - recent.size) { ChartBar(MonitorCardFormat.EMPTY, -1) } + recent
    }

    fun card(input: NotificationInput, t: NotificationTexts): NotificationCard {
        val measured = input.state == "online" || input.state == "slow"
        val answered = measured && input.latency >= 0
        val unstableJitter = input.state == "slow" && ConnectionMath.isJitterUnstable(input.jitter, input.latency)
        val history = input.history
        return NotificationCard(
            state = input.state,
            transportType = input.transportType,
            networkName = when (input.transportType) {
                "wifi" -> input.networkName?.takeIf { it.isNotBlank() } ?: MonitorCardFormat.WIFI
                "cellular" -> t.cellular
                "ethernet" -> t.ethernet
                else -> t.noConnection
            },
            subtitle = subtitle(input, t),
            pill = pill(input.state, t),
            latency = if (answered) input.latency.toString() else MonitorCardFormat.NO_VALUE,
            caption = when {
                input.state == "checking" -> String.format(t.latencyCaption, input.maxLatency)
                answered -> String.format(t.latencyCaption, input.maxLatency)
                else -> String.format(t.noResponseCaption, input.successfulSamples, input.totalSamples, input.maxLatency)
            },
            jitter = if (answered && input.jitter >= 0) "${input.jitter} ms" else MonitorCardFormat.NO_VALUE,
            jitterColor = if (unstableJitter) MonitorCardFormat.SLOW else MonitorCardFormat.TEXT,
            loss = if (input.state == "checking") MonitorCardFormat.NO_VALUE else "${input.failureRate}%",
            lossColor = when {
                input.state == "checking" || input.failureRate <= 0 -> MonitorCardFormat.TEXT
                input.state == "offline" -> MonitorCardFormat.OFFLINE
                else -> MonitorCardFormat.SLOW
            },
            signal = if (input.transportType == "wifi" && input.rssi != 0) "${input.rssi} dBm" else MonitorCardFormat.NO_VALUE,
            diagnosis = diagnosis(input, t),
            diagnosisKind = diagnosisKind(input.state),
            measuredAt = input.measuredAt,
            bars = bars(history),
            axisStart = history.takeLast(MonitorCardFormat.RIBBON_SIZE).firstOrNull()
                ?.let { (input.now - it.timestamp) / MINUTE }
                ?.takeIf { it >= 1 }
                ?.let { String.format(t.axisStart, it) } ?: ""
        )
    }
}

/**
 * Geometry of the bar chart, as fractions of the chart height. The scale always leaves room above
 * the limit line (limit × 1.35) so a healthy connection reads as short bars under the line.
 */
object ChartScale {
    fun max(bars: List<ChartBar>, limit: Int): Double {
        val highest = bars.maxOfOrNull { it.latency } ?: -1L
        return max(limit * 1.35, highest.toDouble()) * 1.05
    }

    /** Height of [bar] between 0 and 1; null for a check that did not answer. */
    fun height(bar: ChartBar, scaleMax: Double): Double? =
        if (bar.latency < 0) null else (bar.latency / scaleMax).coerceIn(0.0, 1.0)

    fun limitLine(limit: Int, scaleMax: Double): Double = (limit / scaleMax).coerceIn(0.0, 1.0)
}
