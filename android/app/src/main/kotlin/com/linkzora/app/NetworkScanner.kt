package com.linkzora.app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.ConnectException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.SocketTimeoutException
import java.net.URL
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.thread

/**
 * Local network inventory: who is on the network (mDNS/DNS-SD, SSDP/UPnP, NetBIOS, reverse
 * DNS and a reachability sweep), the LAN latency of each device, the gateway versus the
 * internet, and the Wi-Fi neighbourhood ([WifiEnvironment]).
 *
 * Android gives apps no access to other devices' traffic, the ARP table or MAC addresses, so
 * this is what the phone can observe by itself. Pure parsing lives in DeviceDiscovery.kt.
 */
class NetworkScanner(private val context: Context) {
    companion object {
        private const val TAG = "LinkzoraScan"
        private const val PREFS = "linkzora_network"
        private const val INVENTORY_EVERY_MS = 15 * 60_000L
        private val MDNS_TYPES = listOf(
            "_googlecast._tcp", "_airplay._tcp", "_raop._tcp", "_companion-link._tcp",
            "_spotify-connect._tcp", "_androidtvremote2._tcp", "_amzn-wplay._tcp", "_hap._tcp",
            "_ipp._tcp", "_printer._tcp", "_smb._tcp", "_workstation._tcp",
            "_http._tcp", "_device-info._tcp", "_matter._tcp", "_ssh._tcp"
        )
        private val SWEEP_PORTS = listOf(80, 443, 62078, 8009)

        private val lock = ReentrantLock()
        private val background = Executors.newSingleThreadExecutor()
        private val main = Handler(Looper.getMainLooper())

        @Volatile private var running = false
        @Volatile private var stage = ""
        @Volatile private var fraction = 0.0

        @Volatile private var sharedStore: DeviceInventoryStore? = null

        fun store(context: Context): DeviceInventoryStore = sharedStore ?: synchronized(this) {
            sharedStore ?: DeviceInventoryStore.of(context.applicationContext.filesDir).also { sharedStore = it }
        }

        /** Method channel entry point for `scanNetwork`, `scanProgress` and `deviceHistory`. */
        fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
            val app = context.applicationContext
            when (call.method) {
                "scanProgress" -> result.success(mapOf("running" to running, "stage" to stage, "fraction" to fraction))
                "deviceHistory" -> thread(name = "linkzora-history") {
                    val history = try { store(app).history() } catch (e: Exception) { null }
                    main.post { if (history != null) result.success(history) else result.error("history_failed", NativeLocale.localized(app).getString(R.string.error_history), null) }
                }
                "scanNetwork" -> thread(name = "linkzora-scan") {
                    val scan = try {
                        NetworkScanner(app).scan(light = false)
                    } catch (e: Exception) {
                        Log.w(TAG, "scan failed", e)
                        null
                    }
                    main.post { if (scan != null) result.success(scan) else result.error("scan_failed", NativeLocale.localized(app).getString(R.string.error_scan), null) }
                }
                else -> result.notImplemented()
            }
        }

        /**
         * Called by [MonitorService] after every check: measures the gateway (so each internet
         * measurement has a local reference) and, every 15 min on Wi-Fi, takes a light device
         * inventory for the presence history. Runs on its own thread with a short wake lock.
         */
        fun afterCheck(context: Context, transportType: String) {
            if (transportType != "wifi" && transportType != "ethernet") return
            val app = context.applicationContext
            background.execute {
                val wake = app.getSystemService(PowerManager::class.java)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Linkzora:lan")
                    .apply { acquire(45_000L) }
                try {
                    val scanner = NetworkScanner(app)
                    scanner.probeGatewayForHistory()
                    val last = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("lastInventoryAt", 0L)
                    if (System.currentTimeMillis() - last >= INVENTORY_EVERY_MS && lock.tryLock()) {
                        try {
                            scanner.scanLocked(light = true)
                        } finally {
                            lock.unlock()
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "background inventory failed", e)
                } finally {
                    if (wake.isHeld) wake.release()
                }
            }
        }
    }

    private data class Lan(
        val network: Network,
        val transport: String,
        val selfIp: String,
        val prefix: Int,
        val gateway: String?,
        val dns: List<InetAddress>,
        val nic: NetworkInterface?
    )

    private val debuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Stage shown by the Rede tab while scanning, in the app language (empty when done). */
    private fun progress(label: Int?, value: Double) {
        stage = label?.let { NativeLocale.localized(context).getString(it) } ?: ""
        fraction = value.coerceIn(0.0, 1.0)
    }

    fun scan(light: Boolean): Map<String, Any?> {
        running = true
        progress(R.string.scan_waiting, 0.01)
        lock.lock()
        try {
            return scanLocked(light)
        } finally {
            lock.unlock()
            running = false
        }
    }

    @Suppress("DEPRECATION")
    private fun lan(): Lan? {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        fun transportOf(network: Network): String? {
            val caps = cm.getNetworkCapabilities(network) ?: return null
            return when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> null
            }
        }
        // With a VPN the active network is the tunnel; the inventory needs the Wi-Fi itself.
        val network = cm.activeNetwork?.takeIf { transportOf(it) != null }
            ?: cm.allNetworks.firstOrNull { transportOf(it) != null }
            ?: return null
        val properties = cm.getLinkProperties(network) ?: return null
        val address = properties.linkAddresses.firstOrNull { it.address is Inet4Address } ?: return null
        val gateway = properties.routes
            .firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }
            ?.gateway?.hostAddress?.takeIf { it != "0.0.0.0" }
        return Lan(
            network = network,
            transport = transportOf(network) ?: "wifi",
            selfIp = address.address.hostAddress ?: return null,
            prefix = address.prefixLength,
            gateway = gateway,
            dns = properties.dnsServers.filterIsInstance<Inet4Address>(),
            nic = try { properties.interfaceName?.let(NetworkInterface::getByName) } catch (_: Exception) { null }
        )
    }

    internal fun scanLocked(light: Boolean): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val elapsedStart = SystemClock.elapsedRealtime()
        progress(R.string.scan_preparing, 0.03)
        val lan = lan() ?: return mapOf(
            "timestamp" to startedAt,
            "error" to "not_wifi",
            "devices" to emptyList<Any>()
        )
        val wifiManager = context.applicationContext.getSystemService(WifiManager::class.java)
        val multicast = wifiManager.createMulticastLock("linkzora-scan").apply {
            setReferenceCounted(false)
            acquire()
        }
        val pool = Executors.newCachedThreadPool()
        try {
            val wifiFuture: Future<Map<String, Any?>>? = if (lan.transport == "wifi") {
                pool.submit<Map<String, Any?>> { WifiEnvironment.read(context, requestScan = !light) }
            } else null
            val mdnsFuture = pool.submit<List<DeviceObservation>> { discoverMdns(if (light) 3_000L else 4_500L, light) }
            val ssdpFuture = pool.submit<List<DeviceObservation>> { discoverSsdp(lan, if (light) 2_500L else 3_500L) }

            progress(R.string.scan_searching, 0.06)
            val hosts = LanStats.subnetHosts(lan.selfIp, lan.prefix)
            val alive = sweep(lan, hosts, light)
            progress(R.string.scan_listening, 0.6)
            val mdns = futureOr(mdnsFuture, 20_000L, emptyList())
            val ssdp = futureOr(ssdpFuture, 12_000L, emptyList())

            progress(R.string.scan_names, 0.66)
            val candidates = (alive.keys + mdns.map { it.ip } + ssdp.map { it.ip } + listOfNotNull(lan.gateway))
                .filter { it != lan.selfIp }.toSet()
            val netbiosFuture = pool.submit<Map<String, String>> { netbiosNames(lan, candidates) }
            val ptr = ptrNames(lan, candidates + lan.selfIp)
            val netbios = futureOr(netbiosFuture, 5_000L, emptyMap())

            val observations = mutableListOf<DeviceObservation>()
            alive.keys.forEach { observations.add(DeviceObservation(it, "ping")) }
            observations.addAll(mdns)
            observations.addAll(ssdp)
            netbios.forEach { (ip, name) -> observations.add(DeviceObservation(ip, "netbios", name)) }
            ptr.forEach { (ip, host) -> DnsPtr.shortName(host)?.let { observations.add(DeviceObservation(ip, "dns", it)) } }
            lan.gateway?.let { observations.add(DeviceObservation(it, "gateway")) }
            observations.add(DeviceObservation(lan.selfIp, "self", NativeLocale.localized(context).getString(R.string.scan_self_device, Build.MODEL), manufacturer = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }))
            val devices = DeviceMerger.merge(observations, lan.gateway, lan.selfIp)

            val stats = ConcurrentHashMap<String, LatencyResult>()
            var gatewayStats: LatencyResult? = null
            var internetStats: LatencyResult? = null
            if (!light) {
                progress(R.string.scan_latency, 0.72)
                val targets = devices.filter { !it.isSelf }.take(48)
                val done = AtomicInteger()
                val probePool = Executors.newFixedThreadPool(6)
                val internetFuture = pool.submit<LatencyResult> { measureInternet(lan) }
                targets.map { device ->
                    probePool.submit {
                        val samples = if (device.isGateway) 10 else 5
                        stats[device.ip] = measureHost(lan, device.ip, alive[device.ip], samples, device.ports)
                        progress(R.string.scan_latency, 0.72 + 0.18 * done.incrementAndGet() / targets.size)
                    }
                }.forEach { futureOr<Any?>(it, 30_000L, null) }
                probePool.shutdownNow()
                gatewayStats = lan.gateway?.let { stats[it] }
                internetStats = futureOr<LatencyResult?>(internetFuture, 15_000L, null)
            }

            progress(R.string.scan_wifi, 0.93)
            val wifi = wifiFuture?.let { futureOr<Map<String, Any?>?>(it, 10_000L, null) }
                ?: if (lan.transport == "wifi") mapOf("available" to false, "reason" to "timeout") else null

            val result = linkedMapOf<String, Any?>(
                "timestamp" to startedAt,
                "durationMs" to (SystemClock.elapsedRealtime() - elapsedStart),
                "light" to light,
                "transportType" to lan.transport,
                "selfIp" to lan.selfIp,
                "prefix" to lan.prefix,
                "gatewayIp" to lan.gateway,
                "hostsSwept" to hosts.size,
                "gateway" to gatewayStats?.toMap(),
                "internet" to internetStats?.toMap(),
                "wifi" to wifi,
                "devices" to devices.map { device ->
                    val s = stats[device.ip]
                    mapOf(
                        "ip" to device.ip,
                        "name" to device.name,
                        "type" to device.type,
                        "vendor" to device.vendor,
                        "model" to device.model,
                        "sources" to device.sources,
                        "services" to device.services,
                        "isGateway" to device.isGateway,
                        "isSelf" to device.isSelf,
                        "latency" to (s?.latency ?: -1L),
                        "jitter" to (s?.jitter ?: -1L),
                        "loss" to (s?.failureRate ?: -1)
                    )
                }
            )
            val store = store(context)
            store.appendScan(startedAt, devices, full = !light)
            if (!light) store.saveLastScan(result)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong("lastInventoryAt", startedAt).apply()
            if (debuggable) logSummary(result, devices, stats)
            return result
        } finally {
            pool.shutdownNow()
            if (multicast.isHeld) multicast.release()
            progress(null, 1.0)
        }
    }

    private fun logSummary(result: Map<String, Any?>, devices: List<LanDevice>, stats: Map<String, LatencyResult>) {
        Log.d(TAG, "scan light=${result["light"]} ${result["durationMs"]} ms, ${devices.size} devices, swept=${result["hostsSwept"]}, " +
            "gateway=${result["gateway"]}, internet=${result["internet"]}")
        devices.forEach { d ->
            val s = stats[d.ip]
            Log.d(TAG, "  ${d.ip} type=${d.type} name=${d.name} vendor=${d.vendor} model=${d.model} " +
                "sources=${d.sources} services=${d.services} rtt=${s?.latency} jitter=${s?.jitter} loss=${s?.failureRate}")
        }
        Log.d(TAG, "wifi=${result["wifi"]}")
    }

    private fun LatencyResult.toMap() = mapOf(
        "latency" to latency, "jitter" to jitter, "loss" to failureRate,
        "samples" to successfulSamples, "attempts" to totalSamples
    )

    private fun <T> futureOr(future: Future<out T>, timeoutMs: Long, fallback: T): T = try {
        future.get(timeoutMs, TimeUnit.MILLISECONDS)
    } catch (_: Exception) {
        future.cancel(true)
        fallback
    }

    // ---------------------------------------------------------------- probing

    private fun elapsedMs(startNanos: Long) = (SystemClock.elapsedRealtimeNanos() - startNanos + 500_000L) / 1_000_000L

    /** ICMP echo (Android allows unprivileged ping sockets); null when there is no reply. */
    private fun ping(lan: Lan, ip: String, timeoutMs: Int): Long? = try {
        val address = InetAddress.getByName(ip)
        val start = SystemClock.elapsedRealtimeNanos()
        val reachable = if (lan.nic != null) address.isReachable(lan.nic, 0, timeoutMs) else address.isReachable(timeoutMs)
        if (reachable) elapsedMs(start) else null
    } catch (_: Exception) {
        null
    }

    /** TCP handshake time; a refused connection also proves the host is there (RST = one RTT). */
    private fun tcp(lan: Lan, ip: String, port: Int, timeoutMs: Int): Long? {
        val start = SystemClock.elapsedRealtimeNanos()
        return try {
            lan.network.socketFactory.createSocket().use { socket ->
                socket.connect(InetSocketAddress(ip, port), timeoutMs)
            }
            elapsedMs(start)
        } catch (e: ConnectException) {
            if (e.message?.contains("ECONNREFUSED") == true || e.message?.contains("refused", true) == true) elapsedMs(start) else null
        } catch (_: Exception) {
            null
        }
    }

    /** Finds live hosts. Returns ip -> port that answered (0 = ICMP). */
    private fun sweep(lan: Lan, hosts: List<String>, light: Boolean): Map<String, Int> {
        val alive = ConcurrentHashMap<String, Int>()
        val done = AtomicInteger()
        val executor = Executors.newFixedThreadPool(if (light) 48 else 64)
        try {
            hosts.map { ip ->
                executor.submit {
                    val port = when {
                        ping(lan, ip, if (light) 400 else 600) != null -> 0
                        light -> null
                        else -> SWEEP_PORTS.firstOrNull { tcp(lan, ip, it, 250) != null }
                    }
                    if (port != null) alive[ip] = port
                    progress(R.string.scan_searching, 0.06 + 0.54 * done.incrementAndGet() / hosts.size)
                }
            }.forEach { futureOr<Any?>(it, 30_000L, null) }
        } finally {
            executor.shutdownNow()
        }
        return alive
    }

    private fun measureHost(lan: Lan, ip: String, knownPort: Int?, count: Int, servicePorts: List<Int> = emptyList()): LatencyResult {
        // Prefer what worked in the sweep; devices only seen via mDNS/SSDP get ICMP, then the
        // ports they announce (PCs often drop ICMP but accept their own service port).
        var port: Int? = knownPort
        if (port == null) {
            port = if (ping(lan, ip, 800) != null) 0
            else (servicePorts + SWEEP_PORTS).distinct().firstOrNull { tcp(lan, ip, it, 400) != null }
        }
        if (port == null) return LanStats.summarize(emptyList(), count)
        val samples = mutableListOf<Long>()
        repeat(count) { index ->
            (if (port == 0) ping(lan, ip, 1_000) else tcp(lan, ip, port, 1_000))?.let(samples::add)
            if (index < count - 1) SystemClock.sleep(80)
        }
        return LanStats.summarize(samples, count)
    }

    /** Same-moment internet reference: TCP handshakes to Cloudflare (as the monitor does). */
    private fun measureInternet(lan: Lan): LatencyResult {
        tcp(lan, "1.1.1.1", 443, 2_000)
        val samples = mutableListOf<Long>()
        repeat(5) { index ->
            tcp(lan, "1.1.1.1", 443, 2_000)?.let(samples::add)
            if (index < 4) SystemClock.sleep(100)
        }
        return LanStats.summarize(samples, 5)
    }

    /** Gateway reference stored after each monitor check (4 probes, ~1 s). */
    fun probeGatewayForHistory() {
        val lan = lan() ?: return
        val gateway = lan.gateway ?: return
        val result = measureHost(lan, gateway, null, 4)
        @Suppress("DEPRECATION")
        val rssi = try {
            context.applicationContext.getSystemService(WifiManager::class.java).connectionInfo?.rssi ?: 0
        } catch (_: Exception) {
            0
        }
        store(context).appendLanProbe(System.currentTimeMillis(), result, rssi)
    }

    // ---------------------------------------------------------------- discovery

    private fun discoverMdns(windowMs: Long, light: Boolean): List<DeviceObservation> {
        val nsd = context.getSystemService(NsdManager::class.java) ?: return emptyList()
        val deadline = SystemClock.elapsedRealtime() + windowMs + 4_000L
        val queue = LinkedBlockingQueue<Pair<String, NsdServiceInfo>>()
        val seen = ConcurrentHashMap.newKeySet<String>()
        val observations = Collections.synchronizedList(mutableListOf<DeviceObservation>())
        val discovering = java.util.concurrent.atomic.AtomicBoolean(true)

        // Before Android 14 the system resolves one service at a time, so resolves are serial.
        val resolver = thread(name = "linkzora-nsd-resolve") {
            while (SystemClock.elapsedRealtime() < deadline) {
                val (type, info) = try {
                    queue.poll(150, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    break
                } ?: if (discovering.get()) continue else break
                resolve(nsd, type, info)?.let(observations::add)
            }
        }
        val types = if (light) MDNS_TYPES.take(8) else MDNS_TYPES
        // The system allows ~10 outstanding requests per app, so types are browsed in batches.
        val batches = types.chunked(8)
        val batchMs = windowMs / batches.size
        for (batch in batches) {
            val listeners = batch.mapNotNull { type ->
                val listener = object : NsdManager.DiscoveryListener {
                    override fun onDiscoveryStarted(serviceType: String) {}
                    override fun onDiscoveryStopped(serviceType: String) {}
                    override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
                    override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
                    override fun onServiceLost(service: NsdServiceInfo) {}
                    override fun onServiceFound(service: NsdServiceInfo) {
                        if (seen.add("$type/${service.serviceName}")) queue.offer(type to service)
                    }
                }
                try {
                    nsd.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, listener)
                    listener
                } catch (_: Exception) {
                    null
                }
            }
            SystemClock.sleep(batchMs)
            listeners.forEach { try { nsd.stopServiceDiscovery(it) } catch (_: Exception) {} }
        }
        discovering.set(false)
        resolver.join((deadline - SystemClock.elapsedRealtime()).coerceAtLeast(1L))
        resolver.interrupt()
        return observations.toList()
    }

    @Suppress("DEPRECATION")
    private fun resolve(nsd: NsdManager, type: String, info: NsdServiceInfo): DeviceObservation? {
        val latch = CountDownLatch(1)
        var resolved: NsdServiceInfo? = null
        try {
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = latch.countDown()
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    resolved = serviceInfo
                    latch.countDown()
                }
            })
            latch.await(2_000, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            return null
        }
        val service = resolved ?: return null
        val host = (if (Build.VERSION.SDK_INT >= 34) service.hostAddresses.firstOrNull { it is Inet4Address } else service.host)
            as? Inet4Address ?: return null
        val txt = service.attributes.mapValues { (_, value) -> value?.let { String(it, Charsets.UTF_8) } ?: "" }
        fun attr(vararg keys: String) = keys.firstNotNullOfOrNull { key -> txt[key]?.takeIf { it.isNotBlank() } }
        return DeviceObservation(
            ip = host.hostAddress ?: return null,
            source = "mdns",
            name = attr("fn", "n") ?: service.serviceName,
            services = setOf(type),
            manufacturer = attr("manufacturer", "usb_MFG", "mf"),
            model = attr("md", "model", "mdl", "ty", "product", "am")?.removeSurrounding("(", ")"),
            port = service.port.takeIf { it > 0 }
        )
    }

    private fun discoverSsdp(lan: Lan, windowMs: Long): List<DeviceObservation> {
        val responses = mutableMapOf<String, MutableList<SsdpResponse>>()
        try {
            DatagramSocket(null as java.net.SocketAddress?).use { socket ->
                socket.reuseAddress = true
                socket.bind(InetSocketAddress(0))
                lan.network.bindSocket(socket)
                socket.soTimeout = 250
                val group = InetAddress.getByName(Ssdp.ADDRESS)
                fun send(target: String) {
                    val bytes = Ssdp.searchRequest(target).toByteArray(Charsets.US_ASCII)
                    socket.send(DatagramPacket(bytes, bytes.size, group, Ssdp.PORT))
                }
                send("ssdp:all")
                send("upnp:rootdevice")
                val buffer = ByteArray(2048)
                val end = SystemClock.elapsedRealtime() + windowMs
                var resent = false
                while (SystemClock.elapsedRealtime() < end) {
                    if (!resent && SystemClock.elapsedRealtime() > end - windowMs / 2) {
                        send("ssdp:all") // UDP multicast is lossy; a second search catches slow devices.
                        resent = true
                    }
                    val packet = DatagramPacket(buffer, buffer.size)
                    try {
                        socket.receive(packet)
                    } catch (_: SocketTimeoutException) {
                        continue
                    }
                    val ip = (packet.address as? Inet4Address)?.hostAddress ?: continue
                    val response = Ssdp.parseResponse(String(packet.data, 0, packet.length, Charsets.UTF_8)) ?: continue
                    responses.getOrPut(ip) { mutableListOf() }.add(response)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "ssdp failed", e)
        }
        return responses.map { (ip, list) ->
            // Only descriptions served by the replying host itself are fetched.
            val location = list.mapNotNull { it.location }
                .firstOrNull { Ssdp.locationHost(it) == ip }
            val description = location?.let { fetchDescription(lan, it) }
            DeviceObservation(
                ip = ip,
                source = "upnp",
                name = description?.friendlyName,
                manufacturer = description?.manufacturer,
                model = description?.modelName ?: description?.modelDescription,
                upnpType = description?.deviceType ?: list.firstNotNullOfOrNull { it.st?.takeIf { st -> st.startsWith("urn:") } },
                server = list.firstNotNullOfOrNull { it.server }
            )
        }
    }

    private fun fetchDescription(lan: Lan, location: String): UpnpDescription? = try {
        val connection = lan.network.openConnection(URL(location)) as HttpURLConnection
        connection.connectTimeout = 1_500
        connection.readTimeout = 1_500
        try {
            val bytes = connection.inputStream.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (out.size() < 64 * 1024) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                }
                out.toByteArray()
            }
            Ssdp.parseDescription(String(bytes, Charsets.UTF_8))
        } finally {
            connection.disconnect()
        }
    } catch (_: Exception) {
        null
    }

    /** NetBIOS node status (Windows PCs, NAS, Samba): one socket, all queries, 1.5 s window. */
    private fun netbiosNames(lan: Lan, ips: Set<String>): Map<String, String> =
        udpQueries(lan, ips.toList(), NetBios.PORT, 1_500L, { index, _ -> NetBios.nodeStatusRequest(0x4C00 + index) }) { data, length ->
            NetBios.parseNodeStatus(data, length)
        }.mapNotNull { (ip, name) -> name?.let { ip to it } }.toMap()

    /** Reverse DNS asked straight to the router (bypasses Private DNS, which knows no LAN names). */
    private fun ptrNames(lan: Lan, ips: Set<String>): Map<String, String> {
        val server = lan.dns.firstOrNull { it.isSiteLocalAddress }?.hostAddress ?: lan.gateway ?: return emptyMap()
        val ordered = ips.toList()
        val names = ConcurrentHashMap<String, String>()
        try {
            DatagramSocket().use { socket ->
                lan.network.bindSocket(socket)
                socket.soTimeout = 200
                val target = InetAddress.getByName(server)
                ordered.forEachIndexed { index, ip ->
                    val query = DnsPtr.query(ip, index)
                    socket.send(DatagramPacket(query, query.size, target, 53))
                }
                val buffer = ByteArray(1500)
                val end = SystemClock.elapsedRealtime() + 1_500L
                while (SystemClock.elapsedRealtime() < end && names.size < ordered.size) {
                    val packet = DatagramPacket(buffer, buffer.size)
                    try {
                        socket.receive(packet)
                    } catch (_: SocketTimeoutException) {
                        continue
                    }
                    if (packet.length < 2) continue
                    val id = ((packet.data[0].toInt() and 0xFF) shl 8) or (packet.data[1].toInt() and 0xFF)
                    val ip = ordered.getOrNull(id) ?: continue
                    DnsPtr.parseResponse(packet.data, packet.length)?.let { names[ip] = it }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "ptr failed", e)
        }
        return names
    }

    private fun <T> udpQueries(
        lan: Lan,
        ips: List<String>,
        port: Int,
        windowMs: Long,
        build: (Int, String) -> ByteArray,
        parse: (ByteArray, Int) -> T?
    ): Map<String, T?> {
        val replies = ConcurrentHashMap<String, T>()
        try {
            DatagramSocket().use { socket ->
                lan.network.bindSocket(socket)
                socket.soTimeout = 200
                ips.forEachIndexed { index, ip ->
                    val bytes = build(index, ip)
                    try {
                        socket.send(DatagramPacket(bytes, bytes.size, InetAddress.getByName(ip), port))
                    } catch (_: Exception) {
                    }
                }
                val buffer = ByteArray(1500)
                val end = SystemClock.elapsedRealtime() + windowMs
                while (SystemClock.elapsedRealtime() < end && replies.size < ips.size) {
                    val packet = DatagramPacket(buffer, buffer.size)
                    try {
                        socket.receive(packet)
                    } catch (_: SocketTimeoutException) {
                        continue
                    }
                    val ip = (packet.address as? Inet4Address)?.hostAddress ?: continue
                    parse(packet.data, packet.length)?.let { replies[ip] = it }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "udp queries failed", e)
        }
        return replies
    }
}
