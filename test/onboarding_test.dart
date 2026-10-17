import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifiwarnme/main.dart';

const channel = MethodChannel('wifiwarnme/monitor');

void main() {
  late List<MethodCall> calls;
  late Map<String, Object?> status;

  setUp(() {
    calls = [];
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
      calls.add(call);
      switch (call.method) {
        case 'status':
          return status;
        case 'requestWifiName':
          return true;
        case 'start':
        case 'configure':
        case 'probe':
          // The splash waits for a reading newer than the one it saw.
          if (call.method == 'start') status['enabled'] = true;
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
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(const Linkzora());
    await tester.pump();
    await tester.pump();
  }

  /// Lets the splash take its first reading and hand over to Home.
  Future<void> passSplash(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Walks the whole flow with non-default choices up to the summary.
  Future<void> chooseEverything(WidgetTester tester) async {
    await tapAndSettle(tester, 'Configurar');
    expect(find.text('Para onde medir'), findsOneWidget);
    await tapAndSettle(tester, 'Google');
    await tapAndSettle(tester, 'Continuar');

    expect(find.text('Alertas de mudança'), findsOneWidget);
    await tapAndSettle(tester, 'Uma vez por sessão');
    await tapAndSettle(tester, 'Continuar');

    expect(find.text('Ritmo das medições'), findsOneWidget);
    await tapAndSettle(tester, '5 min');
    await tapAndSettle(tester, 'Continuar');

    expect(find.text('Nome do Wi-Fi'), findsOneWidget);
    await tapAndSettle(tester, 'Permitir');
    expect(find.text('Tudo pronto'), findsOneWidget);
  }

  testWidgets('first run shows the onboarding before any reading',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    expect(find.text('Boas-vindas ao Linkzora'), findsOneWidget);
    expect(find.text('1/6'), findsOneWidget);
    expect(
        calls.where(
            (call) => call.method != 'status' && call.method != 'setLanguage'),
        isEmpty);
    expect(calls.where((call) => call.method == 'setLanguage').single.arguments,
        {'language': 'pt'});
  });

  testWidgets('back returns to the previous step', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tapAndSettle(tester, 'Configurar');
    await tapAndSettle(tester, 'Continuar');
    expect(find.text('2/6'), findsNothing);
    await tapAndSettle(tester, 'Voltar');
    expect(find.text('Para onde medir'), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);
  });

  testWidgets('finishing saves the choices and starts the monitor',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await chooseEverything(tester);
    expect(find.text('Próximo · Google'), findsOneWidget);
    expect(find.text('Habilitado'), findsOneWidget);
    expect(
        calls.where((call) => call.method == 'requestWifiName'), hasLength(1));

    await tester.tap(find.text('Começar monitoramento'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboardingDone'), isTrue);
    expect(prefs.getString('locationId'), 'near');
    expect(prefs.getString('serverId'), 'google');
    expect(prefs.getString('notificationMode'), 'once');
    expect(prefs.getInt('interval'), 5);
    expect(prefs.getInt('maxLatency'), 300);

    final start = calls.singleWhere((call) => call.method == 'start');
    expect(start.arguments, {
      'interval': 5,
      'maxLatency': 300,
      'serverId': 'google',
      'locationId': 'near',
      'notificationMode': 'once',
      'language': 'pt',
    });

    await passSplash(tester);
    expect(find.text('Boas-vindas ao Linkzora'), findsNothing);
    expect(find.text('Conexão agora'), findsOneWidget);
  });

  testWidgets('"Agora não" saves the choices without starting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await chooseEverything(tester);
    await tester.tap(find.text('Agora não'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboardingDone'), isTrue);
    expect(prefs.getString('serverId'), 'google');
    await passSplash(tester);
    expect(calls.where((call) => call.method == 'start'), isEmpty);
    // The splash still takes a one-off reading.
    expect(calls.where((call) => call.method == 'probe'), hasLength(1));
    expect(find.text('Conexão agora'), findsOneWidget);
  });

  testWidgets('a typed latency limit is validated and sent to start',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tapAndSettle(tester, 'Configurar');
    await tapAndSettle(tester, 'Continuar');
    await tapAndSettle(tester, 'Continuar');
    expect(find.text('Ritmo das medições'), findsOneWidget);

    final field = find.byKey(const ValueKey('limit-custom-field'));
    await tester.tap(find.byKey(const ValueKey('limit-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(field, '5');
    await tester.pump();
    expect(find.text('Use um valor entre 30 e 2000 ms.'), findsOneWidget);
    // Continuar is disabled while the value is invalid.
    await tapAndSettle(tester, 'Continuar');
    expect(find.text('Ritmo das medições'), findsOneWidget);

    await tester.enterText(field, '75');
    await tester.pump();
    await tapAndSettle(tester, 'Continuar');
    await tapAndSettle(tester, 'Pular');
    expect(find.text('75 ms'), findsOneWidget);
    await tester.tap(find.text('Começar monitoramento'));
    await tester.pump();

    final start = calls.singleWhere((call) => call.method == 'start');
    expect((start.arguments as Map)['maxLatency'], 75);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('maxLatency'), 75);
    await passSplash(tester);
  });

  testWidgets('skipping the Wi-Fi step does not ask for the permission',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tapAndSettle(tester, 'Configurar');
    await tapAndSettle(tester, 'Continuar');
    await tapAndSettle(tester, 'Continuar');
    await tapAndSettle(tester, 'Continuar');
    await tapAndSettle(tester, 'Pular');
    expect(find.text('Tudo pronto'), findsOneWidget);
    expect(find.text('Oculto'), findsOneWidget);
    expect(calls.where((call) => call.method == 'requestWifiName'), isEmpty);
  });

  testWidgets('existing choices are preselected for older installs',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'locationId': 'europe', 'interval': 10});
    await pumpApp(tester);
    expect(find.text('Boas-vindas ao Linkzora'), findsOneWidget);
    await tapAndSettle(tester, 'Configurar');
    for (var index = 0; index < 4; index++) {
      await tapAndSettle(tester, index == 3 ? 'Pular' : 'Continuar');
    }
    expect(find.text('Europa'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('onboarding is not shown once it was completed', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    await pumpApp(tester);
    expect(find.text('Boas-vindas ao Linkzora'), findsNothing);
    await passSplash(tester);
    expect(find.text('Boas-vindas ao Linkzora'), findsNothing);
    expect(find.text('Conexão agora'), findsOneWidget);
    expect(calls.where((call) => call.method == 'probe'), hasLength(1));
  });
}
