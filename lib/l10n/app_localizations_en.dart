// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabConnection => 'Connection';

  @override
  String get tabMonitoring => 'Monitoring';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabNetwork => 'Network';

  @override
  String get subtitleConnection => 'Connection now';

  @override
  String get subtitleMonitoring => 'Last 24 hours';

  @override
  String get subtitleEvents => 'History';

  @override
  String get subtitleNetwork => 'Devices and causes';

  @override
  String get nightModeTurnOff => 'Turn off night mode';

  @override
  String get nightModeTurnOn => 'Turn on night mode';

  @override
  String get settings => 'Settings';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusMeasuring => 'Measuring';

  @override
  String get stateStable => 'Stable';

  @override
  String get stateUnstable => 'Unstable';

  @override
  String get stateNoResponse => 'No response';

  @override
  String get noResponseLower => 'no response';

  @override
  String milliseconds(Object value) {
    return '$value ms';
  }

  @override
  String minutes(Object value) {
    return '$value min';
  }

  @override
  String hoursShort(Object value) {
    return '$value h';
  }

  @override
  String get monitoringPaused => 'Monitoring paused';

  @override
  String get checkingNow => 'Checking now';

  @override
  String get preparingCheck => 'Preparing check';

  @override
  String nextCheckIn(Object time) {
    return 'Next in $time';
  }

  @override
  String get monitorUnreachable => 'Couldn\'t reach the monitor';

  @override
  String get wifiNameSheetTitle => 'Show the Wi-Fi name';

  @override
  String get wifiNameSheetSubtitle => 'Precise location permission';

  @override
  String get wifiNameExplanation =>
      'Android only reveals the network name to apps with precise location. Linkzora uses this permission solely to identify the Wi-Fi and read the signal strength; no location is stored or sent.';

  @override
  String get notNow => 'Not now';

  @override
  String get continueAction => 'Continue';

  @override
  String get wifiNameEnabled => 'Network name enabled.';

  @override
  String get wifiNameDenied =>
      'Without the permission, the network shows only as Wi-Fi.';

  @override
  String get identifyNetworkFailed => 'Couldn\'t identify the network';

  @override
  String get settingsApplied => 'Settings applied to the monitor.';

  @override
  String serverTag(Object name) {
    return 'Server · $name';
  }

  @override
  String get noReading => 'No reading';

  @override
  String readingDetails(Object jitter, Object loss, Object ok, Object total) {
    return 'Jitter $jitter ms · Loss $loss% · $ok/$total';
  }

  @override
  String get awaitingSamples => 'Waiting for samples';

  @override
  String get monitoringTitle => 'Monitoring';

  @override
  String get monitoringActive => 'Active in the background';

  @override
  String get monitoringInactive => 'Turn on to measure your connection';

  @override
  String get changeAlerts => 'Change alerts';

  @override
  String get identifyNetwork => 'Identify this network';

  @override
  String get identifyNetworkHint => 'Show the Wi-Fi name and signal';

  @override
  String get metricInterval => 'Interval';

  @override
  String get metricLimit => 'Limit';

  @override
  String get metricSignal => 'Signal';

  @override
  String get transportMobile => 'Mobile';

  @override
  String get transportCable => 'Cable';

  @override
  String get signalWeak => 'Weak';

  @override
  String get signalFair => 'Fair';

  @override
  String get signalGood => 'Good';

  @override
  String signalQuality(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'weak',
        'fair': 'fair',
        'other': 'good',
      },
    );
    return '$_temp0';
  }

  @override
  String get awaitingFirstMeasurement => 'Waiting for the first measurement.';

  @override
  String get serverSummary => 'Server summary';

  @override
  String get oscillations => 'Fluctuations';

  @override
  String get bestHour => 'Best time';

  @override
  String get collectingData => 'Collecting data';

  @override
  String hourRange(Object from, Object to) {
    return '${from}h–${to}h';
  }

  @override
  String get latencyPulse => 'Latency pulse';

  @override
  String get tapForDetails => 'Tap for details';

  @override
  String latencyNow(Object value) {
    return 'Now $value ms';
  }

  @override
  String get jitterBand => 'Jitter band';

  @override
  String get statMinimum => 'Minimum';

  @override
  String get statMedian => 'Median';

  @override
  String get statPeak => 'Peak (p95)';

  @override
  String get statJitter => 'Average jitter';

  @override
  String get probableCause => 'Probable cause';

  @override
  String get awaitingMeasurements => 'Waiting for measurements';

  @override
  String get evidenceNoSample => 'Take a measurement to analyse this server.';

  @override
  String evidenceWifiSignal(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'weak Wi-Fi signal',
        'fair': 'fair Wi-Fi signal',
        'other': 'good Wi-Fi signal',
      },
    );
    return '$_temp0';
  }

  @override
  String evidenceJitter(Object value) {
    return 'jitter $value';
  }

  @override
  String evidenceLoss(Object value) {
    return 'loss $value%';
  }

  @override
  String get failurePeriods => 'Periods with failures';

  @override
  String get unknownCause => 'Cause not identified';

  @override
  String get noConnection => 'No connection';

  @override
  String get unstableConnection => 'Unstable connection';

  @override
  String olderPeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count earlier periods',
      one: '+ 1 earlier period',
    );
    return '$_temp0';
  }

  @override
  String get noFailures24h => 'No failures recorded in the last 24 hours.';

  @override
  String get chartNow => 'now';

  @override
  String chartLimit(Object value) {
    return 'limit $value ms';
  }

  @override
  String chartJitter(Object value) {
    return 'jitter ±$value ms';
  }

  @override
  String measurementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count measurements · 24 h',
      one: '1 measurement · 24 h',
    );
    return '$_temp0';
  }

  @override
  String get analyzedServer => 'Analysed server';

  @override
  String get inUse => 'IN USE';

  @override
  String get unknownTarget => 'Unidentified destination';

  @override
  String get alertNone => 'No alerts';

  @override
  String get alertNoneDescription =>
      'Only the monitor\'s ongoing notification.';

  @override
  String get alertOnce => 'Once per session';

  @override
  String get alertOnceDescription =>
      'Alerts on the first change after turning on.';

  @override
  String get alertChanges => 'On every change';

  @override
  String get alertChangesDescription =>
      'Alerts whenever the connection changes.';

  @override
  String get alertSheetSubtitle => 'When Linkzora should get your attention';

  @override
  String get noEventsTitle => 'No events yet';

  @override
  String get noEventsText => 'Connection changes will show up here.';

  @override
  String get allDays => 'All days';

  @override
  String get filterAll => 'All';

  @override
  String eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String changeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String get summaryDrops => 'Drops';

  @override
  String get summaryInstabilities => 'Instabilities';

  @override
  String get summaryRecoveries => 'Stabilised';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get noDate => 'No date';

  @override
  String dayMonth(Object day, Object month) {
    return '$month/$day';
  }

  @override
  String get settingsSubtitle => 'Measurement rhythm and test destination';

  @override
  String get nightMode => 'Night mode';

  @override
  String get nightModeSubtitle => 'Dark theme across the app';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageSystemHint => 'Follows the device language';

  @override
  String get testLocation => 'Test location';

  @override
  String get nearbyServer => 'Nearby server';

  @override
  String serverAddress(Object address) {
    return 'Address $address · anycast';
  }

  @override
  String get locationNear => 'Nearby';

  @override
  String get locationSaoPaulo => 'São Paulo';

  @override
  String get locationUnitedStates => 'United States';

  @override
  String get locationEurope => 'Europe';

  @override
  String get locationNearDetail => 'Anycast · shortest available route';

  @override
  String get locationSaoPauloDetail => 'AWS · sa-east-1';

  @override
  String get locationUnitedStatesDetail => 'AWS · Virginia · us-east-1';

  @override
  String get locationEuropeDetail => 'AWS · Ireland · eu-west-1';

  @override
  String get checkEvery => 'Check every';

  @override
  String get alertAbove => 'Alert above';

  @override
  String get customLimit => 'Custom';

  @override
  String get limitTypeError => 'Type the limit in milliseconds.';

  @override
  String limitRangeError(Object min, Object max) {
    return 'Use a value between $min and $max ms.';
  }

  @override
  String limitRangeHint(Object min, Object max) {
    return 'Between $min and $max ms.';
  }

  @override
  String get limitHintExample => 'E.g. 450';

  @override
  String get limitFootnote =>
      'Each check uses 5 connections and confirms suspicious results with 5 more.';

  @override
  String get donationTitle => 'Enjoying Linkzora?';

  @override
  String get donationMessage =>
      'Enjoying the app? How about buying this dev a coffee? ;)';

  @override
  String get donationButton => 'Buy me a coffee';

  @override
  String get donationOpenFailed =>
      'Couldn\'t open the link. Visit buymeacoffee.com/andremaracaja';

  @override
  String get donationDismiss => 'Dismiss';

  @override
  String get back => 'Back';

  @override
  String get setUp => 'Set up';

  @override
  String get skip => 'Skip';

  @override
  String get allow => 'Allow';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get permissionRequestFailed => 'Couldn\'t request the permission';

  @override
  String get startFailed => 'Couldn\'t start monitoring';

  @override
  String get welcomeTitle => 'Welcome to Linkzora';

  @override
  String get welcomeText =>
      'Know when the internet drops, fluctuates or slows down, without spending data or battery.';

  @override
  String get featureBackgroundTitle => 'Background measurement';

  @override
  String get featureBackgroundText =>
      'Latency, jitter and loss every few minutes.';

  @override
  String get featureAlertsTitle => 'Timely alerts';

  @override
  String get featureAlertsText =>
      'A heads-up when the connection drops or returns.';

  @override
  String get featureCauseText =>
      'Wi-Fi, route or server, and the best time to use it.';

  @override
  String get setupTime => 'Setup takes less than a minute.';

  @override
  String get targetStepTitle => 'Where to measure';

  @override
  String get targetStepSubtitle =>
      'The destination of the test connections. \"Nearby\" uses the shortest available route and suits most people.';

  @override
  String get alertsStepSubtitle =>
      'When Linkzora should get your attention if the connection drops or fluctuates.';

  @override
  String get rhythmStepTitle => 'Measurement rhythm';

  @override
  String get rhythmStepSubtitle =>
      'Short intervals catch drops sooner; long ones save battery.';

  @override
  String get wifiStepTitle => 'Wi-Fi name';

  @override
  String get wifiStepSubtitle => 'Optional · precise location permission';

  @override
  String get wifiStepNote =>
      'Without it, the network shows only as \"Wi-Fi\". You can allow it later on the Connection screen.';

  @override
  String get summaryStepTitle => 'All set';

  @override
  String get summaryStepSubtitle =>
      'Review your choices. Everything can be changed later in Settings.';

  @override
  String get summaryServer => 'Server';

  @override
  String get summaryAlerts => 'Alerts';

  @override
  String get summaryLimit => 'Latency limit';

  @override
  String get wifiNameShown => 'Enabled';

  @override
  String get wifiNameHidden => 'Hidden';

  @override
  String get kindRouter => 'Router';

  @override
  String get kindTv => 'TV or streaming';

  @override
  String get kindPhone => 'Phone or tablet';

  @override
  String get kindComputer => 'Computer';

  @override
  String get kindPrinter => 'Printer';

  @override
  String get kindConsole => 'Game console';

  @override
  String get kindSpeaker => 'Assistant or speaker';

  @override
  String get kindCamera => 'Camera';

  @override
  String get kindIot => 'Smart home (IoT)';

  @override
  String get kindUnknown => 'Unknown type';

  @override
  String deviceUnnamed(Object suffix) {
    return 'Device .$suffix';
  }

  @override
  String confidence(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'high confidence',
        'medium': 'medium confidence',
        'other': 'low confidence',
      },
    );
    return '$_temp0';
  }

  @override
  String interferenceLevel(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'High interference',
        'medium': 'Medium interference',
        'other': 'Low interference',
      },
    );
    return '$_temp0';
  }

  @override
  String bandGhz(Object band) {
    return '$band GHz';
  }

  @override
  String get causeIsp => 'Provider / internet';

  @override
  String get causeInterference => 'Wi-Fi interference';

  @override
  String get causeSignal => 'Weak signal on your device';

  @override
  String get causeUnknown => 'No identified cause';

  @override
  String reasonHeavyKind(Object kind) {
    return '$kind: tends to use a lot of bandwidth';
  }

  @override
  String reasonLift(Object present, Object absent) {
    return 'Unstable in $present of the checks with it on the network, versus $absent without it';
  }

  @override
  String get reasonNoWorse =>
      'The connection doesn\'t get worse when it is on the network';

  @override
  String get reasonAlwaysPresent =>
      'Always present: no periods without it to compare';

  @override
  String get reasonNoPresence => 'No presence history yet';

  @override
  String reasonJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Joined the network shortly before $count failure periods',
      one: 'Joined the network shortly before 1 failure period',
    );
    return '$_temp0';
  }

  @override
  String reasonSlowLocal(Object latency, Object jitter) {
    return 'Slow or fluctuating local reply ($latency ms, jitter $jitter ms)';
  }

  @override
  String get reasonPhonePowerSave =>
      '; phones in power saving reply slowly, so the weight is reduced';

  @override
  String get reasonNotInLastScan => 'Didn\'t show up in the last scan';

  @override
  String get pairedNone => 'No router measurements alongside the failures yet';

  @override
  String pairedGood(int count, Object paired) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count failures out of $paired the router replied well',
      one: 'In 1 failure out of $paired the router replied well',
    );
    return '$_temp0';
  }

  @override
  String nowRouterInternet(Object router, Object internet) {
    return 'Now: router $router × internet $internet';
  }

  @override
  String get ispIncludes =>
      'Includes the route to the server and heavy internet use at home';

  @override
  String networksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count networks',
      one: '1 network',
    );
    return '$_temp0';
  }

  @override
  String overlappingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overlapping',
      one: '1 overlapping',
    );
    return '$_temp0';
  }

  @override
  String neighborNetworksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neighbouring networks',
      one: '1 neighbouring network',
    );
    return '$_temp0';
  }

  @override
  String reasonChannels(
      Object same, Object overlapping, Object channel, Object band) {
    return '$same on the same channel and $overlapping (channel $channel, $band)';
  }

  @override
  String reasonInterferenceAmong(Object interference, Object neighbors) {
    return '$interference among $neighbors';
  }

  @override
  String reasonFreeChannel(Object channel) {
    return 'Channel $channel is less crowded';
  }

  @override
  String get reasonNoNeighbors =>
      'Neighbouring networks unavailable (allow location)';

  @override
  String reasonWeakFailures(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failures out of $total with a weak signal',
      one: '1 failure out of $total with a weak signal',
    );
    return '$_temp0';
  }

  @override
  String reasonSignalNow(Object rssi, Object quality) {
    return 'Current signal $rssi dBm ($quality)';
  }

  @override
  String get reasonNoInstability => 'No Wi-Fi instability in the last 24 h';

  @override
  String reasonUnexplained(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count unstable checks out of $total; part of it has no observable explanation',
      one:
          '1 unstable check out of $total; part of it has no observable explanation',
    );
    return '$_temp0';
  }

  @override
  String locationNow(Object router, Object internet) {
    return ' Now: router $router, internet $internet.';
  }

  @override
  String get locationNoneTitle => 'No recent problems';

  @override
  String locationNoneDetail(Object now) {
    return 'No Wi-Fi instability in the last 24 h.$now';
  }

  @override
  String get locationUnknownTitle => 'Still inconclusive';

  @override
  String get locationUnknownDetail =>
      'Scan the network and keep monitoring on to compare the router with the internet.';

  @override
  String get locationLocalTitle => 'Local network (Wi-Fi/home)';

  @override
  String locationLocalDetail(Object now) {
    return 'The router also slows down or loses packets when the connection gets worse: signal, interference or devices at home.$now';
  }

  @override
  String locationIspDetail(Object now) {
    return 'The Wi-Fi up to the router stays fine when the connection gets worse. The bottleneck is beyond it: provider, route or the home internet saturated by some device.$now';
  }

  @override
  String get locationMixedTitle => 'On both sides';

  @override
  String locationMixedDetail(Object now) {
    return 'There are failures with the router slow and failures with it normal.$now';
  }

  @override
  String get scanJustNow => 'just now';

  @override
  String scanMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String scanTodayAt(Object time) {
    return 'today at $time';
  }

  @override
  String scanOnDate(Object date, Object time) {
    return 'on $date $time';
  }

  @override
  String get sourceHistory => 'history';

  @override
  String get scanPreparing => 'Preparing';

  @override
  String get scanNeedsWifi =>
      'Connect the phone to a Wi-Fi network to scan it.';

  @override
  String get scanFailed => 'Couldn\'t scan the network.';

  @override
  String get scanUnavailable => 'Scan unavailable';

  @override
  String get neighborsHidden => 'Neighbouring networks hidden';

  @override
  String get neighborsLocationOff =>
      'Turn on the device location: Android requires it to list neighbouring Wi-Fi networks.';

  @override
  String get neighborsPermission =>
      'Android only shows neighbouring networks with the precise location permission and the app open.';

  @override
  String get probableContribution => 'Probable contribution';

  @override
  String get noMeasurementsLower => 'no measurements';

  @override
  String unstableOfTotal(Object unstable, Object total) {
    return '$unstable/$total unstable in 24 h';
  }

  @override
  String get devicesOnNetwork => 'Devices on the network';

  @override
  String devicesOnNetworkCount(Object count) {
    return 'Devices on the network ($count)';
  }

  @override
  String scannedAgo(Object age) {
    return 'scanned $age';
  }

  @override
  String get noScanTitle => 'No scan yet';

  @override
  String get noScanText =>
      'Tap \"Scan now\" to list the devices connected to your Wi-Fi.';

  @override
  String get wifiEnvironment => 'Wi-Fi environment';

  @override
  String get howToReadTitle => 'How to read these numbers';

  @override
  String get howToReadMonitoring =>
      'Android doesn\'t let an app see each device\'s bandwidth use or the network\'s MAC addresses. The percentages are estimates: they cross your measurements with the router latency, the neighbouring networks and which devices were connected at each moment (inventory every 15 min while monitoring is on).';

  @override
  String get howToReadIdle =>
      'Android doesn\'t let an app see each device\'s bandwidth use or the network\'s MAC addresses. The percentages are estimates: they cross your measurements with the router latency, the neighbouring networks and which devices were connected at each moment. Turn on monitoring to record which devices are present every 15 min.';

  @override
  String get onlyRouterAndPhone => 'Only the router and this device replied.';

  @override
  String get whereIsTheProblem => 'Where the problem is';

  @override
  String get localNetwork => 'Local network';

  @override
  String get provider => 'Provider';

  @override
  String get internet => 'Internet';

  @override
  String get scanNow => 'Scan now';

  @override
  String lastScan(Object age) {
    return 'Last scan $age';
  }

  @override
  String scanDuration(Object seconds) {
    return '$seconds s';
  }

  @override
  String get scanning => 'Scanning…';

  @override
  String get scanTakesAbout => 'Takes about 15 seconds. Keep the app open.';

  @override
  String get networkDevices => 'Network devices';

  @override
  String largestShare(Object name, Object percent) {
    return 'Largest share: $name ($percent%)';
  }

  @override
  String get probableLower => 'probable';

  @override
  String get breakdownExplanation =>
      'Largest estimated contribution. The percentages add up to 100% and show the probable weight of each cause, not bandwidth use.';

  @override
  String get yourRouter => 'Your router';

  @override
  String get thisDevice => 'This device';

  @override
  String localLatency(Object value) {
    return 'local $value';
  }

  @override
  String jitterMs(Object value) {
    return 'jitter $value ms';
  }

  @override
  String get absent => 'absent';

  @override
  String get showLess => 'Less';

  @override
  String get why => 'Why?';

  @override
  String get onlyKindWeight =>
      'Only the weight of the device type; no other evidence.';

  @override
  String sources(Object list) {
    return 'Sources: $list';
  }

  @override
  String get noNeighborsTitle => 'No data on neighbouring networks';

  @override
  String get noNeighborsScan =>
      'Scan the network to analyse channel, signal and interference.';

  @override
  String get noNeighborsAndroid =>
      'Android didn\'t provide the Wi-Fi network list in this scan.';

  @override
  String get yourWifi => 'Your Wi-Fi';

  @override
  String get cachedData => 'cached data';

  @override
  String get wifiBand => 'Band';

  @override
  String get wifiChannel => 'Channel';

  @override
  String neighborsSummary(Object same, Object partial, Object total) {
    return '$same on the same channel · $partial overlapping · $total neighbouring networks';
  }

  @override
  String channelTip(Object channel) {
    return 'Tip: channel $channel is less crowded. Change it in the router settings.';
  }

  @override
  String get interferenceBar => 'Interference from neighbouring networks';

  @override
  String get ownNetworkTag => 'your network';

  @override
  String get neighborsWeak =>
      'Neighbours on your channel are faint and barely affect your connection.';

  @override
  String ownNetworksNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count access points of your own network are not counted',
      one: '1 access point of your own network is not counted',
    );
    return '$_temp0';
  }

  @override
  String get diagNoNetwork => 'No active network on the device';

  @override
  String get diagCaptivePortal => 'Network requires sign-in (captive portal)';

  @override
  String get diagDns => 'Failed to resolve the server address (DNS)';

  @override
  String get diagNoInternet => 'Network connected, but without internet access';

  @override
  String get diagWeakWifiOffline =>
      'Wi-Fi signal too weak to keep the connection';

  @override
  String get diagServerNoResponse => 'Server or route not responding';

  @override
  String get diagWeakWifiStable => 'Weak Wi-Fi signal, but stable connection';

  @override
  String get diagNoAnomaly => 'No anomaly detected';

  @override
  String get diagWeakWifi => 'Weak Wi-Fi signal';

  @override
  String get diagPacketLoss => 'Packet loss on the route';

  @override
  String get diagHighJitter => 'High fluctuation on the route';

  @override
  String diagRegionalDistance(Object target) {
    return 'Distance to $target affects the latency';
  }

  @override
  String get diagCongested => 'Congested route or distant server';

  @override
  String get eventStable => 'Stable connection';

  @override
  String get eventUnstable => 'Unstable connection';

  @override
  String get eventOffline => 'Internet unavailable';

  @override
  String get eventRestored => 'Connection restored';

  @override
  String get eventBackUnstable => 'Connection back, but unstable';

  @override
  String get eventChecking => 'Checking connection';

  @override
  String get transportMobileData => 'Mobile data';

  @override
  String get transportNoNetwork => 'No network';
}
