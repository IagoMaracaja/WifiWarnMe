package com.wifiwarnme.app

import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceDiscoveryTest {
    // ------------------------------------------------------------------ SSDP / UPnP

    @Test
    fun parsesSsdpSearchReplyHeadersCaseInsensitively() {
        val reply = "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nlocation: http://192.168.0.20:7676/smp_2_\r\n" +
            "Server: SHP, UPnP/1.0, Samsung UPnP SDK/1.0\r\nST: urn:schemas-upnp-org:device:MediaRenderer:1\r\nUSN: uuid:abc::upnp:rootdevice\r\n\r\n"
        val parsed = Ssdp.parseResponse(reply)!!
        assertEquals("http://192.168.0.20:7676/smp_2_", parsed.location)
        assertEquals("SHP, UPnP/1.0, Samsung UPnP SDK/1.0", parsed.server)
        assertEquals("urn:schemas-upnp-org:device:MediaRenderer:1", parsed.st)
        assertEquals("uuid:abc::upnp:rootdevice", parsed.usn)
    }

    @Test
    fun acceptsNotifyAndRejectsOtherMessages() {
        val notify = "NOTIFY * HTTP/1.1\nNT: upnp:rootdevice\nLOCATION: http://10.0.0.1:1900/igd.xml\n\n"
        assertEquals("upnp:rootdevice", Ssdp.parseResponse(notify)!!.st)
        assertNull(Ssdp.parseResponse("M-SEARCH * HTTP/1.1\r\nST: ssdp:all\r\n\r\n"))
        assertNull(Ssdp.parseResponse(""))
    }

    @Test
    fun searchRequestIsAValidMSearch() {
        val request = Ssdp.searchRequest("ssdp:all", 2)
        assertTrue(request.startsWith("M-SEARCH * HTTP/1.1\r\n"))
        assertTrue(request.contains("HOST: 239.255.255.250:1900\r\n"))
        assertTrue(request.contains("MAN: \"ssdp:discover\"\r\n"))
        assertTrue(request.endsWith("\r\n\r\n"))
    }

    @Test
    fun locationHostOnlyReturnsTheHost() {
        assertEquals("192.168.0.20", Ssdp.locationHost("http://192.168.0.20:7676/smp_2_"))
        assertEquals("10.0.0.1", Ssdp.locationHost("HTTP://10.0.0.1/desc.xml"))
        assertNull(Ssdp.locationHost("not a url"))
    }

    @Test
    fun parsesUpnpDescriptionWithNamespacesAndEntities() {
        val xml = """<?xml version="1.0"?>
            <root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:sec="http://www.sec.co.kr/dlna">
              <device>
                <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
                <friendlyName>[TV] Samsung Q60 &amp; Sala</friendlyName>
                <manufacturer>Samsung Electronics</manufacturer>
                <modelName> QN55Q60 </modelName>
                <sec:ProductCap>Resolution</sec:ProductCap>
              </device>
            </root>"""
        val description = Ssdp.parseDescription(xml)
        assertEquals("[TV] Samsung Q60 & Sala", description.friendlyName)
        assertEquals("Samsung Electronics", description.manufacturer)
        assertEquals("QN55Q60", description.modelName)
        assertEquals("urn:schemas-upnp-org:device:MediaRenderer:1", description.deviceType)
        assertNull(description.modelDescription)
    }

    // ------------------------------------------------------------------ NetBIOS

    @Test
    fun buildsTheWildcardNodeStatusRequest() {
        val packet = NetBios.nodeStatusRequest(0x1234)
        assertEquals(50, packet.size)
        assertEquals(0x12.toByte(), packet[0])
        assertEquals(0x34.toByte(), packet[1])
        assertEquals(1, packet[5].toInt())
        assertEquals(0x20, packet[12].toInt())
        // '*' = 0x2A -> 'C' 'K', then padding 0x00 -> 'A' 'A'.
        assertEquals('C'.code.toByte(), packet[13])
        assertEquals('K'.code.toByte(), packet[14])
        assertEquals('A'.code.toByte(), packet[15])
        assertEquals(0, packet[45].toInt())
        assertArrayEquals(byteArrayOf(0, 0x21, 0, 1), packet.copyOfRange(46, 50))
    }

    private fun nodeStatusResponse(names: List<Triple<String, Int, Boolean>>, compressed: Boolean = false): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(byteArrayOf(0x12, 0x34, 0x84.toByte(), 0, 0, 0, 0, 1, 0, 0, 0, 0))
        if (compressed) {
            out.write(byteArrayOf(0xC0.toByte(), 0x0C))
        } else {
            out.write(0x20)
            out.write(ByteArray(32) { 'A'.code.toByte() })
            out.write(0)
        }
        out.write(byteArrayOf(0, 0x21, 0, 1, 0, 0, 0, 0))
        val rdLength = 1 + names.size * 18 + 46
        out.write(rdLength shr 8); out.write(rdLength and 0xFF)
        out.write(names.size)
        for ((name, suffix, group) in names) {
            out.write(name.padEnd(15, ' ').toByteArray(Charsets.US_ASCII))
            out.write(suffix)
            out.write(if (group) 0x84 else 0x04)
            out.write(0x00)
        }
        out.write(ByteArray(46)) // statistics: MAC (zeros on most hosts) and counters
        return out.toByteArray()
    }

    @Test
    fun parsesTheWorkstationNameAndSkipsGroups() {
        val response = nodeStatusResponse(listOf(
            Triple("WORKGROUP", 0x00, true),
            Triple("DESKTOP-JOAO", 0x20, false),
            Triple("DESKTOP-JOAO", 0x00, false)
        ))
        assertEquals("DESKTOP-JOAO", NetBios.parseNodeStatus(response))
        assertEquals("DESKTOP-JOAO", NetBios.parseNodeStatus(nodeStatusResponse(listOf(Triple("DESKTOP-JOAO", 0x00, false)), compressed = true)))
    }

    @Test
    fun fallsBackToAnyUniqueNameAndRejectsGarbage() {
        assertEquals("NAS", NetBios.parseNodeStatus(nodeStatusResponse(listOf(Triple("NAS", 0x20, false)))))
        assertNull(NetBios.parseNodeStatus(nodeStatusResponse(listOf(Triple("WORKGROUP", 0x00, true)))))
        assertNull(NetBios.parseNodeStatus(ByteArray(5)))
        assertNull(NetBios.parseNodeStatus(nodeStatusResponse(listOf(Triple("PC", 0, false))).copyOf(40)))
    }

    // ------------------------------------------------------------------ DNS PTR

    @Test
    fun buildsAPtrQuery() {
        assertEquals("20.0.168.192.in-addr.arpa", DnsPtr.reverseName("192.168.0.20"))
        val query = DnsPtr.query("192.168.0.20", 7)
        assertEquals(0, query[0].toInt())
        assertEquals(7, query[1].toInt())
        assertEquals(1, query[5].toInt())
        assertEquals(2, query[12].toInt()) // "20"
        assertArrayEquals(byteArrayOf(0, 12, 0, 1), query.copyOfRange(query.size - 4, query.size))
    }

    @Test
    fun parsesACompressedPtrAnswer() {
        val query = DnsPtr.query("192.168.0.20", 7)
        val out = ByteArrayOutputStream()
        out.write(query, 0, 12)
        val response = out.toByteArray().also {
            it[2] = 0x81.toByte(); it[3] = 0x80.toByte(); it[7] = 1 // 1 answer
        }
        val body = ByteArrayOutputStream()
        body.write(response)
        body.write(query, 12, query.size - 12) // question
        body.write(byteArrayOf(0xC0.toByte(), 0x0C, 0, 12, 0, 1, 0, 0, 0, 60))
        val target = byteArrayOf(10) + "galaxy-s21".toByteArray() + byteArrayOf(3) + "lan".toByteArray() + byteArrayOf(0)
        body.write(0); body.write(target.size)
        body.write(target)
        assertEquals("galaxy-s21.lan", DnsPtr.parseResponse(body.toByteArray()))
    }

    @Test
    fun ptrErrorsAndShortNames() {
        val query = DnsPtr.query("192.168.0.20", 7)
        val nxdomain = query.copyOf().also { it[3] = 0x83.toByte() }
        assertNull(DnsPtr.parseResponse(nxdomain))
        assertEquals("joao-pc", DnsPtr.shortName("joao-pc.lan."))
        assertNull(DnsPtr.shortName("20.0.168.192.in-addr.arpa"))
        assertNull(DnsPtr.shortName("192-168-0-20.home"))
    }

    // ------------------------------------------------------------------ classification

    private fun classify(vararg observations: DeviceObservation, gateway: Boolean = false, self: Boolean = false) =
        DeviceClassifier.classify(observations.toList(), gateway, self)

    @Test
    fun classifiesCommonHomeDevices() {
        val ip = "192.168.0.10"
        assertEquals(DeviceTypes.ROUTER, classify(DeviceObservation(ip, "ping"), gateway = true))
        assertEquals(DeviceTypes.PHONE, classify(DeviceObservation(ip, "self", "Este aparelho"), self = true))
        assertEquals(DeviceTypes.TV, classify(DeviceObservation(ip, "upnp", "[TV] Samsung Q60", upnpType = "urn:schemas-upnp-org:device:MediaRenderer:1")))
        assertEquals(DeviceTypes.TV, classify(DeviceObservation(ip, "mdns", "Chromecast-abc", setOf("_googlecast._tcp"), model = "Chromecast")))
        assertEquals(DeviceTypes.SPEAKER, classify(DeviceObservation(ip, "mdns", "Cozinha", setOf("_googlecast._tcp"), model = "Google Home Mini")))
        assertEquals(DeviceTypes.PRINTER, classify(DeviceObservation(ip, "mdns", "EPSON L3150", setOf("_ipp._tcp"))))
        assertEquals(DeviceTypes.CONSOLE, classify(DeviceObservation(ip, "dns", "PS5-123")))
        assertEquals(DeviceTypes.PHONE, classify(DeviceObservation(ip, "mdns", "iPhone de Ana", setOf("_companion-link._tcp"))))
        assertEquals(DeviceTypes.PHONE, classify(DeviceObservation(ip, "dns", "Galaxy-A52")))
        assertEquals(DeviceTypes.COMPUTER, classify(DeviceObservation(ip, "netbios", "DESKTOP-JOAO")))
        assertEquals(DeviceTypes.COMPUTER, classify(DeviceObservation(ip, "mdns", "MacBook Pro", setOf("_smb._tcp"))))
        assertEquals(DeviceTypes.CAMERA, classify(DeviceObservation(ip, "upnp", "IPCam Garagem")))
        assertEquals(DeviceTypes.IOT, classify(DeviceObservation(ip, "mdns", "Lâmpada", setOf("_hap._tcp"))))
        assertEquals(DeviceTypes.ROUTER, classify(DeviceObservation(ip, "upnp", "Archer", upnpType = "urn:schemas-upnp-org:device:InternetGatewayDevice:1")))
        assertEquals(DeviceTypes.UNKNOWN, classify(DeviceObservation(ip, "ping")))
    }

    @Test
    fun tvTokenNeedsAWordBoundary() {
        assertEquals(DeviceTypes.UNKNOWN, classify(DeviceObservation("1.1.1.1", "dns", "atvdevice")))
        assertEquals(DeviceTypes.TV, classify(DeviceObservation("1.1.1.1", "dns", "LG-TV")))
    }

    @Test
    fun vendorComesFromUpnpOrKnownBrands() {
        assertEquals("Samsung", DeviceClassifier.vendor(listOf(DeviceObservation("1", "upnp", manufacturer = "Samsung Electronics"))))
        assertEquals("Apple", DeviceClassifier.vendor(listOf(DeviceObservation("1", "mdns", "iPhone de Ana"))))
        assertEquals("LG", DeviceClassifier.vendor(listOf(DeviceObservation("1", "dns", "LG-TV"))))
        assertNull(DeviceClassifier.vendor(listOf(DeviceObservation("1", "dns", "desconhecido"))))
    }

    // ------------------------------------------------------------------ merging

    @Test
    fun mergesSourcesByIpWithNamePriority() {
        val devices = DeviceMerger.merge(listOf(
            DeviceObservation("192.168.0.30", "ping"),
            DeviceObservation("192.168.0.30", "dns", "samsung-tv"),
            DeviceObservation("192.168.0.30", "upnp", "[TV] Sala", manufacturer = "Samsung Electronics", model = "Q60",
                upnpType = "urn:schemas-upnp-org:device:MediaRenderer:1"),
            DeviceObservation("192.168.0.30", "mdns", "Sala\\032TV", setOf("_airplay._tcp")),
            DeviceObservation("192.168.0.1", "ping"),
            DeviceObservation("192.168.0.1", "gateway"),
            DeviceObservation("192.168.0.5", "self", "Este aparelho (SM-A525M)"),
            DeviceObservation("192.168.0.9", "mdns", "Living\\032Room", setOf("_spotify-connect._tcp"))
        ), gatewayIp = "192.168.0.1", selfIp = "192.168.0.5")
        assertEquals(listOf("192.168.0.1", "192.168.0.5", "192.168.0.9", "192.168.0.30"), devices.map { it.ip })
        val tv = devices.last()
        assertEquals("[TV] Sala", tv.name)
        assertEquals(DeviceTypes.TV, tv.type)
        assertEquals("Samsung", tv.vendor)
        assertEquals("Q60", tv.model)
        assertEquals(listOf("dns", "mdns", "ping", "upnp"), tv.sources)
        assertTrue(devices.first().isGateway)
        assertEquals(DeviceTypes.ROUTER, devices.first().type)
        assertTrue(devices[1].isSelf)
        assertEquals("Living Room", devices[2].name)
        assertEquals(DeviceTypes.SPEAKER, devices[2].type)
    }

    @Test
    fun cleansMdnsNames() {
        assertEquals("Sala de Estar", DeviceMerger.cleanName("Sala\\032de\\032Estar"))
        assertEquals("Chromecast", DeviceMerger.cleanName("Chromecast-1a2b3c4d5e6f7a8b9c0d1e2f3a4b"))
        assertNull(DeviceMerger.cleanName("   "))
        assertEquals("myrouter", DeviceMerger.cleanName("myrouter [e8:20:e2:97:b2:cc]"))
        assertEquals(DeviceTypes.COMPUTER, DeviceClassifier.classify(
            listOf(DeviceObservation("1", "mdns", "Spotify Desktop Launcher", setOf("_spotify-connect._tcp"), port = 57621)),
            isGateway = false, isSelf = false))
    }

    // ------------------------------------------------------------------ LAN stats & subnet

    @Test
    fun lanStatsKeepSlowRepliesAndCountLoss() {
        val result = LanStats.summarize(listOf(4L, 6L, 900L, 5L), 5)
        assertEquals(5L, result.latency)
        assertEquals(20, result.failureRate)
        assertEquals((2 + 894 + 895) / 3L, result.jitter)
        assertEquals(-1L, LanStats.summarize(emptyList(), 4).latency)
        assertEquals(100, LanStats.summarize(emptyList(), 4).failureRate)
    }

    @Test
    fun subnetHostsExcludeNetworkBroadcastAndSelf() {
        val hosts = LanStats.subnetHosts("192.168.0.5", 24)
        assertEquals(253, hosts.size)
        assertEquals("192.168.0.1", hosts.first())
        assertEquals("192.168.0.254", hosts.last())
        assertTrue("192.168.0.5" !in hosts)
        assertEquals(1021, LanStats.subnetHosts("10.0.1.7", 22).size)
        // Very wide subnets are limited to the phone's own /24.
        assertEquals(253, LanStats.subnetHosts("10.20.30.40", 8).size)
        assertEquals("10.20.30.1", LanStats.subnetHosts("10.20.30.40", 8).first())
    }

    // ------------------------------------------------------------------ Wi-Fi math

    @Test
    fun channelsAndBands() {
        assertEquals(1, WifiMath.channel(2412))
        assertEquals(6, WifiMath.channel(2437))
        assertEquals(13, WifiMath.channel(2472))
        assertEquals(14, WifiMath.channel(2484))
        assertEquals(36, WifiMath.channel(5180))
        assertEquals(149, WifiMath.channel(5745))
        assertEquals(1, WifiMath.channel(5955))
        assertEquals("2.4", WifiMath.band(2437))
        assertEquals("5", WifiMath.band(5180))
        assertEquals("6", WifiMath.band(5955))
    }

    private fun net(frequency: Int, rssi: Int = -60, width: Int = 20, center: Int = 0, bssid: String = "other$frequency$rssi") =
        WifiNetwork("x", bssid, frequency, rssi, width, center)

    @Test
    fun overlapOn24GhzFollowsChannelSpacing() {
        val mine = net(2437, bssid = "me") // channel 6
        assertEquals("same", WifiMath.overlap(mine, net(2437)))
        assertEquals("partial", WifiMath.overlap(mine, net(2447))) // channel 8
        assertEquals("partial", WifiMath.overlap(mine, net(2427))) // channel 4
        assertEquals("none", WifiMath.overlap(mine, net(2412))) // channel 1
        assertEquals("none", WifiMath.overlap(mine, net(2462))) // channel 11
        assertEquals("none", WifiMath.overlap(mine, net(5180)))
    }

    @Test
    fun overlapOn5GhzUsesChannelWidth() {
        val mine = net(5180, width = 80, center = 5210, bssid = "me") // 36-48
        assertEquals("partial", WifiMath.overlap(mine, net(5200))) // channel 40 inside the 80 MHz block
        assertEquals("none", WifiMath.overlap(mine, net(5260)))
        assertEquals("none", WifiMath.overlap(net(5180, bssid = "me"), net(5200)))
    }

    @Test
    fun interferenceScoreWeighsLoudnessAndIgnoresOwnBssid() {
        val mine = net(2437, -50, bssid = "me")
        assertEquals(0.0, WifiMath.loudness(-95), 1e-9)
        assertEquals(1.0, WifiMath.loudness(-40), 1e-9)
        assertEquals(0.5, WifiMath.loudness(-70), 1e-9)
        val others = listOf(net(2437, -50), net(2442, -70), net(2412, -40), net(2437, -50, bssid = "me"))
        assertEquals(1.0 + 1.2 * 0.5, WifiMath.interferenceScore(mine, others), 1e-9)
        assertEquals("medium", WifiMath.interferenceLevel(1.6))
        assertEquals("low", WifiMath.interferenceLevel(0.4))
        assertEquals("high", WifiMath.interferenceLevel(3.2))
    }

    @Test
    fun suggestsAQuieterChannelOnlyWhenClearlyBetter() {
        val mine = net(2437, -50, bssid = "me")
        val crowded = listOf(net(2437, -45), net(2437, -50, bssid = "b"), net(2442, -55))
        assertEquals(1, WifiMath.suggestedChannel(mine, crowded))
        assertNull(WifiMath.suggestedChannel(mine, listOf(net(2412, -80))))
        assertNull(WifiMath.suggestedChannel(net(5180, bssid = "me"), crowded))
    }
}
