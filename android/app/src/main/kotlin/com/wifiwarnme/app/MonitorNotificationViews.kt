package com.wifiwarnme.app

import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/**
 * Custom views of the persistent monitor notification (the dark card from the design mockup).
 *
 * Android 16 Live Updates (promoted ongoing notifications) are not allowed to use custom content
 * views, so the card is only used below API 36; from API 36 on, [MonitorService] keeps the
 * standard template and requests promotion (status bar chip, lock screen, AOD).
 *
 * The binders are shared with the home screen widgets ([MonitorWidgets]), which use the same view
 * ids. Setting a view that a layout does not have is a no-op for RemoteViews.
 */
object MonitorNotificationViews {
    fun supported(): Boolean = Build.VERSION.SDK_INT < 36

    /** About 48dp: tile, network name, state and ping. */
    fun collapsed(context: Context, card: MonitorCard): RemoteViews =
        RemoteViews(context.packageName, R.layout.notification_monitor_compact).apply {
            bindHeader(card)
            val color = MonitorCardFormat.stateColor(card.state)
            setTextViewText(R.id.monitor_detail, " · ${card.stateSubtitle}")
            setTextViewText(R.id.monitor_ping, card.ping.takeIf { it != MonitorCardFormat.NO_VALUE } ?: "")
            setTextColor(R.id.monitor_ping, color)
        }

    /** The full card: identity, ping and jitter, the state ribbon, loss and last check time. */
    fun expanded(context: Context, card: MonitorCard): RemoteViews =
        RemoteViews(context.packageName, R.layout.notification_monitor_expanded).apply {
            bindCard(context, card)
        }

    /** Everything of the expanded card; also used by the large widget. */
    internal fun RemoteViews.bindCard(context: Context, card: MonitorCard) {
        bindHeader(card)
        bindLabels(context)
        setTextViewText(R.id.monitor_detail, card.stateSubtitle)
        bindMetrics(card)
        bindRibbon(card)
        setTextViewText(R.id.loss_value, card.loss)
        setTextColor(R.id.loss_value, card.lossColor)
        tint(R.id.loss_icon, MonitorCardFormat.SECONDARY)
        tint(R.id.clock_icon, MonitorCardFormat.SECONDARY)
        setTextViewText(R.id.last_check_value, card.lastCheck)
    }

    /**
     * Static labels. The host inflates RemoteViews with the system locale, so the layout's
     * @string values would ignore the app language; they are set again from [NativeLocale].
     */
    internal fun RemoteViews.bindLabels(context: Context) {
        val localized = NativeLocale.localized(context)
        setTextViewText(R.id.ping_label, localized.getString(R.string.card_ping))
        setTextViewText(R.id.jitter_label, localized.getString(R.string.card_jitter))
        setTextViewText(R.id.loss_label, localized.getString(R.string.card_loss))
        setTextViewText(R.id.last_check_label, localized.getString(R.string.card_last_check))
    }

    internal fun RemoteViews.bindMetrics(card: MonitorCard) {
        val color = MonitorCardFormat.stateColor(card.state)
        setTextViewText(R.id.ping_value, card.ping)
        setTextColor(R.id.ping_value, color)
        tint(R.id.ping_badge, color, alpha = 46)
        tint(R.id.ping_icon, color)

        setTextViewText(R.id.jitter_value, card.jitter)
        setTextColor(R.id.jitter_value, MonitorCardFormat.JITTER)
        tint(R.id.jitter_badge, MonitorCardFormat.JITTER, alpha = 46)
        tint(R.id.jitter_icon, MonitorCardFormat.JITTER)
    }

    internal fun RemoteViews.bindRibbon(card: MonitorCard) {
        card.ribbon.forEachIndexed { index, state ->
            tint(RIBBON_IDS[index], MonitorCardFormat.stateColor(state))
        }
        tint(R.id.ribbon_glow, MonitorCardFormat.stateColor(card.ribbon.lastOrNull() ?: card.state), alpha = 150)
    }

    private val RIBBON_IDS = intArrayOf(
        R.id.ribbon_0, R.id.ribbon_1, R.id.ribbon_2, R.id.ribbon_3, R.id.ribbon_4, R.id.ribbon_5,
        R.id.ribbon_6, R.id.ribbon_7, R.id.ribbon_8, R.id.ribbon_9, R.id.ribbon_10, R.id.ribbon_11
    ).also { check(it.size == MonitorCardFormat.RIBBON_SIZE) }

    private fun transportIcon(transportType: String) = when (transportType) {
        "wifi" -> R.drawable.ic_monitor_wifi
        "cellular" -> R.drawable.ic_monitor_cellular
        "ethernet" -> R.drawable.ic_monitor_ethernet
        else -> R.drawable.ic_monitor_offline
    }

    /** Views shared by every layout: the state-coloured icon tile, network name and state. */
    internal fun RemoteViews.bindHeader(card: MonitorCard) {
        val color = MonitorCardFormat.stateColor(card.state)
        tint(R.id.monitor_tile_fill, color, alpha = 40)
        tint(R.id.monitor_tile_stroke, color, alpha = 90)
        setImageViewResource(R.id.monitor_icon, transportIcon(card.transportType))
        tint(R.id.monitor_icon, color)
        setTextViewText(R.id.monitor_title, card.networkName)
        tint(R.id.monitor_dot, color)
        setTextViewText(R.id.monitor_state, card.stateTitle)
        setTextColor(R.id.monitor_state, color)
    }

    /** Recolours a white mask drawable; RemoteViews cannot set background tints before API 31. */
    internal fun RemoteViews.tint(viewId: Int, color: Int, alpha: Int = 255) {
        setInt(viewId, "setColorFilter", color)
        setInt(viewId, "setImageAlpha", alpha)
    }
}
