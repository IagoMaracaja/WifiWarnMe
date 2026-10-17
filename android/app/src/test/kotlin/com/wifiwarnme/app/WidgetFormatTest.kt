package com.wifiwarnme.app

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetFormatTest {
    private val texts = PT_TEXTS

    private fun input(
        monitoring: Boolean = true,
        hasData: Boolean = true,
        state: String = "online",
        transportType: String = "wifi",
        networkName: String? = "NET_5G97B2C9",
        diagnosis: String? = null,
        latency: Long = 81,
        jitter: Long = 2,
        failureRate: Int = 0,
        lastCheck: String = "11:04",
        ribbon: List<String> = List(12) { "online" }
    ) = WidgetInput(monitoring, hasData, state, transportType, networkName, diagnosis, latency, jitter,
        failureRate, lastCheck, ribbon)

    @Test
    fun monitoringShowsTheLastCheckLikeTheNotification() {
        val card = WidgetFormat.card(input(), texts)
        assertEquals("online", card.state)
        assertEquals("NET_5G97B2C9", card.networkName)
        assertEquals("Conectado", card.stateTitle)
        assertEquals("Internet estável", card.stateSubtitle)
        assertEquals("81 ms", card.ping)
        assertEquals("2 ms", card.jitter)
        assertEquals("11:04", card.lastCheck)
        assertEquals(List(12) { "online" }, card.ribbon)
        assertEquals("81 ms", WidgetFormat.headline(card))
        assertEquals(" · Conectado", WidgetFormat.caption(card))
    }

    @Test
    fun unstableShowsTheProbableCause() {
        val card = WidgetFormat.card(input(state = "slow", diagnosis = "Perda de pacotes na rota", failureRate = 10), texts)
        assertEquals("Instável", card.stateTitle)
        assertEquals("Perda de pacotes na rota", card.stateSubtitle)
        assertEquals(MonitorCardFormat.SLOW, card.lossColor)
    }

    @Test
    fun offlineHeadlineFallsBackToTheState() {
        val card = WidgetFormat.card(input(state = "offline", latency = -1, jitter = -1, failureRate = 100), texts)
        assertEquals("—", card.ping)
        assertEquals("Sem internet", WidgetFormat.headline(card))
        assertEquals("", WidgetFormat.caption(card))
    }

    @Test
    fun pausedKeepsTheLastValuesInGrey() {
        val card = WidgetFormat.card(input(monitoring = false), texts)
        assertEquals(MonitorCardFormat.PAUSED, card.state)
        assertEquals("Pausado", card.stateTitle)
        assertEquals("Monitoramento pausado", card.stateSubtitle)
        assertEquals("81 ms", card.ping)
        assertEquals(MonitorCardFormat.SECONDARY, card.lossColor)
        assertEquals(MonitorCardFormat.PAUSED_COLOR, MonitorCardFormat.stateColor(card.state))
        assertEquals(" · Pausado", WidgetFormat.caption(card))
    }

    @Test
    fun withoutAnyCheckTheCardWaits() {
        val running = WidgetFormat.card(input(hasData = false, state = "online", lastCheck = "08:00"), texts)
        assertEquals("checking", running.state)
        assertEquals("Verificando…", running.stateTitle)
        assertEquals("Medição em andamento", running.stateSubtitle)
        assertEquals("—", running.ping)
        assertEquals("—", running.lastCheck)
        assertEquals("Verificando…", WidgetFormat.headline(running))

        val paused = WidgetFormat.card(input(monitoring = false, hasData = false, transportType = "none", networkName = null), texts)
        assertEquals("Pausado", paused.stateTitle)
        assertEquals("Sem conexão", paused.networkName)
        assertEquals("Pausado", WidgetFormat.headline(paused))
    }
}
