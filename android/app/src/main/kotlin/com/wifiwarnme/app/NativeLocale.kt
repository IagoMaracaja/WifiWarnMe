package com.wifiwarnme.app

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import java.util.Locale

/**
 * App language for the native texts. Flutter is the source of truth: it calls `setLanguage`
 * ({'language': 'pt'|'es'|'en'}) whenever the effective language changes and also sends
 * `language` with `start`/`configure`/`probe`. Until then the system language is used when it is
 * supported, otherwise Portuguese.
 *
 * Texts are resolved through [localized], a configuration context with the chosen locale, so the
 * app language wins over the system one. RemoteViews layouts are inflated by the host (launcher
 * or System UI) with the system locale, so every visible label is also set from code.
 */
object NativeLocale {
    private const val PREFS = "wifiwarnme_native"
    private const val KEY = "language"

    @Volatile
    private var cached: Pair<String, Context>? = null

    fun language(context: Context): String {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
        return AppLanguage.normalize(stored) ?: AppLanguage.fromSystem(systemLanguage())
    }

    /** Stores [code]; returns true when the effective language changed. Unsupported codes are ignored. */
    fun setLanguage(context: Context, code: String?): Boolean {
        val language = AppLanguage.normalize(code) ?: return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val before = language(context)
        // commit: the service and widgets read it right after this call, possibly on other threads.
        prefs.edit().putString(KEY, language).commit()
        return before != language
    }

    /** A context whose resources resolve strings in the app language. */
    fun localized(context: Context): Context {
        val language = language(context)
        cached?.let { (cachedLanguage, localized) -> if (cachedLanguage == language) return localized }
        val (lang, country) = AppLanguage.localeParts(language)
        val app = context.applicationContext ?: context
        val configuration = Configuration(app.resources.configuration).apply { setLocale(Locale(lang, country)) }
        return app.createConfigurationContext(configuration).also { cached = language to it }
    }

    private fun systemLanguage(): String? = try {
        Resources.getSystem().configuration.locales[0]?.language
    } catch (_: Exception) {
        null
    }
}

/** Localized texts shared by the service, the notification and the widgets. */
object NativeText {
    fun cardTexts(context: Context): CardTexts {
        val c = NativeLocale.localized(context)
        return CardTexts(
            titleOnline = c.getString(R.string.card_title_online),
            titleSlow = c.getString(R.string.card_title_slow),
            titleOffline = c.getString(R.string.card_title_offline),
            titleChecking = c.getString(R.string.card_title_checking),
            subtitleOnline = c.getString(R.string.card_subtitle_online),
            subtitleSlow = c.getString(R.string.state_label_slow),
            subtitleOffline = c.getString(R.string.card_subtitle_offline),
            subtitleChecking = c.getString(R.string.card_subtitle_checking),
            cellular = c.getString(R.string.transport_cellular),
            ethernet = c.getString(R.string.transport_ethernet),
            noConnection = c.getString(R.string.network_none),
            paused = c.getString(R.string.widget_paused),
            monitoringPaused = c.getString(R.string.widget_monitoring_paused)
        )
    }

    fun notificationTexts(context: Context): NotificationTexts {
        val c = NativeLocale.localized(context)
        return NotificationTexts(
            pillOnline = c.getString(R.string.notif_pill_online),
            pillSlow = c.getString(R.string.notif_pill_slow),
            pillOffline = c.getString(R.string.notif_pill_offline),
            pillChecking = c.getString(R.string.notif_pill_checking),
            latencyCaption = c.getString(R.string.notif_latency_caption),
            noResponseCaption = c.getString(R.string.notif_no_response_caption),
            band = c.getString(R.string.notif_band),
            signalWeak = c.getString(R.string.signal_weak),
            signalFair = c.getString(R.string.signal_fair),
            signalGood = c.getString(R.string.signal_good),
            connectedNoInternet = c.getString(R.string.notif_connected_no_internet),
            cellular = c.getString(R.string.transport_cellular),
            ethernet = c.getString(R.string.transport_ethernet),
            noConnection = c.getString(R.string.network_none),
            stableWindow = c.getString(R.string.notif_stable_window),
            stable = c.getString(R.string.notif_stable),
            problemSince = c.getString(R.string.notif_problem_since),
            firstCheck = c.getString(R.string.notification_first_check),
            axisStart = c.getString(R.string.notif_axis_start)
        )
    }

    fun diagnosis(context: Context, code: DiagnosisCode, targetLabel: String): String {
        val c = NativeLocale.localized(context)
        return when (code) {
            DiagnosisCode.NO_NETWORK -> c.getString(R.string.diagnosis_no_network)
            DiagnosisCode.CAPTIVE_PORTAL -> c.getString(R.string.diagnosis_captive_portal)
            DiagnosisCode.DNS_FAILURE -> c.getString(R.string.diagnosis_dns_failure)
            DiagnosisCode.NO_INTERNET -> c.getString(R.string.diagnosis_no_internet)
            DiagnosisCode.WIFI_TOO_WEAK -> c.getString(R.string.diagnosis_wifi_too_weak)
            DiagnosisCode.NO_RESPONSE -> c.getString(R.string.diagnosis_no_response)
            DiagnosisCode.WEAK_SIGNAL_STABLE -> c.getString(R.string.diagnosis_weak_signal_stable)
            DiagnosisCode.NONE -> c.getString(R.string.diagnosis_none)
            DiagnosisCode.WEAK_SIGNAL -> c.getString(R.string.diagnosis_weak_signal)
            DiagnosisCode.PACKET_LOSS -> c.getString(R.string.diagnosis_packet_loss)
            DiagnosisCode.HIGH_JITTER -> c.getString(R.string.diagnosis_high_jitter)
            DiagnosisCode.REGIONAL_DISTANCE -> c.getString(R.string.diagnosis_regional_distance, targetLabel)
            DiagnosisCode.CONGESTED_ROUTE -> c.getString(R.string.diagnosis_congested_route)
        }
    }

    /** The card subtitle cause: null when there is no anomaly. */
    fun cardDiagnosis(context: Context, code: DiagnosisCode?, targetLabel: String): String? =
        code?.takeIf { it != DiagnosisCode.NONE }?.let { diagnosis(context, it, targetLabel) }

    /**
     * Display name of a measurement target. The stored `targetName` stays the canonical
     * (Portuguese) name because Flutter groups the history by it; only what is shown changes.
     */
    fun targetLabel(context: Context, targetName: String): String {
        val c = NativeLocale.localized(context)
        return when (targetName) {
            "São Paulo" -> c.getString(R.string.target_sao_paulo)
            "Estados Unidos" -> c.getString(R.string.target_united_states)
            "Europa" -> c.getString(R.string.target_europe)
            else -> targetName
        }
    }
}
