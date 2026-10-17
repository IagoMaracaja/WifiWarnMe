package com.wifiwarnme.app

/**
 * Texts, colours and the state ribbon of the persistent monitor card, without Android types so
 * they can be unit tested. [MonitorNotificationViews] and [MonitorWidgets] turn a [MonitorCard]
 * into RemoteViews.
 */
data class MonitorCard(
    /** "online", "slow", "offline", "checking" or [MonitorCardFormat.PAUSED] (widgets only). */
    val state: String,
    /** "wifi", "cellular", "ethernet" or "none"; selects the tile icon. */
    val transportType: String,
    val networkName: String,
    val stateTitle: String,
    val stateSubtitle: String,
    val ping: String,
    val jitter: String,
    val loss: String,
    val lossColor: Int,
    val lastCheck: String,
    /** Oldest first, always [MonitorCardFormat.RIBBON_SIZE] items; "empty" pads missing checks. */
    val ribbon: List<String>
)

/**
 * The localized words of the card, resolved from the string resources by [NativeText.cardTexts]
 * so this file stays free of Android types.
 */
data class CardTexts(
    val titleOnline: String,
    val titleSlow: String,
    val titleOffline: String,
    val titleChecking: String,
    val subtitleOnline: String,
    val subtitleSlow: String,
    val subtitleOffline: String,
    val subtitleChecking: String,
    val cellular: String,
    val ethernet: String,
    val noConnection: String,
    val paused: String,
    val monitoringPaused: String
)

/** One past check, as read from the measurement history. */
data class RibbonEntry(val targetName: String, val state: String)

object MonitorCardFormat {
    const val RIBBON_SIZE = 12
    const val EMPTY = "empty"
    const val PAUSED = "paused"
    const val WIFI = "Wi-Fi"
    const val NO_VALUE = "—"

    // Same palette as the Flutter UI (docs/linkzora.md, "Padrão visual").
    const val ONLINE = 0xFF20E3A2.toInt()
    const val SLOW = 0xFFFFC857.toInt()
    const val OFFLINE = 0xFFFF6B78.toInt()
    const val CHECKING = 0xFF70B7FF.toInt()
    const val PAUSED_COLOR = 0xFF8193A5.toInt()
    const val JITTER = 0xFF28B8F0.toInt()
    const val EMPTY_SEGMENT = 0xFF263646.toInt()
    const val SECONDARY = 0xFF97A8B8.toInt()

    fun stateColor(state: String): Int = when (state) {
        "online" -> ONLINE
        "slow" -> SLOW
        "offline" -> OFFLINE
        EMPTY -> EMPTY_SEGMENT
        PAUSED -> PAUSED_COLOR
        else -> CHECKING
    }

    fun stateTitle(state: String, texts: CardTexts): String = when (state) {
        "online" -> texts.titleOnline
        "slow" -> texts.titleSlow
        "offline" -> texts.titleOffline
        PAUSED -> texts.paused
        else -> texts.titleChecking
    }

    /**
     * Second line under the state; an unstable connection shows its probable cause. [diagnosis]
     * is the localized cause, or null when there is no anomaly ([DiagnosisCode.NONE]).
     */
    fun stateSubtitle(state: String, diagnosis: String?, texts: CardTexts): String = when (state) {
        "online" -> texts.subtitleOnline
        "slow" -> diagnosis?.takeIf { it.isNotBlank() } ?: texts.subtitleSlow
        "offline" -> texts.subtitleOffline
        PAUSED -> texts.monitoringPaused
        else -> texts.subtitleChecking
    }

    /** The Wi-Fi name when Android reveals it, otherwise the transport. */
    fun networkName(transportType: String, networkName: String?, texts: CardTexts): String = when (transportType) {
        "wifi" -> networkName?.takeIf { it.isNotBlank() } ?: WIFI
        "cellular" -> texts.cellular
        "ethernet" -> texts.ethernet
        else -> texts.noConnection
    }

    fun milliseconds(value: Long?): String = if (value == null || value < 0) NO_VALUE else "$value ms"

    /** Green without loss, otherwise the colour of the state that the loss caused. */
    fun lossColor(state: String, failureRate: Int?): Int = when {
        state == "checking" || state == PAUSED || failureRate == null || failureRate < 0 -> SECONDARY
        failureRate == 0 -> ONLINE
        state == "offline" -> OFFLINE
        else -> SLOW
    }

    fun percent(value: Int?): String = if (value == null || value < 0) NO_VALUE else "$value%"

    /**
     * The last [size] states measured against [targetName], oldest first, padded at the start
     * with [EMPTY] so the ribbon keeps a fixed number of segments.
     */
    fun ribbon(history: List<RibbonEntry>, targetName: String, size: Int = RIBBON_SIZE): List<String> {
        val recent = history.asSequence()
            .filter { it.targetName == targetName }
            .map { it.state.takeIf { state -> state in setOf("online", "slow", "offline") } ?: "offline" }
            .toList()
            .takeLast(size)
        return List(size - recent.size) { EMPTY } + recent
    }

    fun card(
        state: String,
        transportType: String,
        networkName: String?,
        diagnosis: String?,
        latency: Long?,
        jitter: Long?,
        failureRate: Int?,
        lastCheck: String,
        ribbon: List<String>,
        texts: CardTexts
    ): MonitorCard {
        val measured = state == "online" || state == "slow"
        return MonitorCard(
            state = state,
            transportType = transportType,
            networkName = networkName(transportType, networkName, texts),
            stateTitle = stateTitle(state, texts),
            stateSubtitle = stateSubtitle(state, diagnosis, texts),
            ping = milliseconds(latency.takeIf { measured }),
            jitter = milliseconds(jitter.takeIf { measured }),
            loss = percent(failureRate.takeIf { state != "checking" }),
            lossColor = lossColor(state, failureRate),
            lastCheck = lastCheck,
            ribbon = ribbon
        )
    }
}

/** What the home screen widgets read from the native preferences after each check. */
data class WidgetInput(
    /** The service is running and continuous monitoring is on (not a one-shot probe). */
    val monitoring: Boolean,
    /** At least one check was published (`lastCheckedAt > 0`). */
    val hasData: Boolean,
    val state: String,
    val transportType: String,
    val networkName: String?,
    /** Localized probable cause, or null when there is none. */
    val diagnosis: String?,
    val latency: Long,
    val jitter: Long,
    val failureRate: Int,
    /** "HH:mm" of the last check, or [MonitorCardFormat.NO_VALUE]. */
    val lastCheck: String,
    val ribbon: List<String>
)

/** Card shown by the home screen widgets; the same model as the notification plus a paused state. */
object WidgetFormat {
    fun card(input: WidgetInput, texts: CardTexts): MonitorCard {
        val state = if (input.hasData) input.state else "checking"
        val base = MonitorCardFormat.card(
            state = state,
            transportType = input.transportType,
            networkName = input.networkName,
            diagnosis = input.diagnosis,
            latency = input.latency,
            jitter = input.jitter,
            failureRate = input.failureRate,
            lastCheck = if (input.hasData) input.lastCheck else MonitorCardFormat.NO_VALUE,
            ribbon = input.ribbon,
            texts = texts
        )
        if (input.monitoring) return base
        // Paused: grey state, the last measured values stay visible as history.
        return base.copy(
            state = MonitorCardFormat.PAUSED,
            stateTitle = texts.paused,
            stateSubtitle = texts.monitoringPaused,
            lossColor = MonitorCardFormat.SECONDARY
        )
    }

    /** Small widget value next to the dot: the latency, or the state when there is none. */
    fun headline(card: MonitorCard): String =
        card.ping.takeIf { it != MonitorCardFormat.NO_VALUE } ?: card.stateTitle

    /** Small widget caption after the headline: the state, unless the headline already is it. */
    fun caption(card: MonitorCard): String =
        if (headline(card) == card.stateTitle) "" else " · ${card.stateTitle}"
}
