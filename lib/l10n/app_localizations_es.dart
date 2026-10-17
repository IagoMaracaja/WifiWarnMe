// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tabConnection => 'Conexión';

  @override
  String get tabMonitoring => 'Monitoreo';

  @override
  String get tabEvents => 'Eventos';

  @override
  String get tabNetwork => 'Red';

  @override
  String get subtitleConnection => 'Conexión ahora';

  @override
  String get subtitleMonitoring => 'Últimas 24 horas';

  @override
  String get subtitleEvents => 'Historial';

  @override
  String get subtitleNetwork => 'Dispositivos y causas';

  @override
  String get nightModeTurnOff => 'Desactivar modo nocturno';

  @override
  String get nightModeTurnOn => 'Activar modo nocturno';

  @override
  String get settings => 'Ajustes';

  @override
  String get statusPaused => 'En pausa';

  @override
  String get statusMeasuring => 'Midiendo';

  @override
  String get stateStable => 'Estable';

  @override
  String get stateUnstable => 'Inestable';

  @override
  String get stateNoResponse => 'Sin respuesta';

  @override
  String get noResponseLower => 'sin respuesta';

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
  String get monitoringPaused => 'Monitoreo en pausa';

  @override
  String get checkingNow => 'Comprobando ahora';

  @override
  String get preparingCheck => 'Preparando comprobación';

  @override
  String nextCheckIn(Object time) {
    return 'Próxima en $time';
  }

  @override
  String get monitorUnreachable => 'No se pudo comunicar con el monitor';

  @override
  String get wifiNameSheetTitle => 'Mostrar el nombre del Wi-Fi';

  @override
  String get wifiNameSheetSubtitle => 'Permiso de ubicación precisa';

  @override
  String get wifiNameExplanation =>
      'Android solo revela el nombre de la red a las apps con ubicación precisa. Linkzora usa este permiso únicamente para identificar el Wi-Fi y leer la intensidad de la señal; ninguna ubicación se guarda ni se envía.';

  @override
  String get notNow => 'Ahora no';

  @override
  String get continueAction => 'Continuar';

  @override
  String get wifiNameEnabled => 'Nombre de la red habilitado.';

  @override
  String get wifiNameDenied =>
      'Sin el permiso, la red aparece solo como Wi-Fi.';

  @override
  String get identifyNetworkFailed => 'No se pudo identificar la red';

  @override
  String get settingsApplied => 'Ajustes aplicados al monitor.';

  @override
  String serverTag(Object name) {
    return 'Servidor · $name';
  }

  @override
  String get noReading => 'Sin lectura';

  @override
  String readingDetails(Object jitter, Object loss, Object ok, Object total) {
    return 'Jitter $jitter ms · Pérdida $loss% · $ok/$total';
  }

  @override
  String get awaitingSamples => 'Esperando muestras';

  @override
  String get monitoringTitle => 'Monitoreo';

  @override
  String get monitoringActive => 'Activo en segundo plano';

  @override
  String get monitoringInactive => 'Actívalo para medir tu conexión';

  @override
  String get changeAlerts => 'Alertas de cambio';

  @override
  String get identifyNetwork => 'Identificar esta red';

  @override
  String get identifyNetworkHint => 'Mostrar el nombre y la señal del Wi-Fi';

  @override
  String get metricInterval => 'Intervalo';

  @override
  String get metricLimit => 'Límite';

  @override
  String get metricSignal => 'Señal';

  @override
  String get transportMobile => 'Móvil';

  @override
  String get transportCable => 'Cable';

  @override
  String get signalWeak => 'Débil';

  @override
  String get signalFair => 'Regular';

  @override
  String get signalGood => 'Buena';

  @override
  String signalQuality(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'débil',
        'fair': 'regular',
        'other': 'buena',
      },
    );
    return '$_temp0';
  }

  @override
  String get awaitingFirstMeasurement => 'Esperando la primera medición.';

  @override
  String get serverSummary => 'Resumen del servidor';

  @override
  String get oscillations => 'Oscilaciones';

  @override
  String get bestHour => 'Mejor horario';

  @override
  String get collectingData => 'Recopilando datos';

  @override
  String hourRange(Object from, Object to) {
    return '${from}h–${to}h';
  }

  @override
  String get latencyPulse => 'Pulso de la latencia';

  @override
  String get tapForDetails => 'Toca para ver detalles';

  @override
  String latencyNow(Object value) {
    return 'Ahora $value ms';
  }

  @override
  String get jitterBand => 'Banda de jitter';

  @override
  String get statMinimum => 'Mínima';

  @override
  String get statMedian => 'Mediana';

  @override
  String get statPeak => 'Pico (p95)';

  @override
  String get statJitter => 'Jitter medio';

  @override
  String get probableCause => 'Causa probable';

  @override
  String get awaitingMeasurements => 'Esperando mediciones';

  @override
  String get evidenceNoSample =>
      'Haz una medición para analizar este servidor.';

  @override
  String evidenceWifiSignal(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'señal Wi-Fi débil',
        'fair': 'señal Wi-Fi regular',
        'other': 'señal Wi-Fi buena',
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
    return 'pérdida $value%';
  }

  @override
  String get failurePeriods => 'Períodos con fallas';

  @override
  String get unknownCause => 'Causa no identificada';

  @override
  String get noConnection => 'Sin conexión';

  @override
  String get unstableConnection => 'Conexión inestable';

  @override
  String olderPeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count períodos anteriores',
      one: '+ 1 período anterior',
    );
    return '$_temp0';
  }

  @override
  String get noFailures24h =>
      'Ninguna falla registrada en las últimas 24 horas.';

  @override
  String get chartNow => 'ahora';

  @override
  String chartLimit(Object value) {
    return 'límite $value ms';
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
      other: '$count mediciones · 24 h',
      one: '1 medición · 24 h',
    );
    return '$_temp0';
  }

  @override
  String get analyzedServer => 'Servidor analizado';

  @override
  String get inUse => 'EN USO';

  @override
  String get unknownTarget => 'Destino no identificado';

  @override
  String get alertNone => 'Sin alertas';

  @override
  String get alertNoneDescription => 'Solo la notificación fija del monitor.';

  @override
  String get alertOnce => 'Una vez por sesión';

  @override
  String get alertOnceDescription =>
      'Avisa en el primer cambio tras activarlo.';

  @override
  String get alertChanges => 'En cada cambio';

  @override
  String get alertChangesDescription => 'Avisa siempre que la conexión cambie.';

  @override
  String get alertSheetSubtitle => 'Cuándo Linkzora debe llamar tu atención';

  @override
  String get noEventsTitle => 'Ningún evento todavía';

  @override
  String get noEventsText => 'Los cambios de la conexión aparecerán aquí.';

  @override
  String get allDays => 'Todos los días';

  @override
  String get filterAll => 'Todos';

  @override
  String eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
    );
    return '$_temp0';
  }

  @override
  String changeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios',
      one: '1 cambio',
    );
    return '$_temp0';
  }

  @override
  String get summaryDrops => 'Caídas';

  @override
  String get summaryInstabilities => 'Inestabilidades';

  @override
  String get summaryRecoveries => 'Se estabilizó';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get noDate => 'Sin fecha';

  @override
  String dayMonth(Object day, Object month) {
    return '$day/$month';
  }

  @override
  String get settingsSubtitle =>
      'Ritmo de las mediciones y destino de la prueba';

  @override
  String get nightMode => 'Modo nocturno';

  @override
  String get nightModeSubtitle => 'Tema oscuro en toda la app';

  @override
  String get saveSettings => 'Guardar ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageSystemHint => 'Sigue el idioma del dispositivo';

  @override
  String get testLocation => 'Lugar de la prueba';

  @override
  String get nearbyServer => 'Servidor cercano';

  @override
  String serverAddress(Object address) {
    return 'Dirección $address · anycast';
  }

  @override
  String get locationNear => 'Cercano';

  @override
  String get locationSaoPaulo => 'São Paulo';

  @override
  String get locationUnitedStates => 'Estados Unidos';

  @override
  String get locationEurope => 'Europa';

  @override
  String get locationNearDetail => 'Anycast · ruta más corta disponible';

  @override
  String get locationSaoPauloDetail => 'AWS · sa-east-1';

  @override
  String get locationUnitedStatesDetail => 'AWS · Virginia · us-east-1';

  @override
  String get locationEuropeDetail => 'AWS · Irlanda · eu-west-1';

  @override
  String get checkEvery => 'Comprobar cada';

  @override
  String get alertAbove => 'Avisar por encima de';

  @override
  String get customLimit => 'Personalizado';

  @override
  String get limitTypeError => 'Escribe el límite en milisegundos.';

  @override
  String limitRangeError(Object min, Object max) {
    return 'Usa un valor entre $min y $max ms.';
  }

  @override
  String limitRangeHint(Object min, Object max) {
    return 'Entre $min y $max ms.';
  }

  @override
  String get limitHintExample => 'Ej.: 450';

  @override
  String get limitFootnote =>
      'Cada comprobación usa 5 conexiones y confirma los resultados sospechosos con 5 más.';

  @override
  String get donationTitle => '¿Te gusta Linkzora?';

  @override
  String get donationMessage =>
      '¿Te gusta la app? ¿Qué tal invitarle un cafecito a este dev? ;)';

  @override
  String get donationButton => 'Invitar un cafecito';

  @override
  String get donationOpenFailed =>
      'No se pudo abrir el enlace. Visita buymeacoffee.com/andremaracaja';

  @override
  String get donationDismiss => 'Descartar';

  @override
  String get back => 'Volver';

  @override
  String get setUp => 'Configurar';

  @override
  String get skip => 'Omitir';

  @override
  String get allow => 'Permitir';

  @override
  String get startMonitoring => 'Iniciar monitoreo';

  @override
  String get permissionRequestFailed => 'No se pudo pedir el permiso';

  @override
  String get startFailed => 'No se pudo iniciar el monitoreo';

  @override
  String get welcomeTitle => 'Te damos la bienvenida a Linkzora';

  @override
  String get welcomeText =>
      'Entérate de cuándo internet se cae, fluctúa o se vuelve lenta, sin gastar datos ni batería.';

  @override
  String get featureBackgroundTitle => 'Medición en segundo plano';

  @override
  String get featureBackgroundText =>
      'Latencia, jitter y pérdida cada pocos minutos.';

  @override
  String get featureAlertsTitle => 'Alertas en el momento justo';

  @override
  String get featureAlertsText => 'Aviso cuando la conexión se cae o vuelve.';

  @override
  String get featureCauseText =>
      'Wi-Fi, ruta o servidor, y el mejor horario de uso.';

  @override
  String get setupTime => 'Configurarlo lleva menos de un minuto.';

  @override
  String get targetStepTitle => 'Hacia dónde medir';

  @override
  String get targetStepSubtitle =>
      'El destino de las conexiones de prueba. \"Cercano\" usa la ruta más corta disponible y sirve para la mayoría.';

  @override
  String get alertsStepSubtitle =>
      'Cuándo Linkzora debe llamar tu atención si la conexión se cae o fluctúa.';

  @override
  String get rhythmStepTitle => 'Ritmo de las mediciones';

  @override
  String get rhythmStepSubtitle =>
      'Los intervalos cortos detectan caídas antes; los largos ahorran batería.';

  @override
  String get wifiStepTitle => 'Nombre del Wi-Fi';

  @override
  String get wifiStepSubtitle => 'Opcional · permiso de ubicación precisa';

  @override
  String get wifiStepNote =>
      'Sin él, la red aparece solo como \"Wi-Fi\". Puedes permitirlo después en la pantalla Conexión.';

  @override
  String get summaryStepTitle => 'Todo listo';

  @override
  String get summaryStepSubtitle =>
      'Revisa lo que elegiste. Todo se puede cambiar después en Ajustes.';

  @override
  String get summaryServer => 'Servidor';

  @override
  String get summaryAlerts => 'Alertas';

  @override
  String get summaryLimit => 'Límite de latencia';

  @override
  String get wifiNameShown => 'Habilitado';

  @override
  String get wifiNameHidden => 'Oculto';

  @override
  String get kindRouter => 'Router';

  @override
  String get kindTv => 'TV o streaming';

  @override
  String get kindPhone => 'Móvil o tableta';

  @override
  String get kindComputer => 'Computadora';

  @override
  String get kindPrinter => 'Impresora';

  @override
  String get kindConsole => 'Consola de juegos';

  @override
  String get kindSpeaker => 'Asistente o altavoz';

  @override
  String get kindCamera => 'Cámara';

  @override
  String get kindIot => 'Hogar inteligente (IoT)';

  @override
  String get kindUnknown => 'Tipo desconocido';

  @override
  String deviceUnnamed(Object suffix) {
    return 'Dispositivo .$suffix';
  }

  @override
  String confidence(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'confianza alta',
        'medium': 'confianza media',
        'other': 'confianza baja',
      },
    );
    return '$_temp0';
  }

  @override
  String interferenceLevel(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'Interferencia alta',
        'medium': 'Interferencia media',
        'other': 'Interferencia baja',
      },
    );
    return '$_temp0';
  }

  @override
  String bandGhz(Object band) {
    return '$band GHz';
  }

  @override
  String get causeIsp => 'Operador / internet';

  @override
  String get causeInterference => 'Interferencia Wi-Fi';

  @override
  String get causeSignal => 'Señal débil de tu dispositivo';

  @override
  String get causeUnknown => 'Sin causa identificada';

  @override
  String reasonHeavyKind(Object kind) {
    return '$kind: suele usar mucho ancho de banda';
  }

  @override
  String reasonLift(Object present, Object absent) {
    return 'Inestable en el $present de las comprobaciones con él en la red, frente al $absent sin él';
  }

  @override
  String get reasonNoWorse => 'La conexión no empeora cuando está en la red';

  @override
  String get reasonAlwaysPresent =>
      'Siempre presente: no hay períodos sin él para comparar';

  @override
  String get reasonNoPresence => 'Todavía sin historial de presencia';

  @override
  String reasonJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entró en la red poco antes de $count períodos de falla',
      one: 'Entró en la red poco antes de 1 período de falla',
    );
    return '$_temp0';
  }

  @override
  String reasonSlowLocal(Object latency, Object jitter) {
    return 'Respuesta local lenta u oscilante ($latency ms, jitter $jitter ms)';
  }

  @override
  String get reasonPhonePowerSave =>
      '; los móviles en ahorro de energía responden despacio, peso reducido';

  @override
  String get reasonNotInLastScan => 'No apareció en el último escaneo';

  @override
  String get pairedNone =>
      'Todavía no hay mediciones del router junto a las fallas';

  @override
  String pairedGood(int count, Object paired) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En $count fallas de $paired el router respondía bien',
      one: 'En 1 falla de $paired el router respondía bien',
    );
    return '$_temp0';
  }

  @override
  String nowRouterInternet(Object router, Object internet) {
    return 'Ahora: router $router × internet $internet';
  }

  @override
  String get ispIncludes =>
      'Incluye la ruta hasta el servidor y el uso intenso de internet en casa';

  @override
  String networksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redes',
      one: '1 red',
    );
    return '$_temp0';
  }

  @override
  String overlappingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count superpuestas',
      one: '1 superpuesta',
    );
    return '$_temp0';
  }

  @override
  String neighborNetworksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redes vecinas',
      one: '1 red vecina',
    );
    return '$_temp0';
  }

  @override
  String reasonChannels(
      Object same, Object overlapping, Object channel, Object band) {
    return '$same en el mismo canal y $overlapping (canal $channel, $band)';
  }

  @override
  String reasonInterferenceAmong(Object interference, Object neighbors) {
    return '$interference entre $neighbors';
  }

  @override
  String reasonFreeChannel(Object channel) {
    return 'El canal $channel está más libre';
  }

  @override
  String get reasonNoNeighbors =>
      'Redes vecinas no disponibles (permite la ubicación)';

  @override
  String reasonWeakFailures(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallas de $total con señal débil',
      one: '1 falla de $total con señal débil',
    );
    return '$_temp0';
  }

  @override
  String reasonSignalNow(Object rssi, Object quality) {
    return 'Señal actual $rssi dBm ($quality)';
  }

  @override
  String get reasonNoInstability =>
      'Ninguna inestabilidad en el Wi-Fi en las últimas 24 h';

  @override
  String reasonUnexplained(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count comprobaciones inestables de $total; una parte no tiene explicación observable',
      one:
          '1 comprobación inestable de $total; una parte no tiene explicación observable',
    );
    return '$_temp0';
  }

  @override
  String locationNow(Object router, Object internet) {
    return ' Ahora: router $router, internet $internet.';
  }

  @override
  String get locationNoneTitle => 'Ningún problema reciente';

  @override
  String locationNoneDetail(Object now) {
    return 'Sin inestabilidad en el Wi-Fi en las últimas 24 h.$now';
  }

  @override
  String get locationUnknownTitle => 'Todavía no concluyente';

  @override
  String get locationUnknownDetail =>
      'Escanea la red y mantén el monitoreo activo para comparar el router con internet.';

  @override
  String get locationLocalTitle => 'Red local (Wi-Fi/casa)';

  @override
  String locationLocalDetail(Object now) {
    return 'El router también se vuelve lento o pierde paquetes cuando la conexión empeora: señal, interferencia o dispositivos de la casa.$now';
  }

  @override
  String locationIspDetail(Object now) {
    return 'El Wi-Fi hasta el router sigue bien cuando la conexión empeora. El cuello de botella está después: operador, ruta o el internet de la casa saturado por algún dispositivo.$now';
  }

  @override
  String get locationMixedTitle => 'De ambos lados';

  @override
  String locationMixedDetail(Object now) {
    return 'Hay fallas con el router lento y fallas con él normal.$now';
  }

  @override
  String get scanJustNow => 'justo ahora';

  @override
  String scanMinutesAgo(Object minutes) {
    return 'hace $minutes min';
  }

  @override
  String scanTodayAt(Object time) {
    return 'hoy a las $time';
  }

  @override
  String scanOnDate(Object date, Object time) {
    return 'el $date $time';
  }

  @override
  String get sourceHistory => 'historial';

  @override
  String get scanPreparing => 'Preparando';

  @override
  String get scanNeedsWifi =>
      'Conecta el móvil a un Wi-Fi para escanear la red.';

  @override
  String get scanFailed => 'No se pudo escanear la red.';

  @override
  String get scanUnavailable => 'Escaneo no disponible';

  @override
  String get neighborsHidden => 'Redes vecinas ocultas';

  @override
  String get neighborsLocationOff =>
      'Activa la ubicación del dispositivo: Android lo exige para listar las redes Wi-Fi vecinas.';

  @override
  String get neighborsPermission =>
      'Android solo muestra las redes vecinas con el permiso de ubicación precisa y la app abierta.';

  @override
  String get probableContribution => 'Contribución probable';

  @override
  String get noMeasurementsLower => 'sin mediciones';

  @override
  String unstableOfTotal(Object unstable, Object total) {
    return '$unstable/$total inestables en 24 h';
  }

  @override
  String get devicesOnNetwork => 'Dispositivos en la red';

  @override
  String devicesOnNetworkCount(Object count) {
    return 'Dispositivos en la red ($count)';
  }

  @override
  String scannedAgo(Object age) {
    return 'escaneado $age';
  }

  @override
  String get noScanTitle => 'Ningún escaneo todavía';

  @override
  String get noScanText =>
      'Toca \"Escanear ahora\" para listar los dispositivos conectados a tu Wi-Fi.';

  @override
  String get wifiEnvironment => 'Entorno Wi-Fi';

  @override
  String get howToReadTitle => 'Cómo leer estos números';

  @override
  String get howToReadMonitoring =>
      'Android no deja que una app vea el consumo de ancho de banda de cada dispositivo ni las direcciones MAC de la red. Los porcentajes son estimaciones: cruzan tus mediciones con la latencia del router, las redes vecinas y qué dispositivos estaban conectados en cada momento (inventario cada 15 min mientras el monitoreo está activo).';

  @override
  String get howToReadIdle =>
      'Android no deja que una app vea el consumo de ancho de banda de cada dispositivo ni las direcciones MAC de la red. Los porcentajes son estimaciones: cruzan tus mediciones con la latencia del router, las redes vecinas y qué dispositivos estaban conectados en cada momento. Activa el monitoreo para registrar la presencia de los dispositivos cada 15 min.';

  @override
  String get onlyRouterAndPhone =>
      'Solo respondieron el router y este dispositivo.';

  @override
  String get whereIsTheProblem => 'Dónde está el problema';

  @override
  String get localNetwork => 'Red local';

  @override
  String get provider => 'Operador';

  @override
  String get internet => 'Internet';

  @override
  String get scanNow => 'Escanear ahora';

  @override
  String lastScan(Object age) {
    return 'Último escaneo $age';
  }

  @override
  String scanDuration(Object seconds) {
    return '$seconds s';
  }

  @override
  String get scanning => 'Escaneando…';

  @override
  String get scanTakesAbout => 'Tarda unos 15 segundos. Mantén la app abierta.';

  @override
  String get networkDevices => 'Dispositivos de la red';

  @override
  String largestShare(Object name, Object percent) {
    return 'Mayor parte: $name ($percent%)';
  }

  @override
  String get probableLower => 'probable';

  @override
  String get breakdownExplanation =>
      'Mayor contribución estimada. Los porcentajes suman 100% y muestran el peso probable de cada causa, no el consumo de ancho de banda.';

  @override
  String get yourRouter => 'Tu router';

  @override
  String get thisDevice => 'Este dispositivo';

  @override
  String localLatency(Object value) {
    return 'local $value';
  }

  @override
  String jitterMs(Object value) {
    return 'jitter $value ms';
  }

  @override
  String get absent => 'ausente';

  @override
  String get showLess => 'Menos';

  @override
  String get why => '¿Por qué?';

  @override
  String get onlyKindWeight =>
      'Solo el peso del tipo de dispositivo; sin otras evidencias.';

  @override
  String sources(Object list) {
    return 'Fuentes: $list';
  }

  @override
  String get noNeighborsTitle => 'Sin datos de las redes vecinas';

  @override
  String get noNeighborsScan =>
      'Escanea la red para analizar canal, señal e interferencia.';

  @override
  String get noNeighborsAndroid =>
      'Android no entregó la lista de redes Wi-Fi en este escaneo.';

  @override
  String get yourWifi => 'Tu Wi-Fi';

  @override
  String get cachedData => 'datos en caché';

  @override
  String get wifiBand => 'Banda';

  @override
  String get wifiChannel => 'Canal';

  @override
  String neighborsSummary(Object same, Object partial, Object total) {
    return '$same en el mismo canal · $partial superpuestas · $total redes vecinas';
  }

  @override
  String channelTip(Object channel) {
    return 'Consejo: el canal $channel está más libre. Cámbialo en la configuración del router.';
  }

  @override
  String get interferenceBar => 'Interferencia de redes vecinas';

  @override
  String get ownNetworkTag => 'tu red';

  @override
  String get neighborsWeak =>
      'Las redes vecinas en tu canal tienen señal débil y apenas afectan tu conexión.';

  @override
  String ownNetworksNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos de acceso de tu red no se cuentan',
      one: '1 punto de acceso de tu red no se cuenta',
    );
    return '$_temp0';
  }

  @override
  String get diagNoNetwork => 'Sin red activa en el dispositivo';

  @override
  String get diagCaptivePortal =>
      'La red exige inicio de sesión (portal cautivo)';

  @override
  String get diagDns => 'Error al resolver la dirección del servidor (DNS)';

  @override
  String get diagNoInternet => 'Red conectada, pero sin acceso a internet';

  @override
  String get diagWeakWifiOffline =>
      'Señal Wi-Fi demasiado débil para mantener la conexión';

  @override
  String get diagServerNoResponse => 'Servidor o ruta sin respuesta';

  @override
  String get diagWeakWifiStable => 'Señal Wi-Fi débil, pero conexión estable';

  @override
  String get diagNoAnomaly => 'Ninguna anomalía detectada';

  @override
  String get diagWeakWifi => 'Señal Wi-Fi débil';

  @override
  String get diagPacketLoss => 'Pérdida de paquetes en la ruta';

  @override
  String get diagHighJitter => 'Oscilación alta en la ruta';

  @override
  String diagRegionalDistance(Object target) {
    return 'La distancia hasta $target influye en la latencia';
  }

  @override
  String get diagCongested => 'Ruta congestionada o servidor lejano';

  @override
  String get eventStable => 'Conexión estable';

  @override
  String get eventUnstable => 'Conexión inestable';

  @override
  String get eventOffline => 'Internet no disponible';

  @override
  String get eventRestored => 'Conexión restablecida';

  @override
  String get eventBackUnstable => 'La conexión volvió, pero inestable';

  @override
  String get eventChecking => 'Comprobando conexión';

  @override
  String get transportMobileData => 'Datos móviles';

  @override
  String get transportNoNetwork => 'Sin red';
}
