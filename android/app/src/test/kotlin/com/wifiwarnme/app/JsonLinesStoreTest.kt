package com.wifiwarnme.app

import java.io.File
import java.nio.file.Files
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class JsonLinesStoreTest {
    private val hour = 60 * 60 * 1000L
    private var now = 100 * hour

    private fun store(file: File) = JsonLinesStore(file, retentionMs = 24 * hour, pruneEveryMs = hour) { now }

    private fun capped(file: File, max: Int) =
        JsonLinesStore(file, retentionMs = 30 * 24 * hour, maxEntries = max, pruneEveryMs = hour) { now }

    private fun entry(timestamp: Long, latency: Long = 70) =
        JSONObject().put("timestamp", timestamp).put("latency", latency)

    private fun tempFile() = File(Files.createTempDirectory("store").toFile(), "measurements.jsonl")

    @Test
    fun keepsAFullDayAtOneMinuteInterval() {
        // The previous SharedPreferences history was capped at 720 entries (12 h at 1 min).
        val file = tempFile()
        val store = store(file)
        val start = now - 24 * hour + 60_000L
        for (minute in 0 until 1_440) {
            now = start + minute * 60_000L
            store.append(entry(now))
        }
        assertEquals(1_440, store.read().size)
    }

    @Test
    fun readSkipsExpiredAndCorruptLines() {
        val file = tempFile()
        file.writeText(entry(now - 30 * hour).toString() + "\nnot json\n" + entry(now - hour) + "\n")
        val entries = store(file).read()
        assertEquals(1, entries.size)
        assertEquals(now - hour, entries.single().getLong("timestamp"))
    }

    @Test
    fun pruneRewritesOnlyRecentEntries() {
        val file = tempFile()
        file.writeText(entry(now - 30 * hour).toString() + "\n" + entry(now - hour) + "\n")
        store(file).prune()
        assertEquals(1, file.readLines().count { it.isNotBlank() })
    }

    @Test
    fun appendCreatesTheFile() {
        val file = File(Files.createTempDirectory("store").toFile(), "nested/measurements.jsonl")
        store(file).append(entry(now, latency = 42))
        assertEquals(42L, store(file).read().single().getLong("latency"))
    }

    @Test
    fun readAppliesTheCapBeforeThePrune() {
        val file = tempFile()
        val store = capped(file, max = 3)
        for (index in 1..5) store.append(entry(now - 10 + index, latency = index.toLong()))
        // Only the first append pruned; the file still holds 5 lines, but read keeps the newest 3.
        assertEquals(5, file.readLines().count { it.isNotBlank() })
        assertEquals(listOf(3L, 4L, 5L), store.read().map { it.getLong("latency") })
    }

    @Test
    fun pruneKeepsTheNewestEntriesWithinTheCap() {
        val file = tempFile()
        val store = capped(file, max = 2)
        store.appendAll((1..4).map { entry(now - 10 + it, latency = it.toLong()) })
        assertEquals(2, file.readLines().count { it.isNotBlank() })
        assertEquals(listOf(3L, 4L), store.read().map { it.getLong("latency") })
    }

    @Test
    fun eventsStoreKeepsThirtyDaysAndAtMost2000() {
        val dir = Files.createTempDirectory("events").toFile()
        val file = File(dir, "events.jsonl")
        val day = 24 * hour
        val lines = (0 until 2_100).map { entry(now - 29 * day + it * 1_000L) } + entry(now - 31 * day)
        file.writeText(lines.joinToString("\n", postfix = "\n"))
        val read = JsonLinesStore.events(dir) { now }.read()
        assertEquals(2_000, read.size)
        assertEquals(now - 29 * day + 100_000L, read.first().getLong("timestamp"))
    }
}
