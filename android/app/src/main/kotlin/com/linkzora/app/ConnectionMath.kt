package com.linkzora.app

import kotlin.math.abs
import kotlin.math.roundToLong

data class LatencyResult(
    val latency: Long,
    val jitter: Long,
    val failureRate: Int,
    val successfulSamples: Int,
    val totalSamples: Int
)

/** Signals available to [ConnectionMath.diagnosis]; everything the app can observe locally. */
data class DiagnosisInput(
    val state: String,
    val transportType: String,
    val latency: Long,
    val jitter: Long,
    val failureRate: Int,
    val signalLevel: Int,
    val targetName: String,
    val maxLatency: Int,
    val regionalTarget: Boolean,
    val validated: Boolean = true,
    val captivePortal: Boolean = false,
    val dnsFailed: Boolean = false
)

/**
 * Pure statistics used by the monitor, kept free of Android types so they can be unit tested.
 */
object ConnectionMath {
    /**
     * Linux retransmits an unanswered SYN after 1 s, so a handshake that is ~1 s slower than
     * the median only succeeded on the second try and counts as a lost packet.
     */
    const val RETRANSMISSION_PENALTY_MS = 800L

    /** Jitter is unstable when it reaches this value and a third of the latency. */
    const val UNSTABLE_JITTER_MS = 30L

    /** Range of the user's latency limit; the Flutter presets go from 30 ms up to 2000 ms. */
    const val MIN_MAX_LATENCY_MS = 30
    const val MAX_MAX_LATENCY_MS = 2000

    /** Keeps a latency limit received from Flutter or the preferences inside the supported range. */
    fun clampMaxLatency(value: Int): Int = value.coerceIn(MIN_MAX_LATENCY_MS, MAX_MAX_LATENCY_MS)

    fun median(values: List<Long>): Long {
        if (values.isEmpty()) return 0L
        val sorted = values.sorted()
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 1) sorted[middle] else (sorted[middle - 1] + sorted[middle]) / 2
    }

    /** Mean absolute difference between consecutive samples (RFC 3550 style, as speed tests report). */
    fun jitter(samples: List<Long>): Long {
        if (samples.size < 2) return 0L
        val differences = samples.zipWithNext { a, b -> abs(b - a) }
        return differences.average().roundToLong()
    }

    fun isRetransmission(sample: Long, median: Long) = sample >= median + RETRANSMISSION_PENALTY_MS

    /**
     * Whether the first round is suspicious enough to take five more samples:
     * a failure, a retransmission, high jitter or latency within 80% of the limit.
     */
    fun needsConfirmation(samples: List<Long>, attempted: Int, maxLatency: Int): Boolean {
        if (samples.size < attempted || samples.isEmpty()) return true
        val median = median(samples)
        val clean = samples.filterNot { isRetransmission(it, median) }
        if (clean.size < samples.size) return true
        val jitter = jitter(clean)
        return isJitterUnstable(jitter, median) || median * 10 >= maxLatency * 8L
    }

    /** Summarises the samples of one check, in the order they were collected. */
    fun summarize(samples: List<Long>, attempted: Int): LatencyResult {
        val total = attempted.coerceAtLeast(1)
        if (samples.isEmpty()) return LatencyResult(-1, -1, 100, 0, total)
        val median = median(samples)
        val clean = samples.filterNot { isRetransmission(it, median) }
        val lost = (total - samples.size) + (samples.size - clean.size)
        return LatencyResult(
            latency = median(clean),
            jitter = jitter(clean),
            failureRate = lost * 100 / total,
            successfulSamples = samples.size,
            totalSamples = total
        )
    }

    fun isJitterUnstable(jitter: Long, latency: Long) =
        jitter >= UNSTABLE_JITTER_MS && jitter * 3 >= latency

    fun classify(result: LatencyResult, maxLatency: Int): String = when {
        result.successfulSamples == 0 -> "offline"
        result.latency > maxLatency -> "slow"
        result.failureRate > 0 -> "slow"
        isJitterUnstable(result.jitter, result.latency) -> "slow"
        else -> "online"
    }

    /**
     * Probable cause as a language-neutral code. The service maps it to a localized string
     * (`diagnosis_<code>` in the strings.xml of each language) and also stores the code for Flutter.
     */
    fun diagnosis(input: DiagnosisInput): DiagnosisCode = with(input) {
        val weakWifi = transportType == "wifi" && signalLevel in 0..1
        when {
            transportType == "none" -> DiagnosisCode.NO_NETWORK
            captivePortal -> DiagnosisCode.CAPTIVE_PORTAL
            state == "offline" && dnsFailed -> DiagnosisCode.DNS_FAILURE
            state == "offline" && !validated -> DiagnosisCode.NO_INTERNET
            state == "offline" && weakWifi -> DiagnosisCode.WIFI_TOO_WEAK
            state == "offline" -> DiagnosisCode.NO_RESPONSE
            state == "online" && weakWifi -> DiagnosisCode.WEAK_SIGNAL_STABLE
            state == "online" -> DiagnosisCode.NONE
            weakWifi -> DiagnosisCode.WEAK_SIGNAL
            failureRate > 0 -> DiagnosisCode.PACKET_LOSS
            isJitterUnstable(jitter, latency) -> DiagnosisCode.HIGH_JITTER
            latency > maxLatency && regionalTarget -> DiagnosisCode.REGIONAL_DISTANCE
            latency > maxLatency -> DiagnosisCode.CONGESTED_ROUTE
            else -> DiagnosisCode.NONE
        }
    }
}

/**
 * Language-neutral probable causes, in priority order. [code] is what goes into the measurement
 * history and the snapshot (`diagnosisCode`); [REGIONAL_DISTANCE] takes the target name as its
 * only format argument.
 */
enum class DiagnosisCode(val code: String) {
    NO_NETWORK("no_network"),
    CAPTIVE_PORTAL("captive_portal"),
    DNS_FAILURE("dns_failure"),
    NO_INTERNET("no_internet"),
    WIFI_TOO_WEAK("wifi_too_weak"),
    NO_RESPONSE("no_response"),
    WEAK_SIGNAL_STABLE("weak_signal_stable"),
    NONE("none"),
    WEAK_SIGNAL("weak_signal"),
    PACKET_LOSS("packet_loss"),
    HIGH_JITTER("high_jitter"),
    REGIONAL_DISTANCE("regional_distance"),
    CONGESTED_ROUTE("congested_route");

    companion object {
        fun from(code: String?): DiagnosisCode? = values().firstOrNull { it.code == code }

        /**
         * Entries written before the codes existed only have the Portuguese text, which was the
         * only language back then; this recovers their code so Flutter can localize old history.
         */
        fun fromLegacyText(text: String?): DiagnosisCode? = when {
            text.isNullOrBlank() -> null
            text.startsWith("Distância até ") -> REGIONAL_DISTANCE
            else -> LEGACY_PT[text]
        }

        private val LEGACY_PT = mapOf(
            "Sem rede ativa no aparelho" to NO_NETWORK,
            "Rede exige login (portal cativo)" to CAPTIVE_PORTAL,
            "Falha ao resolver o endereço do servidor (DNS)" to DNS_FAILURE,
            "Rede conectada, mas sem acesso à internet" to NO_INTERNET,
            "Sinal Wi-Fi fraco demais para manter a conexão" to WIFI_TOO_WEAK,
            "Servidor ou rota sem resposta" to NO_RESPONSE,
            "Sinal Wi-Fi fraco, mas conexão estável" to WEAK_SIGNAL_STABLE,
            "Nenhuma anomalia detectada" to NONE,
            "Sinal Wi-Fi fraco" to WEAK_SIGNAL,
            "Perda de pacotes na rota" to PACKET_LOSS,
            "Oscilação alta na rota" to HIGH_JITTER,
            "Rota congestionada ou servidor distante" to CONGESTED_ROUTE
        )
    }
}
