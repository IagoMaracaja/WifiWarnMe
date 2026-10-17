package com.wifiwarnme.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationCardTest {
    private val texts = NotificationTexts(
        pillOnline = "Estável", pillSlow = "Instável", pillOffline = "Sem resposta", pillChecking = "Verificando",
        latencyCaption = "latência · limite %1\$d ms",
        noResponseCaption = "%1\$d de %2\$d conexões · limite %3\$d ms",
        band = "Wi-Fi %1\$s GHz", signalWeak = "sinal fraco", signalFair = "sinal regular", signalGood = "sinal bom",
        connectedNoInternet = "conectado sem internet", cellular = "Dados móveis", ethernet = "Ethernet",
        noConnection = "Sem conexão",
        stableWindow = "Estável, sem problemas há %1\$d min.", stable = "Internet estável.",
        problemSince = "%1\$s há %2\$d min.", firstCheck = "Primeira medição em andamento",
        axisStart = "−%1\$d min"
    )

    private val minute = 60_000L
    private val now = 1_000 * minute

    private fun history(vararg states: String, latency: Long = 80) = states.mapIndexed { index, state ->
        HistoryEntry("Cloudflare", state, if (state == "offline") -1 else latency,
            now - (states.size - 1 - index) * 2 * minute)
    }

    private fun input(
        state: String,
        latency: Long = 81,
        jitter: Long = 2,
        failureRate: Int = 0,
        history: List<HistoryEntry> = history("online", "online"),
        diagnosis: String? = null,
        validated: Boolean = true,
        problemFor: Long = 0
    ) = NotificationInput(
        state = state, transportType = "wifi", networkName = "NET_5G97B2C9", frequencyMhz = 5_180,
        signalLevel = 4, rssi = -58, validated = validated, latency = latency, jitter = jitter,
        failureRate = failureRate, successfulSamples = if (state == "offline") 0 else 5, totalSamples = 5,
        maxLatency = 300, diagnosis = diagnosis, problemFor = problemFor, measuredAt = "00:20",
        history = history, now = now
    )

    @Test
    fun stableCardMatchesTheDesign() {
        val card = NotificationFormat.card(input("online", history = history(*Array(12) { "online" })), texts)
        assertEquals("Estável", card.pill)
        assertEquals("Wi-Fi 5 GHz · sinal bom", card.subtitle)
        assertEquals("81", card.latency)
        assertEquals("latência · limite 300 ms", card.caption)
        assertEquals("2 ms", card.jitter)
        assertEquals("0%", card.loss)
        assertEquals("-58 dBm", card.signal)
        assertEquals("Estável, sem problemas há 22 min.", card.diagnosis)
        assertEquals(DiagnosisKind.OK, card.diagnosisKind)
        assertEquals("−22 min", card.axisStart)
        assertEquals(12, card.bars.size)
    }

    @Test
    fun unstableCardHighlightsJitterAndShowsTheCause() {
        val card = NotificationFormat.card(
            input("slow", latency = 382, jitter = 146, diagnosis = "Rota congestionada ou servidor distante"), texts)
        assertEquals("Instável", card.pill)
        assertEquals(MonitorCardFormat.SLOW, card.jitterColor)
        assertEquals("Rota congestionada ou servidor distante.", card.diagnosis)
        assertEquals(DiagnosisKind.WARN, card.diagnosisKind)
    }

    @Test
    fun offlineCardSaysForHowLong() {
        val card = NotificationFormat.card(input("offline", latency = -1, jitter = -1, failureRate = 100,
            diagnosis = "Servidor ou rota sem resposta", validated = false, problemFor = 16 * minute,
            history = history("online", "offline", "offline")), texts)
        assertEquals("Sem resposta", card.pill)
        assertEquals(MonitorCardFormat.NO_VALUE, card.latency)
        assertEquals("0 de 5 conexões · limite 300 ms", card.caption)
        assertEquals("Wi-Fi 5 GHz · conectado sem internet", card.subtitle)
        assertEquals(MonitorCardFormat.NO_VALUE, card.jitter)
        assertEquals("100%", card.loss)
        assertEquals(MonitorCardFormat.OFFLINE, card.lossColor)
        assertEquals("Servidor ou rota sem resposta há 16 min.", card.diagnosis)
    }

    @Test
    fun barsArePaddedOldestFirst() {
        val bars = NotificationFormat.bars(history("online", "slow"))
        assertEquals(12, bars.size)
        assertEquals(MonitorCardFormat.EMPTY, bars.first().state)
        assertEquals("slow", bars.last().state)
    }

    @Test
    fun recentProblemHidesTheCleanWindow() {
        assertEquals(0, NotificationFormat.cleanWindowMinutes(history("slow", "online"), now))
        assertEquals("Internet estável.", NotificationFormat.card(input("online", history = history("online")), texts).diagnosis)
    }

    @Test
    fun bandFromFrequency() {
        assertEquals("2.4", NotificationFormat.band(2_437))
        assertEquals("5", NotificationFormat.band(5_745))
        assertEquals("6", NotificationFormat.band(6_115))
        assertNull(NotificationFormat.band(0))
    }

    @Test
    fun chartScaleKeepsRoomAboveTheLimit() {
        val bars = listOf(ChartBar("online", 80), ChartBar("offline", -1))
        val max = ChartScale.max(bars, 300)
        assertEquals(300 * 1.35 * 1.05, max, 0.001)
        assertNull(ChartScale.height(bars[1], max))
        assertTrue(ChartScale.limitLine(300, max) < 1.0)
        // A spike above the scale still fits.
        assertEquals(1.0, ChartScale.height(ChartBar("slow", 900), ChartScale.max(listOf(ChartBar("slow", 900)), 300))!!, 0.05)
    }
}
