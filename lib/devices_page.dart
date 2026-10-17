part of 'main.dart';

// "Rede" tab: devices on the local network, where the problem is (home
// network versus operator) and the probable contribution of each cause. The
// rules live in devices.dart; the native scan in NetworkScanner.kt.

IconData _deviceKindIcon(DeviceKind kind) => switch (kind) {
      DeviceKind.router => Icons.router_rounded,
      DeviceKind.tv => Icons.tv_rounded,
      DeviceKind.phone => Icons.smartphone_rounded,
      DeviceKind.computer => Icons.computer_rounded,
      DeviceKind.printer => Icons.print_rounded,
      DeviceKind.console => Icons.sports_esports_rounded,
      DeviceKind.speaker => Icons.speaker_rounded,
      DeviceKind.camera => Icons.videocam_rounded,
      DeviceKind.iot => Icons.lightbulb_outline_rounded,
      DeviceKind.unknown => Icons.devices_other_rounded,
    };

Color _causeColor(LinkzoraPalette p, Contribution item) => switch (item.kind) {
      CauseKind.isp => p.info,
      CauseKind.interference => p.slow,
      CauseKind.signal => p.offline,
      CauseKind.device => p.accent,
      CauseKind.unknown => p.paused,
    };

IconData _causeIcon(Contribution item) => switch (item.kind) {
      CauseKind.isp => Icons.public_rounded,
      CauseKind.interference => Icons.wifi_tethering_error_rounded,
      CauseKind.signal => Icons.network_wifi_1_bar_rounded,
      CauseKind.device =>
        _deviceKindIcon(item.device?.kind ?? DeviceKind.unknown),
      CauseKind.unknown => Icons.help_outline_rounded,
    };

class _DevicesPage extends StatefulWidget {
  const _DevicesPage({
    required this.measurements,
    required this.visible,
    required this.monitoring,
  });

  /// Measurement history from Home (all targets; only Wi-Fi checks are used).
  final List<Measurement> measurements;

  /// Whether the tab is on screen; nothing is loaded before the first visit.
  final bool visible;

  /// Monitoring on: the presence history grows every 15 min.
  final bool monitoring;

  @override
  State<_DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<_DevicesPage> {
  AppLocalizations get l => context.l10n;
  NetworkHistory history = const NetworkHistory();
  NetworkScan? scan;
  bool loaded = false;
  bool scanning = false;
  double progress = 0;

  /// Progress label from the native scanner (already in the app language).
  String stage = '';
  String? error;
  Timer? progressTimer;
  final expanded = <String>{};

  NetworkAnalysis? _analysis;
  Object? _analysisKey;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _loadHistory();
  }

  @override
  void didUpdateWidget(_DevicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !loaded) _loadHistory();
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    loaded = true;
    try {
      final raw =
          await bridge.invokeMethod<Map<dynamic, dynamic>>('deviceHistory');
      if (!mounted || raw == null) return;
      final parsed = NetworkHistory.fromMap(raw);
      setState(() {
        history = parsed;
        scan ??= parsed.lastScan;
      });
    } catch (_) {
      // No history yet (or an older native side): the page still works.
    }
  }

  Future<void> _scanNow() async {
    if (scanning) return;
    setState(() {
      scanning = true;
      progress = 0;
      stage = l.scanPreparing;
      error = null;
    });
    progressTimer?.cancel();
    progressTimer = Timer.periodic(
        const Duration(milliseconds: 400), (_) => _pollProgress());
    try {
      final raw =
          await bridge.invokeMethod<Map<dynamic, dynamic>>('scanNetwork');
      if (!mounted) return;
      final result = raw == null ? null : NetworkScan.fromMap(raw);
      setState(() {
        if (result?.error == 'not_wifi') {
          error = l.scanNeedsWifi;
        } else if (result != null) {
          scan = result;
        }
      });
      await _loadHistory();
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? l.scanFailed);
    } catch (_) {
      if (mounted) setState(() => error = l.scanFailed);
    } finally {
      progressTimer?.cancel();
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _pollProgress() async {
    try {
      final raw =
          await bridge.invokeMethod<Map<dynamic, dynamic>>('scanProgress');
      if (!mounted || raw == null || !scanning) return;
      final value = (raw['fraction'] as num?)?.toDouble() ?? progress;
      final label = raw['stage']?.toString() ?? '';
      setState(() {
        progress = value > progress ? value : progress;
        if (label.isNotEmpty) stage = label;
      });
    } catch (_) {}
  }

  Future<void> _allowLocation() async {
    try {
      final granted =
          await bridge.invokeMethod<bool>('requestWifiName') ?? false;
      if (granted && mounted) _scanNow();
    } catch (_) {}
  }

  NetworkAnalysis get analysis {
    final measurements = widget.measurements;
    final l10n = l;
    final key = (
      measurements.length,
      measurements.isEmpty ? null : measurements.last.timestamp,
      scan,
      history,
      l10n.localeName,
    );
    if (_analysis == null || key != _analysisKey) {
      _analysisKey = key;
      _analysis = analyzeNetwork(
          measurements: measurements, scan: scan, history: history, l10n: l10n);
    }
    return _analysis!;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = scan;
    final result = analysis;
    return ListView(
      padding: _tabPagePadding(context, horizontal: 20, top: 18),
      children: [
        _LocationPanel(
          analysis: result,
          scan: current,
          scanning: scanning,
          progress: progress,
          stage: stage,
          onScan: _scanNow,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _NoticePanel(
            icon: Icons.wifi_off_rounded,
            color: p.offline,
            title: l.scanUnavailable,
            text: error!,
          ),
        ],
        if (current?.wifi?.reason == 'permission' ||
            current?.wifi?.reason == 'location_off' ||
            current?.wifi?.reason == 'no_access') ...[
          const SizedBox(height: 12),
          _NoticePanel(
            icon: Icons.location_on_outlined,
            color: p.info,
            title: l.neighborsHidden,
            text: current!.wifi!.reason == 'location_off'
                ? l.neighborsLocationOff
                : l.neighborsPermission,
            action: current.wifi!.reason == 'location_off'
                ? null
                : (l.allow, _allowLocation),
          ),
        ],
        const SizedBox(height: 22),
        _SectionLabel(l.probableContribution,
            trailing: Text(
                result.totalChecks == 0
                    ? l.noMeasurementsLower
                    : l.unstableOfTotal(
                        result.unstableChecks, result.totalChecks),
                style: TextStyle(color: p.muted, fontSize: 11))),
        _BreakdownPanel(analysis: result),
        const SizedBox(height: 22),
        _SectionLabel(
          current == null
              ? l.devicesOnNetwork
              : l.devicesOnNetworkCount(current.devices.length),
          trailing: current == null
              ? null
              : Text(l.scannedAgo(scanAgeLabel(current.timestamp, l)),
                  style: TextStyle(color: p.muted, fontSize: 11)),
        ),
        if (current == null)
          _NoticePanel(
            icon: Icons.radar_rounded,
            color: p.accent,
            title: l.noScanTitle,
            text: l.noScanText,
          )
        else
          ..._deviceCards(current, result),
        const SizedBox(height: 22),
        _SectionLabel(l.wifiEnvironment),
        _WifiPanel(wifi: current?.wifi),
        const SizedBox(height: 22),
        _NoticePanel(
          icon: Icons.info_outline_rounded,
          color: p.muted,
          title: l.howToReadTitle,
          text: widget.monitoring ? l.howToReadMonitoring : l.howToReadIdle,
        ),
      ],
    );
  }

  List<Widget> _deviceCards(NetworkScan current, NetworkAnalysis result) {
    final fixed = current.devices
        .where((device) => device.isGateway || device.isSelf)
        .toList();
    final ranked = result.devices;
    return [
      for (final device in fixed) ...[
        _DeviceCard(
          device: device,
          contribution: null,
          expanded: false,
          onTap: null,
        ),
        const SizedBox(height: 10),
      ],
      for (final item in ranked) ...[
        _DeviceCard(
          device: item.device!,
          contribution: item,
          expanded: expanded.contains(item.id),
          onTap: () => setState(() {
            if (!expanded.remove(item.id)) expanded.add(item.id);
          }),
        ),
        const SizedBox(height: 10),
      ],
      if (ranked.isEmpty)
        Text(l.onlyRouterAndPhone,
            style: TextStyle(color: context.palette.muted, fontSize: 12)),
    ];
  }
}

/// Header: verdict local × operator, gateway versus internet and the scan button.
class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.analysis,
    required this.scan,
    required this.scanning,
    required this.progress,
    required this.stage,
    required this.onScan,
  });

  final NetworkAnalysis analysis;
  final NetworkScan? scan;
  final bool scanning;
  final double progress;
  final String stage;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final location = analysis.location;
    final (icon, color) = switch (location.side) {
      ProblemSide.none => (Icons.verified_rounded, p.accent),
      ProblemSide.local => (Icons.home_rounded, p.slow),
      ProblemSide.isp => (Icons.public_rounded, p.info),
      ProblemSide.mixed => (Icons.compare_arrows_rounded, p.slow),
      ProblemSide.unknown => (Icons.help_outline_rounded, p.muted),
    };
    String ms(LinkStats? stats) => stats == null
        ? '—'
        : stats.replied
            ? l.milliseconds(stats.latency)
            : l.noResponseLower;
    final showSplit = location.side != ProblemSide.none &&
        location.side != ProblemSide.unknown;
    return _Panel(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: color, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.whereIsTheProblem.toUpperCase(),
                        style: TextStyle(
                            color: p.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                    const SizedBox(height: 3),
                    Text(location.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(location.detail,
              style: TextStyle(color: p.textSoft, fontSize: 13, height: 1.35)),
          if (showSplit) ...[
            const SizedBox(height: 14),
            _SplitBar(
              left: location.localShare,
              leftLabel: l.localNetwork,
              rightLabel: l.provider,
              leftColor: p.slow,
              rightColor: p.info,
            ),
          ],
          if (scan?.gateway != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.router_rounded,
                    label: l.kindRouter,
                    value: ms(scan!.gateway),
                    color: scan!.gateway!.healthyGateway ? p.accent : p.slow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.public_rounded,
                    label: l.internet,
                    value: ms(scan!.internet),
                    color: p.info,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (scanning)
            _ScanProgress(progress: progress, stage: stage)
          else
            _GradientButton(
              label: l.scanNow,
              icon: Icons.radar_rounded,
              onPressed: onScan,
            ),
          if (scan != null && !scanning) ...[
            const SizedBox(height: 8),
            Text(
              l.lastScan(scanAgeLabel(scan!.timestamp, l)) +
                  (scan!.duration > Duration.zero
                      ? ' · ${l.scanDuration(scan!.duration.inSeconds)}'
                      : ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.progress, required this.stage});

  final double progress;
  final String stage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(stage.isEmpty ? l.scanning : '$stage…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            Text('${(progress * 100).round()}%',
                style: TextStyle(
                    color: p.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        _GradientBar(value: progress, height: 8),
        const SizedBox(height: 8),
        Text(l.scanTakesAbout, style: TextStyle(color: p.muted, fontSize: 11)),
      ],
    );
  }
}

/// Rounded track with a brand-gradient (or [color]) fill that animates.
class _GradientBar extends StatelessWidget {
  const _GradientBar({required this.value, this.color, this.height = 6});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: p.muted.withValues(alpha: .14),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => FractionallySizedBox(
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: color == null
                    ? p.brandGradient
                    : LinearGradient(
                        colors: [color!.withValues(alpha: .65), color!]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.left,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftColor,
    required this.rightColor,
  });

  final double left;
  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final share = (left * 100).round();
    TextStyle style(Color color) =>
        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: share < 1 ? 1 : share,
                  child: Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                    leftColor.withValues(alpha: .7),
                    leftColor
                  ]))),
                ),
                Container(width: 2, color: p.bg),
                Expanded(
                  flex: share > 99 ? 1 : 100 - share,
                  child: Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                    rightColor,
                    rightColor.withValues(alpha: .7)
                  ]))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('$leftLabel $share%', style: style(leftColor)),
            const Spacer(),
            Text('${100 - share}% $rightLabel', style: style(rightColor)),
          ],
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.bg.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: p.muted, fontSize: 11)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Donut with the breakdown plus one bar per cause and the devices total.
class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({required this.analysis});

  final NetworkAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final causes = analysis.causes;
    final devices = analysis.devices;
    final topDevice = devices.isEmpty ? null : devices.first;
    final rows = <({
      String label,
      int percent,
      Color color,
      IconData icon,
      String? hint,
      Confidence? confidence
    })>[
      for (final item in causes)
        (
          label: item.label,
          percent: item.percent,
          color: _causeColor(p, item),
          icon: _causeIcon(item),
          hint: item.reasons.isEmpty ? null : item.reasons.first,
          confidence: item.confidence,
        ),
      if (devices.isNotEmpty)
        (
          label: l.networkDevices,
          percent: analysis.devicesPercent,
          color: p.accent,
          icon: Icons.devices_rounded,
          hint: topDevice!.percent > 0
              ? l.largestShare(topDevice.label, topDevice.percent)
              : null,
          confidence: null,
        ),
    ]..sort((a, b) => b.percent.compareTo(a.percent));
    final slices = [
      for (final row in rows)
        if (row.percent > 0) (value: row.percent.toDouble(), color: row.color)
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _DonutPainter(slices,
                      track: p.muted.withValues(alpha: .14)),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${rows.first.percent}%',
                            style: TextStyle(
                                color: rows.first.color,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        Text(l.probableLower,
                            style: TextStyle(color: p.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows.first.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(l.breakdownExplanation,
                        style: TextStyle(
                            color: p.muted, fontSize: 11.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final row in rows) ...[
            Row(
              children: [
                Icon(row.icon, size: 16, color: row.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                if (row.confidence != null) ...[
                  _ConfidenceTag(row.confidence!),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  width: 40,
                  child: Text('${row.percent}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: row.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _GradientBar(value: row.percent / 100, color: row.color),
            if (row.hint != null) ...[
              const SizedBox(height: 5),
              Text(row.hint!,
                  style: TextStyle(color: p.muted, fontSize: 11, height: 1.3)),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

const _tau = 6.283185307179586;

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, {required this.track});

  final List<({double value, Color color})> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, _tau, false, paint..color = track);
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return;
    const gap = .04;
    var start = -_tau / 4;
    for (final slice in slices) {
      final sweep = slice.value / total * _tau;
      final visible =
          slices.length > 1 ? (sweep - gap < .01 ? .01 : sweep - gap) : sweep;
      canvas.drawArc(rect, start + (slices.length > 1 ? gap / 2 : 0), visible,
          false, paint..color = slice.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.slices.length != slices.length ||
      [
        for (var i = 0; i < slices.length; i++)
          oldDelegate.slices[i] != slices[i]
      ].any((changed) => changed);
}

class _ConfidenceTag extends StatelessWidget {
  const _ConfidenceTag(this.confidence);

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (confidence) {
      Confidence.high => p.accent,
      Confidence.medium => p.info,
      Confidence.low => p.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(confidence.label(context.l10n),
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.contribution,
    required this.expanded,
    required this.onTap,
  });

  final NetworkDevice device;

  /// Null for the gateway and this phone, which get no percentage.
  final Contribution? contribution;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final item = contribution;
    final stats = device.stats;
    final present = item?.present ?? true;
    final latency = stats == null
        ? null
        : stats.replied
            ? l.milliseconds(stats.latency)
            : l.noResponseLower;
    final badgeColor = device.isGateway || device.isSelf
        ? p.info
        : present
            ? p.accent
            : p.muted;
    final subtitle = [
      device.isGateway
          ? l.yourRouter
          : device.isSelf
              ? l.thisDevice
              : device.description(l),
      device.ip,
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: _Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _IconBadge(
                      icon: _deviceKindIcon(device.kind),
                      color: badgeColor,
                      size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.displayName(l),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: present ? p.text : p.textSoft,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (item != null)
                        Text('${item.percent}%',
                            style: TextStyle(
                                color: present ? p.accent : p.muted,
                                fontSize: 18,
                                fontWeight: FontWeight.w900))
                      else if (latency != null)
                        Text(latency,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                      if (item != null && latency != null)
                        Text(l.localLatency(latency),
                            style: TextStyle(color: p.muted, fontSize: 10.5))
                      else if (item == null && stats != null && stats.replied)
                        Text(l.jitterMs(stats.jitter),
                            style: TextStyle(color: p.muted, fontSize: 10.5)),
                      if (!present)
                        Text(l.absent,
                            style: TextStyle(color: p.muted, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
              if (item != null) ...[
                const SizedBox(height: 10),
                _GradientBar(
                    value: item.percent / 100,
                    color: present ? null : p.muted,
                    height: 5),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.confidence != null)
                      _ConfidenceTag(item.confidence!),
                    const Spacer(),
                    Text(expanded ? l.showLess : l.why,
                        style: TextStyle(
                            color: p.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: p.info),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final reason in item.reasons.isEmpty
                                  ? [l.onlyKindWeight]
                                  : item.reasons)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                              color: p.muted,
                                              shape: BoxShape.circle),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(reason,
                                            style: TextStyle(
                                                color: p.textSoft,
                                                fontSize: 12,
                                                height: 1.3)),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                  l.sources(device.sources.isEmpty
                                      ? '—'
                                      : device.sources
                                          .map((source) =>
                                              source == historySource
                                                  ? l.sourceHistory
                                                  : source)
                                          .join(', ')),
                                  style: TextStyle(
                                      color: p.muted, fontSize: 10.5)),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WifiPanel extends StatelessWidget {
  const _WifiPanel({required this.wifi});

  final WifiEnvironment? wifi;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final env = wifi;
    if (env == null || !env.available) {
      return _NoticePanel(
        icon: Icons.wifi_find_rounded,
        color: p.muted,
        title: l.noNeighborsTitle,
        text: env == null ? l.noNeighborsScan : l.noNeighborsAndroid,
      );
    }
    final levelColor = switch (env.level) {
      'high' => p.offline,
      'medium' => p.slow,
      _ => p.accent,
    };
    Widget fact(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: p.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
        );
    final neighbors = env.networks.take(6).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.wifi_rounded, color: levelColor, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(env.ssid.isEmpty ? l.yourWifi : env.ssid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(
                        env.fresh
                            ? env.levelLabel(l)
                            : '${env.levelLabel(l)} · ${l.cachedData}',
                        style: TextStyle(color: levelColor, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              fact(l.wifiBand, env.bandLabel(l)),
              fact(l.wifiChannel, '${env.channel} · ${env.widthMhz} MHz'),
              fact(l.metricSignal, '${env.rssi} dBm'),
            ],
          ),
          const SizedBox(height: 14),
          _GradientBar(
              value: env.intensity < .03 ? .03 : env.intensity,
              color: levelColor),
          const SizedBox(height: 8),
          Text(
              l.neighborsSummary(
                  env.sameChannel, env.partialOverlap, env.totalNetworks),
              style: TextStyle(color: p.muted, fontSize: 11.5)),
          if (env.suggestedChannel != null) ...[
            const SizedBox(height: 10),
            Text(l.channelTip(env.suggestedChannel!),
                style: TextStyle(
                    color: p.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
          if (neighbors.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final network in neighbors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.wifi_rounded,
                        size: 14,
                        color: network.overlap == 'none'
                            ? p.muted
                            : network.overlap == 'same'
                                ? p.offline
                                : p.slow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(network.ssid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.textSoft, fontSize: 12)),
                    ),
                    Text(
                        '${l.bandGhz(network.band)} · c${network.channel} · ${network.rssi} dBm',
                        style: TextStyle(color: p.muted, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text,
                    style:
                        TextStyle(color: p.muted, fontSize: 12, height: 1.35)),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: action!.$2,
                    child: Text(action!.$1,
                        style: TextStyle(
                            color: p.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
