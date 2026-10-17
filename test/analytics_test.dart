import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifiwarnme/analytics.dart';
import 'package:wifiwarnme/l10n/app_localizations.dart';

final pt = lookupAppLocalizations(const Locale('pt'));
final es = lookupAppLocalizations(const Locale('es'));
final en = lookupAppLocalizations(const Locale('en'));

Measurement sample(
  DateTime time, {
  String state = 'online',
  int latency = 70,
  int jitter = 2,
  int failureRate = 0,
  String target = 'Cloudflare',
  String diagnosis = '',
}) =>
    Measurement(
      timestamp: time,
      state: state,
      latency: latency,
      jitter: jitter,
      failureRate: failureRate,
      transportType: 'wifi',
      targetName: target,
      diagnosis: diagnosis,
      signalLevel: 4,
    );

void main() {
  final base = DateTime(2026, 10, 16, 10);
  DateTime at(int minutes) => base.add(Duration(minutes: minutes));

  group('failurePeriods', () {
    test('groups consecutive problems and ends at the next online sample', () {
      final periods = failurePeriods([
        sample(at(0)),
        sample(at(1), state: 'slow', diagnosis: 'Perda de pacotes na rota'),
        sample(at(2), state: 'offline', latency: -1),
        sample(at(3)),
      ], live: false);
      expect(periods, hasLength(1));
      expect(periods.single.start, at(1));
      expect(periods.single.end, at(3));
      expect(periods.single.worstState, 'offline');
      expect(periods.single.diagnosis, 'Perda de pacotes na rota');
    });

    test('lists the newest period first', () {
      final periods = failurePeriods([
        sample(at(0), state: 'slow'),
        sample(at(1)),
        sample(at(5), state: 'slow'),
        sample(at(6)),
      ], live: false);
      expect(periods.map((period) => period.start), [at(5), at(0)]);
    });

    test('an open period lasts until now only while live', () {
      final samples = [sample(at(0)), sample(at(1), state: 'slow')];
      expect(failurePeriods(samples, live: false).single.end, at(1));
      expect(failurePeriods(samples, live: true, now: at(9)).single.end, at(9));
    });

    test('a server change splits the period', () {
      final periods = failurePeriods([
        sample(at(0), state: 'slow', target: 'Cloudflare'),
        sample(at(1), state: 'slow', target: 'Europa'),
        sample(at(2)),
      ], live: false);
      expect(
          periods.map((period) => period.targetName), ['Europa', 'Cloudflare']);
    });
  });

  test('availability is the share of online checks', () {
    expect(availability([]), 0);
    expect(
        availability([
          sample(at(0)),
          sample(at(1)),
          sample(at(2)),
          sample(at(3), state: 'slow'),
        ]),
        75);
  });

  group('bestHourLabel', () {
    test('needs enough data', () {
      expect(
          bestHourLabel([sample(at(0)), sample(at(1))], pt), 'Coletando dados');
      expect(bestHourLabel([sample(at(0))], en), 'Collecting data');
    });

    test('picks the hour with the lowest latency, jitter and loss', () {
      final samples = [
        sample(DateTime(2026, 10, 16, 9, 0), latency: 150),
        sample(DateTime(2026, 10, 16, 9, 30), latency: 140),
        sample(DateTime(2026, 10, 16, 23, 0), latency: 60),
        sample(DateTime(2026, 10, 16, 23, 30), latency: 62),
        // A single sample cannot win an hour.
        sample(DateTime(2026, 10, 16, 4, 0), latency: 10),
      ];
      expect(bestHourLabel(samples, pt), '23h–00h');
    });
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 30), pt), '< 1 min');
    expect(formatDuration(const Duration(minutes: 42), pt), '42 min');
    expect(formatDuration(const Duration(hours: 2), pt), '2 h');
    expect(
        formatDuration(const Duration(hours: 1, minutes: 5), pt), '1 h 5 min');
  });

  group('chartPoints', () {
    test('keeps small series untouched', () {
      final points = chartPoints([sample(at(0)), sample(at(1), latency: 90)]);
      expect(points.map((point) => point.latency), [70, 90]);
    });

    test('buckets long series and keeps the worst state visible', () {
      final samples = [
        for (var minute = 0; minute < 96; minute++)
          sample(at(minute),
              latency: minute == 10 ? -1 : 80,
              state: minute == 10 ? 'offline' : 'online'),
      ];
      final points = chartPoints(samples, maxPoints: 48);
      expect(points, hasLength(48));
      expect(points.where((point) => point.state == 'offline'), hasLength(1));
      // The outage is ignored by the bucket average.
      expect(points.every((point) => point.latency == 80), isTrue);
    });
  });

  test('LatencyStats ignores samples without response', () {
    final stats = LatencyStats.of([
      sample(at(0), latency: 50, jitter: 2),
      sample(at(1), latency: 70, jitter: 4),
      sample(at(2), latency: 90, jitter: 6),
      sample(at(3), latency: -1, jitter: -1, state: 'offline'),
    ]);
    expect(stats.minimum, 50);
    expect(stats.median, 70);
    expect(stats.p95, 90);
    expect(stats.averageJitter, 4);
    expect(LatencyStats.of([]).median, isNull);
  });

  test('ConnectionEvent parses the native event line', () {
    final event = ConnectionEvent.parse(
        '16/10 11:40 • Conexão instável • Wi-Fi • Europa • 320ms');
    expect(event.time, '16/10 11:40');
    expect(event.title, 'Conexão instável');
    expect(event.details, ['Wi-Fi', 'Europa', '320ms']);
    expect(event.state, 'slow');
    expect(
        ConnectionEvent.parse('16/10 11:41 • Internet indisponível • Wi-Fi')
            .state,
        'offline');
  });

  group('event days', () {
    final now = DateTime(2026, 1, 2, 9, 30);

    test('eventDate infers the year and rejects unreadable lines', () {
      ConnectionEvent event(String time) =>
          ConnectionEvent.parse('$time • Conexão estável • Wi-Fi');
      expect(eventDate(event('02/01 08:00'), now), DateTime(2026, 1, 2));
      expect(eventDate(event('03/01 00:10'), now), DateTime(2026, 1, 3),
          reason: 'a line from tomorrow is a clock skew, not last year');
      // The native line has no year: late December belongs to last year.
      expect(eventDate(event('30/12 23:50'), now), DateTime(2025, 12, 30));
      expect(eventDate(ConnectionEvent.parse('Linha sem data'), now), isNull);
      expect(eventDate(event('45/13 10:00'), now), isNull);
      expect(event('02/01 08:00').clock, '08:00');
    });

    test('eventDayLabel names today and yesterday', () {
      expect(eventDayLabel(DateTime(2026, 1, 2, 23), now, pt), 'Hoje');
      expect(eventDayLabel(DateTime(2026, 1, 1), now, pt), 'Ontem');
      expect(eventDayLabel(DateTime(2025, 12, 31), now, pt), '31/12');
      expect(eventDayLabel(DateTime(2025, 12, 5), now, pt), '05/12');
      expect(eventDayLabel(DateTime(2026, 1, 1), now, es), 'Ayer');
      expect(eventDayLabel(DateTime(2025, 12, 5), now, es), '05/12');
      expect(eventDayLabel(DateTime(2026, 1, 2), now, en), 'Today');
      expect(eventDayLabel(DateTime(2025, 12, 5), now, en), '12/05');
    });

    test('groupEventsByDay keeps the order and counts each kind', () {
      final days = groupEventsByDay([
        '02/01 09:10 • Conexão restabelecida • Wi-Fi · CasaNet • Europa',
        '02/01 09:02 • Internet indisponível • Wi-Fi · CasaNet',
        '02/01 08:40 • Conexão instável • Wi-Fi • Europa • 320ms',
        '01/01 22:00 • Conexão estável • Dados móveis',
        '01/01 21:00 • Conexão lenta • Wi-Fi',
        '31/12 10:00 • Conexão estável • Wi-Fi',
        'Linha sem data',
      ], now: now);
      expect(days.map((day) => day.label(now, pt)),
          ['Hoje', 'Ontem', '31/12', 'Sem data']);
      expect(days.first.date, DateTime(2026, 1, 2));
      expect(days.first.events.map((event) => event.clock),
          ['09:10', '09:02', '08:40']);
      final today = days.first.summary;
      expect([today.total, today.drops, today.instabilities, today.recoveries],
          [3, 1, 1, 1]);
      // Legacy "Conexão lenta" is the slow state.
      expect(days[1].summary.instabilities, 1);
      expect(days[2].date, DateTime(2025, 12, 31));
      expect(days.map((day) => day.key).toSet(), hasLength(4));

      final all = EventSummary.merge(days.map((day) => day.summary));
      expect([all.total, all.drops, all.instabilities, all.recoveries],
          [7, 1, 2, 4]);
      expect(groupEventsByDay([], now: now), isEmpty);
    });

    test('groupEventsByDay handles a full 30-day history', () {
      final lines = [
        for (var index = 0; index < 2000; index++)
          () {
            final time = now.subtract(Duration(minutes: index * 21));
            String two(int value) => value.toString().padLeft(2, '0');
            return '${two(time.day)}/${two(time.month)} '
                '${two(time.hour)}:${two(time.minute)} • '
                '${index.isEven ? 'Conexão instável' : 'Conexão estável'} • Wi-Fi';
          }(),
      ];
      final days = groupEventsByDay(lines, now: now);
      expect(days.fold<int>(0, (sum, day) => sum + day.events.length), 2000);
      expect(days.first.label(now, pt), 'Hoje');
      expect(days.length, 30);
      // Newest day first, each day exactly once.
      for (var index = 1; index < days.length; index++) {
        expect(days[index].date!.isBefore(days[index - 1].date!), isTrue);
      }
    });
  });

  test('groupEventsByDay skips repeated states (service restarts)', () {
    final days = groupEventsByDay([
      '16/10 11:42 • Conexão estável • Wi-Fi',
      '16/10 11:41 • Conexão estável • Wi-Fi',
      '16/10 11:40 • Conexão instável • Wi-Fi',
      '16/10 11:39 • Conexão estável • Wi-Fi',
    ], now: DateTime(2026, 10, 16, 12));
    expect(
        days.single.events.map((event) => event.clock),
        // The oldest of a repeated run is when the state actually began.
        ['11:41', '11:40', '11:39']);
  });

  test('older event details get the space before ms', () {
    final pt = lookupAppLocalizations(const Locale('pt'));
    expect(localizeNativeText('74ms', pt), '74 ms');
    expect(localizeNativeText('jitter 6ms', pt), 'jitter 6 ms');
    expect(localizeNativeText('74 ms', pt), '74 ms');
    expect(localizeNativeText('Wi-Fi · CasaNet', pt), 'Wi-Fi · CasaNet');
  });
}
