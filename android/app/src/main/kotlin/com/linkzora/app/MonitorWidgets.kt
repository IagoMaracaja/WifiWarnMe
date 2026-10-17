package com.linkzora.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/** Small home screen widget (2x1): state dot, network name and latency. */
class LinkzoraSmallWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        MonitorWidgets.update(context, goAsync())

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        MonitorWidgets.update(context, goAsync())
}

/** Large home screen widget (4x2, full card when taller): the notification card plus a refresh button. */
class LinkzoraLargeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        MonitorWidgets.update(context, goAsync())

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        MonitorWidgets.update(context, goAsync())
}

/**
 * Renders both widgets from the native preferences and the measurement history, in the same dark
 * card style as the persistent notification ([MonitorNotificationViews] binders, [WidgetFormat]).
 *
 * [update] is called by [MonitorService] after each published check and when monitoring starts or
 * stops, by MainActivity after a language change, and by the providers (placement, resize and the
 * 30 min `updatePeriodMillis` fallback). Work runs on a single background thread because the
 * ribbon reads the history file.
 */
object MonitorWidgets {
    private const val TAG = "LinkzoraWidgets"
    private const val PREFS = "wifiwarnme_native"

    /** From this height (dp) the large widget shows the full card instead of the compact one. */
    // The full card needs ~240dp; a 4x2 cell on phones is ~210dp, so it starts at 4x3.
    private const val TALL_MIN_HEIGHT_DP = 250f
    private const val MIN_WIDTH_DP = 200f
    private const val COMPACT_MIN_HEIGHT_DP = 90f

    private val executor = Executors.newSingleThreadExecutor()

    fun update(context: Context, pending: BroadcastReceiver.PendingResult? = null) {
        val app = context.applicationContext ?: context
        executor.execute {
            try {
                render(app)
            } catch (e: Exception) {
                Log.w(TAG, "widget update failed", e)
            } finally {
                pending?.finish()
            }
        }
    }

    private fun render(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        val small = manager.getAppWidgetIds(ComponentName(context, LinkzoraSmallWidget::class.java))
        val large = manager.getAppWidgetIds(ComponentName(context, LinkzoraLargeWidget::class.java))
        if (small.isEmpty() && large.isEmpty()) return
        val card = card(context, withRibbon = large.isNotEmpty())
        small.forEach { manager.updateAppWidget(it, smallViews(context, card)) }
        large.forEach { manager.updateAppWidget(it, largeViews(context, card, manager.getAppWidgetOptions(it))) }
    }

    private fun card(context: Context, withRibbon: Boolean): MonitorCard {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastCheckedAt = p.getLong("lastCheckedAt", 0L)
        val target = MonitorService.targetName(p.getString("serverId", null), p.getString("locationId", null))
        val code = DiagnosisCode.from(p.getString("diagnosisCode", null))
            ?: DiagnosisCode.fromLegacyText(p.getString("diagnosis", null))
        val history = if (withRibbon) MonitorService.ribbonEntries(context) else emptyList()
        val input = WidgetInput(
            monitoring = MonitorService.monitoring(context),
            hasData = lastCheckedAt > 0,
            state = p.getString("state", null) ?: "checking",
            transportType = p.getString("transportType", null) ?: "none",
            networkName = p.getString("networkName", null),
            diagnosis = NativeText.cardDiagnosis(context, code, NativeText.targetLabel(context, target)),
            latency = p.getLong("latency", -1L),
            jitter = p.getLong("jitter", -1L),
            failureRate = p.getInt("failureRate", 100),
            lastCheck = if (lastCheckedAt > 0) clock(lastCheckedAt) else MonitorCardFormat.NO_VALUE,
            ribbon = MonitorCardFormat.ribbon(history, target)
        )
        return WidgetFormat.card(input, NativeText.cardTexts(context))
    }

    private fun smallViews(context: Context, card: MonitorCard) =
        RemoteViews(context.packageName, R.layout.widget_monitor_small).apply {
            with(MonitorNotificationViews) { bindHeader(card) }
            setTextViewText(R.id.widget_headline, WidgetFormat.headline(card))
            setTextColor(R.id.widget_headline, MonitorCardFormat.stateColor(card.state))
            setTextViewText(R.id.widget_caption, WidgetFormat.caption(card))
            setOnClickPendingIntent(android.R.id.background, openApp(context))
            setContentDescription(android.R.id.background, describe(card))
        }

    /**
     * Android 12+ picks the layout that fits the current size (and orientation) itself; older
     * versions choose from the minimum height reported in the widget options.
     */
    private fun largeViews(context: Context, card: MonitorCard, options: Bundle?): RemoteViews {
        val compact = largeLayout(context, card, tall = false)
        val tall = largeLayout(context, card, tall = true)
        if (Build.VERSION.SDK_INT >= 31) {
            return RemoteViews(mapOf(
                SizeF(MIN_WIDTH_DP, COMPACT_MIN_HEIGHT_DP) to compact,
                SizeF(MIN_WIDTH_DP, TALL_MIN_HEIGHT_DP) to tall
            ))
        }
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        return if (minHeight >= TALL_MIN_HEIGHT_DP) tall else compact
    }

    private fun largeLayout(context: Context, card: MonitorCard, tall: Boolean) = RemoteViews(
        context.packageName,
        if (tall) R.layout.widget_monitor_large_tall else R.layout.widget_monitor_large
    ).apply {
        with(MonitorNotificationViews) { bindCard(context, card) }
        if (!tall) {
            // One line in the compact card: "● Conectado · Internet estável".
            setTextViewText(R.id.monitor_detail, " · ${card.stateSubtitle}")
        }
        val paused = card.state == MonitorCardFormat.PAUSED
        val localized = NativeLocale.localized(context)
        setViewVisibility(R.id.widget_refresh, if (paused) View.GONE else View.VISIBLE)
        setViewVisibility(R.id.widget_open, if (paused) View.VISIBLE else View.GONE)
        setTextViewText(R.id.widget_open, localized.getString(R.string.widget_open_app))
        setContentDescription(R.id.widget_refresh, localized.getString(R.string.action_check_now))
        setOnClickPendingIntent(R.id.widget_refresh, checkNow(context))
        setOnClickPendingIntent(R.id.widget_open, openApp(context))
        setOnClickPendingIntent(android.R.id.background, openApp(context))
        setContentDescription(android.R.id.background, describe(card))
    }

    private fun describe(card: MonitorCard) = listOf(card.networkName, card.stateTitle, card.stateSubtitle, card.ping)
        .filter { it.isNotBlank() && it != MonitorCardFormat.NO_VALUE }
        .joinToString(", ")

    private fun openApp(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)!!.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, 20, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /**
     * Only offered while monitoring runs: the app then holds a foreground service, so starting
     * the service from the launcher is allowed and CHECK_NOW runs a check immediately.
     */
    private fun checkNow(context: Context): PendingIntent = PendingIntent.getService(
        context, 21, Intent(context, MonitorService::class.java).setAction(MonitorService.CHECK_NOW),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun clock(time: Long) = SimpleDateFormat("HH:mm", Locale.ROOT).format(Date(time))
}
