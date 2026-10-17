part of 'main.dart';

// First-run setup: a short pager that picks the language (on the welcome
// page), the test destination, alerts and measurement rhythm, optionally
// unlocks the Wi-Fi name and can start the monitor. It saves to the same prefs
// keys Home reads and runs only once.

const _onboardingDoneKey = 'onboardingDone';

class _Onboarding extends StatefulWidget {
  const _Onboarding({super.key, required this.onFinished});

  /// Called after the choices and the done flag are saved.
  final VoidCallback onFinished;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  LinkzoraPalette get p => context.palette;
  AppLocalizations get l => context.l10n;

  static const stepCount = 6;
  static const rhythmStep = 3;
  static const wifiStep = 4;
  static const summaryStep = 5;

  final pages = PageController();
  int step = 0;
  bool busy = false;

  int interval = 2;
  int maxLatency = 300;
  String serverId = 'cloudflare';
  String locationId = 'near';
  String notificationMode = 'changes';

  /// Null until the Wi-Fi step is answered.
  bool? wifiNameAllowed;

  /// False while the typed latency limit is invalid.
  bool limitValid = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  /// Installs from before the onboarding keep their saved choices.
  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      interval = prefs.getInt('interval') ?? interval;
      maxLatency = prefs.getInt('maxLatency') ?? maxLatency;
      serverId = prefs.getString('serverId') ?? serverId;
      locationId = prefs.getString('locationId') ?? locationId;
      notificationMode =
          prefs.getString('notificationMode') ?? notificationMode;
    });
  }

  Map<String, Object> get monitorArguments => {
        'interval': interval,
        'maxLatency': maxLatency,
        'serverId': serverId,
        'locationId': locationId,
        'notificationMode': notificationMode,
        'language': l.localeName,
      };

  String get targetLabel {
    final location = testLocations.firstWhere(
        (option) => option.id == locationId,
        orElse: () => testLocations.first);
    if (locationId != 'near') return location.label(l);
    final server = testServers.firstWhere((option) => option.id == serverId,
        orElse: () => testServers.first);
    return '${location.label(l)} · ${server.name}';
  }

  String get alertLabel => _alertMode(notificationMode).title(l);

  void goTo(int target) {
    if (target < 0 || target >= stepCount) return;
    setState(() => step = target);
    pages.animateToPage(target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  Future<void> allowWifiName() async {
    if (busy) return;
    setState(() => busy = true);
    var granted = false;
    try {
      granted = await bridge.invokeMethod<bool>('requestWifiName') ?? false;
    } on PlatformException catch (error) {
      if (mounted) {
        _showToast(context, error.message ?? l.permissionRequestFailed,
            error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      wifiNameAllowed = granted;
    });
    goTo(summaryStep);
  }

  /// Saves every choice, marks the setup as done and optionally starts the
  /// monitor (which also asks for the notification permission natively).
  Future<void> finish({required bool startMonitor}) async {
    if (busy) return;
    setState(() => busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interval', interval);
    await prefs.setInt('maxLatency', maxLatency);
    await prefs.setString('serverId', serverId);
    await prefs.setString('locationId', locationId);
    await prefs.setString('notificationMode', notificationMode);
    await prefs.setBool(_onboardingDoneKey, true);
    if (startMonitor) {
      try {
        await bridge.invokeMethod('start', monitorArguments);
      } on PlatformException catch (error) {
        if (mounted) {
          _showToast(context, error.message ?? l.startFailed, error: true);
        }
      }
    }
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // System back walks the steps instead of closing the app.
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) goTo(step - 1);
        },
        child: Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: PageView(
                    controller: pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _welcomePage(),
                      _OnboardingStep(
                        icon: Icons.public_rounded,
                        title: l.targetStepTitle,
                        subtitle: l.targetStepSubtitle,
                        child: _TargetPicker(
                          locationId: locationId,
                          serverId: serverId,
                          onLocationChanged: (id) =>
                              setState(() => locationId = id),
                          onServerChanged: (id) =>
                              setState(() => serverId = id),
                        ),
                      ),
                      _OnboardingStep(
                        icon: Icons.campaign_rounded,
                        title: l.changeAlerts,
                        subtitle: l.alertsStepSubtitle,
                        child: _AlertModeChoices(
                          current: notificationMode,
                          onSelected: (id) =>
                              setState(() => notificationMode = id),
                        ),
                      ),
                      _OnboardingStep(
                        icon: Icons.tune_rounded,
                        title: l.rhythmStepTitle,
                        subtitle: l.rhythmStepSubtitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _IntervalPicker(
                              value: interval,
                              onChanged: (value) =>
                                  setState(() => interval = value),
                            ),
                            const SizedBox(height: 22),
                            _LatencyLimitPicker(
                              value: maxLatency,
                              onChanged: (value) =>
                                  setState(() => maxLatency = value),
                              onValidityChanged: (valid) =>
                                  setState(() => limitValid = valid),
                            ),
                          ],
                        ),
                      ),
                      _wifiPage(),
                      _summaryPage(),
                    ],
                  ),
                ),
                _actions(),
              ],
            ),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 20, 4),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: step == 0 ? 0 : 1,
                child: IconButton(
                  tooltip: l.back,
                  onPressed: step == 0 ? null : () => goTo(step - 1),
                  icon: Icon(Icons.arrow_back_rounded, color: p.muted),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < stepCount; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: index == step ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: index <= step ? p.brandGradient : null,
                          color: index <= step
                              ? null
                              : p.muted.withValues(alpha: .25),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${step + 1}/$stepCount',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: p.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );

  /// Bottom buttons; they change with the step.
  Widget _actions() {
    final Widget content;
    if (step == 0) {
      content = _GradientButton(
          label: l.setUp,
          icon: Icons.arrow_forward_rounded,
          onPressed: () => goTo(1));
    } else if (step == wifiStep) {
      content = Row(
        children: [
          Expanded(
              child: _GhostButton(
                  label: l.skip, onPressed: () => goTo(summaryStep))),
          const SizedBox(width: 10),
          Expanded(
            child: _GradientButton(
                label: l.allow, onPressed: busy ? null : allowWifiName),
          ),
        ],
      );
    } else if (step == summaryStep) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GradientButton(
              label: l.startMonitoring,
              icon: Icons.play_arrow_rounded,
              onPressed: busy ? null : () => finish(startMonitor: true)),
          const SizedBox(height: 10),
          _GhostButton(
              label: l.notNow, onPressed: () => finish(startMonitor: false)),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
              child:
                  _GhostButton(label: l.back, onPressed: () => goTo(step - 1))),
          const SizedBox(width: 10),
          Expanded(
            child: _GradientButton(
                label: l.continueAction,
                onPressed: step == rhythmStep && !limitValid
                    ? null
                    : () => goTo(step + 1)),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: content,
    );
  }

  Widget _welcomePage() {
    final language = _LanguageScope.maybeOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        const Center(child: _BrandIcon(size: 120)),
        const SizedBox(height: 28),
        Text(l.welcomeTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.5)),
        const SizedBox(height: 10),
        Text(
          l.welcomeText,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 28),
        _Panel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
          child: Column(
            children: [
              _WelcomeFeature(
                icon: Icons.speed_rounded,
                title: l.featureBackgroundTitle,
                text: l.featureBackgroundText,
              ),
              _WelcomeFeature(
                icon: Icons.notifications_active_rounded,
                title: l.featureAlertsTitle,
                text: l.featureAlertsText,
              ),
              _WelcomeFeature(
                icon: Icons.insights_rounded,
                title: l.probableCause,
                text: l.featureCauseText,
              ),
            ],
          ),
        ),
        // The language is picked first so the rest of the setup reads in it.
        if (language != null) ...[
          const SizedBox(height: 16),
          _Panel(
            padding: const EdgeInsets.all(16),
            child: _LanguagePicker(language: language),
          ),
        ],
        const SizedBox(height: 16),
        Text(l.setupTime,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 12)),
      ],
    );
  }

  Widget _wifiPage() => _OnboardingStep(
        icon: Icons.wifi_find_rounded,
        title: l.wifiStepTitle,
        subtitle: l.wifiStepSubtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.wifiNameExplanation,
              style: TextStyle(color: p.textSoft, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: p.info.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: p.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.wifiStepNote,
                        style: const TextStyle(fontSize: 12, height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _summaryPage() => _OnboardingStep(
        icon: Icons.task_alt_rounded,
        title: l.summaryStepTitle,
        subtitle: l.summaryStepSubtitle,
        child: Column(
          children: [
            _SummaryRow(
                icon: Icons.public_rounded,
                label: l.summaryServer,
                value: targetLabel,
                onTap: () => goTo(1)),
            _SummaryRow(
                icon: Icons.notifications_active_rounded,
                label: l.summaryAlerts,
                value: alertLabel,
                onTap: () => goTo(2)),
            _SummaryRow(
                icon: Icons.schedule_rounded,
                label: l.metricInterval,
                value: l.minutes(interval),
                onTap: () => goTo(rhythmStep)),
            _SummaryRow(
                icon: Icons.bolt_rounded,
                label: l.summaryLimit,
                value: l.milliseconds(maxLatency),
                onTap: () => goTo(rhythmStep)),
            _SummaryRow(
                icon: Icons.wifi_rounded,
                label: l.wifiStepTitle,
                value: wifiNameAllowed == true
                    ? l.wifiNameShown
                    : l.wifiNameHidden,
                onTap: () => goTo(wifiStep)),
          ],
        ),
      );
}

/// Scrollable page of one step: branded header and its content in a panel.
class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _IconBadge(icon: icon, filled: true, size: 56),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.4)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.4)),
        const SizedBox(height: 22),
        _Panel(padding: const EdgeInsets.all(16), child: child),
      ],
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature(
      {required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _IconBadge(icon: icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable line of the final summary; jumps back to the step that sets it.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: p.muted, size: 34),
              const SizedBox(width: 12),
              // Label above value: long labels ("Límite de latencia",
              // "Wi-Fi name") never compete with the value for width.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
                    const SizedBox(height: 1),
                    Text(value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
