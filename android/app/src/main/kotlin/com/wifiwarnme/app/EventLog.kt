package com.wifiwarnme.app

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

/**
 * Timeline of state changes shown in the Eventos tab.
 *
 * Each entry is `{timestamp, text}` where `text` is the line delivered to Flutter,
 * "dd/MM HH:mm • title • detail • …". Retention and the size cap come from the [store].
 */
class EventLog(
    private val store: JsonLinesStore,
    private val timeZone: TimeZone = TimeZone.getDefault()
) {
    fun append(timestamp: Long, message: String) {
        store.append(JSONObject().put("timestamp", timestamp).put("text", "${format(timestamp)} • $message"))
    }

    /** Event lines, newest first. Events with the same timestamp keep their insertion order reversed. */
    fun recent(): List<String> =
        store.read().asReversed()
            .sortedByDescending { it.optLong("timestamp") }
            .mapNotNull { entry -> entry.optString("text").takeIf { it.isNotBlank() } }

    /**
     * Imports the old SharedPreferences value: event lines joined by "\n", newest first,
     * stamped "dd/MM HH:mm" without a year.
     */
    fun importLegacy(raw: String, now: Long) {
        store.appendAll(legacyEntries(raw, now, timeZone).asReversed())
    }

    private fun format(timestamp: Long): String =
        SimpleDateFormat("dd/MM HH:mm", Locale("pt", "BR")).apply { timeZone = this@EventLog.timeZone }
            .format(Date(timestamp))

    companion object {
        private val STAMP = Regex("""^(\d{2})/(\d{2}) (\d{2}):(\d{2})""")

        /**
         * Parses legacy lines (newest first) into entries, newest first. The year is the one that
         * puts each event at or before the next newer one (starting from [now]): the current year,
         * or the previous one when that would be in the future. Lines without a readable stamp
         * borrow the timestamp of the newer neighbour.
         */
        fun legacyEntries(raw: String, now: Long, timeZone: TimeZone = TimeZone.getDefault()): List<JSONObject> {
            var reference = now
            return raw.split("\n").map { it.trim() }.filter { it.isNotEmpty() }.map { line ->
                val timestamp = parseStamp(line, reference, timeZone) ?: reference
                reference = timestamp
                JSONObject().put("timestamp", timestamp).put("text", line)
            }
        }

        private fun parseStamp(line: String, notAfter: Long, timeZone: TimeZone): Long? {
            val match = STAMP.find(line) ?: return null
            val (day, month, hour, minute) = match.destructured.toList().map { it.toInt() }
            if (month !in 1..12 || day !in 1..31 || hour > 23 || minute > 59) return null
            val calendar = Calendar.getInstance(timeZone).apply {
                isLenient = false
                timeInMillis = notAfter
            }
            var year = calendar.get(Calendar.YEAR)
            repeat(2) {
                val candidate = try {
                    Calendar.getInstance(timeZone).apply {
                        isLenient = false
                        clear()
                        set(year, month - 1, day, hour, minute, 0)
                    }.timeInMillis
                } catch (_: IllegalArgumentException) {
                    null // 29/02 in a non-leap year
                }
                if (candidate != null && candidate <= notAfter) return candidate
                year -= 1
            }
            return null
        }
    }
}
