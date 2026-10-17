import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifiwarnme/analytics.dart';
import 'package:wifiwarnme/devices.dart';
import 'package:wifiwarnme/l10n/app_localizations.dart';

final pt = lookupAppLocalizations(const Locale('pt'));
final en = lookupAppLocalizations(const Locale('en'));

final base = DateTime(2026, 10, 16, 8);
DateTime at(int minutes) => base.add(Duration(minutes: minutes));

Measurement check(int minute,
        {String state = 'online', int signal = 4, String transport = 'wifi'}) =>
    Measurement(
      timestamp: at(minute),
      state: state,
      latency: state == 'online' ? 40 : 400,
      jitter: 3,
      failureRate: state == 'online' ? 0 : 20,
      transportType: transport,
      targetName: 'São Paulo',
      diagnosis: '',
      signalLevel: signal,
    );

InventorySnapshot snapshot(int minute, List<String> ips,
        {DeviceKind kind = DeviceKind.unknown}) =>
    InventorySnapshot(at(minute), {
      for (final ip in ips) ip: (name: null, kind: kind),
    });

LanProbe probe(int minute, {int latency = 4, int loss = 0}) =>
    LanProbe(at(minute), LinkStats(latency, 1, loss));

NetworkScan scanWith(
        {List<NetworkDevice> devices = const [],
        LinkStats gateway = const LinkStats(5, 2, 0),
        LinkStats internet = const LinkStats(80, 2, 0),
        WifiEnvironment? wifi}) =>
    NetworkScan(
      timestamp: at(24 * 60 - 1),
      selfIp: '192.168.0.42',
      gatewayIp: '192.168.0.1',
      gateway: gateway,
      internet: internet,
      wifi: wifi ??
          const WifiEnvironment(
              available: true, band: '5', channel: 132, rssi: -50),
      devices: [
        const NetworkDevice(
            ip: '192.168.0.1', kind: DeviceKind.router, isGateway: true),
        const NetworkDevice(
            ip: '192.168.0.42', kind: DeviceKind.phone, isSelf: true),
        ...devices,
      ],
    );

int sum(NetworkAnalysis analysis) =>
    analysis.contributions.fold(0, (total, item) => total + item.percent);

void main() {
  final now = at(24 * 60);

  group('roundPercentages', () {
    test('always sums to 100 with largest remainders', () {
      expect(roundPercentages([1, 1, 1]), [34, 33, 33]);
      expect(roundPercentages([.5, .25, .25]), [50, 25, 25]);
      expect(
          roundPercentages([0.001, 10, 3]).fold<int>(0, (a, b) => a + b), 100);
      expect(roundPercentages([0, 0]), [100, 0]);
      expect(roundPercentages([]), isEmpty);
    });
  });

  group('parsing', () {
    test('reads a native scan with devices, stats and Wi-Fi', () {
      final scan = NetworkScan.fromMap({
        'timestamp': at(0).millisecondsSinceEpoch,
        'durationMs': 13012,
        'transportType': 'wifi',
        'selfIp': '192.168.0.42',
        'gatewayIp': '192.168.0.1',
        'gateway': {'latency': 6, 'jitter': 5, 'loss': 0},
        'internet': {'latency': 83, 'jitter': 2, 'loss': 0},
        'wifi': {
          'available': true,
          'fresh': true,
          'band': '5',
          'channel': 132,
          'widthMhz': 80,
          'rssi': -49,
          'score': 0.0,
          'level': 'low',
          'totalNetworks': 30,
          'suggestedChannel': null,
          'networks': [
            {
              'ssid': 'Vizinho',
              'band': '2.4',
              'channel': 1,
              'rssi': -53,
              'overlap': 'none'
            }
          ],
        },
        'devices': [
          {
            'ip': '192.168.0.41',
            'name': 'Spotify Desktop Launcher',
            'type': 'computer',
            'vendor': null,
            'sources': ['mdns'],
            'services': ['_spotify-connect._tcp'],
            'isGateway': false,
            'isSelf': false,
            'latency': 13,
            'jitter': 1,
            'loss': 0,
          },
          {'ip': '192.168.0.20', 'type': 'nope', 'latency': -1, 'loss': -1},
        ],
      });
      expect(scan.duration.inMilliseconds, 13012);
      expect(scan.gateway!.healthyGateway, isTrue);
      expect(scan.wifi!.totalNetworks, 30);
      expect(scan.wifi!.networks.single.ssid, 'Vizinho');
      expect(scan.wifi!.bandLabel(pt), '5 GHz');
      expect(scan.devices.first.kind, DeviceKind.computer);
      expect(scan.devices.first.stats!.latency, 13);
      expect(scan.devices.last.kind, DeviceKind.unknown);
      expect(scan.devices.last.displayName(pt), 'Aparelho .20');
      expect(scan.devices.last.displayName(en), 'Device .20');
    });

    test('history sorts scans and probes and keeps the last scan', () {
      final history = NetworkHistory.fromMap({
        'scans': [
          {
            'timestamp': at(30).millisecondsSinceEpoch,
            'devices': [
              {'ip': '192.168.0.30', 'name': 'TV', 'type': 'tv'}
            ]
          },
          {'timestamp': at(0).millisecondsSinceEpoch, 'devices': []},
        ],
        'lanProbes': [
          {
            'timestamp': at(5).millisecondsSinceEpoch,
            'latency': 4,
            'jitter': 1,
            'loss': 0
          }
        ],
        'lastScan': {'timestamp': at(30).millisecondsSinceEpoch, 'devices': []},
      });
      expect(history.scans.first.timestamp, at(0));
      expect(history.scans.last.devices['192.168.0.30']!.kind, DeviceKind.tv);
      expect(history.lanProbes.single.stats.latency, 4);
      expect(history.lastScan!.timestamp, at(30));
      expect(NetworkHistory.fromMap({}).scans, isEmpty);
    });

    test('display names and descriptions', () {
      const tv = NetworkDevice(
          ip: '1',
          kind: DeviceKind.tv,
          name: '[TV] Samsung',
          vendor: 'Samsung',
          model: 'Q60');
      expect(tv.description(pt), 'TV ou streaming · Q60');
      expect(tv.description(en), 'TV or streaming · Q60');
      const router =
          NetworkDevice(ip: '1', kind: DeviceKind.router, isGateway: true);
      expect(router.displayName(pt), 'Roteador');
      const vendorOnly =
          NetworkDevice(ip: '1', kind: DeviceKind.phone, vendor: 'Apple');
      expect(vendorOnly.displayName(pt), 'Celular ou tablet Apple');
    });
  });

  group('presence', () {
    final scans = [
      snapshot(0, ['a']),
      snapshot(15, ['a', 'b']),
      snapshot(30, ['a']),
    ];

    test('uses the nearest scan within 20 minutes', () {
      expect(presentAt(scans, 'b', at(14)), isTrue);
      expect(presentAt(scans, 'b', at(26)), isFalse);
      expect(presentAt(scans, 'a', at(60)), isNull);
    });

    test('lift needs enough checks on both sides', () {
      final few = presenceLift(scans, 'b', [check(15, state: 'slow')]);
      expect(few.comparable, isFalse);
      expect(few.lift, 0);
    });

    test('joins right before a failure period are counted', () {
      final periods =
          failurePeriods([check(20, state: 'slow'), check(25)], live: false);
      expect(joinsBeforeFailures(scans, 'b', periods), 1);
      expect(joinsBeforeFailures(scans, 'a', periods), 0);
    });

    test('LAN load ignores silent devices and discounts phones', () {
      expect(lanLoadScore(null, DeviceKind.tv), 0);
      expect(lanLoadScore(const LinkStats(-1, -1, 100), DeviceKind.tv), 0);
      expect(lanLoadScore(const LinkStats(5, 1, 0), DeviceKind.tv), 0);
      final busy = lanLoadScore(const LinkStats(180, 60, 40), DeviceKind.tv);
      expect(busy, closeTo(1, 1e-9));
      expect(lanLoadScore(const LinkStats(180, 60, 40), DeviceKind.phone),
          closeTo(.4, 1e-9));
    });
  });

  group('analyzeNetwork', () {
    test('no instability leaves everything unexplained', () {
      final analysis = analyzeNetwork(
        measurements: [for (var m = 0; m < 60; m++) check(24 * 60 - 60 + m)],
        scan: scanWith(),
        now: now,
        l10n: pt,
      );
      expect(analysis.location.side, ProblemSide.none);
      expect(analysis.contributions.first.kind, CauseKind.unknown);
      expect(analysis.contributions.first.percent, 100);
      expect(sum(analysis), 100);
    });

    test('failures with a healthy gateway point to the operator', () {
      final measurements = [
        for (var m = 0; m < 120; m++)
          check(24 * 60 - 120 + m, state: m % 4 == 0 ? 'slow' : 'online')
      ];
      final analysis = analyzeNetwork(
        measurements: measurements,
        scan: scanWith(),
        history: NetworkHistory(lanProbes: [
          for (final sample in measurements)
            LanProbe(sample.timestamp.add(const Duration(seconds: 5)),
                const LinkStats(4, 1, 0))
        ]),
        now: now,
        l10n: pt,
      );
      expect(analysis.location.side, ProblemSide.isp);
      expect(analysis.location.pairedChecks, 30);
      expect(analysis.contributions.first.id, 'isp');
      expect(analysis.contributions.first.percent, greaterThan(70));
      expect(analysis.contributions.first.confidence, Confidence.high);
      expect(analysis.contributions.first.reasons.first,
          'Em 30 falhas de 30 o roteador respondia bem');
      expect(sum(analysis), 100);
    });

    test('a slow gateway and a crowded channel point to the home Wi-Fi', () {
      final measurements = [
        for (var m = 0; m < 40; m++)
          check(24 * 60 - 40 + m, state: m.isEven ? 'slow' : 'online')
      ];
      final analysis = analyzeNetwork(
        measurements: measurements,
        scan: scanWith(
          gateway: const LinkStats(120, 60, 25),
          wifi: const WifiEnvironment(
              available: true,
              band: '2.4',
              channel: 6,
              rssi: -55,
              score: 4,
              level: 'high',
              sameChannel: 5,
              partialOverlap: 3,
              totalNetworks: 20,
              suggestedChannel: 1),
        ),
        history: NetworkHistory(lanProbes: [
          for (final sample in measurements)
            LanProbe(sample.timestamp, const LinkStats(90, 40, 25))
        ]),
        now: now,
        l10n: pt,
      );
      expect(analysis.location.side, ProblemSide.local);
      final interference = analysis.contributions
          .firstWhere((item) => item.id == 'interference');
      expect(interference.percent, greaterThan(50));
      expect(interference.confidence, Confidence.high);
      expect(interference.reasons, contains('O canal 1 está mais livre'));
      expect(
          analysis.contributions.firstWhere((item) => item.id == 'isp').percent,
          lessThan(5));
      expect(sum(analysis), 100);
    });

    test('weak-signal failures go to the phone signal', () {
      final analysis = analyzeNetwork(
        measurements: [
          for (var m = 0; m < 20; m++)
            check(24 * 60 - 20 + m, state: 'slow', signal: 1)
        ],
        scan: scanWith(wifi: const WifiEnvironment(available: true, rssi: -80)),
        now: now,
        l10n: pt,
      );
      expect(analysis.contributions.first.id, 'signal');
      expect(analysis.contributions.first.confidence, Confidence.high);
      expect(
          analysis.contributions.first.reasons,
          containsAll([
            '20 falhas de 20 com sinal fraco',
            'Sinal atual -80 dBm (fraco)'
          ]));
    });

    test('a device whose presence coincides with failures stands out', () {
      // 8 h of checks every 5 min; the console is on from 4 h on, when 60%
      // of the checks fail, versus 5% before.
      final measurements = <Measurement>[];
      final scans = <InventorySnapshot>[];
      for (var m = 0; m < 8 * 60; m += 5) {
        final minute = 16 * 60 + m;
        final consoleOn = m >= 4 * 60;
        final fail = consoleOn ? (m ~/ 5) % 5 < 3 : (m ~/ 5) % 20 == 0;
        measurements.add(check(minute, state: fail ? 'slow' : 'online'));
        if (m % 15 == 0) {
          scans.add(snapshot(minute, [
            '192.168.0.20',
            if (consoleOn) '192.168.0.50',
          ]));
        }
      }
      final analysis = analyzeNetwork(
        measurements: measurements,
        scan: scanWith(devices: const [
          NetworkDevice(
              ip: '192.168.0.50', kind: DeviceKind.console, name: 'PS5'),
          NetworkDevice(ip: '192.168.0.20', kind: DeviceKind.unknown),
        ]),
        history: NetworkHistory(scans: scans),
        now: now,
        l10n: pt,
      );
      final console = analysis.forDevice('192.168.0.50')!;
      final other = analysis.forDevice('192.168.0.20')!;
      expect(console.percent, greaterThan(other.percent * 3));
      expect(console.confidence, Confidence.high);
      expect(
          console.reasons.any((reason) => reason.contains('contra')), isTrue);
      expect(
          console.reasons.any((reason) => reason.startsWith('Entrou')), isTrue);
      expect(other.reasons,
          contains('Sempre presente: sem períodos sem ele para comparar'));
      expect(analysis.devices.first.label, 'PS5');
      expect(sum(analysis), 100);
    });

    test('devices only in the history are listed as absent', () {
      final analysis = analyzeNetwork(
        measurements: [check(24 * 60 - 5, state: 'slow')],
        scan: scanWith(),
        history: NetworkHistory(scans: [
          snapshot(24 * 60 - 30, ['192.168.0.77'], kind: DeviceKind.tv),
          // Older than 24 h: ignored.
          snapshot(0, ['192.168.0.88'], kind: DeviceKind.tv),
          // The gateway in the history never becomes a device slice.
          snapshot(24 * 60 - 20, ['192.168.0.1'], kind: DeviceKind.router),
        ]),
        now: now.add(const Duration(minutes: 1)),
        l10n: pt,
      );
      final ghost = analysis.forDevice('192.168.0.77')!;
      expect(ghost.present, isFalse);
      expect(ghost.reasons, contains('Não apareceu no último escaneamento'));
      expect(analysis.forDevice('192.168.0.88'), isNull);
      expect(analysis.forDevice('192.168.0.1'), isNull);
    });

    test('cellular checks are ignored and priors are capped', () {
      final analysis = analyzeNetwork(
        measurements: [
          for (var m = 0; m < 10; m++)
            check(24 * 60 - 10 + m, state: 'offline', transport: 'cellular'),
          check(24 * 60 - 1, state: 'slow'),
        ],
        scan: scanWith(devices: [
          for (var i = 0; i < 30; i++)
            NetworkDevice(ip: '192.168.0.${100 + i}', kind: DeviceKind.tv)
        ]),
        now: now,
        l10n: pt,
      );
      expect(analysis.totalChecks, 1);
      expect(analysis.unstableChecks, 1);
      expect(analysis.devicesPercent, lessThan(40));
      expect(sum(analysis), 100);
    });

    test('without any gateway data the location is inconclusive', () {
      final analysis = analyzeNetwork(
          measurements: [check(24 * 60 - 5, state: 'slow')],
          now: now,
          l10n: pt);
      expect(analysis.location.side, ProblemSide.unknown);
      expect(sum(analysis), 100);
    });
  });

  test('scanAgeLabel', () {
    expect(scanAgeLabel(at(0), pt, now: at(0)), 'agora mesmo');
    expect(scanAgeLabel(at(0), pt, now: at(12)), 'há 12 min');
    expect(scanAgeLabel(at(0), pt, now: at(120)), 'hoje às 08:00');
    expect(scanAgeLabel(at(0), pt, now: at(60 * 30)), 'em 16/10 08:00');
    expect(scanAgeLabel(at(0), en, now: at(12)), '12 min ago');
    expect(scanAgeLabel(at(0), en, now: at(60 * 30)), 'on 10/16 08:00');
  });
}
