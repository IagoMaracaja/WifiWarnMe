package com.wifiwarnme.app

import java.io.File
import java.nio.file.Files
import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class EventLogTest {
    private val utc = TimeZone.getTimeZone("UTC")
    private val minute = 60_000L
    private val day = 24 * 60 * minute

    private fun at(year: Int, month: Int, dayOfMonth: Int, hour: Int, min: Int): Long =
        Calendar.getInstance(utc).apply {
            clear()
            set(year, month - 1, dayOfMonth, hour, min, 0)
        }.timeInMillis

    private var now = at(2026, 10, 16, 12, 0)

    private fun log(dir: File = Files.createTempDirectory("events").toFile()) =
        EventLog(JsonLinesStore.events(dir) { now }, utc)

    @Test
    fun appendsKeepTheLegacyLineFormatNewestFirst() {
        val log = log()
        log.append(at(2026, 10, 16, 9, 5), "Conexão instável • Wi-Fi • Cloudflare • 410ms")
        log.append(at(2026, 10, 16, 9, 7), "Conexão estável • Wi-Fi • Cloudflare • 40ms")
        assertEquals(
            listOf(
                "16/10 09:07 • Conexão estável • Wi-Fi • Cloudflare • 40ms",
                "16/10 09:05 • Conexão instável • Wi-Fi • Cloudflare • 410ms"
            ),
            log.recent()
        )
    }

    @Test
    fun sameMinuteEventsStayInInsertionOrderReversed() {
        val log = log()
        val t = at(2026, 10, 16, 9, 5)
        log.append(t, "A")
        log.append(t, "B")
        assertEquals(listOf("16/10 09:05 • B", "16/10 09:05 • A"), log.recent())
    }

    @Test
    fun dropsEventsOlderThanThirtyDays() {
        val dir = Files.createTempDirectory("events").toFile()
        val log = log(dir)
        log.append(now - 31 * day, "velho")
        log.append(now - 29 * day, "recente")
        assertEquals(1, log.recent().size)
        assertEquals(true, log.recent().single().endsWith("recente"))
    }

    @Test
    fun capsAt2000Events() {
        val log = log()
        for (index in 0 until 2_050) log.append(now - 2_050 * minute + index * minute, "e$index")
        val recent = log.recent()
        assertEquals(2_000, recent.size)
        assertEquals(true, recent.first().endsWith("e2049"))
        assertEquals(true, recent.last().endsWith("e50"))
    }

    @Test
    fun legacyStampsUseTheCurrentOrPreviousYear() {
        val raw = listOf(
            "16/10 11:30 • Conexão estável • Wi-Fi",
            "not a stamp • Internet indisponível",
            "02/01 08:00 • Conexão instável • Wi-Fi",
            "31/12 23:59 • Internet indisponível • Wi-Fi",
            "20/10 10:00 • Conexão estável • Wi-Fi"
        ).joinToString("\n")
        val entries = EventLog.legacyEntries(raw, now, utc)
        assertEquals(
            listOf(
                at(2026, 10, 16, 11, 30),
                at(2026, 10, 16, 11, 30), // borrowed from the newer neighbour
                at(2026, 1, 2, 8, 0),
                at(2025, 12, 31, 23, 59), // before 02/01, so the previous year
                at(2025, 10, 20, 10, 0) // 20/10/2026 would be in the future
            ),
            entries.map { it.getLong("timestamp") }
        )
    }

    @Test
    fun importLegacyKeepsLinesAndOrderAndAppliesRetention() {
        val log = log()
        val raw = "16/10 11:30 • B • Wi-Fi\n15/10 08:00 • A • Wi-Fi\n01/08 08:00 • velho\n"
        log.importLegacy(raw, now)
        assertEquals(listOf("16/10 11:30 • B • Wi-Fi", "15/10 08:00 • A • Wi-Fi"), log.recent())
        log.append(at(2026, 10, 16, 11, 45), "C")
        assertEquals("16/10 11:45 • C", log.recent().first())
    }
}
