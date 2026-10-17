package com.wifiwarnme.app

import java.io.File
import org.json.JSONObject

/**
 * History kept as JSON lines, one object per line with a `timestamp` field, oldest first.
 *
 * Appending a line is cheap, unlike rewriting a SharedPreferences XML with the whole history
 * on every write. Entries older than [retentionMs], and the oldest entries beyond [maxEntries],
 * are dropped at most once per [pruneEveryMs]; [read] applies both limits on every call, so a
 * file that grew between prunes never leaks extra entries.
 */
class JsonLinesStore(
    private val file: File,
    private val retentionMs: Long = 24 * 60 * 60 * 1000L,
    private val maxEntries: Int = Int.MAX_VALUE,
    private val pruneEveryMs: Long = 60 * 60 * 1000L,
    private val clock: () -> Long = System::currentTimeMillis
) {
    private var lastPruneAt = 0L

    @Synchronized
    fun append(entry: JSONObject) {
        file.parentFile?.mkdirs()
        file.appendText(entry.toString() + "\n")
        val now = clock()
        if (now - lastPruneAt >= pruneEveryMs) {
            lastPruneAt = now
            prune(now)
        }
    }

    /** Appends several entries with a single write (used by migrations). */
    @Synchronized
    fun appendAll(entries: List<JSONObject>) {
        if (entries.isEmpty()) return
        file.parentFile?.mkdirs()
        file.appendText(entries.joinToString("\n", postfix = "\n"))
        prune()
    }

    /** Entries within the retention window and the size cap, oldest first. Corrupt lines are skipped. */
    @Synchronized
    fun read(): List<JSONObject> {
        if (!file.exists()) return emptyList()
        return keep(file.readLines(), clock()).map { it.second }
    }

    @Synchronized
    fun prune(now: Long = clock()) {
        if (!file.exists()) return
        val kept = keep(file.readLines(), now).map { it.first }
        val temp = File(file.parentFile, file.name + ".tmp")
        temp.writeText(if (kept.isEmpty()) "" else kept.joinToString("\n", postfix = "\n"))
        if (!temp.renameTo(file)) {
            file.writeText(temp.readText())
            temp.delete()
        }
    }

    private fun keep(lines: List<String>, now: Long): List<Pair<String, JSONObject>> {
        val cutoff = now - retentionMs
        return lines.mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            try {
                JSONObject(line).takeIf { it.optLong("timestamp") >= cutoff }?.let { line to it }
            } catch (_: Exception) {
                null
            }
        }.takeLast(maxEntries)
    }

    companion object {
        private const val DAY = 24 * 60 * 60 * 1000L

        /** One line per check; 24 h covers the Monitoria charts. */
        fun measurements(filesDir: File) = JsonLinesStore(File(filesDir, "measurements.jsonl"))

        /** State changes for the Eventos tab: 30 days, at most 2000 entries. */
        fun events(filesDir: File, clock: () -> Long = System::currentTimeMillis) =
            JsonLinesStore(File(filesDir, "events.jsonl"), retentionMs = 30 * DAY, maxEntries = 2_000, clock = clock)
    }
}
