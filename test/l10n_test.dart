import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:wifiwarnme/analytics.dart';
import 'package:wifiwarnme/l10n/app_localizations.dart';
import 'package:wifiwarnme/main.dart';

const channel = MethodChannel('wifiwarnme/monitor');

final pt = lookupAppLocalizations(const Locale('pt'));
final es = lookupAppLocalizations(const Locale('es'));
final en = lookupAppLocalizations(const Locale('en'));

class FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final launched = <(String, PreferredLaunchMode)>[];
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    return result;
  }
}

void main() {
  group('resolveLanguage', () {
    test('follows the first supported system language', () {
      expect(resolveLanguage('system', const [Locale('es', 'MX')]), 'es');
      expect(resolveLanguage('system', const [Locale('en', 'GB')]), 'en');
      expect(resolveLanguage('system', const [Locale('pt', 'BR')]), 'pt');
      expect(
          resolveLanguage(
              'system', const [Locale('fr'), Locale('es'), Locale('pt')]),
          'es');
    });

    test('falls back to English for unsupported languages', () {
      expect(resolveLanguage('system', const [Locale('fr', 'FR')]), 'en');
      expect(resolveLanguage('system', const []), fallbackLanguage);
      expect(resolveLanguage(null, const [Locale('de')]), 'en');
    });

    test('an explicit choice wins over the system', () {
      expect(resolveLanguage('es', const [Locale('pt', 'BR')]), 'es');
      expect(resolveLanguage('pt', const [Locale('en')]), 'pt');
      expect(resolveLanguage('klingon', const [Locale('pt')]), 'pt');
    });
  });

  group('native text from before the native side followed the language', () {
    test('known Portuguese diagnoses and event pieces are translated', () {
      expect(localizeNativeText('Perda de pacotes na rota', en),
          'Packet loss on the route');
      expect(localizeNativeText('Nenhuma anomalia detectada', es),
          'Ninguna anomalía detectada');
      expect(localizeNativeText('Internet indisponível', en),
          'Internet unavailable');
      expect(localizeNativeText('Dados móveis', es), 'Datos móviles');
      expect(localizeNativeText('perda 10%', en), 'loss 10%');
      expect(
          localizeNativeText(
              'Distância até Estados Unidos influencia a latência', en),
          'Distance to United States affects the latency');
      expect(localizeNativeText('Perda de pacotes na rota', pt),
          'Perda de pacotes na rota');
    });

    test('event titles and details written in ES/EN show in the app language',
        () {
      expect(
          localizeNativeText('Conexión inestable', en), 'Unstable connection');
      expect(localizeNativeText('Internet unavailable', pt),
          'Internet indisponível');
      expect(localizeNativeText('Stable connection', es), 'Conexión estable');
      expect(localizeNativeText('pérdida 20%', pt), 'perda 20%');
      expect(localizeNativeText('loss 5%', es), 'pérdida 5%');
    });

    test('diagnoses are localized from their code, else from the text', () {
      expect(
          localizeDiagnosis('packet_loss', 'Packet loss on the route', '', es),
          'Pérdida de paquetes en la ruta');
      expect(localizeDiagnosis('dns_failure', '', '', en),
          'Failed to resolve the server address (DNS)');
      expect(localizeDiagnosis('regional_distance', 'x', 'Europa', en),
          'Distance to Europe affects the latency');
      expect(
          localizeDiagnosis('future_code', 'Texto novo', '', en), 'Texto novo');
      expect(localizeDiagnosis('', 'Oscilação alta na rota', '', en),
          'High fluctuation on the route');
      final sample = Measurement.fromMap({
        'state': 'slow',
        'diagnosis': 'Oscilación alta en la ruta',
        'diagnosisCode': 'high_jitter',
      });
      expect(sample.localizedDiagnosis(pt), 'Oscilação alta na rota');
      final period = failurePeriods([sample], live: false).single;
      expect(period.localizedDiagnosis(en), 'High fluctuation on the route');
    });

    test('unknown text passes through unchanged', () {
      expect(localizeNativeText('Wi-Fi · CasaNet', en), 'Wi-Fi · CasaNet');
      expect(
          localizeNativeText('Unstable connection', en), 'Unstable connection');
    });

    test('targets keep one identity in every language', () {
      expect(canonicalTarget('United States'), 'Estados Unidos');
      expect(canonicalTarget('Europe'), 'Europa');
      expect(canonicalTarget('Cloudflare'), 'Cloudflare');
      expect(targetDisplayName('Estados Unidos', en), 'United States');
      expect(targetDisplayName('Europa', es), 'Europa');
      expect(targetDisplayName(unknownTarget, en), 'Unidentified destination');
      expect(
          Measurement.fromMap({'targetName': 'Europe'}).targetName, 'Europa');
    });

    test('event states are read from titles in any language', () {
      for (final (title, state) in [
        ('Internet indisponível', 'offline'),
        ('Internet no disponible', 'offline'),
        ('Internet unavailable', 'offline'),
        ('Conexión inestable', 'slow'),
        ('Unstable connection', 'slow'),
        ('Connection back, but unstable', 'slow'),
        ('Connection restored', 'online'),
      ]) {
        expect(
            ConnectionEvent.parse('16/10 11:40 • $title • Wi-Fi').state, state,
            reason: title);
      }
    });
  });

  group('app', () {
    late List<MethodCall> calls;
    late Map<String, Object?> status;
    late FakeLauncher launcher;

    setUp(() {
      calls = [];
      final now = DateTime.now().millisecondsSinceEpoch;
      status = {
        'enabled': true,
        'checking': false,
        'state': 'slow',
        'transportType': 'wifi',
        'networkName': 'CasaNet',
        'latency': 420,
        'jitter': 30,
        'failureRate': 20,
        'successfulSamples': 4,
        'totalSamples': 5,
        'serverId': 'cloudflare',
        'locationId': 'united_states',
        'notificationMode': 'changes',
        'lastCheckedAt': now,
        'nextCheckAt': now + 60000,
        'signalLevel': 1,
        'wifiRssi': -78,
        'measurements': [
          for (var index = 0; index < 6; index++)
            {
              'timestamp': now - (6 - index) * 60000,
              'state': index.isEven ? 'slow' : 'online',
              'latency': index.isEven ? 420 : 80,
              'jitter': 30,
              'failureRate': index.isEven ? 20 : 0,
              'transportType': 'wifi',
              'targetName': 'Estados Unidos',
              'diagnosis': index.isEven ? 'Perda de pacotes na rota' : '',
              'signalLevel': 1,
            },
        ],
        'events': [
          '16/10 11:40 • Conexão voltou, mas instável • Dados móveis • '
              'Estados Unidos • 420ms • jitter 30ms • perda 20%',
          '16/10 11:30 • Internet indisponível • Sem rede',
        ],
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'status':
            return status;
          case 'configure':
          case 'probe':
            status['lastCheckedAt'] = (status['lastCheckedAt'] as int) + 1;
        }
        return null;
      });
      launcher = FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> pumpApp(WidgetTester tester,
        {required Locale system, Size size = const Size(400, 860)}) async {
      tester.platformDispatcher.localesTestValue = [system];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const Linkzora());
      await tester.pump();
      await tester.pump();
    }

    Future<void> passSplash(WidgetTester tester) async {
      for (var index = 0; index < 6; index++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    /// Scrolls the first vertical list on screen to its end, where its last
    /// item sits clear of the floating tab bar.
    Future<void> scrollToEnd(WidgetTester tester) async {
      final list = find.byWidgetPredicate((widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.vertical);
      final position = tester.state<ScrollableState>(list.first).position;
      double? extent;
      while (extent != position.maxScrollExtent) {
        extent = position.maxScrollExtent;
        position.jumpTo(extent);
        await tester.pumpAndSettle();
      }
    }

    Iterable<Object?> languagesSent(String method) => calls
        .where((call) => call.method == method)
        .map((call) => (call.arguments as Map)['language']);

    for (final (system, title) in [
      (const Locale('es', 'ES'), 'Te damos la bienvenida a Linkzora'),
      (const Locale('en', 'US'), 'Welcome to Linkzora'),
      (const Locale('pt', 'BR'), 'Boas-vindas ao Linkzora'),
      (const Locale('fr', 'FR'), 'Welcome to Linkzora'),
    ]) {
      testWidgets('the onboarding follows the system language $system',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        await pumpApp(tester, system: system);
        expect(find.text(title), findsOneWidget);
        final code = system.languageCode == 'fr' ? 'en' : system.languageCode;
        expect(languagesSent('setLanguage'), [code]);
      });
    }

    testWidgets('a saved choice overrides the system and reaches the monitor',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'onboardingDone': true, 'language': 'es'});
      await pumpApp(tester, system: const Locale('pt', 'BR'));
      await passSplash(tester);
      expect(find.text('Conexión ahora'), findsOneWidget);
      // Old Portuguese history is shown in the chosen language.
      expect(find.text('Servidor · Estados Unidos'), findsOneWidget);
      expect(languagesSent('configure'), ['es']);
      // const Linkzora() reads the choice after the first frame; main()
      // passes it in, so a real start only ever sends 'es'.
      expect(languagesSent('setLanguage').last, 'es');

      await tester.tap(find.text('En cada cambio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin alertas'));
      await tester.pumpAndSettle();
      expect(languagesSent('configure'), ['es', 'es']);
    });

    testWidgets('picking a language in the onboarding applies and persists',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester, system: const Locale('pt', 'BR'));
      expect(find.text('Boas-vindas ao Linkzora'), findsOneWidget);

      await scrollToEnd(tester);
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(
          find.text('Follows the device language · Português'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'en');
      expect(languagesSent('setLanguage'), ['pt', 'en']);

      // "Sistema" goes back to following the device.
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();
      expect(
          find.text('Segue o idioma do aparelho · Português'), findsOneWidget);
      expect(prefs.getString('language'), 'system');
      expect(languagesSent('setLanguage'), ['pt', 'en', 'pt']);

      // With "Sistema", a change of the device language applies live.
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      await tester.pumpAndSettle();
      expect(find.text('Sigue el idioma del dispositivo · Español'),
          findsOneWidget);
      expect(languagesSent('setLanguage').last, 'es');
    });

    testWidgets('Ajustes switches the language live', (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingDone': true});
      await pumpApp(tester, system: const Locale('pt', 'BR'));
      await passSplash(tester);
      expect(find.text('Conexão agora'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('language-es')));
      await tester.tap(find.byKey(const ValueKey('language-es')));
      await tester.pumpAndSettle();
      // The open sheet and the page behind it are already in Spanish.
      expect(find.text('Guardar ajustes'), findsOneWidget);
      expect(find.text('Conexión ahora'), findsOneWidget);
      expect(languagesSent('setLanguage').last, 'es');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'es');
    });

    group('donation', () {
      Future<void> openDonation(WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'onboardingDone': true});
        await pumpApp(tester, system: const Locale('pt', 'BR'));
        await passSplash(tester);
        await tester.tap(find.byTooltip('Ajustes'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Pagar um cafezinho'));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'Gostando do app? Que tal pagar um cafezinho pra esse dev ;)'),
            findsOneWidget);
        await tester.tap(find.text('Pagar um cafezinho'));
        await tester.pumpAndSettle();
      }

      testWidgets('the button opens Buy Me a Coffee in the browser',
          (tester) async {
        await openDonation(tester);
        expect(launcher.launched, [
          (
            'https://buymeacoffee.com/andremaracaja',
            PreferredLaunchMode.externalApplication
          )
        ]);
        expect(find.textContaining('Não foi possível abrir'), findsNothing);
      });

      testWidgets('a launch failure becomes a toast', (tester) async {
        launcher.result = false;
        await openDonation(tester);
        expect(
            find.text('Não foi possível abrir o link. '
                'Acesse buymeacoffee.com/andremaracaja'),
            findsOneWidget);
      });

      testWidgets('the nudge shows once after a week and can be dismissed',
          (tester) async {
        final weekAgo = DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch;
        SharedPreferences.setMockInitialValues(
            {'onboardingDone': true, 'firstUseAt': weekAgo});
        await pumpApp(tester, system: const Locale('pt', 'BR'));
        await passSplash(tester);
        final dismiss = find.byKey(const ValueKey('donation-dismiss'));
        await scrollToEnd(tester);
        await tester.tap(dismiss);
        await tester.pumpAndSettle();
        expect(dismiss, findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('donationNudgeDone'), isTrue);
      });

      testWidgets('no nudge on a fresh install', (tester) async {
        SharedPreferences.setMockInitialValues({'onboardingDone': true});
        await pumpApp(tester, system: const Locale('pt', 'BR'));
        await passSplash(tester);
        expect(find.byKey(const ValueKey('donation-dismiss')), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('firstUseAt'), isNotNull);
      });
    });

    // Layout overflows fail these tests, so every screen is rendered at a
    // narrow phone width in the two longer languages.
    for (final language in ['es', 'en']) {
      testWidgets('every tab, Ajustes and the onboarding fit in $language',
          (tester) async {
        final weekAgo = DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch;
        SharedPreferences.setMockInitialValues(
            {'onboardingDone': true, 'firstUseAt': weekAgo});
        await pumpApp(tester,
            system: Locale(language), size: const Size(360, 740));
        await passSplash(tester);
        final l = language == 'es' ? es : en;

        Future<void> scrollThrough() async {
          final scrollables = find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical);
          for (final element in scrollables.evaluate()) {
            final position =
                (element as StatefulElement).state as ScrollableState;
            if (!position.mounted) continue;
            position.position.jumpTo(position.position.maxScrollExtent);
            await tester.pumpAndSettle();
          }
        }

        expect(find.text(l.subtitleConnection), findsOneWidget);
        await scrollThrough();
        expect(find.text(l.donationTitle), findsOneWidget);
        for (final tab in [l.tabMonitoring, l.tabEvents, l.tabNetwork]) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          if (tab == l.tabNetwork) {
            expect(find.text(l.probableContribution.toUpperCase()),
                findsOneWidget);
          }
          await scrollThrough();
        }

        await tester.tap(find.byTooltip(l.settings));
        await tester.pumpAndSettle();
        expect(find.text(l.saveSettings), findsOneWidget);
        await scrollThrough();
        expect(find.text(l.donationButton), findsOneWidget);
      });

      testWidgets('the onboarding summary fits in $language', (tester) async {
        SharedPreferences.setMockInitialValues({
          'language': language,
          'locationId': 'united_states',
          'maxLatency': 1000,
        });
        await pumpApp(tester,
            system: const Locale('pt'), size: const Size(360, 740));
        final l = language == 'es' ? es : en;
        Future<void> tap(String text) async {
          await tester.tap(find.text(text));
          await tester.pumpAndSettle();
        }

        await scrollToEnd(tester);
        expect(find.byKey(const ValueKey('language-pt')), findsOneWidget);
        await tap(l.setUp);
        for (var step = 0; step < 3; step++) {
          await tap(l.continueAction);
        }
        await tap(l.skip);
        expect(find.text(l.summaryStepTitle), findsOneWidget);
        // Labels are never cut ("Límite de latencia", "Wi-Fi name").
        for (final label in [l.summaryLimit, l.wifiStepTitle]) {
          final text = tester.renderObject<RenderParagraph>(find.text(label));
          expect(text.didExceedMaxLines, isFalse, reason: label);
        }
        expect(find.text(l.locationUnitedStates), findsOneWidget);
      });
    }
  });
}
