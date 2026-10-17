package com.linkzora.app

import java.util.Locale

/*
 * Pure parts of the local network inventory (no Android types, unit tested):
 * protocol packets and parsers (SSDP, UPnP description, NetBIOS, DNS PTR), device type
 * classification, merging of observations by IP, and Wi-Fi channel math.
 *
 * Android does not expose other devices' traffic, the ARP table (Android 10+) or MAC
 * addresses, so devices are identified by IP and by what they announce about themselves.
 */

/** Something one discovery source learned about the host at [ip]. */
data class DeviceObservation(
    val ip: String,
    val source: String,
    val name: String? = null,
    val services: Set<String> = emptySet(),
    val manufacturer: String? = null,
    val model: String? = null,
    val upnpType: String? = null,
    val server: String? = null,
    /** TCP port of an announced service, used to measure RTT when ICMP is blocked. */
    val port: Int? = null
)

/** One device after merging all observations of an IP. */
data class LanDevice(
    val ip: String,
    val name: String?,
    val type: String,
    val vendor: String?,
    val model: String?,
    val sources: List<String>,
    val services: List<String>,
    val isGateway: Boolean,
    val isSelf: Boolean,
    val ports: List<Int> = emptyList()
)

data class SsdpResponse(val location: String?, val server: String?, val st: String?, val usn: String?)

data class UpnpDescription(
    val friendlyName: String?,
    val manufacturer: String?,
    val modelName: String?,
    val modelDescription: String?,
    val deviceType: String?
)

object Ssdp {
    const val ADDRESS = "239.255.255.250"
    const val PORT = 1900

    fun searchRequest(target: String = "ssdp:all", mx: Int = 2): String =
        "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: $ADDRESS:$PORT\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "MX: $mx\r\n" +
            "ST: $target\r\n" +
            "USER-AGENT: Android UPnP/1.1 Linkzora/1.0\r\n\r\n"

    /** Parses an M-SEARCH reply or NOTIFY; null when it is not an SSDP message. */
    fun parseResponse(text: String): SsdpResponse? {
        val lines = text.split("\r\n", "\n")
        val first = lines.firstOrNull()?.trim()?.uppercase(Locale.ROOT) ?: return null
        if (!first.startsWith("HTTP/1.1 200") && !first.startsWith("NOTIFY")) return null
        val headers = mutableMapOf<String, String>()
        for (line in lines.drop(1)) {
            val colon = line.indexOf(':')
            if (colon <= 0) continue
            headers[line.substring(0, colon).trim().uppercase(Locale.ROOT)] = line.substring(colon + 1).trim()
        }
        return SsdpResponse(headers["LOCATION"], headers["SERVER"], headers["ST"] ?: headers["NT"], headers["USN"])
    }

    /** Host part of a LOCATION url, used to only fetch descriptions from the replying host. */
    fun locationHost(location: String): String? =
        Regex("^https?://\\[?([^/\\]:]+)", RegexOption.IGNORE_CASE).find(location.trim())?.groupValues?.get(1)

    /** Reads the first `<device>` of a UPnP device description. Regex keeps it parser-free. */
    fun parseDescription(xml: String): UpnpDescription {
        fun tag(name: String): String? = Regex("<(?:\\w+:)?$name>\\s*([^<]*?)\\s*</(?:\\w+:)?$name>", RegexOption.IGNORE_CASE)
            .find(xml)?.groupValues?.get(1)?.let(::unescapeXml)?.takeIf { it.isNotBlank() }
        return UpnpDescription(tag("friendlyName"), tag("manufacturer"), tag("modelName"),
            tag("modelDescription"), tag("deviceType"))
    }

    private fun unescapeXml(value: String) = value
        .replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"")
        .replace("&apos;", "'").replace("&#39;", "'").replace("&amp;", "&")
}

object NetBios {
    const val PORT = 137

    /** Node status request (NBSTAT) for the wildcard name "*". */
    fun nodeStatusRequest(transactionId: Int): ByteArray {
        val packet = ByteArray(50)
        packet[0] = (transactionId shr 8).toByte()
        packet[1] = transactionId.toByte()
        packet[5] = 1 // one question
        packet[12] = 0x20
        val name = ByteArray(16).also { it[0] = '*'.code.toByte() }
        for (index in 0 until 16) {
            val value = name[index].toInt() and 0xFF
            packet[13 + index * 2] = ('A'.code + (value shr 4)).toByte()
            packet[14 + index * 2] = ('A'.code + (value and 0x0F)).toByte()
        }
        // packet[45] = 0 terminates the name.
        packet[47] = 0x21 // NBSTAT
        packet[49] = 0x01 // IN
        return packet
    }

    /**
     * The machine name from a node status response: the first unique (non-group) name with
     * suffix 0x00 (workstation), else the first unique name. Null for malformed packets.
     */
    fun parseNodeStatus(data: ByteArray, length: Int = data.size): String? {
        try {
            if (length < 12 + 1) return null
            val answers = ((data[6].toInt() and 0xFF) shl 8) or (data[7].toInt() and 0xFF)
            if (answers < 1) return null
            var offset = 12
            // Answer name: either a compression pointer or a label sequence.
            if ((data[offset].toInt() and 0xC0) == 0xC0) {
                offset += 2
            } else {
                while (offset < length && data[offset].toInt() != 0) offset += (data[offset].toInt() and 0xFF) + 1
                offset += 1
            }
            val type = ((data[offset].toInt() and 0xFF) shl 8) or (data[offset + 1].toInt() and 0xFF)
            if (type != 0x21) return null
            offset += 10 // type, class, ttl, rdlength
            val count = data[offset].toInt() and 0xFF
            offset += 1
            var fallback: String? = null
            for (index in 0 until count) {
                if (offset + 18 > length) break
                val name = String(data, offset, 15, Charsets.US_ASCII).trimEnd(' ', '\u0000')
                val suffix = data[offset + 15].toInt() and 0xFF
                val group = (data[offset + 16].toInt() and 0x80) != 0
                offset += 18
                if (group || name.isBlank()) continue
                if (suffix == 0x00) return name
                if (fallback == null) fallback = name
            }
            return fallback
        } catch (_: IndexOutOfBoundsException) {
            return null
        }
    }
}

object DnsPtr {
    fun reverseName(ipv4: String): String = ipv4.split('.').reversed().joinToString(".") + ".in-addr.arpa"

    fun query(ipv4: String, id: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        out.write(id shr 8 and 0xFF); out.write(id and 0xFF)
        out.write(0x01); out.write(0x00) // recursion desired
        out.write(0); out.write(1) // one question
        repeat(6) { out.write(0) }
        for (label in reverseName(ipv4).split('.')) {
            out.write(label.length)
            out.write(label.toByteArray(Charsets.US_ASCII))
        }
        out.write(0)
        out.write(0); out.write(12) // PTR
        out.write(0); out.write(1) // IN
        return out.toByteArray()
    }

    /** The first PTR target of a response, or null. Handles name compression. */
    fun parseResponse(data: ByteArray, length: Int = data.size): String? {
        try {
            if (length < 12) return null
            if ((data[3].toInt() and 0x0F) != 0) return null // rcode
            val questions = u16(data, 4)
            val answers = u16(data, 6)
            var offset = 12
            repeat(questions) { offset = skipName(data, offset) + 4 }
            repeat(answers) {
                offset = skipName(data, offset)
                val type = u16(data, offset)
                val rdLength = u16(data, offset + 8)
                val rdata = offset + 10
                if (type == 12) return readName(data, rdata).takeIf { it.isNotBlank() }
                offset = rdata + rdLength
            }
            return null
        } catch (_: IndexOutOfBoundsException) {
            return null
        }
    }

    private fun u16(data: ByteArray, offset: Int) =
        ((data[offset].toInt() and 0xFF) shl 8) or (data[offset + 1].toInt() and 0xFF)

    private fun skipName(data: ByteArray, start: Int): Int {
        var offset = start
        while (true) {
            val length = data[offset].toInt() and 0xFF
            if (length == 0) return offset + 1
            if (length and 0xC0 == 0xC0) return offset + 2
            offset += length + 1
        }
    }

    private fun readName(data: ByteArray, start: Int): String {
        val labels = mutableListOf<String>()
        var offset = start
        var jumps = 0
        while (jumps < 16) {
            val length = data[offset].toInt() and 0xFF
            if (length == 0) break
            if (length and 0xC0 == 0xC0) {
                offset = ((length and 0x3F) shl 8) or (data[offset + 1].toInt() and 0xFF)
                jumps++
                continue
            }
            labels.add(String(data, offset + 1, length, Charsets.UTF_8))
            offset += length + 1
        }
        return labels.joinToString(".")
    }

    /** "joao-pc.lan" -> "joao-pc"; drops the generic home domains routers append. */
    fun shortName(host: String): String? {
        val trimmed = host.trimEnd('.')
        if (trimmed.endsWith(".in-addr.arpa")) return null
        val first = trimmed.substringBefore('.')
        return first.takeIf { it.isNotBlank() && !Regex("^\\d+$").matches(it) && !it.matches(Regex("^(\\d+-){3}\\d+$")) }
    }
}

/** Device type ids shared with Flutter (lib/devices.dart). */
object DeviceTypes {
    const val ROUTER = "router"
    const val TV = "tv"
    const val PHONE = "phone"
    const val COMPUTER = "computer"
    const val PRINTER = "printer"
    const val CONSOLE = "console"
    const val SPEAKER = "speaker"
    const val CAMERA = "camera"
    const val IOT = "iot"
    const val UNKNOWN = "unknown"
}

object DeviceClassifier {
    private val vendors = listOf(
        "Samsung", "LG", "Apple", "Google", "Amazon", "Sony", "Xiaomi", "Motorola", "Philips", "TCL",
        "Roku", "Microsoft", "Nintendo", "Epson", "HP", "Brother", "Canon", "Intelbras", "TP-Link",
        "Huawei", "Positivo", "Multilaser", "Dell", "Lenovo", "Asus", "Acer", "Sonos", "Hikvision",
        "Tuya", "Shelly", "Sonoff", "Realme", "Oppo", "Vivo", "OnePlus", "Nokia", "Huawei", "Mi"
    )

    fun classify(observations: List<DeviceObservation>, isGateway: Boolean, isSelf: Boolean): String {
        if (isGateway) return DeviceTypes.ROUTER
        if (isSelf) return DeviceTypes.PHONE
        val services = observations.flatMap { it.services }.map { it.lowercase(Locale.ROOT) }.toSet()
        val upnp = observations.mapNotNull { it.upnpType }.joinToString(" ").lowercase(Locale.ROOT)
        val text = observations.flatMap { listOfNotNull(it.name, it.manufacturer, it.model, it.server, it.upnpType) }
            .joinToString(" ").lowercase(Locale.ROOT)
        fun has(vararg words: String) = words.any { text.contains(it) }
        fun service(vararg types: String) = types.any { type -> services.any { it.startsWith(type) } }

        return when {
            upnp.contains("internetgatewaydevice") || upnp.contains("wandevice") -> DeviceTypes.ROUTER
            has("xbox", "playstation", "ps4", "ps5", "nintendo", "switch-") -> DeviceTypes.CONSOLE
            service("_ipp", "_ipps", "_printer", "_pdl-datastream", "_scanner", "_uscan") ||
                upnp.contains("printer") || has("printer", "laserjet", "deskjet", "officejet", "ecotank", "impressora") ->
                DeviceTypes.PRINTER
            has("camera", "câmera", "ipcam", "hikvision", "dahua", "wyze", "imou", "ezviz") ||
                service("_rtsp", "_onvif") -> DeviceTypes.CAMERA
            has("google home", "nest mini", "nest audio", "nest hub", "echo", "alexa", "homepod", "sonos", "speaker") ->
                DeviceTypes.SPEAKER
            service("_androidtvremote", "_amzn-wplay", "_viziocast") ||
                Regex("(^|[^a-z])tv([^a-z]|$)|smarttv").containsMatchIn(text) ||
                has("chromecast", "roku", "fire tv", "firetv", "bravia", "tizen", "webos", "smartcast", "appletv", "apple tv") ||
                upnp.contains("mediarenderer") && !service("_spotify-connect") -> DeviceTypes.TV
            service("_googlecast") -> DeviceTypes.TV
            has("iphone", "ipad", "android", "galaxy", "pixel", "redmi", "moto ", "moto-", "motorola", "sm-", "xiaomi", "poco") ||
                service("_companion-link", "_apple-mobdev") -> DeviceTypes.PHONE
            service("_workstation", "_smb", "_rdp", "_sftp-ssh", "_ssh", "_afpovertcp", "_adisk") ||
                observations.any { it.source == "netbios" } ||
                has("macbook", "imac", "desktop", "laptop-", "notebook", "windows", "ubuntu") -> DeviceTypes.COMPUTER
            service("_spotify-connect", "_raop") -> DeviceTypes.SPEAKER
            service("_hap", "_matter", "_miio", "_esphomelib", "_shelly", "_tuya") ||
                has("esp-", "esp32", "esp8266", "tasmota", "shelly", "sonoff", "tuya", "lamp", "bulb", "plug", "lampada", "tomada") ->
                DeviceTypes.IOT
            else -> DeviceTypes.UNKNOWN
        }
    }

    /** Manufacturer from UPnP or, failing that, a known brand in the names. */
    fun vendor(observations: List<DeviceObservation>): String? {
        observations.firstNotNullOfOrNull { it.manufacturer?.takeIf(String::isNotBlank) }?.let { return cleanVendor(it) }
        val text = observations.flatMap { listOfNotNull(it.name, it.model, it.server) }.joinToString(" ")
        return vendors.firstOrNull { brand ->
            Regex("(^|[^A-Za-z])${Regex.escape(brand)}([^A-Za-z]|$)", RegexOption.IGNORE_CASE).containsMatchIn(text)
        }?.let { if (it == "Mi") "Xiaomi" else it }
            ?: if (Regex("iphone|ipad|macbook|imac|apple", RegexOption.IGNORE_CASE).containsMatchIn(text)) "Apple" else null
    }

    private fun cleanVendor(raw: String): String = raw
        .replace(Regex("(?i),?\\s*(inc\\.?|ltd\\.?|co\\.,?|corporation|corp\\.?|electronics)\\b"), "")
        .trim().trimEnd(',', '.').ifBlank { raw.trim() }
}

object DeviceMerger {
    /** Name priority: what the device calls itself first, the router's DNS last. */
    private val namePriority = listOf("self", "upnp", "mdns", "netbios", "dns")

    fun merge(observations: List<DeviceObservation>, gatewayIp: String?, selfIp: String?): List<LanDevice> =
        observations.groupBy { it.ip }.map { (ip, items) ->
            val isGateway = ip == gatewayIp
            val isSelf = ip == selfIp
            val name = namePriority.firstNotNullOfOrNull { source ->
                items.filter { it.source == source }.firstNotNullOfOrNull { it.name?.let(::cleanName) }
            }
            LanDevice(
                ip = ip,
                name = name,
                type = DeviceClassifier.classify(items, isGateway, isSelf),
                vendor = DeviceClassifier.vendor(items),
                model = items.firstNotNullOfOrNull { it.model?.takeIf(String::isNotBlank) },
                sources = items.map { it.source }.distinct().sorted(),
                services = items.flatMap { it.services }.distinct().sorted(),
                isGateway = isGateway,
                isSelf = isSelf,
                ports = items.mapNotNull { it.port }.filter { it in 1..65535 }.distinct()
            )
        }.sortedWith(compareBy<LanDevice>({ !it.isGateway }, { !it.isSelf }, { ipOrder(it.ip) }))

    /** mDNS instance names escape spaces and carry service suffixes; tidy them for display. */
    fun cleanName(raw: String): String? {
        val name = raw.replace("\\032", " ").replace("\\.", ".").replace(Regex("\\\\(\\d{3})")) {
            it.groupValues[1].toInt().toChar().toString()
        }.replace(Regex("\\s*\\[([0-9a-f]{2}:){5}[0-9a-f]{2}\\]$", RegexOption.IGNORE_CASE), "").trim()
        // _workstation names end with the MAC ("pc [aa:bb:..]"); the app does not show MACs.
        // Chromecast-style ids ("Chromecast-1a2b3c...") and raw MAC-ish names stay but shortened.
        return name.replace(Regex("-[0-9a-f]{24,}$", RegexOption.IGNORE_CASE), "").take(48).takeIf { it.isNotBlank() }
    }

    fun ipOrder(ip: String): Long = ip.split('.').fold(0L) { acc, part -> acc * 256 + (part.toLongOrNull() ?: 0L) }
}

object LanStats {
    /**
     * Round-trip summary of LAN probes: median, RFC 3550-style jitter and loss. Unlike the
     * internet check, slow replies are not counted as SYN retransmissions: Wi-Fi clients in
     * power save legitimately answer hundreds of ms late.
     */
    fun summarize(samples: List<Long>, attempted: Int): LatencyResult {
        val total = attempted.coerceAtLeast(1)
        if (samples.isEmpty()) return LatencyResult(-1, -1, 100, 0, total)
        return LatencyResult(
            latency = ConnectionMath.median(samples),
            jitter = ConnectionMath.jitter(samples),
            failureRate = (total - samples.size) * 100 / total,
            successfulSamples = samples.size,
            totalSamples = total
        )
    }

    /** Usable host addresses of the subnet; wider than /22 falls back to the own /24. */
    fun subnetHosts(selfIp: String, prefix: Int): List<String> {
        val parts = selfIp.split('.').map { it.toInt() }
        val self = (parts[0].toLong() shl 24) or (parts[1].toLong() shl 16) or (parts[2].toLong() shl 8) or parts[3].toLong()
        val bits = if (prefix in 22..30) prefix else 24
        val mask = (0xFFFFFFFFL shl (32 - bits)) and 0xFFFFFFFFL
        val network = self and mask
        val broadcast = network or (mask.inv() and 0xFFFFFFFFL)
        return ((network + 1) until broadcast).filter { it != self }.map { value ->
            "${value shr 24 and 255}.${value shr 16 and 255}.${value shr 8 and 255}.${value and 255}"
        }
    }
}

/** A neighbour network from the Wi-Fi scan. */
data class WifiNetwork(
    val ssid: String,
    val bssid: String,
    val frequency: Int,
    val rssi: Int,
    val widthMhz: Int = 20,
    val centerFrequency: Int = 0
)

object WifiMath {
    fun band(frequency: Int): String = when {
        frequency in 2400..2500 -> "2.4"
        frequency in 4900..5925 -> "5"
        frequency in 5925..7125 -> "6"
        else -> "?"
    }

    fun channel(frequency: Int): Int = when {
        frequency == 2484 -> 14
        frequency in 2412..2472 -> (frequency - 2407) / 5
        frequency in 5000..5925 -> (frequency - 5000) / 5
        frequency in 5955..7115 -> (frequency - 5950) / 5
        else -> 0
    }

    /** Occupied range in MHz; 2.4 GHz transmissions spread ~22 MHz even on 20 MHz channels. */
    fun range(frequency: Int, widthMhz: Int, centerFrequency: Int): IntRange {
        val center = if (centerFrequency > 0) centerFrequency else frequency
        val half = if (band(frequency) == "2.4") maxOf(11, widthMhz / 2) else maxOf(10, widthMhz / 2)
        return (center - half) until (center + half)
    }

    /** "same" when the primary channel is shared, "partial" when the ranges overlap, else "none". */
    fun overlap(mine: WifiNetwork, other: WifiNetwork): String {
        if (band(mine.frequency) != band(other.frequency)) return "none"
        if (mine.frequency == other.frequency) return "same"
        val a = range(mine.frequency, mine.widthMhz, mine.centerFrequency)
        val b = range(other.frequency, other.widthMhz, other.centerFrequency)
        return if (a.first < b.last && b.first < a.last) "partial" else "none"
    }

    /** 0 at -90 dBm (barely audible) to 1 at -50 dBm (as loud as a nearby router). */
    fun loudness(rssi: Int): Double = ((rssi + 90) / 40.0).coerceIn(0.0, 1.0)

    /**
     * Interference score: sum of the loudness of overlapping networks. Partially overlapping
     * networks weigh 1.2 because they cannot coordinate airtime with yours (CSMA only defers
     * to decodable frames on the same primary channel), so they collide more.
     */
    fun interferenceScore(mine: WifiNetwork, others: List<WifiNetwork>): Double =
        others.filter { it.bssid != mine.bssid }.sumOf { other ->
            when (overlap(mine, other)) {
                "same" -> loudness(other.rssi)
                "partial" -> 1.2 * loudness(other.rssi)
                else -> 0.0
            }
        }

    /**
     * A clearly quieter 2.4 GHz channel among the non-overlapping 1, 6 and 11, or null when the
     * current one is fine (or the network is on 5/6 GHz, where wide channels make advice unreliable).
     */
    fun suggestedChannel(mine: WifiNetwork, others: List<WifiNetwork>): Int? {
        if (band(mine.frequency) != "2.4") return null
        val current = interferenceScore(mine, others)
        val best = listOf(1, 6, 11).map { channel ->
            val frequency = 2407 + channel * 5
            channel to interferenceScore(mine.copy(frequency = frequency, widthMhz = 20, centerFrequency = 0), others)
        }.minByOrNull { it.second } ?: return null
        return best.first.takeIf { it != channel(mine.frequency) && best.second <= current - 0.8 }
    }

    fun interferenceLevel(score: Double): String = when {
        score < 1.0 -> "low"
        score < 3.0 -> "medium"
        else -> "high"
    }
}
