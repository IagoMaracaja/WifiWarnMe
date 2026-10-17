import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifiwarnme/main.dart';

const channel = MethodChannel('wifiwarnme/monitor');

void main() {
  late Map<String, Object?> status;

  setUp(() {
    status = {
      'enabled': false,
      'checking': false,
      'state': 'online',
      'transportType': 'wifi',
      'networkName': 'CasaNet',
      'latency': 40,
      'jitter': 2,
      'failureRate': 0,
      'successfulSamples': 5,
      'totalSamples': 5,
      'lastCheckedAt': 1000,
      'measurements': <Object>[],
      'events': <Object>[],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') return status;
      // The splash waits for a reading newer than the one it saw.
      if (call.method == 'probe') {
        status['lastCheckedAt'] = (status['lastCheckedAt'] as int) + 1;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // The system language (pt) is the default: no explicit choice is saved.
    tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(const Linkzora());
    await tester.pump();
    await tester.pump();
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  LinkzoraPalette? paletteOf(WidgetTester tester, Finder finder) =>
      Theme.of(tester.element(finder)).extension<LinkzoraPalette>();

  Color scaffoldColor(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first))
          .scaffoldBackgroundColor;

  Brightness statusIcons(WidgetTester tester) => tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first)
      .value
      .statusBarIconBrightness!;

  List<Color> dialColors(WidgetTester tester) => (tester
          .widget<AnimatedContainer>(find.byKey(const ValueKey('status-dial')))
          .decoration! as BoxDecoration)
      .gradient!
      .colors;

  testWidgets('night mode is on by default', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    await pumpApp(tester);
    final title = find.text('Linkzora');
    expect(paletteOf(tester, title), LinkzoraPalette.dark);
    // The night mode switch lives in Ajustes, not in the top bar.
    expect(find.byTooltip('Desligar modo noturno'), findsNothing);
    expect(statusIcons(tester), Brightness.light);
    expect(dialColors(tester), LinkzoraPalette.dark.dial);
  });

  testWidgets('the Ajustes switch changes the palette and persists it',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    Finder nightSwitch() => find.descendant(
        of: find.ancestor(
            of: find.text('Modo noturno'), matching: find.byType(Row)),
        matching: find.byType(Switch));
    Future<void> toggleInSettings() async {
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(nightSwitch());
      await tester.pumpAndSettle();
    }

    await pumpApp(tester);
    await toggleInSettings();

    expect(paletteOf(tester, find.text('Linkzora')), LinkzoraPalette.light);
    expect(scaffoldColor(tester), LinkzoraPalette.light.bg);
    expect(statusIcons(tester), Brightness.dark);
    // The day dial uses the light surfaces, never stark white.
    expect(dialColors(tester), LinkzoraPalette.light.dial);
    expect(dialColors(tester), isNot(contains(Colors.white)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('darkMode'), isFalse);

    // A fresh start reads the saved choice.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    expect(paletteOf(tester, find.text('Linkzora')), LinkzoraPalette.light);

    await toggleInSettings();
    expect(paletteOf(tester, find.text('Linkzora')), LinkzoraPalette.dark);
    expect(prefs.getBool('darkMode'), isTrue);
  });

  testWidgets('Ajustes has the night mode switch', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Modo noturno'), findsOneWidget);

    final nightSwitch = find.descendant(
        of: find.ancestor(
            of: find.text('Modo noturno'), matching: find.byType(Row)),
        matching: find.byType(Switch));
    expect(tester.widget<Switch>(nightSwitch).value, isTrue);
    await tester.tap(nightSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(nightSwitch).value, isFalse);
    expect(paletteOf(tester, find.text('Modo noturno')), LinkzoraPalette.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('darkMode'), isFalse);
  });

  testWidgets('the onboarding follows the saved choice', (tester) async {
    SharedPreferences.setMockInitialValues({'darkMode': false});
    await pumpApp(tester);
    final welcome = find.text('Boas-vindas ao Linkzora');
    expect(welcome, findsOneWidget);
    expect(paletteOf(tester, welcome), LinkzoraPalette.light);
  });
}
