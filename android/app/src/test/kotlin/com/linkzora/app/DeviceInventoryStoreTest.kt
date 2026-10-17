package com.linkzora.app

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeviceInventoryStoreTest {
    private val day = 24 * 60 * 60 * 1000L
    private var now = 30 * day

    private fun dir(): File = Files.createTempDirectory("inventory").toFile()

    private fun device(ip: String, name: String?, type: String, self: Boolean = false) =
        LanDevice(ip, name, type, null, null, listOf("ping"), emptyList(), isGateway = false, isSelf = self)

    @Test
    fun storesScansWithoutTheOwnPhoneAndKeepsSevenDays() {
        val store = DeviceInventoryStore(dir()) { now }
        store.appendScan(now - 8 * day, listOf(device("192.168.0.9", "Velho", "tv")), full = true)
        store.appendScan(now - day, listOf(device("192.168.0.30", "TV", "tv"), device("192.168.0.5", "Eu", "phone", self = true)), full = false)
        @Suppress("UNCHECKED_CAST")
        val scans = store.history()["scans"] as List<Map<String, Any?>>
        assertEquals(1, scans.size)
        assertEquals(now - day, scans[0]["timestamp"])
        assertEquals(false, scans[0]["full"])
        assertEquals(listOf(mapOf("ip" to "192.168.0.30", "name" to "TV", "type" to "tv")), scans[0]["devices"])
    }

    @Test
    fun storesLanProbesAndUnnamedDevices() {
        val store = DeviceInventoryStore(dir()) { now }
        store.appendLanProbe(now, LatencyResult(4, 1, 0, 4, 4), -61)
        store.appendScan(now, listOf(device("192.168.0.7", null, "unknown")), full = true)
        val history = store.history()
        @Suppress("UNCHECKED_CAST")
        val probe = (history["lanProbes"] as List<Map<String, Any?>>).single()
        assertEquals(4L, (probe["latency"] as Number).toLong())
        assertEquals(-61, (probe["rssi"] as Number).toInt())
        @Suppress("UNCHECKED_CAST")
        val devices = (history["scans"] as List<Map<String, Any?>>).single()["devices"] as List<Map<String, Any?>>
        assertNull(devices.single()["name"])
    }

    @Test
    fun lastScanRoundTripsNestedMapsAndLists() {
        val folder = dir()
        val store = DeviceInventoryStore(folder) { now }
        assertNull(store.lastScan())
        val scan = mapOf(
            "timestamp" to now,
            "gateway" to mapOf("latency" to 3L, "loss" to 0),
            "gatewayIp" to null,
            "devices" to listOf(mapOf("ip" to "192.168.0.1", "sources" to listOf("ping", "upnp")))
        )
        store.saveLastScan(scan)
        val restored = DeviceInventoryStore(folder) { now }.lastScan()!!
        assertEquals(now, (restored["timestamp"] as Number).toLong())
        assertNull(restored["gatewayIp"])
        @Suppress("UNCHECKED_CAST")
        val devices = restored["devices"] as List<Map<String, Any?>>
        assertEquals(listOf("ping", "upnp"), devices.single()["sources"])
        assertEquals(3, ((restored["gateway"] as Map<*, *>)["latency"] as Number).toInt())
    }

    @Test
    fun corruptLastScanReadsAsNull() {
        val folder = dir()
        File(folder, "last_scan.json").writeText("{broken")
        assertNull(DeviceInventoryStore(folder) { now }.lastScan())
    }
}
