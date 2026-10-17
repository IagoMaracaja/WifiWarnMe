package com.linkzora.app

import org.junit.Assert.assertEquals
import org.junit.Test

/** The Portuguese words from res/values/strings.xml, as NativeText.cardTexts resolves them. */
val PT_TEXTS = CardTexts(
    titleOnline = "Conectado",
    titleSlow = "Instável",
    titleOffline = "Sem internet",
    titleChecking = "Verificando…",
    subtitleOnline = "Internet estável",
    subtitleSlow = "Conexão instável",
    subtitleOffline = "Sem resposta",
    subtitleChecking = "Medição em andamento",
    cellular = "Dados móveis",
    ethernet = "Ethernet",
    noConnection = "Sem conexão",
    paused = "Pausado",
    monitoringPaused = "Monitoramento pausado"
)

class MonitorCardTest {
    private val empty = MonitorCardFormat.EMPTY
    private val texts = PT_TEXTS

    @Test
    fun stateTitlesAndSubtitles() {
        assertEquals("Conectado", MonitorCardFormat.stateTitle("online", texts))
        assertEquals("Internet estável", MonitorCardFormat.stateSubtitle("online", null, texts))
        assertEquals("Instável", MonitorCardFormat.stateTitle("slow", texts))
        assertEquals("Perda de pacotes na rota", MonitorCardFormat.stateSubtitle("slow", "Perda de pacotes na rota", texts))
        // No anomaly (DiagnosisCode.NONE) arrives as null; blank texts are ignored too.
        assertEquals("Conexão instável", MonitorCardFormat.stateSubtitle("slow", null, texts))
        assertEquals("Conexão instável", MonitorCardFormat.stateSubtitle("slow", " ", texts))
        assertEquals("Sem internet", MonitorCardFormat.stateTitle("offline", texts))
        assertEquals("Sem resposta", MonitorCardFormat.stateSubtitle("offline", "Servidor ou rota sem resposta", texts))
        assertEquals("Verificando…", MonitorCardFormat.stateTitle("checking", texts))
        assertEquals("Verificando…", MonitorCardFormat.stateTitle("unknown", texts))
        assertEquals("Pausado", MonitorCardFormat.stateTitle(MonitorCardFormat.PAUSED, texts))
        assertEquals("Monitoramento pausado", MonitorCardFormat.stateSubtitle(MonitorCardFormat.PAUSED, null, texts))
    }

    @Test
    fun textsComeFromTheGivenLanguage() {
        val english = texts.copy(titleOnline = "Connected", subtitleOnline = "Stable internet", cellular = "Mobile data")
        assertEquals("Connected", MonitorCardFormat.stateTitle("online", english))
        assertEquals("Stable internet", MonitorCardFormat.stateSubtitle("online", null, english))
        assertEquals("Mobile data", MonitorCardFormat.networkName("cellular", "Dados móveis", english))
    }

    @Test
    fun stateColorsFollowTheAppPalette() {
        assertEquals(0xFF20E3A2.toInt(), MonitorCardFormat.stateColor("online"))
        assertEquals(0xFFFFC857.toInt(), MonitorCardFormat.stateColor("slow"))
        assertEquals(0xFFFF6B78.toInt(), MonitorCardFormat.stateColor("offline"))
        assertEquals(0xFF70B7FF.toInt(), MonitorCardFormat.stateColor("checking"))
        assertEquals(MonitorCardFormat.EMPTY_SEGMENT, MonitorCardFormat.stateColor(empty))
        assertEquals(MonitorCardFormat.PAUSED_COLOR, MonitorCardFormat.stateColor(MonitorCardFormat.PAUSED))
    }

    @Test
    fun networkNameFallsBackToTransport() {
        assertEquals("NET_5G97B2C9", MonitorCardFormat.networkName("wifi", "NET_5G97B2C9", texts))
        assertEquals("Wi-Fi", MonitorCardFormat.networkName("wifi", " ", texts))
        assertEquals("Wi-Fi", MonitorCardFormat.networkName("wifi", null, texts))
        assertEquals("Dados móveis", MonitorCardFormat.networkName("cellular", "Dados móveis", texts))
        assertEquals("Ethernet", MonitorCardFormat.networkName("ethernet", null, texts))
        assertEquals("Sem conexão", MonitorCardFormat.networkName("none", "Sem conexão", texts))
    }

    @Test
    fun formatsMetrics() {
        assertEquals("81 ms", MonitorCardFormat.milliseconds(81))
        assertEquals("0 ms", MonitorCardFormat.milliseconds(0))
        assertEquals("—", MonitorCardFormat.milliseconds(-1))
        assertEquals("—", MonitorCardFormat.milliseconds(null))
        assertEquals("0%", MonitorCardFormat.percent(0))
        assertEquals("20%", MonitorCardFormat.percent(20))
        assertEquals("—", MonitorCardFormat.percent(null))
    }

    @Test
    fun lossColorDependsOnLossAndState() {
        assertEquals(MonitorCardFormat.ONLINE, MonitorCardFormat.lossColor("online", 0))
        assertEquals(MonitorCardFormat.SLOW, MonitorCardFormat.lossColor("slow", 20))
        assertEquals(MonitorCardFormat.OFFLINE, MonitorCardFormat.lossColor("offline", 100))
        assertEquals(MonitorCardFormat.SECONDARY, MonitorCardFormat.lossColor("checking", 0))
        assertEquals(MonitorCardFormat.SECONDARY, MonitorCardFormat.lossColor(MonitorCardFormat.PAUSED, 0))
    }

    @Test
    fun ribbonKeepsLastChecksOfTheCurrentServerPaddedAtTheStart() {
        val history = listOf(
            RibbonEntry("São Paulo", "online"),
            RibbonEntry("Europa", "offline"),
            RibbonEntry("São Paulo", "slow"),
            RibbonEntry("São Paulo", "online")
        )
        val ribbon = MonitorCardFormat.ribbon(history, "São Paulo")
        assertEquals(MonitorCardFormat.RIBBON_SIZE, ribbon.size)
        assertEquals(List(9) { empty } + listOf("online", "slow", "online"), ribbon)
        assertEquals(List(12) { empty }, MonitorCardFormat.ribbon(emptyList(), "São Paulo"))
    }

    @Test
    fun ribbonDropsOlderChecksAndTreatsUnknownStatesAsOffline() {
        val history = List(20) { RibbonEntry("Cloudflare", if (it < 10) "offline" else "online") } +
            RibbonEntry("Cloudflare", "weird")
        val ribbon = MonitorCardFormat.ribbon(history, "Cloudflare")
        assertEquals(listOf("offline") + List(10) { "online" } + "offline", ribbon)
    }

    @Test
    fun onlineCardMatchesTheMockup() {
        val card = MonitorCardFormat.card(
            state = "online", transportType = "wifi", networkName = "NET_5G97B2C9",
            diagnosis = null, latency = 81, jitter = 2, failureRate = 0,
            lastCheck = "11:04", ribbon = List(12) { "online" }, texts = texts
        )
        assertEquals("NET_5G97B2C9", card.networkName)
        assertEquals("Conectado", card.stateTitle)
        assertEquals("Internet estável", card.stateSubtitle)
        assertEquals("81 ms", card.ping)
        assertEquals("2 ms", card.jitter)
        assertEquals("0%", card.loss)
        assertEquals(MonitorCardFormat.ONLINE, card.lossColor)
        assertEquals("11:04", card.lastCheck)
    }

    @Test
    fun offlineAndCheckingCardsHideMetrics() {
        val offline = MonitorCardFormat.card(
            state = "offline", transportType = "wifi", networkName = "Casa",
            diagnosis = "Servidor ou rota sem resposta", latency = -1, jitter = -1, failureRate = 100,
            lastCheck = "11:05", ribbon = emptyList(), texts = texts
        )
        assertEquals("Sem internet", offline.stateTitle)
        assertEquals("—", offline.ping)
        assertEquals("—", offline.jitter)
        assertEquals("100%", offline.loss)
        assertEquals(MonitorCardFormat.OFFLINE, offline.lossColor)

        val checking = MonitorCardFormat.card(
            state = "checking", transportType = "none", networkName = null, diagnosis = null,
            latency = null, jitter = null, failureRate = null, lastCheck = "—", ribbon = emptyList(),
            texts = texts
        )
        assertEquals("Sem conexão", checking.networkName)
        assertEquals("Verificando…", checking.stateTitle)
        assertEquals("—", checking.ping)
        assertEquals("—", checking.loss)
    }
}
