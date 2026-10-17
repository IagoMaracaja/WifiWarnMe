import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:wifiwarnme/l10n/app_localizations.dart';
import 'package:wifiwarnme/main.dart';

/// Home inside an app pinned to Portuguese, the language these tests read.
Widget portugueseApp(Widget home) => MaterialApp(
      locale: const Locale('pt'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

const channel = MethodChannel('wifiwarnme/monitor');

void main() {
  late List<MethodCall> calls;
  late Map<String, Object?> status;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    final now = DateTime.now().millisecondsSinceEpoch;
    status = {
      'enabled': true,
      'checking': false,
      'state': 'online',
      'transportType': 'wifi',
      'networkName': 'CasaNet',
      'latency': 74,
      'jitter': 3,
      'failureRate': 0,
      'successfulSamples': 5,
      'totalSamples': 5,
      'serverId': 'cloudflare',
      'locationId': 'europe',
      'notificationMode': 'changes',
      'lastCheckedAt': now,
      'nextCheckAt': now + 60000,
      'signalLevel': 4,
      'wifiRssi': -55,
      'linkSpeed': 866,
      'diagnosis': 'Nenhuma anomalia detectada',
      'measurements': [
        for (var index = 0; index < 5; index++)
          {
            'timestamp': now - (5 - index) * 60000,
            'state': index == 2 ? 'slow' : 'online',
            'latency': 70 + index,
            'jitter': 2,
            'failureRate': index == 2 ? 10 : 0,
            'transportType': 'wifi',
            'targetName': 'Europa',
            'diagnosis': index == 2 ? 'Perda de pacotes na rota' : '',
            'signalLevel': 4,
          },
      ],
      'events': ['16/10 11:40 • Conexão estável • Wi-Fi · CasaNet • Europa'],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'status') return status;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(portugueseApp(const Home()));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('home shows the live reading and the server in use',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('CasaNet'), findsOneWidget);
    expect(find.text('74 ms'), findsOneWidget);
    expect(find.text('Servidor · Europa'), findsOneWidget);
    expect(find.textContaining('Perda 0%'), findsOneWidget);
    expect(find.text('A cada mudança'), findsOneWidget);
  });

  testWidgets('status requests history only when it is out of date',
      (tester) async {
    await pumpHome(tester);
    final statusCalls = calls.where((call) => call.method == 'status').toList();
    expect(statusCalls.first.arguments, {'knownCheckedAt': null});
    await tester.pump(const Duration(seconds: 1));
    final latest = calls.lastWhere((call) => call.method == 'status');
    expect(
        (latest.arguments as Map)['knownCheckedAt'], status['lastCheckedAt']);
  });

  testWidgets('monitoria filters by server and shows the probable cause',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Monitoria'));
    await tester.pump();
    expect(find.text('Europa'), findsWidgets);
    expect(find.text('EM USO'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Conexão instável'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Perda de pacotes na rota'), findsOneWidget);
  });

  testWidgets('back closes the server dropdown before leaving the screen',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    (status['measurements'] as List).add({
      'timestamp': now - 30000,
      'state': 'online',
      'latency': 12,
      'jitter': 1,
      'failureRate': 0,
      'transportType': 'wifi',
      'targetName': 'Cloudflare',
      'diagnosis': '',
      'signalLevel': 4,
    });
    await pumpHome(tester);
    await tester.tap(find.text('Monitoria'));
    await tester.pump();
    await tester.tap(find.text('Servidor analisado'));
    await tester.pumpAndSettle();
    expect(find.text('Cloudflare'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Cloudflare'), findsNothing);
    expect(find.text('Servidor analisado'), findsOneWidget);
  });

  testWidgets('choosing an alert mode reconfigures the running monitor',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('A cada mudança'));
    await tester.pumpAndSettle();
    expect(
        find.text('Quando o Linkzora deve chamar sua atenção'), findsOneWidget);
    await tester.tap(find.text('Sem alertas'));
    await tester.pumpAndSettle();
    final configure = calls.lastWhere((call) => call.method == 'configure');
    expect((configure.arguments as Map)['notificationMode'], 'none');
  });

  testWidgets('a notification action can open the monitoria tab',
      (tester) async {
    status['launchTab'] = 1;
    await pumpHome(tester);
    expect(find.text('Últimas 24 horas'), findsOneWidget);
  });

  testWidgets('the tab bar switches between the three pages', (tester) async {
    await pumpHome(tester);
    expect(find.text('Conexão agora'), findsOneWidget);
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Conexão estável'), findsOneWidget);
    expect(find.text('CasaNet'), findsNothing);
    await tester.tap(find.text('Monitoria'));
    await tester.pumpAndSettle();
    expect(find.text('Últimas 24 horas'), findsOneWidget);
    expect(find.text('Servidor analisado'), findsOneWidget);
    // Off the Conexão page the top bar shows the live latency.
    final topBar = find.byType(PreferredSize);
    expect(find.descendant(of: topBar, matching: find.text('74 ms')),
        findsOneWidget);
    await tester.tap(find.text('Conexão'));
    await tester.pumpAndSettle();
    expect(find.text('Conexão agora'), findsOneWidget);
    expect(find.text('CasaNet'), findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('Estável')),
        findsOneWidget);
  });

  group('latency limit', () {
    final limitField = find.byKey(const ValueKey('limit-custom-field'));

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Avisar acima de'.toUpperCase()), findsOneWidget);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Salvar ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar ajustes'));
      await tester.pumpAndSettle();
    }

    Future<int?> configuredLimit() async =>
        (calls.lastWhere((call) => call.method == 'configure').arguments
            as Map)['maxLatency'] as int?;

    testWidgets('a preset is saved and sent to the monitor', (tester) async {
      await pumpHome(tester);
      await openSettings(tester);
      expect(limitField, findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('limit-30')));
      await tester.tap(find.byKey(const ValueKey('limit-30')));
      await tester.pump();
      expect(find.text('30 ms'), findsOneWidget);
      await save(tester);

      expect(await configuredLimit(), 30);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('maxLatency'), 30);
      expect(find.text('30 ms'), findsOneWidget);
    });

    testWidgets('a typed value is saved and reopens as custom', (tester) async {
      await pumpHome(tester);
      await openSettings(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('limit-custom')));
      await tester.tap(find.byKey(const ValueKey('limit-custom')));
      await tester.pumpAndSettle();
      expect(limitField, findsOneWidget);
      await tester.enterText(limitField, '450');
      await tester.pump();
      expect(find.text('450 ms'), findsOneWidget);
      await save(tester);

      expect(await configuredLimit(), 450);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('maxLatency'), 450);

      await openSettings(tester);
      expect(limitField, findsOneWidget);
      expect(find.widgetWithText(TextField, '450'), findsOneWidget);
    });

    testWidgets('invalid or out of range values cannot be saved',
        (tester) async {
      await pumpHome(tester);
      await openSettings(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('limit-custom')));
      await tester.tap(find.byKey(const ValueKey('limit-custom')));
      await tester.pumpAndSettle();

      await tester.enterText(limitField, '20');
      await tester.pump();
      expect(find.text('Use um valor entre 30 e 2000 ms.'), findsOneWidget);
      await tester.enterText(limitField, '2500');
      await tester.pump();
      expect(find.text('Use um valor entre 30 e 2000 ms.'), findsOneWidget);
      await tester.enterText(limitField, '');
      await tester.pump();
      expect(find.text('Digite o limite em milissegundos.'), findsOneWidget);
      // Letters never reach the field.
      await tester.enterText(limitField, 'abc');
      await tester.pump();
      expect(find.widgetWithText(TextField, 'abc'), findsNothing);

      await save(tester);
      expect(find.text('Salvar ajustes'), findsOneWidget,
          reason: 'the sheet stays open while the value is invalid');
      expect(calls.where((call) => call.method == 'configure'), isEmpty);

      await tester.enterText(limitField, '2000');
      await tester.pump();
      expect(find.text('Use um valor entre 30 e 2000 ms.'), findsNothing);
      await save(tester);
      expect(await configuredLimit(), 2000);
    });
  });

  group('pages clear the floating tab bar', () {
    final tabBar = find.byKey(const ValueKey('tab-bar'));

    /// Scrolls the visible page to its end and checks that [last] ends above
    /// the tab bar.
    Future<void> expectEndAboveTabBar(WidgetTester tester, Finder last) async {
      final vertical = find.byWidgetPredicate((widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.vertical);
      if (vertical.evaluate().isNotEmpty) {
        final position = tester.state<ScrollableState>(vertical.first).position;
        // Lazy lists refine their extent as they lay out; jump until stable.
        double? extent;
        while (extent != position.maxScrollExtent) {
          extent = position.maxScrollExtent;
          position.jumpTo(extent);
          await tester.pumpAndSettle();
        }
      }
      expect(last, findsOneWidget);
      expect(tester.getRect(last).bottom,
          lessThanOrEqualTo(tester.getRect(tabBar).top));
    }

    setUp(() {
      status['events'] = [
        for (var index = 0; index < 40; index++)
          '16/10 ${(59 - index).toString().padLeft(2, '0')}:00 • '
              'Conexão estável • Wi-Fi · CasaNet • evento $index',
      ];
    });

    testWidgets('on every tab, with a bottom safe-area inset', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      await pumpHome(tester);

      await expectEndAboveTabBar(
          tester,
          find
              .ancestor(
                  of: find.text('-55 dBm'), matching: find.byType(InkWell))
              .first);
      await tester.tap(find.text('Monitoria'));
      await tester.pumpAndSettle();
      await expectEndAboveTabBar(tester, find.text('Perda de pacotes na rota'));
      await tester.tap(find.text('Eventos'));
      await tester.pumpAndSettle();
      await expectEndAboveTabBar(tester, find.text('evento 39'));
    });

    testWidgets('in the empty states', (tester) async {
      status['events'] = <String>[];
      status['measurements'] = <Object>[];
      await tester.binding.setSurfaceSize(const Size(360, 560));
      await tester.pumpWidget(portugueseApp(const Home()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Eventos'));
      await tester.pumpAndSettle();
      await expectEndAboveTabBar(
          tester, find.text('As mudanças da conexão aparecerão aqui.'));
      await tester.tap(find.text('Monitoria'));
      await tester.pumpAndSettle();
      await expectEndAboveTabBar(
          tester, find.text('Nenhuma falha registrada nas últimas 24 horas.'));
    });
  });

  testWidgets('targets show their brand logo or flag', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    (status['measurements'] as List).add({
      'timestamp': now - 30000,
      'state': 'online',
      'latency': 12,
      'jitter': 1,
      'failureRate': 0,
      'transportType': 'wifi',
      'targetName': 'Cloudflare',
      'diagnosis': '',
      'signalLevel': 4,
    });
    await pumpHome(tester);
    // Home tag: Europa in use.
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Servidor · Europa'), matching: find.byType(Row)),
            matching: find.byType(CountryFlag)),
        findsOneWidget);

    await tester.tap(find.text('Monitoria'));
    await tester.pumpAndSettle();
    expect(find.byIcon(SimpleIcons.cloudflare), findsNothing);
    await tester.tap(find.text('Servidor analisado'));
    await tester.pumpAndSettle();
    expect(find.byIcon(SimpleIcons.cloudflare), findsOneWidget);
    // Trigger and menu row for Europa.
    expect(find.byType(CountryFlag), findsNWidgets(2));
    await tester.tap(find.text('Cloudflare'));
    await tester.pumpAndSettle();
    expect(find.byIcon(SimpleIcons.cloudflare), findsOneWidget);

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    // São Paulo, Estados Unidos and Europa cards.
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(CountryFlag)),
        findsNWidgets(3));
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    for (final glyph in [
      SimpleIcons.cloudflare,
      SimpleIcons.google,
      SimpleIcons.quad9,
    ]) {
      expect(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.byIcon(glyph)),
          findsOneWidget);
    }
  });

  testWidgets('eventos filters by day and summarises the range',
      (tester) async {
    String two(int value) => value.toString().padLeft(2, '0');
    String line(DateTime time, String text) =>
        '${two(time.day)}/${two(time.month)} '
        '${two(time.hour)}:${two(time.minute)} • $text';

    final today = DateTime.now();
    final noon = DateTime(today.year, today.month, today.day, 12);
    final older = noon.subtract(const Duration(days: 5));
    status['events'] = [
      line(DateTime(today.year, today.month, today.day, 0, 20),
          'Conexão restabelecida • Wi-Fi · CasaNet'),
      line(DateTime(today.year, today.month, today.day, 0, 10),
          'Internet indisponível • Wi-Fi · CasaNet'),
      line(noon.subtract(const Duration(days: 1)),
          'Conexão instável • Wi-Fi · CasaNet • Europa'),
      line(older, 'Conexão estável • Wi-Fi · CasaNet • Europa'),
    ];
    await pumpHome(tester);
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();

    final olderChip = '${two(older.day)}/${two(older.month)} · 1';
    for (final chip in ['Todos · 4', 'Hoje · 2', 'Ontem · 1']) {
      expect(find.text(chip), findsOneWidget);
    }
    // Older days sit further along the horizontal chip row.
    expect(find.text(olderChip), findsOneWidget);
    expect(find.text('Todos os dias'), findsOneWidget);
    expect(find.text('4 mudanças'), findsOneWidget);
    expect(find.text('HOJE'), findsOneWidget);

    await tester.ensureVisible(find.text('Ontem · 1'));
    await tester.tap(find.text('Ontem · 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 mudança'), findsOneWidget);
    expect(find.text('Conexão instável'), findsOneWidget);
    expect(find.text('Internet indisponível'), findsNothing);
    expect(find.text('HOJE'), findsNothing);

    await tester.ensureVisible(find.text('Hoje · 2'));
    await tester.tap(find.text('Hoje · 2'));
    await tester.pumpAndSettle();
    expect(find.text('2 mudanças'), findsOneWidget);
    expect(find.text('Internet indisponível'), findsOneWidget);
    expect(find.text('Conexão restabelecida'), findsOneWidget);
    expect(find.text('Conexão instável'), findsNothing);

    await tester.ensureVisible(find.text('Todos · 4'));
    await tester.tap(find.text('Todos · 4'));
    await tester.pumpAndSettle();
    expect(find.text('4 mudanças'), findsOneWidget);
  });

  testWidgets('native errors become a toast instead of a crash',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') return status;
      throw PlatformException(code: 'boom', message: 'Serviço indisponível');
    });
    await pumpHome(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Serviço indisponível'), findsOneWidget);
  });
}
