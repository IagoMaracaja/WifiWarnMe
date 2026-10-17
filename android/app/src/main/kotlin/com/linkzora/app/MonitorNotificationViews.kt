package com.linkzora.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * Custom views of the persistent monitor notification, after design/notificacao/notificacao-redesign.png.
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

    // ---- Redesigned card (design/notificacao/notificacao-redesign.png) ----

    private fun diagnosisIcon(kind: DiagnosisKind) = when (kind) {
        DiagnosisKind.OK -> R.drawable.ic_diag_ok
        DiagnosisKind.WARN -> R.drawable.ic_diag_warn
        DiagnosisKind.OFF -> R.drawable.ic_diag_off
        DiagnosisKind.INFO -> R.drawable.ic_diag_info
    }

    private fun cardIcon(card: NotificationCard) =
        if (card.state == "offline") R.drawable.ic_monitor_offline else transportIcon(card.transportType)

    /** Tile, network, latency: shared by both sizes. */
    private fun RemoteViews.bindIdentity(card: NotificationCard) {
        val color = MonitorCardFormat.stateColor(card.state)
        tint(R.id.notif_tile, color, alpha = 31)
        setImageViewResource(R.id.notif_icon, cardIcon(card))
        tint(R.id.notif_icon, color)
        setTextViewText(R.id.notif_network, card.networkName)
        val answered = card.latency != MonitorCardFormat.NO_VALUE
        setTextViewText(R.id.notif_latency, card.latency)
        setViewVisibility(R.id.notif_latency_unit, if (answered) View.VISIBLE else View.GONE)
        setTextColor(R.id.notif_latency_unit, color)
    }

    /** About 48dp: tile, network, "Estável · Wi-Fi 5 GHz", the last checks as a strip, latency. */
    fun redesignedCollapsed(context: Context, card: NotificationCard): RemoteViews =
        RemoteViews(context.packageName, R.layout.notif_collapsed).apply {
            bindIdentity(card)
            val color = MonitorCardFormat.stateColor(card.state)
            setTextViewText(R.id.notif_subtitle,
                listOf(card.pill, card.subtitle.substringBefore(" · ")).filter { it.isNotBlank() }.joinToString(" · "))
            setTextColor(R.id.notif_latency, color)
            setImageViewBitmap(R.id.notif_strip, ChartBitmaps.strip(context, card.bars))
        }

    /**
     * The full card: identity and state pill, big latency with the chart of the last checks
     * against the limit, jitter / loss / signal, the probable cause and the countdown.
     */
    fun redesignedExpanded(context: Context, card: NotificationCard, limit: Int, nextCheckAt: Long): RemoteViews =
        RemoteViews(context.packageName, R.layout.notif_expanded).apply {
            val texts = NativeLocale.localized(context)
            val color = MonitorCardFormat.stateColor(card.state)
            bindIdentity(card)
            setTextViewText(R.id.notif_subtitle, card.subtitle)
            setViewVisibility(R.id.notif_subtitle, if (card.subtitle.isBlank()) View.GONE else View.VISIBLE)
            tint(R.id.notif_glow, color, alpha = 41)
            tint(R.id.notif_accent, color)
            tint(R.id.notif_pill_bg, color, alpha = 31)
            tint(R.id.notif_pill_dot, color)
            setTextViewText(R.id.notif_pill, card.pill)
            setTextColor(R.id.notif_pill, color)
            setTextViewText(R.id.notif_caption, card.caption)
            setImageViewBitmap(R.id.notif_chart, ChartBitmaps.chart(context, card.bars, limit))
            setTextViewText(R.id.notif_axis_start, card.axisStart)
            setTextViewText(R.id.notif_axis_end, texts.getString(R.string.notif_axis_now))
            setTextViewText(R.id.notif_jitter_label, texts.getString(R.string.card_jitter))
            setTextViewText(R.id.notif_jitter, card.jitter)
            setTextColor(R.id.notif_jitter, card.jitterColor)
            setTextViewText(R.id.notif_loss_label, texts.getString(R.string.card_loss))
            setTextViewText(R.id.notif_loss, card.loss)
            setTextColor(R.id.notif_loss, card.lossColor)
            setTextViewText(R.id.notif_signal_label, texts.getString(R.string.notif_signal))
            setTextViewText(R.id.notif_signal, card.signal)
            setImageViewResource(R.id.notif_diag_icon, diagnosisIcon(card.diagnosisKind))
            tint(R.id.notif_diag_icon, color)
            setTextViewText(R.id.notif_diagnosis, card.diagnosis)
            setTextViewText(R.id.notif_measured, texts.getString(R.string.notif_measured_at, card.measuredAt))
            val remaining = nextCheckAt - System.currentTimeMillis()
            if (remaining > 0) {
                setChronometer(R.id.notif_next, SystemClock.elapsedRealtime() + remaining,
                    texts.getString(R.string.notif_next_in), true)
                setChronometerCountDown(R.id.notif_next, true)
                setViewVisibility(R.id.notif_next, View.VISIBLE)
            } else {
                setViewVisibility(R.id.notif_next, View.GONE)
            }
        }
}

/**
 * The bar chart and the collapsed strip are drawn into bitmaps: RemoteViews cannot draw. Kept
 * small (density capped at 2x) because they travel with every notification update.
 */
object ChartBitmaps {
    private const val LIMIT_LINE = 0x739FB2C6
    private const val GAP_DP = 4f

    private fun density(context: Context) = context.resources.displayMetrics.density.coerceAtMost(2f)

    /** 12 bars against the dashed limit line; a check without answer is a stub on a faint column. */
    fun chart(context: Context, bars: List<ChartBar>, limit: Int, widthDp: Float = 150f, heightDp: Float = 48f): Bitmap {
        val d = density(context)
        val w = (widthDp * d).toInt()
        val h = (heightDp * d).toInt()
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val gap = GAP_DP * d
        val barWidth = (w - gap * (bars.size - 1)) / bars.size
        val radius = 3f * d
        val scale = ChartScale.max(bars, limit)
        bars.forEachIndexed { index, bar ->
            val x = index * (barWidth + gap)
            val color = MonitorCardFormat.stateColor(bar.state)
            val last = index == bars.lastIndex
            if (bar.state == MonitorCardFormat.EMPTY) {
                paint.color = color
                canvas.drawRoundRect(RectF(x, h - 4f * d, x + barWidth, h.toFloat()), radius, radius, paint)
                return@forEachIndexed
            }
            val fraction = ChartScale.height(bar, scale)
            if (fraction == null) {
                paint.color = color
                paint.alpha = 26
                canvas.drawRoundRect(RectF(x, 2f * d, x + barWidth, h - 8f * d), radius, radius, paint)
                paint.alpha = 230
                canvas.drawRoundRect(RectF(x, h - 6f * d, x + barWidth, h.toFloat()), 2f * d, 2f * d, paint)
                return@forEachIndexed
            }
            val top = h - maxOf(5f * d, (fraction * h).toFloat())
            if (last) {
                paint.color = color
                paint.alpha = 72
                paint.maskFilter = BlurMaskFilter(3f * d, BlurMaskFilter.Blur.NORMAL)
                canvas.drawRoundRect(RectF(x - 2f * d, top - 2f * d, x + barWidth + 2f * d, h.toFloat()), 4f * d, 4f * d, paint)
                paint.maskFilter = null
            }
            paint.color = color
            paint.alpha = if (last) 255 else 199
            canvas.drawRoundRect(RectF(x, top, x + barWidth, h.toFloat()), radius, radius, paint)
        }
        val y = (h - ChartScale.limitLine(limit, scale) * h).toFloat().coerceIn(1f, h - 1f)
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = LIMIT_LINE
            strokeWidth = 1f * d
            style = Paint.Style.STROKE
            pathEffect = DashPathEffect(floatArrayOf(3f * d, 3f * d), 0f)
        }
        canvas.drawLine(0f, y, w.toFloat(), y, line)
        return bitmap
    }

    /** Collapsed strip: one short rounded segment per check, in the state colour. */
    fun strip(context: Context, bars: List<ChartBar>, widthDp: Float = 166f, heightDp: Float = 4f): Bitmap {
        val d = density(context)
        val w = (widthDp * d).toInt()
        val h = (heightDp * d).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val gap = 2f * d
        val width = (w - gap * (bars.size - 1)) / bars.size
        bars.forEachIndexed { index, bar ->
            paint.color = MonitorCardFormat.stateColor(bar.state)
            val x = index * (width + gap)
            canvas.drawRoundRect(RectF(x, 0f, x + width, h.toFloat()), h / 2f, h / 2f, paint)
        }
        return bitmap
    }
}
