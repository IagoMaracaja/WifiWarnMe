package com.linkzora.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConnectionMathTest {
    @Test
    fun medianOfOddAndEvenLists() {
        assertEquals(30L, ConnectionMath.median(listOf(50, 10, 30)))
        assertEquals(25L, ConnectionMath.median(listOf(40, 10, 20, 30)))
        assertEquals(0L, ConnectionMath.median(emptyList()))
    }

    @Test
    fun jitterIsMeanDifferenceBetweenConsecutiveSamples() {
        // |22-20| + |30-22| + |28-30| = 12 over 3 differences.
        assertEquals(4L, ConnectionMath.jitter(listOf(20, 22, 30, 28)))
        assertEquals(0L, ConnectionMath.jitter(listOf(42)))
    }

    @Test
    fun stableSamplesSummarizeWithoutLoss() {
        val result = ConnectionMath.summarize(listOf(70, 72, 71, 75, 70), attempted = 5)
        assertEquals(71L, result.latency)
        assertEquals(0, result.failureRate)
        assertEquals(5, result.successfulSamples)
        assertEquals("online", ConnectionMath.classify(result, maxLatency = 300))
    }

    @Test
    fun synRetransmissionCountsAsLossAndDoesNotInflateJitter() {
        // The fourth handshake only completed after the 1 s SYN retransmission.
        val samples = listOf<Long>(70, 72, 71, 1_071, 70, 72, 71, 73, 70, 71)
        val result = ConnectionMath.summarize(samples, attempted = 10)
        assertEquals(71L, result.latency)
        assertEquals(10, result.failureRate)
        assertTrue(result.jitter < 5)
        assertEquals("slow", ConnectionMath.classify(result, maxLatency = 300))
    }

    @Test
    fun failedConnectionsCountAsLoss() {
        val result = ConnectionMath.summarize(listOf(80, 82, 81, 79), attempted = 5)
        assertEquals(20, result.failureRate)
        assertEquals(4, result.successfulSamples)
    }

    @Test
    fun noSamplesMeansOffline() {
        val result = ConnectionMath.summarize(emptyList(), attempted = 5)
        assertEquals(-1L, result.latency)
        assertEquals(100, result.failureRate)
        assertEquals("offline", ConnectionMath.classify(result, maxLatency = 300))
    }

    @Test
    fun latencyAboveLimitIsSlow() {
        val result = ConnectionMath.summarize(listOf(320, 330, 325, 322, 321), attempted = 5)
        assertEquals("slow", ConnectionMath.classify(result, maxLatency = 300))
    }

    @Test
    fun highJitterIsSlowEvenUnderTheLimit() {
        val result = ConnectionMath.summarize(listOf(40, 140, 50, 150, 45), attempted = 5)
        assertTrue(ConnectionMath.isJitterUnstable(result.jitter, result.latency))
        assertEquals("slow", ConnectionMath.classify(result, maxLatency = 300))
    }

    @Test
    fun confirmationOnlyForSuspiciousRounds() {
        assertFalse(ConnectionMath.needsConfirmation(listOf(70, 71, 72, 70, 71), 5, 300))
        assertTrue(ConnectionMath.needsConfirmation(listOf(70, 71, 72, 70), 5, 300))
        assertTrue(ConnectionMath.needsConfirmation(listOf(70, 71, 1_072, 70, 71), 5, 300))
        // 250 ms is within 80% of a 300 ms limit.
        assertTrue(ConnectionMath.needsConfirmation(listOf(250, 251, 249, 250, 252), 5, 300))
    }

    private fun input(
        state: String,
        transportType: String = "wifi",
        signalLevel: Int = 4,
        latency: Long = 70,
        jitter: Long = 2,
        failureRate: Int = 0,
        regional: Boolean = false,
        validated: Boolean = true,
        captive: Boolean = false,
        dnsFailed: Boolean = false
    ) = DiagnosisInput(state, transportType, latency, jitter, failureRate, signalLevel,
        "Europa", 300, regional, validated, captive, dnsFailed)

    @Test
    fun diagnosisSeparatesOfflineCauses() {
        assertEquals(DiagnosisCode.NO_NETWORK,
            ConnectionMath.diagnosis(input("offline", transportType = "none")))
        assertEquals(DiagnosisCode.CAPTIVE_PORTAL,
            ConnectionMath.diagnosis(input("offline", captive = true)))
        assertEquals(DiagnosisCode.DNS_FAILURE,
            ConnectionMath.diagnosis(input("offline", dnsFailed = true)))
        assertEquals(DiagnosisCode.NO_INTERNET,
            ConnectionMath.diagnosis(input("offline", validated = false)))
        assertEquals(DiagnosisCode.WIFI_TOO_WEAK,
            ConnectionMath.diagnosis(input("offline", signalLevel = 1)))
        assertEquals(DiagnosisCode.NO_RESPONSE,
            ConnectionMath.diagnosis(input("offline")))
    }

    @Test
    fun diagnosisExplainsInstability() {
        assertEquals(DiagnosisCode.WEAK_SIGNAL, ConnectionMath.diagnosis(input("slow", signalLevel = 1)))
        assertEquals(DiagnosisCode.PACKET_LOSS, ConnectionMath.diagnosis(input("slow", failureRate = 10)))
        assertEquals(DiagnosisCode.HIGH_JITTER, ConnectionMath.diagnosis(input("slow", latency = 90, jitter = 40)))
        assertEquals(DiagnosisCode.REGIONAL_DISTANCE,
            ConnectionMath.diagnosis(input("slow", latency = 420, regional = true)))
        assertEquals(DiagnosisCode.CONGESTED_ROUTE,
            ConnectionMath.diagnosis(input("slow", latency = 420)))
    }

    @Test
    fun weakSignalWithStableConnectionIsOnlyInformative() {
        assertEquals(DiagnosisCode.WEAK_SIGNAL_STABLE,
            ConnectionMath.diagnosis(input("online", signalLevel = 0)))
        assertEquals(DiagnosisCode.NONE, ConnectionMath.diagnosis(input("online")))
        // Captive portal wins over the state; weak signal on cellular is ignored.
        assertEquals(DiagnosisCode.CAPTIVE_PORTAL, ConnectionMath.diagnosis(input("online", captive = true)))
        assertEquals(DiagnosisCode.NONE, ConnectionMath.diagnosis(input("online", transportType = "cellular", signalLevel = 0)))
    }

    @Test
    fun diagnosisCodesAreStableAndUnique() {
        // Flutter reads these strings from `diagnosisCode`; renaming one breaks its localization.
        assertEquals(
            listOf("no_network", "captive_portal", "dns_failure", "no_internet", "wifi_too_weak",
                "no_response", "weak_signal_stable", "none", "weak_signal", "packet_loss",
                "high_jitter", "regional_distance", "congested_route"),
            DiagnosisCode.values().map { it.code }
        )
        DiagnosisCode.values().forEach { assertEquals(it, DiagnosisCode.from(it.code)) }
        assertEquals(null, DiagnosisCode.from("unknown"))
        assertEquals(null, DiagnosisCode.from(null))
    }

    @Test
    fun legacyPortugueseTextsMapToCodes() {
        assertEquals(DiagnosisCode.PACKET_LOSS, DiagnosisCode.fromLegacyText("Perda de pacotes na rota"))
        assertEquals(DiagnosisCode.NONE, DiagnosisCode.fromLegacyText("Nenhuma anomalia detectada"))
        assertEquals(DiagnosisCode.REGIONAL_DISTANCE,
            DiagnosisCode.fromLegacyText("Distância até Europa influencia a latência"))
        assertEquals(DiagnosisCode.NO_INTERNET,
            DiagnosisCode.fromLegacyText("Rede conectada, mas sem acesso à internet"))
        assertEquals(null, DiagnosisCode.fromLegacyText("Packet loss on the route"))
        assertEquals(null, DiagnosisCode.fromLegacyText(""))
        assertEquals(null, DiagnosisCode.fromLegacyText(null))
    }

    @Test
    fun maxLatencyIsClampedTo30Through2000() {
        assertEquals(30, ConnectionMath.clampMaxLatency(10))
        assertEquals(30, ConnectionMath.clampMaxLatency(30))
        assertEquals(60, ConnectionMath.clampMaxLatency(60))
        assertEquals(80, ConnectionMath.clampMaxLatency(80))
        assertEquals(100, ConnectionMath.clampMaxLatency(100))
        assertEquals(2000, ConnectionMath.clampMaxLatency(2000))
        assertEquals(2000, ConnectionMath.clampMaxLatency(5000))
    }

    @Test
    fun lowLimitsClassifyAndConfirmAgainstTheLimit() {
        val fast = LatencyResult(latency = 25, jitter = 2, failureRate = 0, successfulSamples = 5, totalSamples = 5)
        val over = fast.copy(latency = 45)
        assertEquals("online", ConnectionMath.classify(fast, 30))
        assertEquals("slow", ConnectionMath.classify(over, 30))
        assertEquals("online", ConnectionMath.classify(over, 60))
        // 80% of a 30 ms limit is 24 ms, so a 25 ms median takes the confirmation round.
        assertTrue(ConnectionMath.needsConfirmation(listOf(25, 25, 25, 25, 25), 5, 30))
        assertFalse(ConnectionMath.needsConfirmation(listOf(20, 20, 20, 20, 20), 5, 30))
    }
}
