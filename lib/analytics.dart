/// Pure analysis of the measurement history, independent of Flutter widgets.
/// User-visible text comes from the [AppLocalizations] passed in.
library;

import 'l10n/app_localizations.dart';

class Measurement {
  const Measurement({
    required this.timestamp,
    required this.state,
    required this.latency,
    required this.jitter,
    required this.failureRate,
    required this.transportType,
    required this.targetName,
    required this.diagnosis,
    required this.signalLevel,
    this.diagnosisCode = '',
  });

  factory Measurement.fromMap(Map<dynamic, dynamic> value) => Measurement(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (value['timestamp'] as num?)?.toInt() ?? 0),
        state: value['state']?.toString() ?? 'offline',
        latency: (value['latency'] as num?)?.toInt() ?? -1,
        jitter: (value['jitter'] as num?)?.toInt() ?? -1,
        failureRate: (value['failureRate'] as num?)?.toInt() ?? 100,
        transportType: value['transportType']?.toString() ?? 'none',
        targetName: canonicalTarget(value['targetName']?.toString() ?? ''),
        diagnosis: value['diagnosis']?.toString() ?? '',
        diagnosisCode: value['diagnosisCode']?.toString() ?? '',
        signalLevel: (value['signalLevel'] as num?)?.toInt() ?? -1,
      );

  final DateTime timestamp;
  final String state;
  final int latency;
  final int jitter;

  /// Share of handshakes lost: failed or only completed after a SYN retransmission.
  final int failureRate;
  final String transportType;
  final String targetName;

  /// Diagnosis as text in the language it was measured in.
  final String diagnosis;

  /// Language-neutral id of [diagnosis] (e.g. "packet_loss"); empty in
  /// readings from before the native side sent it.
  final String diagnosisCode;
  final int signalLevel;

  /// [diagnosis] in the language of [l10n]; empty without a diagnosis.
  String localizedDiagnosis(AppLocalizations l10n) =>
      localizeDiagnosis(diagnosisCode, diagnosis, targetName, l10n);
}

/// Identity of samples without a target name; shown via [targetDisplayName].
const unknownTarget = 'Destino não identificado';

/// Names of the regional targets in other languages, mapped to the Portuguese
/// name the native side has always recorded (and the flags are keyed by).
const _targetAliases = {
  'United States': 'Estados Unidos',
  'Europe': 'Europa',
  'Sao Paulo': 'São Paulo',
};

/// The stable identity of a target name, whatever language it was saved in.
String canonicalTarget(String name) => _targetAliases[name] ?? name;

/// [target] in the language of [l10n]; brand names stay as they are.
String targetDisplayName(String target, AppLocalizations l10n) =>
    switch (canonicalTarget(target)) {
      'São Paulo' => l10n.locationSaoPaulo,
      'Estados Unidos' => l10n.locationUnitedStates,
      'Europa' => l10n.locationEurope,
      unknownTarget => l10n.unknownTarget,
      final other => other,
    };

String targetOf(Measurement sample) =>
    sample.targetName.isEmpty ? unknownTarget : sample.targetName;

class FailurePeriod {
  const FailurePeriod(
      this.start, this.end, this.worstState, this.targetName, this.diagnosis,
      {this.diagnosisCode = ''});

  final DateTime start;
  final DateTime end;
  final String worstState;
  final String targetName;
  final String diagnosis;
  final String diagnosisCode;

  /// [diagnosis] in the language of [l10n]; empty without a diagnosis.
  String localizedDiagnosis(AppLocalizations l10n) =>
      localizeDiagnosis(diagnosisCode, diagnosis, targetName, l10n);

  Duration get duration => end.difference(start);
}

/// Consecutive non-online samples grouped into periods, newest first.
///
/// A period ends at the first online sample after it. When [live] is true the
/// last open period is still happening and ends at [now].
List<FailurePeriod> failurePeriods(List<Measurement> samples,
    {required bool live, DateTime? now}) {
  final periods = <FailurePeriod>[];
  DateTime? start;
  var worst = 'slow';
  var target = '';
  var problem = '';
  var problemCode = '';
  void close(DateTime end) {
    periods.add(FailurePeriod(start!, end, worst, target, problem,
        diagnosisCode: problemCode));
    start = null;
    worst = 'slow';
    target = '';
    problem = '';
    problemCode = '';
  }

  for (final sample in samples) {
    if (sample.state != 'online') {
      if (start != null && target != sample.targetName) close(sample.timestamp);
      start ??= sample.timestamp;
      target = sample.targetName;
      if (sample.diagnosis.isNotEmpty || sample.diagnosisCode.isNotEmpty) {
        problem = sample.diagnosis;
        problemCode = sample.diagnosisCode;
      }
      if (sample.state == 'offline') worst = 'offline';
    } else if (start != null) {
      close(sample.timestamp);
    }
  }
  if (start != null) {
    close(live ? (now ?? DateTime.now()) : samples.last.timestamp);
  }
  return periods.reversed.toList();
}

/// Percentage of checks classified as online.
int availability(List<Measurement> samples) => samples.isEmpty
    ? 0
    : (samples.where((sample) => sample.state == 'online').length *
            100 /
            samples.length)
        .round();

/// Hour of the day with the best average score of latency, jitter and loss,
/// considering only hours with at least two samples.
String bestHourLabel(List<Measurement> samples, AppLocalizations l10n) {
  final valid = samples
      .where((sample) => sample.latency >= 0 && sample.state != 'offline')
      .toList();
  if (valid.length < 3) return l10n.collectingData;
  final byHour = <int, List<Measurement>>{};
  for (final sample in valid) {
    byHour.putIfAbsent(sample.timestamp.hour, () => []).add(sample);
  }
  final eligible = byHour.entries.where((entry) => entry.value.length >= 2);
  if (eligible.isEmpty) return l10n.collectingData;
  double score(MapEntry<int, List<Measurement>> entry) =>
      entry.value
          .map((sample) =>
              sample.latency + sample.jitter * 2 + sample.failureRate * 5)
          .reduce((a, b) => a + b) /
      entry.value.length;
  final best = eligible.reduce((a, b) => score(a) <= score(b) ? a : b);
  String hour(int value) => value.toString().padLeft(2, '0');
  return l10n.hourRange(hour(best.key), hour((best.key + 1) % 24));
}

String formatDuration(Duration value, AppLocalizations l10n) {
  if (value.inMinutes < 1) return '< ${l10n.minutes(1)}';
  if (value.inHours < 1) return l10n.minutes(value.inMinutes);
  final minutes = value.inMinutes.remainder(60);
  final hours = l10n.hoursShort(value.inHours);
  return minutes == 0 ? hours : '$hours ${l10n.minutes(minutes)}';
}

String formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// "16/10" (or "10/16" in English): the short day and month of [value].
String formatDayMonth(DateTime value, AppLocalizations l10n) => l10n.dayMonth(
    value.day.toString().padLeft(2, '0'),
    value.month.toString().padLeft(2, '0'));

/// One plotted point: a single measurement or a bucket of consecutive ones.
class ChartPoint {
  const ChartPoint(this.timestamp, this.latency, this.jitter, this.state);

  final DateTime timestamp;
  final int latency;
  final int jitter;
  final String state;
}

/// Reduces [samples] to at most [maxPoints] points. Each bucket keeps the
/// average latency, the highest jitter and the worst state, so short outages
/// stay visible.
List<ChartPoint> chartPoints(List<Measurement> samples, {int maxPoints = 48}) {
  if (samples.length <= maxPoints) {
    return samples
        .map((sample) => ChartPoint(
            sample.timestamp, sample.latency, sample.jitter, sample.state))
        .toList();
  }
  final size = (samples.length / maxPoints).ceil();
  final points = <ChartPoint>[];
  for (var start = 0; start < samples.length; start += size) {
    final end = start + size > samples.length ? samples.length : start + size;
    final bucket = samples.sublist(start, end);
    final valid = bucket.where((sample) => sample.latency >= 0).toList();
    final state = bucket.any((sample) => sample.state == 'offline')
        ? 'offline'
        : bucket.any((sample) => sample.state == 'slow')
            ? 'slow'
            : 'online';
    points.add(ChartPoint(
      bucket[bucket.length ~/ 2].timestamp,
      valid.isEmpty
          ? -1
          : (valid.fold<int>(0, (sum, sample) => sum + sample.latency) /
                  valid.length)
              .round(),
      valid.fold<int>(
          0, (high, sample) => sample.jitter > high ? sample.jitter : high),
      state,
    ));
  }
  return points;
}

/// Latency statistics shown under the chart. Values are null without data.
class LatencyStats {
  const LatencyStats({this.minimum, this.median, this.p95, this.averageJitter});

  factory LatencyStats.of(List<Measurement> samples) {
    final latencies = samples
        .where((sample) => sample.latency >= 0)
        .map((sample) => sample.latency)
        .toList()
      ..sort();
    final jitters = samples
        .where((sample) => sample.latency >= 0 && sample.jitter >= 0)
        .map((sample) => sample.jitter)
        .toList();
    int? percentile(double ratio) => latencies.isEmpty
        ? null
        : latencies[((latencies.length - 1) * ratio).round()];
    return LatencyStats(
      minimum: percentile(0),
      median: percentile(.5),
      p95: percentile(.95),
      averageJitter: jitters.isEmpty
          ? null
          : (jitters.reduce((a, b) => a + b) / jitters.length).round(),
    );
  }

  final int? minimum;
  final int? median;
  final int? p95;
  final int? averageJitter;
}

/// An entry of the events tab, parsed from the native "time • title • detail…" line.
class ConnectionEvent {
  const ConnectionEvent(this.time, this.title, this.details, this.state);

  factory ConnectionEvent.parse(String raw) {
    final pieces = raw.split(' • ');
    final time = pieces.length > 1 ? pieces.first : '';
    final title = pieces.length > 1 ? pieces[1] : raw;
    final details = pieces.length > 2 ? pieces.sublist(2) : const <String>[];
    final lower = title.toLowerCase();
    final state = _offlineWords.any(lower.contains)
        ? 'offline'
        : _unstableWords.any(lower.contains)
            ? 'slow'
            : 'online';
    return ConnectionEvent(time, title, details, state);
  }

  // Titles may be stored in any app language (pt, es, en).
  static const _offlineWords = ['indisponível', 'no disponible', 'unavailable'];
  // "lenta" is the slow-state title of the first versions.
  static const _unstableWords = ['instável', 'inestable', 'unstable', 'lenta'];

  final String time;
  final String title;
  final List<String> details;
  final String state;

  /// The "HH:mm" part of [time].
  String get clock {
    final space = time.lastIndexOf(' ');
    return space < 0 ? time : time.substring(space + 1);
  }
}

/// The calendar day of an event line ("dd/MM HH:mm"), with the year inferred
/// from [now]: the native line has no year, so a date later than tomorrow
/// belongs to the previous year. Null when the time cannot be parsed.
DateTime? eventDate(ConnectionEvent event, DateTime now) {
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})').firstMatch(event.time);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(now.year, month, day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return date.isAfter(tomorrow) ? DateTime(now.year - 1, month, day) : date;
}

/// "Hoje", "Ontem" or "dd/MM" for [day] relative to [now].
String eventDayLabel(DateTime day, DateTime now, AppLocalizations l10n) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  if (date == today) return l10n.today;
  if (date == DateTime(today.year, today.month, today.day - 1)) {
    return l10n.yesterday;
  }
  return formatDayMonth(date, l10n);
}

/// How many drops, instabilities and recoveries a set of events holds.
class EventSummary {
  const EventSummary(
      {this.total = 0,
      this.drops = 0,
      this.instabilities = 0,
      this.recoveries = 0});

  factory EventSummary.of(Iterable<ConnectionEvent> events) {
    var drops = 0, instabilities = 0, recoveries = 0, total = 0;
    for (final event in events) {
      total++;
      switch (event.state) {
        case 'offline':
          drops++;
        case 'slow':
          instabilities++;
        default:
          recoveries++;
      }
    }
    return EventSummary(
        total: total,
        drops: drops,
        instabilities: instabilities,
        recoveries: recoveries);
  }

  /// Totals of several summaries, e.g. of every day.
  factory EventSummary.merge(Iterable<EventSummary> summaries) =>
      summaries.fold(
          const EventSummary(),
          (sum, item) => EventSummary(
              total: sum.total + item.total,
              drops: sum.drops + item.drops,
              instabilities: sum.instabilities + item.instabilities,
              recoveries: sum.recoveries + item.recoveries));

  final int total;

  /// "Internet indisponível" events.
  final int drops;

  /// Events that left the connection unstable.
  final int instabilities;

  /// Events where the connection became stable again.
  final int recoveries;
}

/// The events of one calendar day, newest first like the native list.
class EventDay {
  const EventDay(this.date, this.events, this.summary);

  /// Midnight of the day; null groups the lines without a readable time.
  final DateTime? date;
  final List<ConnectionEvent> events;
  final EventSummary summary;

  /// Stable id of the day, used to remember the selected filter.
  String get key =>
      date == null ? 'sem-data' : '${date!.year}-${date!.month}-${date!.day}';

  String label(DateTime now, AppLocalizations l10n) =>
      date == null ? l10n.noDate : eventDayLabel(date!, now, l10n);
}

/// Groups the native event lines (newest first) by calendar day, newest day
/// first, keeping the order of the events inside each day.
List<EventDay> groupEventsByDay(Iterable<String> lines, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final events = lines.map(ConnectionEvent.parse).toList();
  final byDay = <DateTime?, List<ConnectionEvent>>{};
  for (var index = 0; index < events.length; index++) {
    final event = events[index];
    // Lines are newest first. Older versions logged the current state again
    // whenever the service restarted; an event repeating the state before it
    // is not a change, so it is skipped.
    if (index + 1 < events.length &&
        event.time.isNotEmpty &&
        events[index + 1].time.isNotEmpty &&
        events[index + 1].state == event.state) {
      continue;
    }
    byDay.putIfAbsent(eventDate(event, reference), () => []).add(event);
  }
  return [
    for (final entry in byDay.entries)
      EventDay(entry.key, entry.value, EventSummary.of(entry.value)),
  ];
}

/// A diagnosis in the language of [l10n]: from its language-neutral [code]
/// when known, else the stored [text] (translated when it is a Portuguese
/// text from before the codes existed). [target] fills "regional_distance".
String localizeDiagnosis(
    String code, String text, String target, AppLocalizations l10n) {
  final byCode = switch (code) {
    'no_network' => l10n.diagNoNetwork,
    'captive_portal' => l10n.diagCaptivePortal,
    'dns_failure' => l10n.diagDns,
    'no_internet' => l10n.diagNoInternet,
    'wifi_too_weak' => l10n.diagWeakWifiOffline,
    'no_response' => l10n.diagServerNoResponse,
    'weak_signal_stable' => l10n.diagWeakWifiStable,
    'none' => l10n.diagNoAnomaly,
    'weak_signal' => l10n.diagWeakWifi,
    'packet_loss' => l10n.diagPacketLoss,
    'high_jitter' => l10n.diagHighJitter,
    'regional_distance' when target.isNotEmpty =>
      l10n.diagRegionalDistance(targetDisplayName(target, l10n)),
    'congested_route' => l10n.diagCongested,
    _ => null,
  };
  return byCode ?? localizeNativeText(text, l10n);
}

// Text the native side writes (event titles and details, network names) and
// Portuguese diagnoses stored before it sent diagnosis codes. Each is known in
// every app language, so history written in one language reads in the active
// one; anything else (SSIDs, numbers) passes through unchanged.

final List<String Function(AppLocalizations)> _nativeTextGetters = [
  (l) => l.diagNoNetwork,
  (l) => l.diagCaptivePortal,
  (l) => l.diagDns,
  (l) => l.diagNoInternet,
  (l) => l.diagWeakWifiOffline,
  (l) => l.diagServerNoResponse,
  (l) => l.diagWeakWifiStable,
  (l) => l.diagNoAnomaly,
  (l) => l.diagWeakWifi,
  (l) => l.diagPacketLoss,
  (l) => l.diagHighJitter,
  (l) => l.diagCongested,
  (l) => l.awaitingMeasurements,
  (l) => l.eventStable,
  (l) => l.eventUnstable,
  (l) => l.eventOffline,
  (l) => l.eventRestored,
  (l) => l.eventBackUnstable,
  (l) => l.eventChecking,
  (l) => l.transportMobileData,
  (l) => l.transportNoNetwork,
  (l) => l.noConnection,
  (l) => l.locationUnitedStates,
  (l) => l.locationEurope,
  (l) => l.unknownTarget,
];

/// Text in any supported language → the getter that gives it in another.
final Map<String, String Function(AppLocalizations)> _nativeTexts = {
  for (final locale in AppLocalizations.supportedLocales)
    for (final getter in _nativeTextGetters)
      getter(lookupAppLocalizations(locale)): getter,
};

final _regionalDistance = RegExp(r'^Distância até (.+) influencia a latência$');
final _lossDetail = RegExp(r'^(?:perda|pérdida|loss) (\d+)%$');

/// "74ms" / "jitter 6ms" from older events, written without the space the
/// rest of the app uses.
final _glued = RegExp(r'(\d)ms$');

/// [text] from the native side in the language of [l10n] when it is a known
/// text in any app language; anything else is returned unchanged.
String localizeNativeText(String text, AppLocalizations l10n) {
  final known = _nativeTexts[text];
  if (known != null) return known(l10n);
  final distance = _regionalDistance.firstMatch(text);
  if (distance != null) {
    return l10n
        .diagRegionalDistance(targetDisplayName(distance.group(1)!, l10n));
  }
  final loss = _lossDetail.firstMatch(text);
  if (loss != null) return l10n.evidenceLoss(loss.group(1)!);
  return text.replaceFirstMapped(_glued, (match) => '${match[1]} ms');
}
