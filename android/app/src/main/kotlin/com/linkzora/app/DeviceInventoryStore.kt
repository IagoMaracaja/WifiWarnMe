package com.linkzora.app

import java.io.File
import org.json.JSONArray
import org.json.JSONObject

/**
 * Network inventory history, kept for 7 days so instability periods can be correlated with
 * the devices present at the time:
 * - `devices.jsonl`: one line per inventory ({timestamp, devices: [{ip, name, type}]});
 * - `lan_probes.jsonl`: gateway latency measured right after each monitor check;
 * - `last_scan.json`: the last full scan, so the tab can show it before a new scan.
 */
class DeviceInventoryStore(
    private val dir: File,
    clock: () -> Long = System::currentTimeMillis
) {
    private val scans = JsonLinesStore(File(dir, "devices.jsonl"), RETENTION_MS, clock = clock)
    private val probes = JsonLinesStore(File(dir, "lan_probes.jsonl"), RETENTION_MS, clock = clock)
    private val lastScanFile = File(dir, "last_scan.json")

    fun appendScan(timestamp: Long, devices: List<LanDevice>, full: Boolean) {
        val list = JSONArray()
        for (device in devices) {
            if (device.isSelf) continue
            list.put(JSONObject().put("ip", device.ip).put("name", device.name ?: JSONObject.NULL).put("type", device.type))
        }
        scans.append(JSONObject().put("timestamp", timestamp).put("full", full).put("devices", list))
    }

    fun appendLanProbe(timestamp: Long, gateway: LatencyResult, rssi: Int) {
        probes.append(JSONObject()
            .put("timestamp", timestamp)
            .put("latency", gateway.latency)
            .put("jitter", gateway.jitter)
            .put("loss", gateway.failureRate)
            .put("rssi", rssi))
    }

    @Synchronized
    fun saveLastScan(scan: Map<String, Any?>) {
        dir.mkdirs()
        val temp = File(dir, "last_scan.json.tmp")
        temp.writeText(toJson(scan).toString())
        if (!temp.renameTo(lastScanFile)) {
            lastScanFile.writeText(temp.readText())
            temp.delete()
        }
    }

    @Synchronized
    fun lastScan(): Map<String, Any?>? = try {
        if (lastScanFile.exists()) toMap(JSONObject(lastScanFile.readText())) else null
    } catch (_: Exception) {
        null
    }

    /** Everything the Flutter tab needs to correlate devices with instability. */
    fun history(): Map<String, Any?> = mapOf(
        "scans" to scans.read().map(::toMap),
        "lanProbes" to probes.read().map(::toMap),
        "lastScan" to lastScan()
    )

    companion object {
        const val RETENTION_MS = 7 * 24 * 60 * 60 * 1000L

        fun of(filesDir: File) = DeviceInventoryStore(File(filesDir, "network"))

        /** Map/List/primitive tree (as sent over the method channel) to org.json. */
        fun toJson(value: Map<String, Any?>): JSONObject {
            val json = JSONObject()
            for ((key, item) in value) json.put(key, wrap(item))
            return json
        }

        private fun wrap(value: Any?): Any = when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> toJson(value.entries.associate { it.key.toString() to it.value })
            is Iterable<*> -> JSONArray().also { array -> value.forEach { array.put(wrap(it)) } }
            else -> value
        }

        fun toMap(json: JSONObject): Map<String, Any?> {
            val map = linkedMapOf<String, Any?>()
            for (key in json.keys()) map[key] = unwrap(json.opt(key))
            return map
        }

        private fun unwrap(value: Any?): Any? = when (value) {
            null, JSONObject.NULL -> null
            is JSONObject -> toMap(value)
            is JSONArray -> (0 until value.length()).map { unwrap(value.opt(it)) }
            else -> value
        }
    }
}
