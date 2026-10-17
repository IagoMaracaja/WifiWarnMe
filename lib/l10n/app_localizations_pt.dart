// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabConnection => 'Conexão';

  @override
  String get tabMonitoring => 'Monitoria';

  @override
  String get tabEvents => 'Eventos';

  @override
  String get tabNetwork => 'Rede';

  @override
  String get subtitleConnection => 'Conexão agora';

  @override
  String get subtitleMonitoring => 'Últimas 24 horas';

  @override
  String get subtitleEvents => 'Histórico';

  @override
  String get subtitleNetwork => 'Aparelhos e causas';

  @override
  String get nightModeTurnOff => 'Desligar modo noturno';

  @override
  String get nightModeTurnOn => 'Ligar modo noturno';

  @override
  String get settings => 'Ajustes';

  @override
  String get statusPaused => 'Pausado';

  @override
  String get statusMeasuring => 'Medindo';

  @override
  String get stateStable => 'Estável';

  @override
  String get stateUnstable => 'Instável';

  @override
  String get stateNoResponse => 'Sem resposta';

  @override
  String get noResponseLower => 'sem resposta';

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
  String get monitoringPaused => 'Monitoramento pausado';

  @override
  String get checkingNow => 'Verificando agora';

  @override
  String get preparingCheck => 'Preparando verificação';

  @override
  String nextCheckIn(Object time) {
    return 'Próxima em $time';
  }

  @override
  String get monitorUnreachable => 'Não foi possível falar com o monitor';

  @override
  String get wifiNameSheetTitle => 'Mostrar o nome do Wi-Fi';

  @override
  String get wifiNameSheetSubtitle => 'Permissão de localização precisa';

  @override
  String get wifiNameExplanation =>
      'O Android só revela o nome da rede para apps com localização precisa. O Linkzora usa essa permissão apenas para identificar o Wi-Fi e ler a intensidade do sinal; nenhuma localização é salva ou enviada.';

  @override
  String get notNow => 'Agora não';

  @override
  String get continueAction => 'Continuar';

  @override
  String get wifiNameEnabled => 'Nome da rede habilitado.';

  @override
  String get wifiNameDenied =>
      'Sem a permissão, a rede aparece apenas como Wi-Fi.';

  @override
  String get identifyNetworkFailed => 'Não foi possível identificar a rede';

  @override
  String get settingsApplied => 'Ajustes aplicados ao monitor.';

  @override
  String serverTag(Object name) {
    return 'Servidor · $name';
  }

  @override
  String get noReading => 'Sem leitura';

  @override
  String readingDetails(Object jitter, Object loss, Object ok, Object total) {
    return 'Jitter $jitter ms · Perda $loss% · $ok/$total';
  }

  @override
  String get awaitingSamples => 'Aguardando amostras';

  @override
  String get monitoringTitle => 'Monitoramento';

  @override
  String get monitoringActive => 'Ativo em segundo plano';

  @override
  String get monitoringInactive => 'Ative para medir sua conexão';

  @override
  String get changeAlerts => 'Alertas de mudança';

  @override
  String get identifyNetwork => 'Identificar esta rede';

  @override
  String get identifyNetworkHint => 'Mostrar o nome e o sinal do Wi-Fi';

  @override
  String get metricInterval => 'Intervalo';

  @override
  String get metricLimit => 'Limite';

  @override
  String get metricSignal => 'Sinal';

  @override
  String get transportMobile => 'Móvel';

  @override
  String get transportCable => 'Cabo';

  @override
  String get signalWeak => 'Fraco';

  @override
  String get signalFair => 'Regular';

  @override
  String get signalGood => 'Bom';

  @override
  String signalQuality(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'fraco',
        'fair': 'regular',
        'other': 'bom',
      },
    );
    return '$_temp0';
  }

  @override
  String get awaitingFirstMeasurement => 'Aguardando a primeira medição.';

  @override
  String get serverSummary => 'Resumo do servidor';

  @override
  String get oscillations => 'Oscilações';

  @override
  String get bestHour => 'Melhor horário';

  @override
  String get collectingData => 'Coletando dados';

  @override
  String hourRange(Object from, Object to) {
    return '${from}h–${to}h';
  }

  @override
  String get latencyPulse => 'Pulso da latência';

  @override
  String get tapForDetails => 'Toque para detalhes';

  @override
  String latencyNow(Object value) {
    return 'Agora $value ms';
  }

  @override
  String get jitterBand => 'Faixa de jitter';

  @override
  String get statMinimum => 'Mínima';

  @override
  String get statMedian => 'Mediana';

  @override
  String get statPeak => 'Pico (p95)';

  @override
  String get statJitter => 'Jitter médio';

  @override
  String get probableCause => 'Causa provável';

  @override
  String get awaitingMeasurements => 'Aguardando medições';

  @override
  String get evidenceNoSample =>
      'Faça uma medição para analisar este servidor.';

  @override
  String evidenceWifiSignal(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'weak': 'sinal Wi-Fi fraco',
        'fair': 'sinal Wi-Fi regular',
        'other': 'sinal Wi-Fi bom',
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
    return 'perda $value%';
  }

  @override
  String get failurePeriods => 'Períodos com falhas';

  @override
  String get unknownCause => 'Causa não identificada';

  @override
  String get noConnection => 'Sem conexão';

  @override
  String get unstableConnection => 'Conexão instável';

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
  String get noFailures24h => 'Nenhuma falha registrada nas últimas 24 horas.';

  @override
  String get chartNow => 'agora';

  @override
  String chartLimit(Object value) {
    return 'limite $value ms';
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
      other: '$count medições · 24 h',
      one: '1 medição · 24 h',
    );
    return '$_temp0';
  }

  @override
  String get analyzedServer => 'Servidor analisado';

  @override
  String get inUse => 'EM USO';

  @override
  String get unknownTarget => 'Destino não identificado';

  @override
  String get alertNone => 'Sem alertas';

  @override
  String get alertNoneDescription => 'Só a notificação fixa do monitor.';

  @override
  String get alertOnce => 'Uma vez por sessão';

  @override
  String get alertOnceDescription => 'Avisa na primeira mudança após ativar.';

  @override
  String get alertChanges => 'A cada mudança';

  @override
  String get alertChangesDescription => 'Avisa sempre que a conexão mudar.';

  @override
  String get alertSheetSubtitle => 'Quando o Linkzora deve chamar sua atenção';

  @override
  String get noEventsTitle => 'Nenhum evento ainda';

  @override
  String get noEventsText => 'As mudanças da conexão aparecerão aqui.';

  @override
  String get allDays => 'Todos os dias';

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
      other: '$count mudanças',
      one: '1 mudança',
    );
    return '$_temp0';
  }

  @override
  String get summaryDrops => 'Quedas';

  @override
  String get summaryInstabilities => 'Instabilidades';

  @override
  String get summaryRecoveries => 'Estabilizou';

  @override
  String get today => 'Hoje';

  @override
  String get yesterday => 'Ontem';

  @override
  String get noDate => 'Sem data';

  @override
  String dayMonth(Object day, Object month) {
    return '$day/$month';
  }

  @override
  String get settingsSubtitle => 'Ritmo das medições e destino do teste';

  @override
  String get nightMode => 'Modo noturno';

  @override
  String get nightModeSubtitle => 'Tema escuro em todo o app';

  @override
  String get saveSettings => 'Salvar ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageSystemHint => 'Segue o idioma do aparelho';

  @override
  String get testLocation => 'Local do teste';

  @override
  String get nearbyServer => 'Servidor próximo';

  @override
  String serverAddress(Object address) {
    return 'Endereço $address · anycast';
  }

  @override
  String get locationNear => 'Próximo';

  @override
  String get locationSaoPaulo => 'São Paulo';

  @override
  String get locationUnitedStates => 'Estados Unidos';

  @override
  String get locationEurope => 'Europa';

  @override
  String get locationNearDetail => 'Anycast · menor rota disponível';

  @override
  String get locationSaoPauloDetail => 'AWS · sa-east-1';

  @override
  String get locationUnitedStatesDetail => 'AWS · Virgínia · us-east-1';

  @override
  String get locationEuropeDetail => 'AWS · Irlanda · eu-west-1';

  @override
  String get checkEvery => 'Verificar a cada';

  @override
  String get alertAbove => 'Avisar acima de';

  @override
  String get customLimit => 'Personalizado';

  @override
  String get limitTypeError => 'Digite o limite em milissegundos.';

  @override
  String limitRangeError(Object min, Object max) {
    return 'Use um valor entre $min e $max ms.';
  }

  @override
  String limitRangeHint(Object min, Object max) {
    return 'Entre $min e $max ms.';
  }

  @override
  String get limitHintExample => 'Ex.: 450';

  @override
  String get limitFootnote =>
      'Cada verificação usa 5 conexões e confirma resultados suspeitos com mais 5.';

  @override
  String get donationTitle => 'Gostando do Linkzora?';

  @override
  String get donationMessage =>
      'Gostando do app? Que tal pagar um cafezinho pra esse dev ;)';

  @override
  String get donationButton => 'Pagar um cafezinho';

  @override
  String get donationOpenFailed =>
      'Não foi possível abrir o link. Acesse buymeacoffee.com/andremaracaja';

  @override
  String get donationDismiss => 'Dispensar';

  @override
  String get back => 'Voltar';

  @override
  String get setUp => 'Configurar';

  @override
  String get skip => 'Pular';

  @override
  String get allow => 'Permitir';

  @override
  String get startMonitoring => 'Começar monitoramento';

  @override
  String get permissionRequestFailed => 'Não foi possível pedir a permissão';

  @override
  String get startFailed => 'Não foi possível iniciar o monitoramento';

  @override
  String get welcomeTitle => 'Boas-vindas ao Linkzora';

  @override
  String get welcomeText =>
      'Saiba quando a internet cai, oscila ou fica lenta, sem gastar dados nem bateria.';

  @override
  String get featureBackgroundTitle => 'Medição em segundo plano';

  @override
  String get featureBackgroundText =>
      'Latência, jitter e perda a cada poucos minutos.';

  @override
  String get featureAlertsTitle => 'Alertas na hora certa';

  @override
  String get featureAlertsText => 'Aviso quando a conexão cai ou volta.';

  @override
  String get featureCauseText =>
      'Wi-Fi, rota ou servidor, e o melhor horário de uso.';

  @override
  String get setupTime => 'Leva menos de um minuto para configurar.';

  @override
  String get targetStepTitle => 'Para onde medir';

  @override
  String get targetStepSubtitle =>
      'O destino das conexões de teste. \"Próximo\" usa a menor rota disponível e serve para a maioria.';

  @override
  String get alertsStepSubtitle =>
      'Quando o Linkzora deve chamar sua atenção se a conexão cair ou oscilar.';

  @override
  String get rhythmStepTitle => 'Ritmo das medições';

  @override
  String get rhythmStepSubtitle =>
      'Intervalos curtos detectam quedas mais cedo; longos economizam bateria.';

  @override
  String get wifiStepTitle => 'Nome do Wi-Fi';

  @override
  String get wifiStepSubtitle => 'Opcional · permissão de localização precisa';

  @override
  String get wifiStepNote =>
      'Sem ela, a rede aparece apenas como \"Wi-Fi\". Você pode permitir depois na tela Conexão.';

  @override
  String get summaryStepTitle => 'Tudo pronto';

  @override
  String get summaryStepSubtitle =>
      'Confira as escolhas. Tudo pode ser mudado depois em Ajustes.';

  @override
  String get summaryServer => 'Servidor';

  @override
  String get summaryAlerts => 'Alertas';

  @override
  String get summaryLimit => 'Limite de latência';

  @override
  String get wifiNameShown => 'Habilitado';

  @override
  String get wifiNameHidden => 'Oculto';

  @override
  String get kindRouter => 'Roteador';

  @override
  String get kindTv => 'TV ou streaming';

  @override
  String get kindPhone => 'Celular ou tablet';

  @override
  String get kindComputer => 'Computador';

  @override
  String get kindPrinter => 'Impressora';

  @override
  String get kindConsole => 'Console de jogos';

  @override
  String get kindSpeaker => 'Assistente ou caixa de som';

  @override
  String get kindCamera => 'Câmera';

  @override
  String get kindIot => 'Casa inteligente (IoT)';

  @override
  String get kindUnknown => 'Tipo desconhecido';

  @override
  String deviceUnnamed(Object suffix) {
    return 'Aparelho .$suffix';
  }

  @override
  String confidence(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'confiança alta',
        'medium': 'confiança média',
        'other': 'confiança baixa',
      },
    );
    return '$_temp0';
  }

  @override
  String interferenceLevel(String level) {
    String _temp0 = intl.Intl.selectLogic(
      level,
      {
        'high': 'Interferência alta',
        'medium': 'Interferência média',
        'other': 'Interferência baixa',
      },
    );
    return '$_temp0';
  }

  @override
  String bandGhz(Object band) {
    return '$band GHz';
  }

  @override
  String get causeIsp => 'Operadora / internet';

  @override
  String get causeInterference => 'Interferência Wi-Fi';

  @override
  String get causeSignal => 'Sinal fraco do seu aparelho';

  @override
  String get causeUnknown => 'Sem causa identificada';

  @override
  String reasonHeavyKind(Object kind) {
    return '$kind: costuma usar bastante banda';
  }

  @override
  String reasonLift(Object present, Object absent) {
    return 'Instável em $present das verificações com ele na rede, contra $absent sem ele';
  }

  @override
  String get reasonNoWorse => 'A conexão não piora quando ele está na rede';

  @override
  String get reasonAlwaysPresent =>
      'Sempre presente: sem períodos sem ele para comparar';

  @override
  String get reasonNoPresence => 'Sem histórico de presença ainda';

  @override
  String reasonJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entrou na rede pouco antes de $count períodos de falha',
      one: 'Entrou na rede pouco antes de 1 período de falha',
    );
    return '$_temp0';
  }

  @override
  String reasonSlowLocal(Object latency, Object jitter) {
    return 'Resposta local lenta ou oscilando ($latency ms, jitter $jitter ms)';
  }

  @override
  String get reasonPhonePowerSave =>
      '; celulares em economia de energia respondem devagar, peso reduzido';

  @override
  String get reasonNotInLastScan => 'Não apareceu no último escaneamento';

  @override
  String get pairedNone => 'Ainda não há medições do roteador junto das falhas';

  @override
  String pairedGood(int count, Object paired) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em $count falhas de $paired o roteador respondia bem',
      one: 'Em 1 falha de $paired o roteador respondia bem',
    );
    return '$_temp0';
  }

  @override
  String nowRouterInternet(Object router, Object internet) {
    return 'Agora: roteador $router × internet $internet';
  }

  @override
  String get ispIncludes =>
      'Inclui a rota até o servidor e o uso intenso da internet da casa';

  @override
  String networksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redes',
      one: '1 rede',
    );
    return '$_temp0';
  }

  @override
  String overlappingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sobrepostas',
      one: '1 sobreposta',
    );
    return '$_temp0';
  }

  @override
  String neighborNetworksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redes vizinhas',
      one: '1 rede vizinha',
    );
    return '$_temp0';
  }

  @override
  String reasonChannels(
      Object same, Object overlapping, Object channel, Object band) {
    return '$same no mesmo canal e $overlapping (canal $channel, $band)';
  }

  @override
  String reasonInterferenceAmong(Object interference, Object neighbors) {
    return '$interference entre $neighbors';
  }

  @override
  String reasonFreeChannel(Object channel) {
    return 'O canal $channel está mais livre';
  }

  @override
  String get reasonNoNeighbors =>
      'Redes vizinhas indisponíveis (permita a localização)';

  @override
  String reasonWeakFailures(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count falhas de $total com sinal fraco',
      one: '1 falha de $total com sinal fraco',
    );
    return '$_temp0';
  }

  @override
  String reasonSignalNow(Object rssi, Object quality) {
    return 'Sinal atual $rssi dBm ($quality)';
  }

  @override
  String get reasonNoInstability =>
      'Nenhuma instabilidade no Wi-Fi nas últimas 24 h';

  @override
  String reasonUnexplained(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count verificações instáveis em $total; parte não tem explicação observável',
      one:
          '1 verificação instável em $total; parte não tem explicação observável',
    );
    return '$_temp0';
  }

  @override
  String locationNow(Object router, Object internet) {
    return ' Agora: roteador $router, internet $internet.';
  }

  @override
  String get locationNoneTitle => 'Nenhum problema recente';

  @override
  String locationNoneDetail(Object now) {
    return 'Sem instabilidade no Wi-Fi nas últimas 24 h.$now';
  }

  @override
  String get locationUnknownTitle => 'Ainda inconclusivo';

  @override
  String get locationUnknownDetail =>
      'Escaneie a rede e mantenha o monitoramento ligado para comparar o roteador com a internet.';

  @override
  String get locationLocalTitle => 'Rede local (Wi-Fi/casa)';

  @override
  String locationLocalDetail(Object now) {
    return 'O roteador também fica lento ou perde pacotes quando a conexão piora: sinal, interferência ou aparelhos da casa.$now';
  }

  @override
  String locationIspDetail(Object now) {
    return 'O Wi-Fi até o roteador segue bom quando a conexão piora. O gargalo está depois dele: operadora, rota ou a internet da casa saturada por algum aparelho.$now';
  }

  @override
  String get locationMixedTitle => 'Dos dois lados';

  @override
  String locationMixedDetail(Object now) {
    return 'Há falhas com o roteador lento e falhas com ele normal.$now';
  }

  @override
  String get scanJustNow => 'agora mesmo';

  @override
  String scanMinutesAgo(Object minutes) {
    return 'há $minutes min';
  }

  @override
  String scanTodayAt(Object time) {
    return 'hoje às $time';
  }

  @override
  String scanOnDate(Object date, Object time) {
    return 'em $date $time';
  }

  @override
  String get sourceHistory => 'histórico';

  @override
  String get scanPreparing => 'Preparando';

  @override
  String get scanNeedsWifi =>
      'Conecte o celular a um Wi-Fi para escanear a rede.';

  @override
  String get scanFailed => 'Não foi possível escanear a rede.';

  @override
  String get scanUnavailable => 'Escaneamento indisponível';

  @override
  String get neighborsHidden => 'Redes vizinhas ocultas';

  @override
  String get neighborsLocationOff =>
      'Ligue a localização do aparelho: o Android exige isso para listar as redes Wi-Fi vizinhas.';

  @override
  String get neighborsPermission =>
      'O Android só mostra as redes vizinhas com a permissão de localização precisa e o app aberto.';

  @override
  String get probableContribution => 'Contribuição provável';

  @override
  String get noMeasurementsLower => 'sem medições';

  @override
  String unstableOfTotal(Object unstable, Object total) {
    return '$unstable/$total instáveis em 24 h';
  }

  @override
  String get devicesOnNetwork => 'Aparelhos na rede';

  @override
  String devicesOnNetworkCount(Object count) {
    return 'Aparelhos na rede ($count)';
  }

  @override
  String scannedAgo(Object age) {
    return 'escaneado $age';
  }

  @override
  String get noScanTitle => 'Nenhum escaneamento ainda';

  @override
  String get noScanText =>
      'Toque em \"Escanear agora\" para listar os aparelhos conectados ao seu Wi-Fi.';

  @override
  String get wifiEnvironment => 'Ambiente Wi-Fi';

  @override
  String get howToReadTitle => 'Como ler estes números';

  @override
  String get howToReadMonitoring =>
      'O Android não deixa um app ver o consumo de banda de cada aparelho nem os endereços MAC da rede. Os percentuais são estimativas: cruzam as suas medições com a latência do roteador, as redes vizinhas e quais aparelhos estavam conectados em cada momento (inventário a cada 15 min enquanto o monitoramento está ligado).';

  @override
  String get howToReadIdle =>
      'O Android não deixa um app ver o consumo de banda de cada aparelho nem os endereços MAC da rede. Os percentuais são estimativas: cruzam as suas medições com a latência do roteador, as redes vizinhas e quais aparelhos estavam conectados em cada momento. Ligue o monitoramento para registrar a presença dos aparelhos a cada 15 min.';

  @override
  String get onlyRouterAndPhone => 'Só o roteador e este aparelho responderam.';

  @override
  String get whereIsTheProblem => 'Onde está o problema';

  @override
  String get localNetwork => 'Rede local';

  @override
  String get provider => 'Operadora';

  @override
  String get internet => 'Internet';

  @override
  String get scanNow => 'Escanear agora';

  @override
  String lastScan(Object age) {
    return 'Último escaneamento $age';
  }

  @override
  String scanDuration(Object seconds) {
    return '$seconds s';
  }

  @override
  String get scanning => 'Escaneando…';

  @override
  String get scanTakesAbout =>
      'Leva cerca de 15 segundos. Mantenha o app aberto.';

  @override
  String get networkDevices => 'Aparelhos da rede';

  @override
  String largestShare(Object name, Object percent) {
    return 'Maior parcela: $name ($percent%)';
  }

  @override
  String get probableLower => 'provável';

  @override
  String get breakdownExplanation =>
      'Maior contribuição estimada. Os percentuais somam 100% e mostram o peso provável de cada causa, não o consumo de banda.';

  @override
  String get yourRouter => 'Seu roteador';

  @override
  String get thisDevice => 'Este aparelho';

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
  String get why => 'Por quê?';

  @override
  String get onlyKindWeight =>
      'Só o peso do tipo de aparelho; sem outras evidências.';

  @override
  String sources(Object list) {
    return 'Fontes: $list';
  }

  @override
  String get noNeighborsTitle => 'Sem dados das redes vizinhas';

  @override
  String get noNeighborsScan =>
      'Escaneie a rede para analisar canal, sinal e interferência.';

  @override
  String get noNeighborsAndroid =>
      'O Android não liberou a lista de redes Wi-Fi neste escaneamento.';

  @override
  String get yourWifi => 'Seu Wi-Fi';

  @override
  String get cachedData => 'dados em cache';

  @override
  String get wifiBand => 'Faixa';

  @override
  String get wifiChannel => 'Canal';

  @override
  String neighborsSummary(Object same, Object partial, Object total) {
    return '$same no mesmo canal · $partial sobrepostas · $total redes vizinhas';
  }

  @override
  String channelTip(Object channel) {
    return 'Dica: o canal $channel está mais livre. Mude nas configurações do roteador.';
  }

  @override
  String get interferenceBar => 'Interferência de redes vizinhas';

  @override
  String get ownNetworkTag => 'sua rede';

  @override
  String get neighborsWeak =>
      'Os vizinhos no seu canal têm sinal fraco e pouco afetam a sua conexão.';

  @override
  String ownNetworksNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos de acesso da sua rede não entram na conta',
      one: '1 ponto de acesso da sua rede não entra na conta',
    );
    return '$_temp0';
  }

  @override
  String get diagNoNetwork => 'Sem rede ativa no aparelho';

  @override
  String get diagCaptivePortal => 'Rede exige login (portal cativo)';

  @override
  String get diagDns => 'Falha ao resolver o endereço do servidor (DNS)';

  @override
  String get diagNoInternet => 'Rede conectada, mas sem acesso à internet';

  @override
  String get diagWeakWifiOffline =>
      'Sinal Wi-Fi fraco demais para manter a conexão';

  @override
  String get diagServerNoResponse => 'Servidor ou rota sem resposta';

  @override
  String get diagWeakWifiStable => 'Sinal Wi-Fi fraco, mas conexão estável';

  @override
  String get diagNoAnomaly => 'Nenhuma anomalia detectada';

  @override
  String get diagWeakWifi => 'Sinal Wi-Fi fraco';

  @override
  String get diagPacketLoss => 'Perda de pacotes na rota';

  @override
  String get diagHighJitter => 'Oscilação alta na rota';

  @override
  String diagRegionalDistance(Object target) {
    return 'Distância até $target influencia a latência';
  }

  @override
  String get diagCongested => 'Rota congestionada ou servidor distante';

  @override
  String get eventStable => 'Conexão estável';

  @override
  String get eventUnstable => 'Conexão instável';

  @override
  String get eventOffline => 'Internet indisponível';

  @override
  String get eventRestored => 'Conexão restabelecida';

  @override
  String get eventBackUnstable => 'Conexão voltou, mas instável';

  @override
  String get eventChecking => 'Verificando conexão';

  @override
  String get transportMobileData => 'Dados móveis';

  @override
  String get transportNoNetwork => 'Sem rede';
}
