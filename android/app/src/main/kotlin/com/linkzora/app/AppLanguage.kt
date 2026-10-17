package com.linkzora.app

/**
 * Languages of the native texts (notification, alerts, events, widgets), without Android types so
 * the rules can be unit tested. Flutter sends the effective app language with `setLanguage` and in
 * the `start`/`configure`/`probe` arguments; [NativeLocale] stores it and builds the localized
 * context.
 */
object AppLanguage {
    const val DEFAULT = "pt"
    val SUPPORTED = listOf("pt", "es", "en")

    /** "pt", "pt-BR", "ES", "en_US" → the supported code, or null when unsupported or blank. */
    fun normalize(code: String?): String? = code?.trim()?.lowercase()
        ?.substringBefore('-')?.substringBefore('_')
        ?.takeIf { it in SUPPORTED }

    /** Default before Flutter sends a language: the system one when supported, otherwise Portuguese. */
    fun fromSystem(languageTag: String?): String = normalize(languageTag) ?: DEFAULT

    /** Language and country for [java.util.Locale]; Portuguese is the Brazilian variant. */
    fun localeParts(code: String): Pair<String, String> = when (normalize(code) ?: DEFAULT) {
        "es" -> "es" to ""
        "en" -> "en" to ""
        else -> "pt" to "BR"
    }
}
