import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:country_flags/country_flags.dart'
    show Circle, CountryFlag, ImageTheme;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'analytics.dart';
import 'devices.dart';
import 'l10n/app_localizations.dart';

part 'devices_page.dart';
part 'donation.dart';
part 'language.dart';
part 'monitoria_widgets.dart';
part 'onboarding.dart';
part 'palette.dart';
part 'ui_kit.dart';

const bridge = MethodChannel('wifiwarnme/monitor');

class TestServerOption {
  const TestServerOption(this.id, this.name, this.address);

  final String id;
  final String name;
  final String address;
}

const testServers = [
  TestServerOption('cloudflare', 'Cloudflare', '1.1.1.1'),
  TestServerOption('google', 'Google', '8.8.8.8'),
  TestServerOption('quad9', 'Quad9', '9.9.9.9'),
];

class TestLocationOption {
  const TestLocationOption(this.id, this.name);

  final String id;

  /// Target name the native side records (and the flags are keyed by); shown
  /// through [label].
  final String name;

  String label(AppLocalizations l10n) => switch (id) {
        'near' => l10n.locationNear,
        _ => targetDisplayName(name, l10n),
      };

  String detail(AppLocalizations l10n) => switch (id) {
        'sao_paulo' => l10n.locationSaoPauloDetail,
        'united_states' => l10n.locationUnitedStatesDetail,
        'europe' => l10n.locationEuropeDetail,
        _ => l10n.locationNearDetail,
      };
}

const testLocations = [
  TestLocationOption('near', 'Próximo'),
  TestLocationOption('sao_paulo', 'São Paulo'),
  TestLocationOption('united_states', 'Estados Unidos'),
  TestLocationOption('europe', 'Europa'),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const icon = AssetImage('assets/brand/linkzora_icon.png');
  final imageReady = Completer<void>();
  final stream = icon.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, __) {
      if (!imageReady.isCompleted) imageReady.complete();
      stream.removeListener(listener);
    },
    onError: (_, __) {
      if (!imageReady.isCompleted) imageReady.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  await imageReady.future;
  // Read before the first frame so the splash already has the right theme
  // and language.
  final prefs = await SharedPreferences.getInstance();
  runApp(Linkzora(
    darkMode: prefs.getBool(_darkModeKey) ?? true,
    language: prefs.getString(_languageKey) ?? _systemLanguage,
  ));
}

class Linkzora extends StatefulWidget {
  const Linkzora({super.key, this.darkMode, this.language});

  /// Night mode at launch; null reads the saved choice (dark by default).
  final bool? darkMode;

  /// Language choice at launch ('system', 'pt', 'es' or 'en'); null reads
  /// the saved choice (the system language by default).
  final String? language;

  @override
  State<Linkzora> createState() => _LinkzoraState();
}

class _LinkzoraState extends State<Linkzora> with WidgetsBindingObserver {
  late final appearance = _Appearance(widget.darkMode ?? true);
  late final language = _Language(widget.language ?? _systemLanguage,
      WidgetsBinding.instance.platformDispatcher.locales);

  /// The language the native side was last told about.
  String? _nativeLanguage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    language.addListener(_sendLanguage);
    _sendLanguage();
    if (widget.darkMode == null || widget.language == null) _loadChoices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appearance.dispose();
    language.dispose();
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) =>
      language.systemLocales = locales ?? const [];

  Future<void> _loadChoices() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (widget.darkMode == null) {
      appearance.value = prefs.getBool(_darkModeKey) ?? true;
    }
    if (widget.language == null) {
      language.preference = prefs.getString(_languageKey) ?? _systemLanguage;
    }
  }

  /// Notifications, the widget and new history entries follow the app
  /// language; the native side is told whenever the effective one changes.
  Future<void> _sendLanguage() async {
    final code = language.code;
    if (code == _nativeLanguage) return;
    _nativeLanguage = code;
    try {
      await bridge.invokeMethod('setLanguage', {'language': code});
    } on PlatformException {
      // An older native side ignores it; the next start/configure carries it.
    } on MissingPluginException {
      // No native side (e.g. widget tests without a channel mock).
    }
  }

  @override
  Widget build(BuildContext context) => _AppearanceScope(
        appearance: appearance,
        child: _LanguageScope(
          language: language,
          child: ListenableBuilder(
            listenable: Listenable.merge([appearance, language]),
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Linkzora',
              locale: Locale(language.code),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: (appearance.darkMode
                      ? LinkzoraPalette.dark
                      : LinkzoraPalette.light)
                  .theme,
              themeAnimationDuration: const Duration(milliseconds: 450),
              themeAnimationCurve: Curves.easeInOutCubic,
              // Status and navigation bar icons follow the (animated) palette.
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                value: context.palette.overlayStyle,
                child: child!,
              ),
              home: const _StartupGate(),
            ),
          ),
        ),
      );
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool ready = false;

  /// Whether the first-run setup is showing; null while the flag is read.
  bool? onboarding;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingDoneKey) ?? false;
    if (!mounted) return;
    setState(() => onboarding = !done);
    if (done) _prepareFirstReading();
  }

  /// The onboarding already saved its choices; take the first reading now.
  void _finishOnboarding() {
    setState(() => onboarding = false);
    _prepareFirstReading();
  }

  Future<void> _prepareFirstReading() async {
    final startedAt = DateTime.now();
    final systemLocales = WidgetsBinding.instance.platformDispatcher.locales;
    try {
      final prefs = await SharedPreferences.getInstance();
      // From the saved choice: the app may not have applied it yet.
      final languageCode =
          resolveLanguage(prefs.getString(_languageKey), systemLocales);
      final initial =
          Map<String, dynamic>.from(await bridge.invokeMethod('status'));
      final previousReading = (initial['lastCheckedAt'] as num?)?.toInt() ?? 0;
      final arguments = {
        'interval': prefs.getInt('interval') ?? 2,
        'maxLatency': prefs.getInt('maxLatency') ?? 300,
        'serverId': prefs.getString('serverId') ?? 'cloudflare',
        'locationId': prefs.getString('locationId') ?? 'near',
        'notificationMode': prefs.getString('notificationMode') ?? 'changes',
        'language': languageCode,
      };
      if (initial['checking'] != true) {
        await bridge.invokeMethod(
            initial['enabled'] == true ? 'configure' : 'probe', arguments);
      }

      final timeout = DateTime.now().add(const Duration(seconds: 35));
      while (DateTime.now().isBefore(timeout)) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final current =
            Map<String, dynamic>.from(await bridge.invokeMethod('status'));
        final checkedAt = (current['lastCheckedAt'] as num?)?.toInt() ?? 0;
        if (checkedAt > previousReading) break;
      }
    } on PlatformException {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < const Duration(milliseconds: 1400)) {
      await Future<void>.delayed(const Duration(milliseconds: 1400) - elapsed);
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: onboarding == true
          ? _Onboarding(
              key: const ValueKey('onboarding'), onFinished: _finishOnboarding)
          : ready
              ? const Home(key: ValueKey('home'))
              : Scaffold(
                  key: const ValueKey('splash'),
                  backgroundColor: p.bg,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Image(
                          image: AssetImage('assets/brand/linkzora_icon.png'),
                          width: 168,
                          height: 168,
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: p.spinner,
                            backgroundColor: p.spinnerTrack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool enabled = false;
  int interval = 2;
  int maxLatency = 300;
  int selectedTab = 0;
  int latency = -1;
  int jitter = -1;
  int failureRate = 100;
  int successfulSamples = 0;
  int totalSamples = 5;
  String connectionState = 'checking';
  String transportType = 'none';

  /// As the native side sends it; shown through [localizeNativeText].
  String networkName = '';
  String serverId = 'cloudflare';
  String locationId = 'near';
  String notificationMode = 'changes';
  String? analyticsTarget;
  int chartRangeHours = 1;
  int nextCheckAt = 0;
  int lastCheckedAt = 0;
  int signalLevel = -1;
  int wifiRssi = 0;
  int linkSpeed = 0;
  bool checking = false;
  List<Measurement> measurements = [];
  List<String> events = [];

  /// [events] grouped by day, refreshed only when the history changes.
  List<EventDay> eventDays = [];

  /// [EventDay.key] of the day shown in Eventos; null shows every day.
  String? eventDayKey;

  /// lastCheckedAt of the history we hold; the native side only resends the
  /// history when this is out of date.
  int? historyCheckedAt;
  Timer? refresh;

  /// Whether the one-time "pague um cafezinho" card shows on Conexão.
  bool showDonationNudge = false;

  LinkzoraPalette get p => context.palette;
  AppLocalizations get l => context.l10n;

  /// Fades and slides the page in whenever the tab changes.
  late final tabTransition = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  int tabDirection = 1;

  Color get stateColor {
    if (!enabled) return p.paused;
    return switch (connectionState) {
      'online' => p.accent,
      'slow' => p.slow,
      'offline' => p.offline,
      _ => p.info,
    };
  }

  IconData get networkIcon => switch (transportType) {
        'wifi' => Icons.wifi_rounded,
        'cellular' => Icons.signal_cellular_alt_rounded,
        'ethernet' => Icons.settings_ethernet_rounded,
        _ => Icons.portable_wifi_off_rounded,
      };

  String get latencyLabel => l.milliseconds(latency < 0 ? '—' : latency);

  String get nextCheckLabel {
    if (!enabled) return l.monitoringPaused;
    if (checking) return l.checkingNow;
    if (nextCheckAt <= 0) return l.preparingCheck;
    final remaining = DateTime.fromMillisecondsSinceEpoch(nextCheckAt)
        .difference(DateTime.now());
    if (remaining.inSeconds <= 0) return l.checkingNow;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return l.nextCheckIn(
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}');
  }

  List<Measurement> get recentMeasurements {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return measurements
        .where((sample) => sample.timestamp.isAfter(cutoff))
        .toList();
  }

  String get activeTargetName {
    if (locationId != 'near') {
      return testLocations
          .firstWhere((location) => location.id == locationId,
              orElse: () => testLocations.first)
          .name;
    }
    return testServers
        .firstWhere((server) => server.id == serverId,
            orElse: () => testServers.first)
        .name;
  }

  String get notificationModeLabel => _alertMode(notificationMode).title(l);

  Map<String, Object> get monitorArguments => {
        'interval': interval,
        'maxLatency': maxLatency,
        'serverId': serverId,
        'locationId': locationId,
        'notificationMode': notificationMode,
        'language': l.localeName,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    startPolling();
  }

  /// The status is polled every second only while the app is visible; the
  /// native service keeps measuring in the background on its own.
  void startPolling() {
    refresh?.cancel();
    refresh = Timer.periodic(const Duration(seconds: 1), (_) => sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sync();
      startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      refresh?.cancel();
      refresh = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refresh?.cancel();
    tabTransition.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    interval = prefs.getInt('interval') ?? 2;
    maxLatency = prefs.getInt('maxLatency') ?? 300;
    serverId = prefs.getString('serverId') ?? 'cloudflare';
    locationId = prefs.getString('locationId') ?? 'near';
    notificationMode = prefs.getString('notificationMode') ?? 'changes';
    analyticsTarget = prefs.getString('analyticsTarget');
    chartRangeHours = prefs.getInt('chartRangeHours') ?? 1;
    showDonationNudge = await _donationNudgeDue(prefs);
    await sync();
  }

  Future<void> finishDonationNudge() async {
    setState(() => showDonationNudge = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_donationNudgeDoneKey, true);
  }

  Future<void> sync() async {
    try {
      final data = Map<String, dynamic>.from(await bridge
          .invokeMethod('status', {'knownCheckedAt': historyCheckedAt}));
      if (!mounted) return;
      setState(() {
        enabled = data['enabled'] == true;
        checking = data['checking'] == true;
        connectionState = data['state']?.toString() ?? 'checking';
        transportType = data['transportType']?.toString() ?? 'none';
        networkName = data['networkName']?.toString() ?? '';
        latency = (data['latency'] as num?)?.toInt() ?? -1;
        jitter = (data['jitter'] as num?)?.toInt() ?? -1;
        failureRate = (data['failureRate'] as num?)?.toInt() ?? 100;
        successfulSamples = (data['successfulSamples'] as num?)?.toInt() ?? 0;
        totalSamples = (data['totalSamples'] as num?)?.toInt() ?? 5;
        if (enabled) {
          serverId = data['serverId']?.toString() ?? serverId;
          locationId = data['locationId']?.toString() ?? locationId;
          notificationMode =
              data['notificationMode']?.toString() ?? notificationMode;
        }
        nextCheckAt = (data['nextCheckAt'] as num?)?.toInt() ?? 0;
        lastCheckedAt = (data['lastCheckedAt'] as num?)?.toInt() ?? 0;
        signalLevel = (data['signalLevel'] as num?)?.toInt() ?? -1;
        wifiRssi = (data['wifiRssi'] as num?)?.toInt() ?? 0;
        linkSpeed = (data['linkSpeed'] as num?)?.toInt() ?? 0;
        if (data.containsKey('measurements')) {
          measurements = (data['measurements'] as List?)
                  ?.map((item) => Measurement.fromMap(
                      Map<dynamic, dynamic>.from(item as Map)))
                  .toList() ??
              [];
          events = (data['events'] as List?)
                  ?.map((event) => event.toString())
                  .toList() ??
              [];
          eventDays = groupEventsByDay(events);
          historyCheckedAt = lastCheckedAt;
        }
      });
      final launchTab = (data['launchTab'] as num?)?.toInt();
      if (launchTab != null && launchTab >= 0 && launchTab <= 3) {
        selectTab(launchTab);
      }
    } on PlatformException {
      if (mounted) setState(() => connectionState = 'offline');
    }
  }

  void selectTab(int index) {
    if (index == selectedTab) return;
    setState(() {
      tabDirection = index > selectedTab ? 1 : -1;
      selectedTab = index;
    });
    tabTransition.forward(from: 0);
  }

  /// Short state of the top bar pill. Conexão already shows the latency in
  /// its ring, so there the pill names the state instead.
  String get liveLabel {
    if (!enabled) return l.statusPaused;
    if (checking || connectionState == 'checking') return l.statusMeasuring;
    if (selectedTab != 0 && latency >= 0) return l.milliseconds(latency);
    return switch (connectionState) {
      'online' => l.stateStable,
      'slow' => l.stateUnstable,
      _ => l.stateNoResponse,
    };
  }

  /// Calls the native monitor and reports failures in the app's toast.
  Future<bool> invokeMonitor(String method, [Object? arguments]) async {
    try {
      await bridge.invokeMethod(method, arguments);
      return true;
    } on PlatformException catch (error) {
      if (mounted) {
        _showToast(context, error.message ?? l.monitorUnreachable, error: true);
      }
      return false;
    }
  }

  Future<void> toggle(bool value) async {
    if (await invokeMonitor(value ? 'start' : 'stop', monitorArguments)) {
      await sync();
    }
  }

  Future<void> checkNow() async {
    if (!enabled || checking) return;
    setState(() => checking = true);
    await invokeMonitor('checkNow');
  }

  Future<void> chooseNotificationMode() async {
    final selected = await _showGlassSheet<String>(
        context, (_) => _AlertModeSheet(current: notificationMode));
    if (selected == null || selected == notificationMode || !mounted) return;

    setState(() => notificationMode = selected);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notificationMode', notificationMode);
    if (enabled) await invokeMonitor('configure', monitorArguments);
  }

  Future<void> identifyWifi() async {
    final allow = await _showGlassSheet<bool>(
      context,
      (sheetContext) => _GlassSheet(
        icon: Icons.wifi_find_rounded,
        title: l.wifiNameSheetTitle,
        subtitle: l.wifiNameSheetSubtitle,
        children: [
          _Panel(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.wifiNameExplanation,
              style: TextStyle(color: p.textSoft, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                    label: l.notNow,
                    onPressed: () => Navigator.pop(sheetContext, false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradientButton(
                    label: l.continueAction,
                    onPressed: () => Navigator.pop(sheetContext, true)),
              ),
            ],
          ),
        ],
      ),
    );
    if (allow != true || !mounted) return;
    try {
      final granted =
          await bridge.invokeMethod<bool>('requestWifiName') ?? false;
      if (granted && enabled) {
        await invokeMonitor('configure', monitorArguments);
        await sync();
      }
      if (!mounted) return;
      _showToast(context, granted ? l.wifiNameEnabled : l.wifiNameDenied,
          error: !granted);
    } on PlatformException catch (error) {
      if (mounted) {
        _showToast(context, error.message ?? l.identifyNetworkFailed,
            error: true);
      }
    }
  }

  Future<void> settings() async {
    final result = await _showGlassSheet<_SettingsValues>(
      context,
      (_) => _SettingsSheet(
        initial: _SettingsValues(
          locationId: locationId,
          serverId: serverId,
          interval: interval,
          maxLatency: maxLatency,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final targetChanged =
        result.serverId != serverId || result.locationId != locationId;
    setState(() {
      interval = result.interval;
      maxLatency = result.maxLatency;
      serverId = result.serverId;
      locationId = result.locationId;
      // Monitoria follows the server that is now in use.
      if (targetChanged) analyticsTarget = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interval', interval);
    await prefs.setInt('maxLatency', maxLatency);
    await prefs.setString('serverId', serverId);
    await prefs.setString('locationId', locationId);
    if (targetChanged) await prefs.remove('analyticsTarget');
    if (enabled && await invokeMonitor('configure', monitorArguments)) {
      if (mounted) _showToast(context, l.settingsApplied);
    }
  }

  List<_TabItem> get tabs => [
        (
          label: l.tabConnection,
          icon: Icons.speed_rounded,
          selectedIcon: Icons.speed_rounded
        ),
        (
          label: l.tabMonitoring,
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart_rounded
        ),
        (
          label: l.tabEvents,
          icon: Icons.history_rounded,
          selectedIcon: Icons.history_rounded
        ),
        (
          label: l.tabNetwork,
          icon: Icons.lan_outlined,
          selectedIcon: Icons.lan_rounded
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final curve =
        CurvedAnimation(parent: tabTransition, curve: Curves.easeOutCubic);
    return Scaffold(
      // Pages scroll under the floating tab bar.
      extendBody: true,
      // Explicit background behind the status bar and the top bar: on some
      // Android GPUs (seen on a Galaxy Z Fold, Impeller/Vulkan) areas left to
      // the Scaffold showed static while the tab transition ran.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: ColoredBox(color: p.bg, child: topBar()),
      ),
      // No opacity on the whole page: a fading page is drawn into an offscreen
      // layer, and that is where the static came from. The tab change is a
      // short slide of an opaque page over an opaque background instead.
      body: ColoredBox(
        color: p.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: Offset(.04 * tabDirection, 0), end: Offset.zero)
                      .animate(curve),
                  child: ColoredBox(
                    color: p.bg,
                    // Builders give each page the body context, whose padding holds
                    // the floating tab bar (see _tabPagePadding).
                    child: IndexedStack(
                      index: selectedTab,
                      children: [
                        Builder(builder: monitorPage),
                        Builder(builder: analyticsPage),
                        Builder(builder: historyPage),
                        Builder(
                          builder: (_) => _DevicesPage(
                            measurements: measurements,
                            // Scans only start once the tab is first opened.
                            visible: selectedTab == 3,
                            monitoring: enabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Soft edge under the top bar, so content scrolling up fades out
            // instead of being cut mid-line. Painted on top of the sliding page.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 20,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [p.bg, p.bg.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(
        key: const ValueKey('tab-bar'),
        items: tabs,
        selected: selectedTab,
        onSelected: selectTab,
      ),
    );
  }

  // Night mode is switched in Ajustes, leaving the subtitle room to fit.
  Widget topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            const _BrandIcon(size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Linkzora',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4)),
                  // Changes without a fade: fading text is drawn in an
                  // offscreen layer, which showed static on a Galaxy Z Fold.
                  Text(
                    switch (selectedTab) {
                      0 => l.subtitleConnection,
                      1 => l.subtitleMonitoring,
                      2 => l.subtitleEvents,
                      _ => l.subtitleNetwork,
                    },
                    key: ValueKey(selectedTab),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _LiveStatus(
              color: stateColor,
              label: liveLabel,
              pulseKey: lastCheckedAt,
              live: enabled,
            ),
            const SizedBox(width: 8),
            _TopBarButton(
              icon: Icons.tune_rounded,
              tooltip: l.settings,
              onPressed: settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag({
    IconData? icon,
    Widget? leading,
    required String text,
    required Color color,
    VoidCallback? onTap,
    IconData? trailing,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading ?? Icon(icon, size: 16, color: color),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailing, size: 15, color: color),
                ],
              ],
            ),
          ),
        ),
      );

  String get signalValue {
    if (transportType != 'wifi') {
      return switch (transportType) {
        'cellular' => l.transportMobile,
        'ethernet' => l.transportCable,
        _ => '—',
      };
    }
    return switch (signalLevel) {
      0 || 1 => l.signalWeak,
      2 => l.signalFair,
      3 || 4 => l.signalGood,
      _ => '—',
    };
  }

  Widget monitorPage(BuildContext page) => ListView(
        padding: _tabPagePadding(page, horizontal: 24, top: 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: _tag(
                leading: _TargetGlyph(activeTargetName,
                    size: 16, fallbackColor: p.info),
                text: l.serverTag(targetDisplayName(activeTargetName, l)),
                color: p.info,
                onTap: settings,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              width: 272,
              height: 272,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The channel between ring and dial is a faint wash of the
                // state colour, so both read as one even, deliberate inset.
                color: Color.alphaBlend(
                    stateColor.withValues(alpha: p.isDark ? .06 : .1), p.bg),
                border: Border.all(color: stateColor, width: 4),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                            color: stateColor.withValues(alpha: .20),
                            blurRadius: 46,
                            spreadRadius: 4),
                        BoxShadow(
                            color: stateColor.withValues(alpha: .08),
                            blurRadius: 80,
                            spreadRadius: 18),
                      ]
                    : [],
              ),
              child: AnimatedContainer(
                key: const ValueKey('status-dial'),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: p.dial,
                  ),
                  border: Border.all(color: stateColor.withValues(alpha: .18)),
                  boxShadow: [
                    BoxShadow(
                        color: stateColor.withValues(alpha: .12),
                        blurRadius: 16),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stateColor.withValues(alpha: .13),
                      ),
                      child: Icon(networkIcon, color: stateColor, size: 31),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: _AdaptiveSsidLabel(
                        text: latency >= 0
                            ? localizeNativeText(networkName, l)
                            : l.noReading,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      latencyLabel,
                      style: TextStyle(
                          color: stateColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    // One line: shrinks instead of wrapping when jitter grows.
                    // The padding keeps it clear of the ring's curve.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          jitter >= 0
                              ? l.readingDetails(jitter, failureRate,
                                  successfulSamples, totalSamples)
                              : l.awaitingSamples,
                          maxLines: 1,
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: _tag(
              icon: Icons.timer_outlined,
              text: nextCheckLabel,
              color: stateColor,
              onTap: enabled && !checking ? checkNow : null,
              trailing: enabled && !checking ? Icons.refresh_rounded : null,
            ),
          ),
          const SizedBox(height: 20),
          _Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    children: [
                      _IconBadge(
                          icon: Icons.monitor_heart_rounded, color: stateColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.monitoringTitle,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                                enabled
                                    ? l.monitoringActive
                                    : l.monitoringInactive,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      _BrandSwitch(value: enabled, onChanged: toggle),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: p.muted.withValues(alpha: .14)),
                InkWell(
                  onTap: chooseNotificationMode,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
                    child: Row(
                      children: [
                        _IconBadge(
                            icon: Icons.notifications_active_rounded,
                            color: p.muted,
                            size: 34),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.changeAlerts,
                                  style:
                                      TextStyle(color: p.muted, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(notificationModeLabel,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: p.muted, size: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (enabled && transportType == 'wifi' && networkName == 'Wi-Fi') ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: identifyWifi,
                child: _Panel(
                  padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                  borderColor: p.info.withValues(alpha: .3),
                  child: Row(
                    children: [
                      _IconBadge(
                          icon: Icons.wifi_find_rounded,
                          color: p.info,
                          size: 38),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.identifyNetwork,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(l.identifyNetworkHint,
                                style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: metricCard(Icons.schedule_rounded, l.metricInterval,
                      l.minutes(interval))),
              const SizedBox(width: 10),
              Expanded(
                  child: metricCard(Icons.bolt_rounded, l.metricLimit,
                      l.milliseconds(maxLatency))),
              const SizedBox(width: 10),
              Expanded(
                  child: metricCard(
                      transportType == 'wifi'
                          ? Icons.network_wifi_rounded
                          : Icons.cell_tower_rounded,
                      transportType == 'wifi' && wifiRssi != 0
                          ? '$wifiRssi dBm'
                          : l.metricSignal,
                      signalValue)),
            ],
          ),
          if (showDonationNudge) ...[
            const SizedBox(height: 12),
            _DonationCard(onDone: finishDonationNudge),
          ],
        ],
      );

  Widget metricCard(IconData icon, String label, String value) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: settings,
          child: _Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: icon, color: p.muted, size: 32),
                const SizedBox(height: 14),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      );

  Widget analyticsPage(BuildContext page) {
    final allSamples = recentMeasurements;
    final byTarget = <String, List<Measurement>>{};
    for (final sample in allSamples) {
      byTarget.putIfAbsent(targetOf(sample), () => []).add(sample);
    }
    final active = activeTargetName;
    final targets = byTarget.keys.toList()
      ..sort((a, b) {
        if (a == active) return -1;
        if (b == active) return 1;
        return a.compareTo(b);
      });
    final selectedTarget =
        analyticsTarget != null && targets.contains(analyticsTarget)
            ? analyticsTarget
            : targets.contains(active)
                ? active
                : allSamples.isEmpty
                    ? null
                    : targetOf(allSamples.last);
    // Every card below reflects only the selected server.
    final samples = byTarget[selectedTarget] ?? const <Measurement>[];
    final periods =
        failurePeriods(samples, live: enabled && selectedTarget == active);
    final degradedTime = periods.fold<Duration>(
        Duration.zero, (total, period) => total + period.duration);
    final latest = samples.isEmpty ? null : samples.last;
    final diagnosisColor =
        latest == null ? p.accent : p.stateColor(latest.state);
    final range = Duration(hours: chartRangeHours);
    final rangeCutoff = DateTime.now().subtract(range);
    final chartSamples = samples
        .where((sample) => sample.timestamp.isAfter(rangeCutoff))
        .toList();
    final stats = LatencyStats.of(chartSamples);
    String ms(int? value) => value == null ? '—' : l.milliseconds(value);

    return ListView(
      padding: _tabPagePadding(page, horizontal: 20, top: 18),
      children: [
        if (selectedTarget == null)
          _Panel(
            child: Row(
              children: [
                _IconBadge(icon: Icons.hourglass_top_rounded, color: p.info),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(l.awaitingFirstMeasurement,
                      style: TextStyle(color: p.muted)),
                ),
              ],
            ),
          )
        else
          _ServerDropdown(
            selected: selectedTarget,
            options: targets
                .map((target) => _ServerOption(
                      target,
                      byTarget[target]!.length,
                      availability(byTarget[target]!),
                      target == active,
                    ))
                .toList(),
            onSelected: (target) async {
              setState(() => analyticsTarget = target);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('analyticsTarget', target);
            },
          ),
        const SizedBox(height: 14),
        _Panel(
          padding: const EdgeInsets.all(22),
          raised: true,
          borderColor: p.accent.withValues(alpha: .18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: p.accent, size: 22),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(l.serverSummary,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Text(l.hoursShort(24),
                      style: TextStyle(
                          color: p.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                      child: _SummaryMetric(
                          value: samples.isEmpty
                              ? '—'
                              : '${availability(samples)}%',
                          label: l.stateStable)),
                  Expanded(
                      child: _SummaryMetric(
                          value: '${periods.length}', label: l.oscillations)),
                  Expanded(
                      child: _SummaryMetric(
                          value: bestHourLabel(samples, l), label: l.bestHour)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.latencyPulse,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              latest == null || latest.latency < 0
                                  ? l.tapForDetails
                                  : l.latencyNow(latest.latency),
                              style: TextStyle(color: p.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    _RangeSelector(
                      value: chartRangeHours,
                      onChanged: (hours) async {
                        setState(() => chartRangeHours = hours);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('chartRangeHours', hours);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _LatencyChart(
                samples: chartSamples,
                limit: maxLatency,
                range: range,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _ChartLegend(color: p.accent, label: l.stateStable),
                    _ChartLegend(color: p.slow, label: l.stateUnstable),
                    _ChartLegend(color: p.offline, label: l.stateNoResponse),
                    _ChartLegend(color: p.info, label: l.jitterBand),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: p.bg.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _ChartStat(label: l.statMinimum, value: ms(stats.minimum)),
                    _ChartStat(
                        label: l.statMedian,
                        value: ms(stats.median),
                        color: p.accent),
                    _ChartStat(label: l.statPeak, value: ms(stats.p95)),
                    _ChartStat(
                        label: l.statJitter, value: ms(stats.averageJitter)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          borderColor: diagnosisColor.withValues(alpha: .22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                  icon: Icons.manage_search_rounded,
                  color: diagnosisColor,
                  size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.probableCause,
                        style: TextStyle(color: p.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                        latest == null || latest.localizedDiagnosis(l).isEmpty
                            ? l.awaitingMeasurements
                            : latest.localizedDiagnosis(l),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(_diagnosisEvidence(latest),
                        style: TextStyle(
                            color: p.muted, fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l.failurePeriods,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Text(formatDuration(degradedTime, l),
                      style: TextStyle(
                          color: p.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              if (periods.isEmpty)
                const _EmptyFailures()
              else ...[
                ...periods.take(3).map((period) => _FailureRow(
                      color: p.stateColor(period.worstState),
                      time:
                          '${formatClock(period.start)}–${formatClock(period.end)}',
                      duration: formatDuration(period.duration, l),
                      target: targetDisplayName(period.targetName, l),
                      problem: period.localizedDiagnosis(l).isEmpty
                          ? l.unknownCause
                          : period.localizedDiagnosis(l),
                      label: period.worstState == 'offline'
                          ? l.noConnection
                          : l.unstableConnection,
                    )),
                if (periods.length > 3)
                  Text(l.olderPeriods(periods.length - 3),
                      style: TextStyle(
                          color: p.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _diagnosisEvidence(Measurement? sample) {
    if (sample == null) return l.evidenceNoSample;
    final latencyText =
        sample.latency < 0 ? l.noResponseLower : l.milliseconds(sample.latency);
    final jitterText = sample.jitter < 0 ? '—' : l.milliseconds(sample.jitter);
    final parts = <String>[
      if (sample.transportType == 'wifi' && sample.signalLevel >= 0)
        l.evidenceWifiSignal(switch (sample.signalLevel) {
          0 || 1 => 'weak',
          2 => 'fair',
          _ => 'good',
        }),
      latencyText,
      l.evidenceJitter(jitterText),
      l.evidenceLoss(sample.failureRate),
    ];
    final text = parts.join(' · ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  Widget historyPage(BuildContext page) {
    final padding = _tabPagePadding(page, horizontal: 20, top: 20);
    if (eventDays.isEmpty) {
      return Padding(
        padding: padding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(icon: Icons.timeline_rounded, color: p.info, size: 64),
              const SizedBox(height: 18),
              Text(l.noEventsTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(l.noEventsText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted)),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final selected =
        eventDays.where((day) => day.key == eventDayKey).firstOrNull;
    final days = selected == null ? eventDays : [selected];
    final summary = selected?.summary ??
        EventSummary.merge(eventDays.map((day) => day.summary));
    // One row per day header and per event; tiles are built lazily, so long
    // histories (up to 30 days) stay cheap.
    final rows = <({EventDay day, int index})>[
      for (final day in days) ...[
        (day: day, index: -1),
        for (var index = 0; index < day.events.length; index++)
          (day: day, index: index),
      ],
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventDayFilter(
                  days: eventDays,
                  selected: selected?.key,
                  now: now,
                  onSelected: (key) => setState(() => eventDayKey = key),
                ),
                const SizedBox(height: 12),
                _EventSummaryPanel(
                  title: selected == null ? l.allDays : selected.label(now, l),
                  summary: summary,
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, row) {
              final (:day, :index) = rows[row];
              if (index < 0) {
                final count = day.events.length;
                return Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
                  child: _SectionLabel(
                    day.label(now, l),
                    trailing: Text(l.eventCount(count),
                        style: TextStyle(
                            color: p.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                );
              }
              final event = day.events[index];
              return _EventTile(
                  event: event,
                  time: event.clock,
                  last: index == day.events.length - 1);
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal pill row: "Todos" plus one chip per day with its event count.
class _EventDayFilter extends StatelessWidget {
  const _EventDayFilter({
    required this.days,
    required this.selected,
    required this.now,
    required this.onSelected,
  });

  final List<EventDay> days;

  /// [EventDay.key] of the selected day; null is "Todos".
  final String? selected;
  final DateTime now;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = days.fold<int>(0, (sum, day) => sum + day.events.length);
    Widget chip(String? key, String label, int count) => _PillOption(
          key: ValueKey('event-day-${key ?? 'all'}'),
          label: '$label · $count',
          selected: key == selected,
          onTap: () => onSelected(key),
          radius: 11,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        );
    // At most ~30 days of history, so a plain row is cheap.
    return _PillTrack(
      radius: 15,
      padding: 3,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(null, l.filterAll, total),
            for (final day in days)
              chip(day.key, day.label(now, l), day.events.length),
          ],
        ),
      ),
    );
  }
}

/// Compact counts of the selected range: drops, instabilities and recoveries.
class _EventSummaryPanel extends StatelessWidget {
  const _EventSummaryPanel({required this.title, required this.summary});

  final String title;
  final EventSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final total = summary.total;
    return _Panel(
      raised: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderColor: p.accent.withValues(alpha: .18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: p.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text(l.changeCount(total),
                  style: TextStyle(
                      color: p.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _SummaryMetric(
                      value: '${summary.drops}',
                      label: l.summaryDrops,
                      color: p.offline)),
              Expanded(
                  child: _SummaryMetric(
                      value: '${summary.instabilities}',
                      label: l.summaryInstabilities,
                      color: p.slow)),
              Expanded(
                  child: _SummaryMetric(
                      value: '${summary.recoveries}',
                      label: l.summaryRecoveries)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(
      {required this.event, required this.time, required this.last});

  final ConnectionEvent event;
  final String time;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final color = p.stateColor(event.state);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text(time,
                    style: TextStyle(
                        color: p.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 15),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: .5), blurRadius: 8)
                    ],
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: p.muted.withValues(alpha: .15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Panel(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                borderColor: color.withValues(alpha: .2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizeNativeText(event.title, l),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800)),
                    if (event.details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: event.details
                            .map((detail) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.bg.withValues(alpha: .5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(localizeNativeText(detail, l),
                                      style: TextStyle(
                                          color: p.textSoft,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsValues {
  const _SettingsValues({
    required this.locationId,
    required this.serverId,
    required this.interval,
    required this.maxLatency,
  });

  final String locationId;
  final String serverId;
  final int interval;
  final int maxLatency;
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial});

  final _SettingsValues initial;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late var locationId = widget.initial.locationId;
  late var serverId = widget.initial.serverId;
  late var interval = widget.initial.interval;
  late var maxLatency = widget.initial.maxLatency;
  bool limitValid = true;

  @override
  Widget build(BuildContext context) {
    final appearance = _AppearanceScope.maybeOf(context);
    final language = _LanguageScope.maybeOf(context);
    final l = context.l10n;
    return _GlassSheet(
      icon: Icons.tune_rounded,
      title: l.settings,
      subtitle: l.settingsSubtitle,
      children: [
        // Theme and language apply at once; they are not monitor settings.
        if (appearance != null) ...[
          _SwitchRow(
            icon: Icons.dark_mode_rounded,
            title: l.nightMode,
            subtitle: l.nightModeSubtitle,
            value: appearance.darkMode,
            onChanged: appearance.setDarkMode,
          ),
          const SizedBox(height: 20),
        ],
        if (language != null) ...[
          _LanguagePicker(language: language),
          const SizedBox(height: 20),
        ],
        _TargetPicker(
          locationId: locationId,
          serverId: serverId,
          onLocationChanged: (id) => setState(() => locationId = id),
          onServerChanged: (id) => setState(() => serverId = id),
        ),
        const SizedBox(height: 20),
        _IntervalPicker(
          value: interval,
          onChanged: (value) => setState(() => interval = value),
        ),
        const SizedBox(height: 20),
        _LatencyLimitPicker(
          value: maxLatency,
          onChanged: (value) => setState(() => maxLatency = value),
          onValidityChanged: (valid) => setState(() => limitValid = valid),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          label: l.saveSettings,
          icon: Icons.check_rounded,
          onPressed: !limitValid
              ? null
              : () => Navigator.pop(
                    context,
                    _SettingsValues(
                      locationId: locationId,
                      serverId: serverId,
                      interval: interval,
                      maxLatency: maxLatency,
                    ),
                  ),
        ),
        const SizedBox(height: 24),
        const _DonationCard(),
      ],
    );
  }
}

// Selectors shared by the settings sheet and the first-run onboarding.

/// Test location cards plus the anycast server choice for "Próximo".
class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.locationId,
    required this.serverId,
    required this.onLocationChanged,
    required this.onServerChanged,
  });

  final String locationId;
  final String serverId;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onServerChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final location = testLocations.firstWhere(
        (option) => option.id == locationId,
        orElse: () => testLocations.first);
    final server = testServers.firstWhere((option) => option.id == serverId,
        orElse: () => testServers.first);
    // "Próximo" picks the nearest anycast server; regions show their flag.
    Widget locationCard(TestLocationOption option) => _ChoiceCard(
          compact: true,
          icon: Icons.near_me_rounded,
          leading:
              option.id == 'near' ? null : _TargetMark(option.name, size: 34),
          title: option.label(l),
          selected: option.id == locationId,
          onTap: () => onLocationChanged(option.id),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l.testLocation),
        for (var row = 0; row < testLocations.length; row += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: locationCard(testLocations[row])),
                const SizedBox(width: 8),
                Expanded(
                    child: row + 1 < testLocations.length
                        ? locationCard(testLocations[row + 1])
                        : const SizedBox()),
              ],
            ),
          ),
        Text(location.detail(l),
            style: TextStyle(color: p.muted, fontSize: 12)),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: locationId != 'near'
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(l.nearbyServer),
                      _Segmented<String>(
                        values: testServers.map((option) => option.id).toList(),
                        value: serverId,
                        label: (id) => testServers
                            .firstWhere((option) => option.id == id)
                            .name,
                        icon: (id) => _targetGlyph(testServers
                            .firstWhere((option) => option.id == id)
                            .name),
                        onChanged: onServerChanged,
                      ),
                      const SizedBox(height: 7),
                      Text(l.serverAddress(server.address),
                          style: TextStyle(color: p.muted, fontSize: 12)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(context.l10n.checkEvery),
          _Segmented<int>(
            values: const [1, 2, 5, 10, 15],
            value: value,
            label: context.l10n.minutes,
            onChanged: onChanged,
          ),
        ],
      );
}

/// Latency limit presets plus a typed value (30–2000 ms); above the limit a
/// reading counts as unstable. Only valid values reach [onChanged].
class _LatencyLimitPicker extends StatefulWidget {
  const _LatencyLimitPicker({
    required this.value,
    required this.onChanged,
    this.onValidityChanged,
  });

  static const presets = [30, 60, 80, 100, 200, 300, 400, 500, 750, 1000];
  static const minimum = 30;
  static const maximum = 2000;

  final int value;
  final ValueChanged<int> onChanged;

  /// False while the typed value is invalid, so the caller can hold saving.
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<_LatencyLimitPicker> createState() => _LatencyLimitPickerState();
}

class _LatencyLimitPickerState extends State<_LatencyLimitPicker> {
  static const columns = 4;
  static const gap = 4.0;

  late bool custom = !_LatencyLimitPicker.presets.contains(widget.value);
  late final controller =
      TextEditingController(text: custom ? '${widget.value}' : '');
  final focus = FocusNode();
  String? error;

  @override
  void didUpdateWidget(_LatencyLimitPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Saved choices can arrive after the first build (onboarding).
    if (widget.value != oldWidget.value &&
        widget.value != int.tryParse(controller.text)) {
      custom = !_LatencyLimitPicker.presets.contains(widget.value);
      controller.text = custom ? '${widget.value}' : '';
      error = null;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  void _setError(String? message) {
    if (message == error) return;
    setState(() => error = message);
    widget.onValidityChanged?.call(message == null);
  }

  void choosePreset(int value) {
    focus.unfocus();
    setState(() => custom = false);
    _setError(null);
    widget.onChanged(value);
  }

  void chooseCustom() {
    if (!custom) {
      final text = '${widget.value}';
      setState(() => custom = true);
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      );
    }
    focus.requestFocus();
  }

  void typed(String text) {
    final value = int.tryParse(text);
    final l = context.l10n;
    if (value == null) {
      _setError(l.limitTypeError);
    } else if (value < _LatencyLimitPicker.minimum ||
        value > _LatencyLimitPicker.maximum) {
      _setError(l.limitRangeError(
          _LatencyLimitPicker.minimum, _LatencyLimitPicker.maximum));
    } else {
      _setError(null);
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final fieldColor = error == null ? p.accent : p.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          l.alertAbove,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.slow.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(l.milliseconds(widget.value),
                style: TextStyle(
                    color: p.slow, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
        _PillTrack(
          radius: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final preset in _LatencyLimitPicker.presets)
                    SizedBox(
                      width: width,
                      child: _PillOption(
                        key: ValueKey('limit-$preset'),
                        label: '$preset',
                        selected: !custom && preset == widget.value,
                        onTap: () => choosePreset(preset),
                      ),
                    ),
                  // Fills the rest of the last row.
                  SizedBox(
                    width: width * 2 + gap,
                    child: _PillOption(
                      key: const ValueKey('limit-custom'),
                      label: l.customLimit,
                      icon: Icons.edit_rounded,
                      selected: custom,
                      onTap: chooseCustom,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !custom
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: p.bg.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: fieldColor.withValues(alpha: .55),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: fieldColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('limit-custom-field'),
                                controller: controller,
                                focusNode: focus,
                                onChanged: typed,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                style: TextStyle(
                                    color: p.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: l.limitHintExample,
                                  hintStyle: TextStyle(
                                      color: p.muted.withValues(alpha: .6),
                                      fontWeight: FontWeight.w700),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            Text('ms',
                                style: TextStyle(
                                    color: p.muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error ??
                            l.limitRangeHint(_LatencyLimitPicker.minimum,
                                _LatencyLimitPicker.maximum),
                        style: TextStyle(
                            color: error == null ? p.muted : p.offline,
                            fontSize: 12,
                            fontWeight: error == null
                                ? FontWeight.w500
                                : FontWeight.w700),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          l.limitFootnote,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label, this.color});

  final String value;
  final String label;

  /// Defaults to the accent colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color ?? p.accent,
                fontSize: 19,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            maxLines: 1, style: TextStyle(color: p.muted, fontSize: 11)),
      ],
    );
  }
}

class _EmptyFailures extends StatelessWidget {
  const _EmptyFailures();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: p.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.l10n.noFailures24h,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FailureRow extends StatelessWidget {
  const _FailureRow({
    required this.color,
    required this.time,
    required this.duration,
    required this.label,
    required this.target,
    required this.problem,
  });

  final Color color;
  final String time;
  final String duration;
  final String label;
  final String target;
  final String problem;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 66,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$target · $time',
                    style: TextStyle(color: p.muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(problem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text(duration,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: p.muted, fontSize: 10)),
      ],
    );
  }
}

class _AdaptiveSsidLabel extends StatelessWidget {
  const _AdaptiveSsidLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const minimumFontSize = 12.0;
          const maximumFontSize = 27.0;
          var fontSize = maximumFontSize;
          final textScaler = MediaQuery.textScalerOf(context);

          while (fontSize > minimumFontSize) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              maxLines: 1,
              textDirection: Directionality.of(context),
              textScaler: textScaler,
            )..layout();

            if (painter.width <= constraints.maxWidth &&
                painter.height <= constraints.maxHeight) {
              break;
            }
            fontSize -= .5;
          }

          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.palette.text,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        },
      );
}
