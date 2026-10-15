import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bridge = MethodChannel('wifiwarnme/monitor');
const bg = Color(0xFF07121E);
const accent = Color(0xFF20E3A2);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WifiWarnMe());
}

class WifiWarnMe extends StatelessWidget {
  const WifiWarnMe({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'WifiWarnMe',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool enabled = false;
  int interval = 2;
  int maxLatency = 300;
  String status = 'Monitoramento desligado';
  String transport = '—';
  List<String> events = [];
  Timer? refresh;

  @override
  void initState() {
    super.initState();
    load();
    refresh = Timer.periodic(const Duration(seconds: 3), (_) => sync());
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    interval = p.getInt('interval') ?? 2;
    maxLatency = p.getInt('maxLatency') ?? 300;
    await sync();
  }

  Future<void> sync() async {
    try {
      final data = Map<String, dynamic>.from(await bridge.invokeMethod('status'));
      if (!mounted) return;
      setState(() {
        enabled = data['enabled'] == true;
        status = data['status']?.toString() ?? 'Aguardando';
        transport = data['transport']?.toString() ?? '—';
        events = (data['events'] as List?)?.map((e) => e.toString()).toList() ?? [];
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => status = 'Erro: ${e.message}');
    }
  }

  Future<void> toggle(bool value) async {
    try {
      await bridge.invokeMethod(value ? 'start' : 'stop', {
        'interval': interval,
        'maxLatency': maxLatency,
      });
      await sync();
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Não foi possível alterar o monitoramento')),
      );
    }
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: bg, title: const Text('WifiWarnMe', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [IconButton(icon: const Icon(Icons.tune), onPressed: settings)]),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 36),
      Center(child: Container(
        width: 240, height: 240,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: enabled ? accent : Colors.blueGrey, width: 8),
          boxShadow: enabled ? [BoxShadow(color: accent.withValues(alpha: .13), blurRadius: 40)] : []),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(enabled ? Icons.wifi : Icons.wifi_off, size: 62, color: enabled ? accent : Colors.blueGrey),
          const SizedBox(height: 12),
          Text(enabled ? 'Monitorando' : 'Pausado', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ]),
      )),
      const SizedBox(height: 36),
      Card(child: SwitchListTile(
        title: const Text('Monitorar internet', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Alertas enquanto você usa o celular'),
        value: enabled, activeColor: accent, onChanged: toggle,
      )),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.network_check, color: accent),
        title: const Text('Conexão atual'), subtitle: Text(transport))),
      const SizedBox(height: 28),
      const Text('Últimos eventos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (events.isEmpty) const Text('Os eventos aparecerão aqui.', style: TextStyle(color: Colors.white60)),
      ...events.take(15).map((e) => Card(child: ListTile(leading: const Icon(Icons.bolt), title: Text(e)))),
    ]),
  );

  Future<void> settings() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) =>
      StatefulBuilder(builder: (context, update) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ajustes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Verificar a cada'),
          DropdownButton<int>(value: interval, isExpanded: true, items: [1, 2, 5, 10, 15]
            .map((n) => DropdownMenuItem(value: n, child: Text('$n minuto(s)'))).toList(),
            onChanged: (n) => update(() => interval = n!)),
          const SizedBox(height: 12),
          Text('Alerta de latência acima de $maxLatency ms'),
          Slider(min: 100, max: 1000, divisions: 18, value: maxLatency.toDouble(),
            onChanged: (v) => update(() => maxLatency = v.round())),
          const SizedBox(height: 12),
          FilledButton(onPressed: () async {
            final p = await SharedPreferences.getInstance();
            await p.setInt('interval', interval);
            await p.setInt('maxLatency', maxLatency);
            if (enabled) await bridge.invokeMethod('configure', {'interval': interval, 'maxLatency': maxLatency});
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('Salvar')),
        ]),
      )),
    );
    if (mounted) setState(() {});
  }
}
