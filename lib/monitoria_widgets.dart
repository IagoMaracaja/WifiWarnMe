part of 'main.dart';

class _LatencyChart extends StatelessWidget {
  const _LatencyChart({
    required this.samples,
    required this.limit,
    required this.range,
  });

  static const maxPoints = 48;

  final List<Measurement> samples;
  final int limit;
  final Duration range;

  static int _niceCeiling(double value) {
    for (final step in [50, 100, 200, 250, 500, 1000]) {
      final rounded = (value / step).ceil() * step;
      if (rounded / step <= 8) return rounded.clamp(100, 4000);
    }
    return 4000;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final points = chartPoints(samples, maxPoints: maxPoints);
    if (points.isEmpty) {
      return SizedBox(
        height: 230,
        child: Center(
            child: Icon(Icons.show_chart_rounded, color: p.muted, size: 44)),
      );
    }
    final start = DateTime.now().subtract(range);
    // x is expressed in minutes since the start of the visible range.
    double x(DateTime time) => time.difference(start).inSeconds / 60.0;
    final maxX = range.inMinutes.toDouble();

    final observed = points.fold<int>(
        0,
        (high, point) => point.latency + point.jitter > high
            ? point.latency + point.jitter
            : high);
    final ceiling = _niceCeiling((observed > limit ? observed : limit) * 1.15);

    FlSpot spot(ChartPoint point, num value) => point.latency < 0
        ? FlSpot.nullSpot
        : FlSpot(x(point.timestamp), value.toDouble());

    final main = points.map((point) => spot(point, point.latency)).toList();
    final upper = points
        .map((point) =>
            spot(point, (point.latency + point.jitter).clamp(0, ceiling)))
        .toList();
    final lower = points
        .map((point) =>
            spot(point, (point.latency - point.jitter).clamp(0, ceiling)))
        .toList();
    final outages = points
        .where((point) => point.latency < 0)
        .map((point) => FlSpot(x(point.timestamp), 0))
        .toList();

    // The line takes the colour of each measurement's state along the x axis.
    final valid = points.where((point) => point.latency >= 0).toList();
    LinearGradient? lineGradient;
    if (valid.length >= 2) {
      final firstX = x(valid.first.timestamp);
      final span = x(valid.last.timestamp) - firstX;
      if (span > 0) {
        lineGradient = LinearGradient(
          colors: valid.map((point) => p.stateColor(point.state)).toList(),
          stops: valid
              .map((point) =>
                  ((x(point.timestamp) - firstX) / span).clamp(0.0, 1.0))
              .toList(),
        );
      }
    }

    final axisStyle =
        TextStyle(color: p.muted, fontSize: 9, fontWeight: FontWeight.w600);

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: ceiling.toDouble(),
              clipData: const FlClipData.none(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: ceiling / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: p.muted.withValues(alpha: .09),
                    strokeWidth: 1,
                    dashArray: const [3, 5]),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: ceiling / 2,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(value.round().toString(), style: axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: maxX / 3,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                          value >= maxX - .5
                              ? l.chartNow
                              : formatClock(start.add(
                                  Duration(seconds: (value * 60).round()))),
                          style: axisStyle),
                    ),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: limit.clamp(0, ceiling).toDouble(),
                  color: p.slow.withValues(alpha: .55),
                  strokeWidth: 1.2,
                  dashArray: const [6, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 2, bottom: 3),
                    style: TextStyle(
                        color: p.slow,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                    labelResolver: (_) => l.chartLimit(limit),
                  ),
                ),
              ]),
              // Jitter band: area between latency + jitter and latency - jitter.
              betweenBarsData: [
                BetweenBarsData(
                  fromIndex: 1,
                  toIndex: 2,
                  color: p.info.withValues(alpha: .13),
                ),
              ],
              lineBarsData: [
                LineChartBarData(
                  spots: main,
                  isCurved: true,
                  curveSmoothness: .25,
                  preventCurveOverShooting: true,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  color: p.accent,
                  gradient: lineGradient,
                  shadow: Shadow(
                      color: p.accent.withValues(alpha: .45), blurRadius: 10),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.accent.withValues(alpha: .22),
                        p.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  dotData: FlDotData(
                    checkToShowDot: (spot, bar) =>
                        valid.isNotEmpty && spot.x == x(valid.last.timestamp),
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 5,
                      color: p.stateColor(valid.last.state),
                      strokeWidth: 3,
                      strokeColor: p.panel.last,
                    ),
                  ),
                ),
                for (final band in [upper, lower])
                  LineChartBarData(
                    spots: band,
                    isCurved: true,
                    curveSmoothness: .25,
                    preventCurveOverShooting: true,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: const FlDotData(show: false),
                  ),
                LineChartBarData(
                  spots: outages,
                  barWidth: 0,
                  color: Colors.transparent,
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4.5,
                      color: p.offline,
                      strokeWidth: 2,
                      strokeColor: p.panel.last,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchSpotThreshold: 24,
                getTouchedSpotIndicator: (bar, indexes) => indexes
                    .map((_) => bar.barWidth == 0 && bar.spots != outages
                        ? null
                        : TouchedSpotIndicatorData(
                            FlLine(
                                color: p.muted.withValues(alpha: .35),
                                strokeWidth: 1,
                                dashArray: const [3, 3]),
                            FlDotData(
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                radius: 6,
                                color: Colors.white,
                                strokeWidth: 3,
                                strokeColor: p.accent,
                              ),
                            ),
                          ))
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(14),
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 160,
                  tooltipBorder:
                      BorderSide(color: p.accent.withValues(alpha: .25)),
                  getTooltipColor: (_) => p.tooltip,
                  getTooltipItems: (spots) => spots.map((touched) {
                    // Only the latency line and the outage markers get a tooltip.
                    if (touched.barIndex != 0 && touched.barIndex != 3) {
                      return null;
                    }
                    final point = points.firstWhere(
                        (point) => x(point.timestamp) == touched.x,
                        orElse: () => points.last);
                    return LineTooltipItem(
                      '${formatClock(point.timestamp)}\n',
                      TextStyle(
                          color: p.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                          text: point.latency < 0
                              ? l.stateNoResponse
                              : l.milliseconds(point.latency),
                          style: TextStyle(
                              color: p.stateColor(point.state),
                              fontSize: 15,
                              fontWeight: FontWeight.w900),
                        ),
                        if (point.latency >= 0)
                          TextSpan(
                            text: '\n${l.chartJitter(point.jitter)}',
                            style: TextStyle(
                                color: p.textSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: CustomPaint(
                  painter: _StateRibbonPainter(start, range, points, p)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thin timeline under the chart: each slice is coloured by connection state.
class _StateRibbonPainter extends CustomPainter {
  const _StateRibbonPainter(this.start, this.range, this.points, this.palette);

  final DateTime start;
  final Duration range;
  final List<ChartPoint> points;
  final LinkzoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = palette.muted.withValues(alpha: .1));
    final total = range.inSeconds.toDouble();
    double x(DateTime time) =>
        (time.difference(start).inSeconds / total * size.width)
            .clamp(0.0, size.width);
    for (var index = 0; index < points.length; index++) {
      final current = x(points[index].timestamp);
      final from =
          index == 0 ? current : (x(points[index - 1].timestamp) + current) / 2;
      final to = index == points.length - 1
          ? current + 3
          : (current + x(points[index + 1].timestamp)) / 2;
      canvas.drawRect(Rect.fromLTRB(from, 0, to, size.height),
          Paint()..color = palette.stateColor(points[index].state));
    }
  }

  @override
  bool shouldRepaint(covariant _StateRibbonPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.start != start ||
      oldDelegate.palette != palette;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  static const options = [1, 6, 24];

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _PillTrack(
        radius: 13,
        padding: 3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final hours in options)
              _PillOption(
                label: context.l10n.hoursShort(hours),
                selected: hours == value,
                onTap: () => onChanged(hours),
                radius: 10,
                fontSize: 11,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              ),
          ],
        ),
      );
}

class _ChartStat extends StatelessWidget {
  const _ChartStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? p.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: p.muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ServerOption {
  const _ServerOption(this.name, this.count, this.availability, this.active);

  final String name;
  final int count;
  final int availability;
  final bool active;
}

/// Anchored dropdown for the analysed server, styled like the rest of the app.
class _ServerDropdown extends StatefulWidget {
  const _ServerDropdown({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_ServerOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<_ServerDropdown> createState() => _ServerDropdownState();
}

class _ServerDropdownState extends State<_ServerDropdown>
    with SingleTickerProviderStateMixin {
  final controller = OverlayPortalController();
  final link = LayerLink();
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy controller would be first built inside dispose().
    animation = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  bool isOpen = false;

  void open() {
    setState(() => isOpen = true);
    controller.show();
    animation.forward(from: 0);
  }

  Future<void> close() async {
    if (!isOpen) return;
    setState(() => isOpen = false);
    await animation.reverse();
    if (mounted) controller.hide();
  }

  LinkzoraPalette get p => context.palette;
  AppLocalizations get l => context.l10n;

  Color _availabilityColor(int value) => value >= 90
      ? p.accent
      : value >= 60
          ? p.slow
          : p.offline;

  Widget _name(_ServerOption option, double fontSize) => Row(
        children: [
          Flexible(
            child: Text(targetDisplayName(option.name, l),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800)),
          ),
          if (option.active) ...[
            const SizedBox(width: 7),
            const _ActiveBadge(),
          ],
        ],
      );

  Widget _menu(double width, _ServerOption current) => Container(
        width: width,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.surfaceBright,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.accent.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
                color: p.shadow, blurRadius: 30, offset: const Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.options.map((option) {
            final selected = option.name == current.name;
            return InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                widget.onSelected(option.name);
                close();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? p.accent.withValues(alpha: .09)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _TargetMark(option.name, selected: selected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _name(option, 14),
                          const SizedBox(height: 2),
                          Text(l.measurementCount(option.count),
                              style: TextStyle(color: p.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('${option.availability}%',
                        style: TextStyle(
                            color: _availabilityColor(option.availability),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 19,
                      color:
                          selected ? p.accent : p.muted.withValues(alpha: .5),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final current = widget.options.firstWhere(
        (option) => option.name == widget.selected,
        orElse: () => widget.options.first);
    final expandable = widget.options.length > 1;
    // The menu is an overlay, not a route: Back must close it instead of leaving the app.
    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => CompositedTransformTarget(
          link: link,
          child: OverlayPortal(
            controller: controller,
            overlayChildBuilder: (_) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: close,
                    // The scrim colour itself animates: a fading full-screen
                    // layer showed static on a Galaxy Z Fold.
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) => ColoredBox(
                          color: p.bg.withValues(alpha: .45 * animation.value)),
                    ),
                  ),
                ),
                CompositedTransformFollower(
                  link: link,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 72),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizeTransition(
                      sizeFactor: CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic),
                      axisAlignment: -1,
                      child: Material(
                        color: Colors.transparent,
                        child: _menu(constraints.maxWidth, current),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: expandable ? () => isOpen ? close() : open() : null,
                child: Ink(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: p.panelRaised),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.accent.withValues(alpha: .2)),
                  ),
                  child: Row(
                    children: [
                      _TargetMark(current.name, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.analyzedServer,
                                style: TextStyle(color: p.muted, fontSize: 11)),
                            const SizedBox(height: 2),
                            _name(current, 16),
                          ],
                        ),
                      ),
                      if (expandable)
                        RotationTransition(
                          turns: Tween<double>(begin: 0, end: .5).animate(
                              CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic)),
                          child:
                              Icon(Icons.expand_more_rounded, color: p.accent),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(context.l10n.inUse,
          style: TextStyle(
              color: p.accent,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .6)),
    );
  }
}

/// A change-alert mode; [id] is what the native side stores.
class _AlertMode {
  const _AlertMode(this.id, this.icon);

  final String id;
  final IconData icon;

  String title(AppLocalizations l10n) => switch (id) {
        'none' => l10n.alertNone,
        'once' => l10n.alertOnce,
        _ => l10n.alertChanges,
      };

  String description(AppLocalizations l10n) => switch (id) {
        'none' => l10n.alertNoneDescription,
        'once' => l10n.alertOnceDescription,
        _ => l10n.alertChangesDescription,
      };
}

const _alertModes = [
  _AlertMode('none', Icons.notifications_off_rounded),
  _AlertMode('once', Icons.notification_important_rounded),
  _AlertMode('changes', Icons.notifications_active_rounded),
];

/// The mode with [id]; unknown ids fall back to "A cada mudança".
_AlertMode _alertMode(String id) => _alertModes
    .firstWhere((mode) => mode.id == id, orElse: () => _alertModes.last);

/// Bottom sheet for the change-alert mode, in the app's own visual language.
class _AlertModeSheet extends StatelessWidget {
  const _AlertModeSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) => _GlassSheet(
        icon: Icons.campaign_rounded,
        title: context.l10n.changeAlerts,
        subtitle: context.l10n.alertSheetSubtitle,
        children: [
          _AlertModeChoices(
            current: current,
            onSelected: (id) => Navigator.pop(context, id),
          ),
        ],
      );
}

/// The alert mode cards, shared by the sheet above and the onboarding.
class _AlertModeChoices extends StatelessWidget {
  const _AlertModeChoices({required this.current, required this.onSelected});

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _alertModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ChoiceCard(
                icon: option.icon,
                title: option.title(context.l10n),
                subtitle: option.description(context.l10n),
                selected: option.id == current,
                onTap: () => onSelected(option.id),
              ),
            ),
        ],
      );
}
