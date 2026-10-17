/// Pure logic of the "Rede" tab: models of the native network scan and the
/// rules that estimate where connection problems come from ("contribuição
/// provável"), independent of Flutter widgets. User-visible text comes from
/// the [AppLocalizations] passed in.
///
/// Android gives apps no per-device traffic counters, ARP table or MAC
/// addresses, so every percentage here is an estimate built from what the
/// phone observes: its own measurements, the gateway latency, the Wi-Fi
/// neighbourhood and which devices were on the network at the time.
library;

import 'dart:math' as math;

import 'analytics.dart';
import 'l10n/app_localizations.dart';

// ---------------------------------------------------------------- models

enum DeviceKind {
  router,
  tv,
  phone,
  computer,
  printer,
  console,
  speaker,
  camera,
  iot,
  unknown;

  String label(AppLocalizations l10n) => switch (this) {
        DeviceKind.router => l10n.kindRouter,
        DeviceKind.tv => l10n.kindTv,
        DeviceKind.phone => l10n.kindPhone,
        DeviceKind.computer => l10n.kindComputer,
        DeviceKind.printer => l10n.kindPrinter,
        DeviceKind.console => l10n.kindConsole,
        DeviceKind.speaker => l10n.kindSpeaker,
        DeviceKind.camera => l10n.kindCamera,
        DeviceKind.iot => l10n.kindIot,
        DeviceKind.unknown => l10n.kindUnknown,
      };

  static DeviceKind of(String? id) => DeviceKind.values
      .firstWhere((kind) => kind.name == id, orElse: () => DeviceKind.unknown);

  /// How likely this kind of device is to use a lot of bandwidth or airtime
  /// (streaming, downloads, uploads of video). Used as a weak prior only.
  double get prior => switch (this) {
        DeviceKind.tv => .6,
        DeviceKind.console => .6,
        DeviceKind.camera => .5,
        DeviceKind.computer => .4,
        DeviceKind.phone => .25,
        DeviceKind.unknown => .2,
        DeviceKind.speaker => .15,
        DeviceKind.iot => .1,
        DeviceKind.printer => .05,
        DeviceKind.router => 0,
      };
}

int _int(Object? value, [int fallback = -1]) =>
    (value as num?)?.toInt() ?? fallback;

/// Latency, jitter and loss of a set of probes. `latency < 0` means no reply.
class LinkStats {
  const LinkStats(this.latency, this.jitter, this.loss);

  static LinkStats? fromMap(Object? value) {
    if (value is! Map) return null;
    return LinkStats(_int(value['latency']), _int(value['jitter']),
        _int(value['loss'], 100));
  }

  final int latency;
  final int jitter;
  final int loss;

  bool get replied => latency >= 0 && loss < 100;

  /// A home gateway normally answers in a few ms; these limits leave room for
  /// Wi-Fi power save while still catching a congested or noisy link.
  bool get healthyGateway =>
      replied && latency < gatewaySlowMs && jitter < 30 && loss < 25;
}

const gatewaySlowMs = 50;

/// Source id of devices that only appear in the presence history.
const historySource = 'history';

class NetworkDevice {
  const NetworkDevice({
    required this.ip,
    required this.kind,
    this.name,
    this.vendor,
    this.model,
    this.sources = const [],
    this.services = const [],
    this.isGateway = false,
    this.isSelf = false,
    this.stats,
  });

  factory NetworkDevice.fromMap(Map<dynamic, dynamic> value) {
    final latency = _int(value['latency']);
    return NetworkDevice(
      ip: value['ip']?.toString() ?? '',
      kind: DeviceKind.of(value['type']?.toString()),
      name: value['name']?.toString(),
      vendor: value['vendor']?.toString(),
      model: value['model']?.toString(),
      sources: [for (final item in (value['sources'] as List? ?? [])) '$item'],
      services: [
        for (final item in (value['services'] as List? ?? [])) '$item'
      ],
      isGateway: value['isGateway'] == true,
      isSelf: value['isSelf'] == true,
      stats: value.containsKey('latency') && value['loss'] != null
          ? LinkStats(latency, _int(value['jitter']), _int(value['loss'], 100))
          : null,
    );
  }

  final String ip;
  final DeviceKind kind;
  final String? name;
  final String? vendor;
  final String? model;
  final List<String> sources;
  final List<String> services;
  final bool isGateway;
  final bool isSelf;
  final LinkStats? stats;

  String displayName(AppLocalizations l10n) {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (isGateway) return l10n.kindRouter;
    if (vendor != null) return '${kind.label(l10n)} $vendor';
    return l10n.deviceUnnamed(ip.split('.').last);
  }

  /// "TV ou streaming · Samsung · Q60" without repeating what the name says.
  String description(AppLocalizations l10n) {
    final name = displayName(l10n);
    return [
      kind.label(l10n),
      if (vendor != null && !name.contains(vendor!)) vendor!,
      if (model != null && !name.contains(model!)) model!,
    ].join(' · ');
  }
}

class WifiNeighbor {
  const WifiNeighbor(
      this.ssid, this.band, this.channel, this.rssi, this.overlap,
      {this.own = false});

  factory WifiNeighbor.fromMap(Map<dynamic, dynamic> value) => WifiNeighbor(
        value['ssid']?.toString() ?? '',
        value['band']?.toString() ?? '',
        _int(value['channel'], 0),
        _int(value['rssi'], -100),
        value['overlap']?.toString() ?? 'none',
        own: value['own'] == true,
      );

  final String ssid;
  final String band;
  final int channel;
  final int rssi;

  /// "same" (same channel), "partial" (overlapping channels) or "none".
  final String overlap;

  /// Part of the user's own network (repeater, mesh node, the router's other
  /// band): listed, but not counted as interference.
  final bool own;

  /// How much this network adds to the interference score, as in the native
  /// WifiMath: its loudness (0 at -90 dBm, 1 at -50 dBm) weighed by the
  /// overlap (partial overlap collides more, so it weighs 1.2).
  double get impact {
    final loudness = ((rssi + 90) / 40).clamp(0, 1).toDouble();
    return switch (overlap) {
      'same' => loudness,
      'partial' => 1.2 * loudness,
      _ => 0,
    };
  }
}

class WifiEnvironment {
  const WifiEnvironment({
    required this.available,
    this.reason,
    this.fresh = false,
    this.ssid = '',
    this.band = '',
    this.channel = 0,
    this.widthMhz = 20,
    this.rssi = 0,
    this.linkSpeed = 0,
    this.score = 0,
    this.level = 'low',
    this.sameChannel = 0,
    this.partialOverlap = 0,
    this.totalNetworks = 0,
    this.ownNetworks = 0,
    this.suggestedChannel,
    this.networks = const [],
  });

  static WifiEnvironment? fromMap(Object? value) {
    if (value is! Map) return null;
    return WifiEnvironment(
      available: value['available'] == true,
      reason: value['reason']?.toString(),
      fresh: value['fresh'] == true,
      ssid: value['ssid']?.toString() ?? '',
      band: value['band']?.toString() ?? '',
      channel: _int(value['channel'], 0),
      widthMhz: _int(value['widthMhz'], 20),
      rssi: _int(value['rssi'], 0),
      linkSpeed: _int(value['linkSpeed'], 0),
      score: (value['score'] as num?)?.toDouble() ?? 0,
      level: value['level']?.toString() ?? 'low',
      sameChannel: _int(value['sameChannel'], 0),
      partialOverlap: _int(value['partialOverlap'], 0),
      totalNetworks: _int(value['totalNetworks'], 0),
      ownNetworks: _int(value['ownNetworks'], 0),
      suggestedChannel: (value['suggestedChannel'] as num?)?.toInt(),
      networks: [
        for (final item in (value['networks'] as List? ?? []))
          if (item is Map) WifiNeighbor.fromMap(item)
      ],
    );
  }

  final bool available;

  /// Why it is unavailable: permission, location_off, no_access, not_connected.
  final String? reason;
  final bool fresh;
  final String ssid;
  final String band;
  final int channel;
  final int widthMhz;
  final int rssi;
  final int linkSpeed;
  final double score;

  /// low, medium or high.
  final String level;
  final int sameChannel;
  final int partialOverlap;
  final int totalNetworks;

  /// Access points of the user's own network left out of the counts above.
  final int ownNetworks;
  final int? suggestedChannel;
  final List<WifiNeighbor> networks;

  /// 0..1, the share of the interference scale (score 3 = high).
  double get intensity => (score / 3).clamp(0, 1).toDouble();

  /// "Interferência alta", "média" or "baixa".
  String levelLabel(AppLocalizations l10n) => l10n.interferenceLevel(level);

  String bandLabel(AppLocalizations l10n) =>
      band.isEmpty ? '—' : l10n.bandGhz(band);
}

class NetworkScan {
  const NetworkScan({
    required this.timestamp,
    this.error,
    this.transportType = 'wifi',
    this.selfIp,
    this.gatewayIp,
    this.gateway,
    this.internet,
    this.wifi,
    this.devices = const [],
    this.duration = Duration.zero,
  });

  factory NetworkScan.fromMap(Map<dynamic, dynamic> value) => NetworkScan(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(_int(value['timestamp'], 0)),
        error: value['error']?.toString(),
        transportType: value['transportType']?.toString() ?? 'wifi',
        selfIp: value['selfIp']?.toString(),
        gatewayIp: value['gatewayIp']?.toString(),
        gateway: LinkStats.fromMap(value['gateway']),
        internet: LinkStats.fromMap(value['internet']),
        wifi: WifiEnvironment.fromMap(value['wifi']),
        duration: Duration(milliseconds: _int(value['durationMs'], 0)),
        devices: [
          for (final item in (value['devices'] as List? ?? []))
            if (item is Map) NetworkDevice.fromMap(item)
        ],
      );

  final DateTime timestamp;

  /// "not_wifi" when the phone is not on Wi-Fi or Ethernet.
  final String? error;
  final String transportType;
  final String? selfIp;
  final String? gatewayIp;
  final LinkStats? gateway;
  final LinkStats? internet;
  final WifiEnvironment? wifi;
  final List<NetworkDevice> devices;
  final Duration duration;

  /// Other devices: without the gateway and this phone.
  List<NetworkDevice> get others =>
      devices.where((device) => !device.isGateway && !device.isSelf).toList();
}

/// One inventory from the presence history (every 15 min while monitoring).
class InventorySnapshot {
  const InventorySnapshot(this.timestamp, this.devices);

  factory InventorySnapshot.fromMap(Map<dynamic, dynamic> value) =>
      InventorySnapshot(
        DateTime.fromMillisecondsSinceEpoch(_int(value['timestamp'], 0)),
        {
          for (final item in (value['devices'] as List? ?? []))
            if (item is Map && item['ip'] != null)
              item['ip'].toString(): (
                name: item['name']?.toString(),
                kind: DeviceKind.of(item['type']?.toString()),
              )
        },
      );

  final DateTime timestamp;
  final Map<String, ({String? name, DeviceKind kind})> devices;
}

/// Gateway latency measured right after a monitor check.
class LanProbe {
  const LanProbe(this.timestamp, this.stats);

  factory LanProbe.fromMap(Map<dynamic, dynamic> value) => LanProbe(
        DateTime.fromMillisecondsSinceEpoch(_int(value['timestamp'], 0)),
        LinkStats(_int(value['latency']), _int(value['jitter']),
            _int(value['loss'], 100)),
      );

  final DateTime timestamp;
  final LinkStats stats;
}

class NetworkHistory {
  const NetworkHistory(
      {this.scans = const [], this.lanProbes = const [], this.lastScan});

  factory NetworkHistory.fromMap(Map<dynamic, dynamic> value) {
    final scans = [
      for (final item in (value['scans'] as List? ?? []))
        if (item is Map) InventorySnapshot.fromMap(item)
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final probes = [
      for (final item in (value['lanProbes'] as List? ?? []))
        if (item is Map) LanProbe.fromMap(item)
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final last = value['lastScan'];
    return NetworkHistory(
      scans: scans,
      lanProbes: probes,
      lastScan: last is Map ? NetworkScan.fromMap(last) : null,
    );
  }

  final List<InventorySnapshot> scans;
  final List<LanProbe> lanProbes;
  final NetworkScan? lastScan;
}

// ---------------------------------------------------------------- analysis

enum Confidence {
  low,
  medium,
  high;

  /// "confiança alta", "média" or "baixa".
  String label(AppLocalizations l10n) => l10n.confidence(name);
}

enum CauseKind { isp, interference, signal, device, unknown }

/// One slice of the "contribuição provável" breakdown.
class Contribution {
  const Contribution({
    required this.id,
    required this.kind,
    required this.label,
    required this.percent,
    required this.reasons,
    this.confidence,
    this.device,
    this.present = true,
  });

  final String id;
  final CauseKind kind;
  final String label;

  /// Integer percentage; all contributions of an analysis sum to 100.
  final int percent;
  final List<String> reasons;

  /// Null for "Sem causa identificada".
  final Confidence? confidence;
  final NetworkDevice? device;

  /// False for devices only seen in the history (not in the last scan).
  final bool present;
}

enum ProblemSide { none, local, isp, mixed, unknown }

class ProblemLocation {
  const ProblemLocation(
      this.side, this.localShare, this.pairedChecks, this.title, this.detail);

  final ProblemSide side;

  /// 0..1: smoothed share of the evidence pointing to the home network.
  final double localShare;

  /// Unstable checks with a gateway measurement next to them.
  final int pairedChecks;
  final String title;
  final String detail;
}

class NetworkAnalysis {
  const NetworkAnalysis({
    required this.location,
    required this.contributions,
    required this.unstableChecks,
    required this.totalChecks,
  });

  final ProblemLocation location;

  /// Sorted by percentage, highest first; sums to 100.
  final List<Contribution> contributions;
  final int unstableChecks;
  final int totalChecks;

  Contribution? forDevice(String ip) => contributions
      .where((item) => item.device?.ip == ip || item.id == 'device:$ip')
      .firstOrNull;

  /// Causes other than devices (and "sem causa"), for the summary bars.
  List<Contribution> get causes =>
      contributions.where((item) => item.kind != CauseKind.device).toList();

  List<Contribution> get devices =>
      contributions.where((item) => item.kind == CauseKind.device).toList();

  /// Sum of all device slices.
  int get devicesPercent =>
      devices.fold(0, (total, item) => total + item.percent);
}

/// Tunables of the rules, documented in docs/linkzora.md ("Rede").
class NetworkRules {
  static const window = Duration(hours: 24);

  /// A gateway probe must be this close to a check to be compared with it.
  static const probePairing = Duration(minutes: 3);

  /// A device counts as present at a check when a scan this close saw it.
  static const presenceTolerance = Duration(minutes: 20);

  /// Joining this long before a failure period counts as "entrou antes".
  static const joinWindow = Duration(minutes: 30);

  /// Minimum checks with the device present and absent to compare rates.
  static const minPresenceSamples = 5;

  /// Evidence needed for half the breakdown to be explained (c = E/(E+k)).
  static const evidenceHalf = 3.0;

  /// Local slack that stays unexplained even with evidence.
  static const otherWeight = .5;
}

String _pct(double value) => '${(value * 100).round()}%';

/// Largest-remainder rounding: integer percentages that always sum to 100.
List<int> roundPercentages(List<double> weights) {
  final total =
      weights.fold<double>(0, (sum, value) => sum + math.max(0, value));
  if (weights.isEmpty) return const [];
  if (total <= 0) return [100, ...List.filled(weights.length - 1, 0)];
  final exact = [for (final value in weights) math.max(0, value) * 100 / total];
  final result = [for (final value in exact) value.floor()];
  var missing = 100 - result.fold<int>(0, (sum, value) => sum + value);
  final order = List.generate(weights.length, (index) => index)
    ..sort((a, b) {
      final byRemainder =
          (exact[b] - result[b]).compareTo(exact[a] - result[a]);
      return byRemainder != 0 ? byRemainder : exact[b].compareTo(exact[a]);
    });
  for (final index in order) {
    if (missing <= 0) break;
    result[index]++;
    missing--;
  }
  return result;
}

/// Whether [ip] was on the network at [time], from the nearest inventory
/// within [NetworkRules.presenceTolerance]; null when no scan is close enough.
bool? presentAt(List<InventorySnapshot> scans, String ip, DateTime time) {
  InventorySnapshot? nearest;
  var best = NetworkRules.presenceTolerance;
  for (final scan in scans) {
    final distance = scan.timestamp.difference(time).abs();
    if (distance <= best) {
      best = distance;
      nearest = scan;
    }
  }
  return nearest?.devices.containsKey(ip);
}

/// Instability rate with the device present versus absent (Laplace smoothed).
class PresenceLift {
  const PresenceLift(this.presentChecks, this.presentUnstable,
      this.absentChecks, this.absentUnstable);

  final int presentChecks;
  final int presentUnstable;
  final int absentChecks;
  final int absentUnstable;

  double get presentRate => (presentUnstable + 1) / (presentChecks + 2);
  double get absentRate => (absentUnstable + 1) / (absentChecks + 2);

  bool get comparable =>
      presentChecks >= NetworkRules.minPresenceSamples &&
      absentChecks >= NetworkRules.minPresenceSamples;

  double get lift => comparable ? presentRate - absentRate : 0;
}

PresenceLift presenceLift(
    List<InventorySnapshot> scans, String ip, List<Measurement> checks) {
  var presentChecks = 0, presentUnstable = 0;
  var absentChecks = 0, absentUnstable = 0;
  for (final check in checks) {
    final present = presentAt(scans, ip, check.timestamp);
    if (present == null) continue;
    final unstable = check.state != 'online';
    if (present) {
      presentChecks++;
      if (unstable) presentUnstable++;
    } else {
      absentChecks++;
      if (unstable) absentUnstable++;
    }
  }
  return PresenceLift(
      presentChecks, presentUnstable, absentChecks, absentUnstable);
}

/// Failure periods that started up to [NetworkRules.joinWindow] after [ip]
/// appeared (absent in one scan, present in the next).
int joinsBeforeFailures(
    List<InventorySnapshot> scans, String ip, List<FailurePeriod> periods) {
  final joins = <DateTime>[
    for (var index = 1; index < scans.length; index++)
      if (scans[index].devices.containsKey(ip) &&
          !scans[index - 1].devices.containsKey(ip))
        scans[index].timestamp
  ];
  return periods.where((period) {
    return joins.any((join) {
      final gap = period.start.difference(join);
      return !gap.isNegative && gap <= NetworkRules.joinWindow;
    });
  }).length;
}

/// LAN round trip evidence: a slow or erratic reply from a device suggests a
/// busy device or a weak Wi-Fi client competing for airtime. 0..1.
double lanLoadScore(LinkStats? stats, DeviceKind kind) {
  if (stats == null || !stats.replied) return 0;
  final score = ((stats.latency - 30) / 150).clamp(0, 1) * .5 +
      ((stats.jitter - 10) / 50).clamp(0, 1) * .3 +
      (stats.loss >= 40 ? .2 : 0);
  // Phones in Wi-Fi power save answer pings late even when idle.
  return score * (kind == DeviceKind.phone ? .4 : 1);
}

LanProbe? _nearestProbe(List<LanProbe> probes, DateTime time) {
  LanProbe? nearest;
  var best = NetworkRules.probePairing;
  for (final probe in probes) {
    final distance = probe.timestamp.difference(time).abs();
    if (distance <= best) {
      best = distance;
      nearest = probe;
    }
  }
  return nearest;
}

/// Estimates where problems come from and how much each cause contributes.
///
/// Rules (all values are estimates and labelled "provável" in the UI):
/// 1. Evidence: E = unstable Wi-Fi checks in 24 h, +2 if the gateway is bad in
///    the last scan, +1 for high interference, +1 for a weak signal now. A
///    share c = E/(E+3) of the breakdown is explained; the rest is "Sem causa
///    identificada".
/// 2. Local versus beyond the router: each unstable check with a gateway probe
///    next to it votes local (gateway slow/lossy) or beyond (gateway fine);
///    weak-signal checks without a probe vote local. L = (local+1)/(total+2).
/// 3. Weights: operadora 2(1−L); sinal 2·L·weak; interferência 2·L·i; each
///    device 0.5·prior (priors capped at 1 in total) + presence lift×4 (max 2)
///    + 0.5 per failure it joined right before (max 1.5) + L·LAN load; plus a
///    fixed 0.5 local slack that goes to "Sem causa identificada".
/// 4. Percentages are the weights normalised to c, rounded to sum 100.
NetworkAnalysis analyzeNetwork({
  required List<Measurement> measurements,
  required AppLocalizations l10n,
  NetworkScan? scan,
  NetworkHistory history = const NetworkHistory(),
  DateTime? now,
}) {
  final l = l10n;
  final at = now ?? DateTime.now();
  final cutoff = at.subtract(NetworkRules.window);
  final checks = measurements
      .where((sample) =>
          sample.timestamp.isAfter(cutoff) &&
          (sample.transportType == 'wifi' ||
              sample.transportType == 'ethernet'))
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final unstable = checks.where((sample) => sample.state != 'online').toList();
  final wifi = scan?.wifi;
  final wifiOk = wifi != null && wifi.available;
  final gatewayNow = scan?.gateway;
  final gatewayBadNow = gatewayNow != null && !gatewayNow.healthyGateway;

  // -- 2. local versus beyond the router
  var localVotes = 0, ispVotes = 0, paired = 0, pairedGood = 0;
  var weakUnstable = 0;
  for (final check in unstable) {
    final weak = check.signalLevel >= 0 && check.signalLevel <= 1;
    if (weak) weakUnstable++;
    final probe = _nearestProbe(history.lanProbes, check.timestamp);
    if (probe != null) {
      paired++;
      if (probe.stats.healthyGateway) {
        ispVotes++;
        pairedGood++;
      } else {
        localVotes++;
      }
    } else if (weak) {
      localVotes++;
    }
  }
  final latestUnstable = checks.isNotEmpty && checks.last.state != 'online';
  if (gatewayBadNow) {
    localVotes += 2;
  } else if (gatewayNow != null && latestUnstable) {
    ispVotes += 1;
  }
  final local = (localVotes + 1) / (localVotes + ispVotes + 2);

  // -- 1. evidence
  final rssi = wifiOk ? wifi.rssi : 0;
  final weakNow = rssi != 0 && rssi <= -75
      ? 1.0
      : rssi != 0 && rssi <= -67
          ? .5
          : 0.0;
  final evidence = unstable.length +
      (gatewayBadNow ? 2 : 0) +
      (wifiOk && wifi.level == 'high' ? 1 : 0) +
      (weakNow >= 1 ? 1 : 0);
  final explained = evidence / (evidence + NetworkRules.evidenceHalf);

  // -- 3. weights
  final weakShare = unstable.isEmpty ? 0.0 : weakUnstable / unstable.length;
  final signal = math.max(weakShare, weakNow * .8);
  final interference = wifiOk ? wifi.intensity : 0.0;
  final weights = <String, double>{
    'isp': 2 * (1 - local),
    'signal': 2 * local * signal,
    'interference': 2 * local * interference,
  };

  final periods = failurePeriods(checks, live: false);
  // Only inventories that can match a check of the window are compared.
  final scans = history.scans
      .where((item) => !item.timestamp
          .isBefore(cutoff.subtract(NetworkRules.presenceTolerance)))
      .toList();
  final current = {
    for (final device in scan?.others ?? <NetworkDevice>[]) device.ip: device
  };
  final historical = <String, ({String? name, DeviceKind kind})>{};
  for (final snapshot in history.scans) {
    if (snapshot.timestamp.isBefore(cutoff)) continue;
    for (final entry in snapshot.devices.entries) {
      if (entry.key == scan?.gatewayIp || entry.key == scan?.selfIp) continue;
      if (entry.value.kind == DeviceKind.router) continue;
      historical[entry.key] = entry.value;
    }
  }
  final deviceIps = {...current.keys, ...historical.keys};
  final devices = <String, NetworkDevice>{
    for (final ip in deviceIps)
      ip: current[ip] ??
          NetworkDevice(
              ip: ip,
              kind: historical[ip]!.kind,
              name: historical[ip]!.name,
              sources: const [historySource]),
  };
  double priorOf(NetworkDevice device) =>
      device.kind.prior * (current.containsKey(device.ip) ? 1 : .5);
  final priorTotal = devices.values
      .fold<double>(0, (sum, device) => sum + .5 * priorOf(device));
  final priorScale = priorTotal > 1 ? 1 / priorTotal : 1.0;

  final deviceReasons = <String, List<String>>{};
  final deviceConfidence = <String, Confidence>{};
  for (final device in devices.values) {
    final reasons = <String>[];
    final prior = .5 * priorOf(device) * priorScale;
    if (device.kind.prior >= .4) {
      reasons.add(l.reasonHeavyKind(device.kind.label(l)));
    }
    final lift = presenceLift(scans, device.ip, checks);
    var liftScore = 0.0;
    if (lift.comparable) {
      liftScore = math.min(2, math.max(0, lift.lift) * 4);
      reasons.add(lift.lift > .02
          ? l.reasonLift(_pct(lift.presentRate), _pct(lift.absentRate))
          : l.reasonNoWorse);
    } else if (lift.presentChecks > 0 && lift.absentChecks == 0) {
      reasons.add(l.reasonAlwaysPresent);
    } else if (lift.presentChecks + lift.absentChecks == 0) {
      reasons.add(l.reasonNoPresence);
    }
    final joins = joinsBeforeFailures(scans, device.ip, periods);
    final joinScore = math.min(1.5, .5 * joins);
    if (joins > 0) {
      reasons.add(l.reasonJoined(joins));
    }
    final load = lanLoadScore(device.stats, device.kind);
    if (load > .05) {
      final stats = device.stats!;
      reasons.add(l.reasonSlowLocal(stats.latency, stats.jitter) +
          (device.kind == DeviceKind.phone ? l.reasonPhonePowerSave : ''));
    }
    if (!current.containsKey(device.ip)) {
      reasons.add(l.reasonNotInLastScan);
    }
    weights['device:${device.ip}'] =
        prior + liftScore + joinScore + local * load;
    deviceReasons[device.ip] = reasons;
    deviceConfidence[device.ip] =
        lift.comparable && lift.presentChecks >= 10 && lift.absentChecks >= 10
            ? Confidence.high
            : lift.comparable || joins > 0
                ? Confidence.medium
                : Confidence.low;
  }
  weights['other'] = NetworkRules.otherWeight;

  // -- 4. normalise
  final total = weights.values.fold<double>(0, (sum, value) => sum + value);
  final shares = <String, double>{
    for (final entry in weights.entries)
      if (entry.key != 'other') entry.key: explained * entry.value / total,
  };
  shares['other'] = (1 - explained) + explained * weights['other']! / total;
  final keys = shares.keys.toList();
  final percents = roundPercentages([for (final key in keys) shares[key]!]);
  final percentOf = {
    for (var index = 0; index < keys.length; index++)
      keys[index]: percents[index]
  };

  final pairedLabel =
      paired == 0 ? l.pairedNone : l.pairedGood(pairedGood, paired);
  final nowLabel = gatewayNow != null && scan?.internet != null
      ? l.nowRouterInternet(
          _replyLabel(gatewayNow, l), _replyLabel(scan!.internet, l))
      : null;

  Confidence pairedConfidence() => paired >= 10
      ? Confidence.high
      : paired >= 3
          ? Confidence.medium
          : Confidence.low;

  final contributions = <Contribution>[
    Contribution(
      id: 'isp',
      kind: CauseKind.isp,
      label: l.causeIsp,
      percent: percentOf['isp']!,
      confidence: pairedConfidence(),
      reasons: [
        pairedLabel,
        if (nowLabel != null) nowLabel,
        l.ispIncludes,
      ],
    ),
    Contribution(
      id: 'interference',
      kind: CauseKind.interference,
      label: l.causeInterference,
      percent: percentOf['interference']!,
      confidence: !wifiOk
          ? Confidence.low
          : wifi.level == 'high' && local >= .6
              ? Confidence.high
              : Confidence.medium,
      reasons: wifiOk
          ? [
              l.reasonChannels(
                  l.networksCount(wifi.sameChannel),
                  l.overlappingCount(wifi.partialOverlap),
                  wifi.channel,
                  wifi.bandLabel(l)),
              l.reasonInterferenceAmong(wifi.levelLabel(l),
                  l.neighborNetworksCount(wifi.totalNetworks)),
              if (wifi.suggestedChannel != null)
                l.reasonFreeChannel(wifi.suggestedChannel!),
            ]
          : [l.reasonNoNeighbors],
    ),
    Contribution(
      id: 'signal',
      kind: CauseKind.signal,
      label: l.causeSignal,
      percent: percentOf['signal']!,
      confidence: unstable.length >= 5 && weakShare >= .5
          ? Confidence.high
          : rssi != 0
              ? Confidence.medium
              : Confidence.low,
      reasons: [
        if (unstable.isNotEmpty)
          l.reasonWeakFailures(weakUnstable, unstable.length),
        if (rssi != 0)
          l.reasonSignalNow(
              rssi,
              l.signalQuality(rssi <= -75
                  ? 'weak'
                  : rssi <= -67
                      ? 'fair'
                      : 'good')),
      ],
    ),
    for (final device in devices.values)
      Contribution(
        id: 'device:${device.ip}',
        kind: CauseKind.device,
        label: device.displayName(l),
        percent: percentOf['device:${device.ip}']!,
        confidence: deviceConfidence[device.ip],
        reasons: deviceReasons[device.ip]!,
        device: device,
        present: current.containsKey(device.ip),
      ),
    Contribution(
      id: 'other',
      kind: CauseKind.unknown,
      label: l.causeUnknown,
      percent: percentOf['other']!,
      reasons: [
        if (unstable.isEmpty)
          l.reasonNoInstability
        else
          l.reasonUnexplained(unstable.length, checks.length),
      ],
    ),
  ]..sort((a, b) {
      final byPercent = b.percent.compareTo(a.percent);
      return byPercent != 0 ? byPercent : a.label.compareTo(b.label);
    });

  return NetworkAnalysis(
    location: _location(unstable.length, local, paired, gatewayNow,
        gatewayBadNow, scan?.internet, l),
    contributions: contributions,
    unstableChecks: unstable.length,
    totalChecks: checks.length,
  );
}

/// "74 ms", "sem resposta" or "—" without a measurement.
String _replyLabel(LinkStats? stats, AppLocalizations l10n) => stats == null
    ? '—'
    : stats.replied
        ? l10n.milliseconds(stats.latency)
        : l10n.noResponseLower;

ProblemLocation _location(
    int unstable,
    double local,
    int paired,
    LinkStats? gateway,
    bool gatewayBad,
    LinkStats? internet,
    AppLocalizations l) {
  final now = gateway == null
      ? ''
      : l.locationNow(_replyLabel(gateway, l), _replyLabel(internet, l));
  if (unstable == 0 && !gatewayBad) {
    return ProblemLocation(ProblemSide.none, local, paired, l.locationNoneTitle,
        l.locationNoneDetail(now));
  }
  if (paired == 0 && gateway == null) {
    return ProblemLocation(ProblemSide.unknown, local, paired,
        l.locationUnknownTitle, l.locationUnknownDetail);
  }
  if (local >= .65) {
    return ProblemLocation(ProblemSide.local, local, paired,
        l.locationLocalTitle, l.locationLocalDetail(now));
  }
  if (local <= .35) {
    return ProblemLocation(
        ProblemSide.isp, local, paired, l.causeIsp, l.locationIspDetail(now));
  }
  return ProblemLocation(ProblemSide.mixed, local, paired, l.locationMixedTitle,
      l.locationMixedDetail(now));
}

/// "há 5 min", "hoje às 14:32" or "em 16/10 14:32".
String scanAgeLabel(DateTime time, AppLocalizations l10n, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final age = at.difference(time);
  if (age.inMinutes < 1) return l10n.scanJustNow;
  if (age.inMinutes < 60) return l10n.scanMinutesAgo(age.inMinutes);
  if (age.inHours < 24 && time.day == at.day) {
    return l10n.scanTodayAt(formatClock(time));
  }
  return l10n.scanOnDate(formatDayMonth(time, l10n), formatClock(time));
}
