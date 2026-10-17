import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @tabConnection.
  ///
  /// In pt, this message translates to:
  /// **'Conexão'**
  String get tabConnection;

  /// No description provided for @tabMonitoring.
  ///
  /// In pt, this message translates to:
  /// **'Monitoria'**
  String get tabMonitoring;

  /// No description provided for @tabEvents.
  ///
  /// In pt, this message translates to:
  /// **'Eventos'**
  String get tabEvents;

  /// No description provided for @tabNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Rede'**
  String get tabNetwork;

  /// No description provided for @subtitleConnection.
  ///
  /// In pt, this message translates to:
  /// **'Conexão agora'**
  String get subtitleConnection;

  /// No description provided for @subtitleMonitoring.
  ///
  /// In pt, this message translates to:
  /// **'Últimas 24 horas'**
  String get subtitleMonitoring;

  /// No description provided for @subtitleEvents.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get subtitleEvents;

  /// No description provided for @subtitleNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Aparelhos e causas'**
  String get subtitleNetwork;

  /// No description provided for @nightModeTurnOff.
  ///
  /// In pt, this message translates to:
  /// **'Desligar modo noturno'**
  String get nightModeTurnOff;

  /// No description provided for @nightModeTurnOn.
  ///
  /// In pt, this message translates to:
  /// **'Ligar modo noturno'**
  String get nightModeTurnOn;

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @statusPaused.
  ///
  /// In pt, this message translates to:
  /// **'Pausado'**
  String get statusPaused;

  /// No description provided for @statusMeasuring.
  ///
  /// In pt, this message translates to:
  /// **'Medindo'**
  String get statusMeasuring;

  /// No description provided for @stateStable.
  ///
  /// In pt, this message translates to:
  /// **'Estável'**
  String get stateStable;

  /// No description provided for @stateUnstable.
  ///
  /// In pt, this message translates to:
  /// **'Instável'**
  String get stateUnstable;

  /// No description provided for @stateNoResponse.
  ///
  /// In pt, this message translates to:
  /// **'Sem resposta'**
  String get stateNoResponse;

  /// No description provided for @noResponseLower.
  ///
  /// In pt, this message translates to:
  /// **'sem resposta'**
  String get noResponseLower;

  /// No description provided for @milliseconds.
  ///
  /// In pt, this message translates to:
  /// **'{value} ms'**
  String milliseconds(Object value);

  /// No description provided for @minutes.
  ///
  /// In pt, this message translates to:
  /// **'{value} min'**
  String minutes(Object value);

  /// No description provided for @hoursShort.
  ///
  /// In pt, this message translates to:
  /// **'{value} h'**
  String hoursShort(Object value);

  /// No description provided for @monitoringPaused.
  ///
  /// In pt, this message translates to:
  /// **'Monitoramento pausado'**
  String get monitoringPaused;

  /// No description provided for @checkingNow.
  ///
  /// In pt, this message translates to:
  /// **'Verificando agora'**
  String get checkingNow;

  /// No description provided for @preparingCheck.
  ///
  /// In pt, this message translates to:
  /// **'Preparando verificação'**
  String get preparingCheck;

  /// No description provided for @nextCheckIn.
  ///
  /// In pt, this message translates to:
  /// **'Próxima em {time}'**
  String nextCheckIn(Object time);

  /// No description provided for @monitorUnreachable.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível falar com o monitor'**
  String get monitorUnreachable;

  /// No description provided for @wifiNameSheetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar o nome do Wi-Fi'**
  String get wifiNameSheetTitle;

  /// No description provided for @wifiNameSheetSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Permissão de localização precisa'**
  String get wifiNameSheetSubtitle;

  /// No description provided for @wifiNameExplanation.
  ///
  /// In pt, this message translates to:
  /// **'O Android só revela o nome da rede para apps com localização precisa. O Linkzora usa essa permissão apenas para identificar o Wi-Fi e ler a intensidade do sinal; nenhuma localização é salva ou enviada.'**
  String get wifiNameExplanation;

  /// No description provided for @notNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get notNow;

  /// No description provided for @continueAction.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @wifiNameEnabled.
  ///
  /// In pt, this message translates to:
  /// **'Nome da rede habilitado.'**
  String get wifiNameEnabled;

  /// No description provided for @wifiNameDenied.
  ///
  /// In pt, this message translates to:
  /// **'Sem a permissão, a rede aparece apenas como Wi-Fi.'**
  String get wifiNameDenied;

  /// No description provided for @identifyNetworkFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível identificar a rede'**
  String get identifyNetworkFailed;

  /// No description provided for @settingsApplied.
  ///
  /// In pt, this message translates to:
  /// **'Ajustes aplicados ao monitor.'**
  String get settingsApplied;

  /// No description provided for @serverTag.
  ///
  /// In pt, this message translates to:
  /// **'Servidor · {name}'**
  String serverTag(Object name);

  /// No description provided for @noReading.
  ///
  /// In pt, this message translates to:
  /// **'Sem leitura'**
  String get noReading;

  /// No description provided for @readingDetails.
  ///
  /// In pt, this message translates to:
  /// **'Jitter {jitter} ms · Perda {loss}% · {ok}/{total}'**
  String readingDetails(Object jitter, Object loss, Object ok, Object total);

  /// No description provided for @awaitingSamples.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando amostras'**
  String get awaitingSamples;

  /// No description provided for @monitoringTitle.
  ///
  /// In pt, this message translates to:
  /// **'Monitoramento'**
  String get monitoringTitle;

  /// No description provided for @monitoringActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativo em segundo plano'**
  String get monitoringActive;

  /// No description provided for @monitoringInactive.
  ///
  /// In pt, this message translates to:
  /// **'Ative para medir sua conexão'**
  String get monitoringInactive;

  /// No description provided for @changeAlerts.
  ///
  /// In pt, this message translates to:
  /// **'Alertas de mudança'**
  String get changeAlerts;

  /// No description provided for @identifyNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Identificar esta rede'**
  String get identifyNetwork;

  /// No description provided for @identifyNetworkHint.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar o nome e o sinal do Wi-Fi'**
  String get identifyNetworkHint;

  /// No description provided for @metricInterval.
  ///
  /// In pt, this message translates to:
  /// **'Intervalo'**
  String get metricInterval;

  /// No description provided for @metricLimit.
  ///
  /// In pt, this message translates to:
  /// **'Limite'**
  String get metricLimit;

  /// No description provided for @metricSignal.
  ///
  /// In pt, this message translates to:
  /// **'Sinal'**
  String get metricSignal;

  /// No description provided for @transportMobile.
  ///
  /// In pt, this message translates to:
  /// **'Móvel'**
  String get transportMobile;

  /// No description provided for @transportCable.
  ///
  /// In pt, this message translates to:
  /// **'Cabo'**
  String get transportCable;

  /// No description provided for @signalWeak.
  ///
  /// In pt, this message translates to:
  /// **'Fraco'**
  String get signalWeak;

  /// No description provided for @signalFair.
  ///
  /// In pt, this message translates to:
  /// **'Regular'**
  String get signalFair;

  /// No description provided for @signalGood.
  ///
  /// In pt, this message translates to:
  /// **'Bom'**
  String get signalGood;

  /// No description provided for @signalQuality.
  ///
  /// In pt, this message translates to:
  /// **'{level, select, weak{fraco} fair{regular} other{bom}}'**
  String signalQuality(String level);

  /// No description provided for @awaitingFirstMeasurement.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando a primeira medição.'**
  String get awaitingFirstMeasurement;

  /// No description provided for @serverSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo do servidor'**
  String get serverSummary;

  /// No description provided for @oscillations.
  ///
  /// In pt, this message translates to:
  /// **'Oscilações'**
  String get oscillations;

  /// No description provided for @bestHour.
  ///
  /// In pt, this message translates to:
  /// **'Melhor horário'**
  String get bestHour;

  /// No description provided for @collectingData.
  ///
  /// In pt, this message translates to:
  /// **'Coletando dados'**
  String get collectingData;

  /// No description provided for @hourRange.
  ///
  /// In pt, this message translates to:
  /// **'{from}h–{to}h'**
  String hourRange(Object from, Object to);

  /// No description provided for @latencyPulse.
  ///
  /// In pt, this message translates to:
  /// **'Pulso da latência'**
  String get latencyPulse;

  /// No description provided for @tapForDetails.
  ///
  /// In pt, this message translates to:
  /// **'Toque para detalhes'**
  String get tapForDetails;

  /// No description provided for @latencyNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora {value} ms'**
  String latencyNow(Object value);

  /// No description provided for @jitterBand.
  ///
  /// In pt, this message translates to:
  /// **'Faixa de jitter'**
  String get jitterBand;

  /// No description provided for @statMinimum.
  ///
  /// In pt, this message translates to:
  /// **'Mínima'**
  String get statMinimum;

  /// No description provided for @statMedian.
  ///
  /// In pt, this message translates to:
  /// **'Mediana'**
  String get statMedian;

  /// No description provided for @statPeak.
  ///
  /// In pt, this message translates to:
  /// **'Pico (p95)'**
  String get statPeak;

  /// No description provided for @statJitter.
  ///
  /// In pt, this message translates to:
  /// **'Jitter médio'**
  String get statJitter;

  /// No description provided for @probableCause.
  ///
  /// In pt, this message translates to:
  /// **'Causa provável'**
  String get probableCause;

  /// No description provided for @awaitingMeasurements.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando medições'**
  String get awaitingMeasurements;

  /// No description provided for @evidenceNoSample.
  ///
  /// In pt, this message translates to:
  /// **'Faça uma medição para analisar este servidor.'**
  String get evidenceNoSample;

  /// No description provided for @evidenceWifiSignal.
  ///
  /// In pt, this message translates to:
  /// **'{level, select, weak{sinal Wi-Fi fraco} fair{sinal Wi-Fi regular} other{sinal Wi-Fi bom}}'**
  String evidenceWifiSignal(String level);

  /// No description provided for @evidenceJitter.
  ///
  /// In pt, this message translates to:
  /// **'jitter {value}'**
  String evidenceJitter(Object value);

  /// No description provided for @evidenceLoss.
  ///
  /// In pt, this message translates to:
  /// **'perda {value}%'**
  String evidenceLoss(Object value);

  /// No description provided for @failurePeriods.
  ///
  /// In pt, this message translates to:
  /// **'Períodos com falhas'**
  String get failurePeriods;

  /// No description provided for @unknownCause.
  ///
  /// In pt, this message translates to:
  /// **'Causa não identificada'**
  String get unknownCause;

  /// No description provided for @noConnection.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão'**
  String get noConnection;

  /// No description provided for @unstableConnection.
  ///
  /// In pt, this message translates to:
  /// **'Conexão instável'**
  String get unstableConnection;

  /// No description provided for @olderPeriods.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{+ 1 período anterior} other{+ {count} períodos anteriores}}'**
  String olderPeriods(int count);

  /// No description provided for @noFailures24h.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma falha registrada nas últimas 24 horas.'**
  String get noFailures24h;

  /// No description provided for @chartNow.
  ///
  /// In pt, this message translates to:
  /// **'agora'**
  String get chartNow;

  /// No description provided for @chartLimit.
  ///
  /// In pt, this message translates to:
  /// **'limite {value} ms'**
  String chartLimit(Object value);

  /// No description provided for @chartJitter.
  ///
  /// In pt, this message translates to:
  /// **'jitter ±{value} ms'**
  String chartJitter(Object value);

  /// No description provided for @measurementCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 medição · 24 h} other{{count} medições · 24 h}}'**
  String measurementCount(int count);

  /// No description provided for @analyzedServer.
  ///
  /// In pt, this message translates to:
  /// **'Servidor analisado'**
  String get analyzedServer;

  /// No description provided for @inUse.
  ///
  /// In pt, this message translates to:
  /// **'EM USO'**
  String get inUse;

  /// No description provided for @unknownTarget.
  ///
  /// In pt, this message translates to:
  /// **'Destino não identificado'**
  String get unknownTarget;

  /// No description provided for @alertNone.
  ///
  /// In pt, this message translates to:
  /// **'Sem alertas'**
  String get alertNone;

  /// No description provided for @alertNoneDescription.
  ///
  /// In pt, this message translates to:
  /// **'Só a notificação fixa do monitor.'**
  String get alertNoneDescription;

  /// No description provided for @alertOnce.
  ///
  /// In pt, this message translates to:
  /// **'Uma vez por sessão'**
  String get alertOnce;

  /// No description provided for @alertOnceDescription.
  ///
  /// In pt, this message translates to:
  /// **'Avisa na primeira mudança após ativar.'**
  String get alertOnceDescription;

  /// No description provided for @alertChanges.
  ///
  /// In pt, this message translates to:
  /// **'A cada mudança'**
  String get alertChanges;

  /// No description provided for @alertChangesDescription.
  ///
  /// In pt, this message translates to:
  /// **'Avisa sempre que a conexão mudar.'**
  String get alertChangesDescription;

  /// No description provided for @alertSheetSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Quando o Linkzora deve chamar sua atenção'**
  String get alertSheetSubtitle;

  /// No description provided for @noEventsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum evento ainda'**
  String get noEventsTitle;

  /// No description provided for @noEventsText.
  ///
  /// In pt, this message translates to:
  /// **'As mudanças da conexão aparecerão aqui.'**
  String get noEventsText;

  /// No description provided for @allDays.
  ///
  /// In pt, this message translates to:
  /// **'Todos os dias'**
  String get allDays;

  /// No description provided for @filterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @eventCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 evento} other{{count} eventos}}'**
  String eventCount(int count);

  /// No description provided for @changeCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 mudança} other{{count} mudanças}}'**
  String changeCount(int count);

  /// No description provided for @summaryDrops.
  ///
  /// In pt, this message translates to:
  /// **'Quedas'**
  String get summaryDrops;

  /// No description provided for @summaryInstabilities.
  ///
  /// In pt, this message translates to:
  /// **'Instabilidades'**
  String get summaryInstabilities;

  /// No description provided for @summaryRecoveries.
  ///
  /// In pt, this message translates to:
  /// **'Estabilizou'**
  String get summaryRecoveries;

  /// No description provided for @today.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem'**
  String get yesterday;

  /// No description provided for @noDate.
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get noDate;

  /// Short day and month of an event day; reorder for the locale.
  ///
  /// In pt, this message translates to:
  /// **'{day}/{month}'**
  String dayMonth(Object day, Object month);

  /// No description provided for @settingsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ritmo das medições e destino do teste'**
  String get settingsSubtitle;

  /// No description provided for @nightMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo noturno'**
  String get nightMode;

  /// No description provided for @nightModeSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Tema escuro em todo o app'**
  String get nightModeSubtitle;

  /// No description provided for @saveSettings.
  ///
  /// In pt, this message translates to:
  /// **'Salvar ajustes'**
  String get saveSettings;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @languageSystemHint.
  ///
  /// In pt, this message translates to:
  /// **'Segue o idioma do aparelho'**
  String get languageSystemHint;

  /// No description provided for @testLocation.
  ///
  /// In pt, this message translates to:
  /// **'Local do teste'**
  String get testLocation;

  /// No description provided for @nearbyServer.
  ///
  /// In pt, this message translates to:
  /// **'Servidor próximo'**
  String get nearbyServer;

  /// No description provided for @serverAddress.
  ///
  /// In pt, this message translates to:
  /// **'Endereço {address} · anycast'**
  String serverAddress(Object address);

  /// No description provided for @locationNear.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get locationNear;

  /// No description provided for @locationSaoPaulo.
  ///
  /// In pt, this message translates to:
  /// **'São Paulo'**
  String get locationSaoPaulo;

  /// No description provided for @locationUnitedStates.
  ///
  /// In pt, this message translates to:
  /// **'Estados Unidos'**
  String get locationUnitedStates;

  /// No description provided for @locationEurope.
  ///
  /// In pt, this message translates to:
  /// **'Europa'**
  String get locationEurope;

  /// No description provided for @locationNearDetail.
  ///
  /// In pt, this message translates to:
  /// **'Anycast · menor rota disponível'**
  String get locationNearDetail;

  /// No description provided for @locationSaoPauloDetail.
  ///
  /// In pt, this message translates to:
  /// **'AWS · sa-east-1'**
  String get locationSaoPauloDetail;

  /// No description provided for @locationUnitedStatesDetail.
  ///
  /// In pt, this message translates to:
  /// **'AWS · Virgínia · us-east-1'**
  String get locationUnitedStatesDetail;

  /// No description provided for @locationEuropeDetail.
  ///
  /// In pt, this message translates to:
  /// **'AWS · Irlanda · eu-west-1'**
  String get locationEuropeDetail;

  /// No description provided for @checkEvery.
  ///
  /// In pt, this message translates to:
  /// **'Verificar a cada'**
  String get checkEvery;

  /// No description provided for @alertAbove.
  ///
  /// In pt, this message translates to:
  /// **'Avisar acima de'**
  String get alertAbove;

  /// No description provided for @customLimit.
  ///
  /// In pt, this message translates to:
  /// **'Personalizado'**
  String get customLimit;

  /// No description provided for @limitTypeError.
  ///
  /// In pt, this message translates to:
  /// **'Digite o limite em milissegundos.'**
  String get limitTypeError;

  /// No description provided for @limitRangeError.
  ///
  /// In pt, this message translates to:
  /// **'Use um valor entre {min} e {max} ms.'**
  String limitRangeError(Object min, Object max);

  /// No description provided for @limitRangeHint.
  ///
  /// In pt, this message translates to:
  /// **'Entre {min} e {max} ms.'**
  String limitRangeHint(Object min, Object max);

  /// No description provided for @limitHintExample.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: 450'**
  String get limitHintExample;

  /// No description provided for @limitFootnote.
  ///
  /// In pt, this message translates to:
  /// **'Cada verificação usa 5 conexões e confirma resultados suspeitos com mais 5.'**
  String get limitFootnote;

  /// No description provided for @donationTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gostando do Linkzora?'**
  String get donationTitle;

  /// Friendly donation nudge; keep the playful tone and the wink.
  ///
  /// In pt, this message translates to:
  /// **'Gostando do app? Que tal pagar um cafezinho pra esse dev ;)'**
  String get donationMessage;

  /// No description provided for @donationButton.
  ///
  /// In pt, this message translates to:
  /// **'Pagar um cafezinho'**
  String get donationButton;

  /// No description provided for @donationOpenFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir o link. Acesse buymeacoffee.com/andremaracaja'**
  String get donationOpenFailed;

  /// No description provided for @donationDismiss.
  ///
  /// In pt, this message translates to:
  /// **'Dispensar'**
  String get donationDismiss;

  /// No description provided for @back.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get back;

  /// No description provided for @setUp.
  ///
  /// In pt, this message translates to:
  /// **'Configurar'**
  String get setUp;

  /// No description provided for @skip.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get skip;

  /// No description provided for @allow.
  ///
  /// In pt, this message translates to:
  /// **'Permitir'**
  String get allow;

  /// No description provided for @startMonitoring.
  ///
  /// In pt, this message translates to:
  /// **'Começar monitoramento'**
  String get startMonitoring;

  /// No description provided for @permissionRequestFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível pedir a permissão'**
  String get permissionRequestFailed;

  /// No description provided for @startFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível iniciar o monitoramento'**
  String get startFailed;

  /// No description provided for @welcomeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Boas-vindas ao Linkzora'**
  String get welcomeTitle;

  /// No description provided for @welcomeText.
  ///
  /// In pt, this message translates to:
  /// **'Saiba quando a internet cai, oscila ou fica lenta, sem gastar dados nem bateria.'**
  String get welcomeText;

  /// No description provided for @featureBackgroundTitle.
  ///
  /// In pt, this message translates to:
  /// **'Medição em segundo plano'**
  String get featureBackgroundTitle;

  /// No description provided for @featureBackgroundText.
  ///
  /// In pt, this message translates to:
  /// **'Latência, jitter e perda a cada poucos minutos.'**
  String get featureBackgroundText;

  /// No description provided for @featureAlertsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alertas na hora certa'**
  String get featureAlertsTitle;

  /// No description provided for @featureAlertsText.
  ///
  /// In pt, this message translates to:
  /// **'Aviso quando a conexão cai ou volta.'**
  String get featureAlertsText;

  /// No description provided for @featureCauseText.
  ///
  /// In pt, this message translates to:
  /// **'Wi-Fi, rota ou servidor, e o melhor horário de uso.'**
  String get featureCauseText;

  /// No description provided for @setupTime.
  ///
  /// In pt, this message translates to:
  /// **'Leva menos de um minuto para configurar.'**
  String get setupTime;

  /// No description provided for @targetStepTitle.
  ///
  /// In pt, this message translates to:
  /// **'Para onde medir'**
  String get targetStepTitle;

  /// No description provided for @targetStepSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'O destino das conexões de teste. \"Próximo\" usa a menor rota disponível e serve para a maioria.'**
  String get targetStepSubtitle;

  /// No description provided for @alertsStepSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Quando o Linkzora deve chamar sua atenção se a conexão cair ou oscilar.'**
  String get alertsStepSubtitle;

  /// No description provided for @rhythmStepTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ritmo das medições'**
  String get rhythmStepTitle;

  /// No description provided for @rhythmStepSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Intervalos curtos detectam quedas mais cedo; longos economizam bateria.'**
  String get rhythmStepSubtitle;

  /// No description provided for @wifiStepTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nome do Wi-Fi'**
  String get wifiStepTitle;

  /// No description provided for @wifiStepSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Opcional · permissão de localização precisa'**
  String get wifiStepSubtitle;

  /// No description provided for @wifiStepNote.
  ///
  /// In pt, this message translates to:
  /// **'Sem ela, a rede aparece apenas como \"Wi-Fi\". Você pode permitir depois na tela Conexão.'**
  String get wifiStepNote;

  /// No description provided for @summaryStepTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tudo pronto'**
  String get summaryStepTitle;

  /// No description provided for @summaryStepSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Confira as escolhas. Tudo pode ser mudado depois em Ajustes.'**
  String get summaryStepSubtitle;

  /// No description provided for @summaryServer.
  ///
  /// In pt, this message translates to:
  /// **'Servidor'**
  String get summaryServer;

  /// No description provided for @summaryAlerts.
  ///
  /// In pt, this message translates to:
  /// **'Alertas'**
  String get summaryAlerts;

  /// No description provided for @summaryLimit.
  ///
  /// In pt, this message translates to:
  /// **'Limite de latência'**
  String get summaryLimit;

  /// No description provided for @wifiNameShown.
  ///
  /// In pt, this message translates to:
  /// **'Habilitado'**
  String get wifiNameShown;

  /// No description provided for @wifiNameHidden.
  ///
  /// In pt, this message translates to:
  /// **'Oculto'**
  String get wifiNameHidden;

  /// No description provided for @kindRouter.
  ///
  /// In pt, this message translates to:
  /// **'Roteador'**
  String get kindRouter;

  /// No description provided for @kindTv.
  ///
  /// In pt, this message translates to:
  /// **'TV ou streaming'**
  String get kindTv;

  /// No description provided for @kindPhone.
  ///
  /// In pt, this message translates to:
  /// **'Celular ou tablet'**
  String get kindPhone;

  /// No description provided for @kindComputer.
  ///
  /// In pt, this message translates to:
  /// **'Computador'**
  String get kindComputer;

  /// No description provided for @kindPrinter.
  ///
  /// In pt, this message translates to:
  /// **'Impressora'**
  String get kindPrinter;

  /// No description provided for @kindConsole.
  ///
  /// In pt, this message translates to:
  /// **'Console de jogos'**
  String get kindConsole;

  /// No description provided for @kindSpeaker.
  ///
  /// In pt, this message translates to:
  /// **'Assistente ou caixa de som'**
  String get kindSpeaker;

  /// No description provided for @kindCamera.
  ///
  /// In pt, this message translates to:
  /// **'Câmera'**
  String get kindCamera;

  /// No description provided for @kindIot.
  ///
  /// In pt, this message translates to:
  /// **'Casa inteligente (IoT)'**
  String get kindIot;

  /// No description provided for @kindUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Tipo desconhecido'**
  String get kindUnknown;

  /// No description provided for @deviceUnnamed.
  ///
  /// In pt, this message translates to:
  /// **'Aparelho .{suffix}'**
  String deviceUnnamed(Object suffix);

  /// No description provided for @confidence.
  ///
  /// In pt, this message translates to:
  /// **'{level, select, high{confiança alta} medium{confiança média} other{confiança baixa}}'**
  String confidence(String level);

  /// No description provided for @interferenceLevel.
  ///
  /// In pt, this message translates to:
  /// **'{level, select, high{Interferência alta} medium{Interferência média} other{Interferência baixa}}'**
  String interferenceLevel(String level);

  /// No description provided for @bandGhz.
  ///
  /// In pt, this message translates to:
  /// **'{band} GHz'**
  String bandGhz(Object band);

  /// No description provided for @causeIsp.
  ///
  /// In pt, this message translates to:
  /// **'Operadora / internet'**
  String get causeIsp;

  /// No description provided for @causeInterference.
  ///
  /// In pt, this message translates to:
  /// **'Interferência Wi-Fi'**
  String get causeInterference;

  /// No description provided for @causeSignal.
  ///
  /// In pt, this message translates to:
  /// **'Sinal fraco do seu aparelho'**
  String get causeSignal;

  /// No description provided for @causeUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Sem causa identificada'**
  String get causeUnknown;

  /// No description provided for @reasonHeavyKind.
  ///
  /// In pt, this message translates to:
  /// **'{kind}: costuma usar bastante banda'**
  String reasonHeavyKind(Object kind);

  /// No description provided for @reasonLift.
  ///
  /// In pt, this message translates to:
  /// **'Instável em {present} das verificações com ele na rede, contra {absent} sem ele'**
  String reasonLift(Object present, Object absent);

  /// No description provided for @reasonNoWorse.
  ///
  /// In pt, this message translates to:
  /// **'A conexão não piora quando ele está na rede'**
  String get reasonNoWorse;

  /// No description provided for @reasonAlwaysPresent.
  ///
  /// In pt, this message translates to:
  /// **'Sempre presente: sem períodos sem ele para comparar'**
  String get reasonAlwaysPresent;

  /// No description provided for @reasonNoPresence.
  ///
  /// In pt, this message translates to:
  /// **'Sem histórico de presença ainda'**
  String get reasonNoPresence;

  /// No description provided for @reasonJoined.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Entrou na rede pouco antes de 1 período de falha} other{Entrou na rede pouco antes de {count} períodos de falha}}'**
  String reasonJoined(int count);

  /// No description provided for @reasonSlowLocal.
  ///
  /// In pt, this message translates to:
  /// **'Resposta local lenta ou oscilando ({latency} ms, jitter {jitter} ms)'**
  String reasonSlowLocal(Object latency, Object jitter);

  /// No description provided for @reasonPhonePowerSave.
  ///
  /// In pt, this message translates to:
  /// **'; celulares em economia de energia respondem devagar, peso reduzido'**
  String get reasonPhonePowerSave;

  /// No description provided for @reasonNotInLastScan.
  ///
  /// In pt, this message translates to:
  /// **'Não apareceu no último escaneamento'**
  String get reasonNotInLastScan;

  /// No description provided for @pairedNone.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há medições do roteador junto das falhas'**
  String get pairedNone;

  /// No description provided for @pairedGood.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Em 1 falha de {paired} o roteador respondia bem} other{Em {count} falhas de {paired} o roteador respondia bem}}'**
  String pairedGood(int count, Object paired);

  /// No description provided for @nowRouterInternet.
  ///
  /// In pt, this message translates to:
  /// **'Agora: roteador {router} × internet {internet}'**
  String nowRouterInternet(Object router, Object internet);

  /// No description provided for @ispIncludes.
  ///
  /// In pt, this message translates to:
  /// **'Inclui a rota até o servidor e o uso intenso da internet da casa'**
  String get ispIncludes;

  /// No description provided for @networksCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 rede} other{{count} redes}}'**
  String networksCount(int count);

  /// No description provided for @overlappingCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 sobreposta} other{{count} sobrepostas}}'**
  String overlappingCount(int count);

  /// No description provided for @neighborNetworksCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 rede vizinha} other{{count} redes vizinhas}}'**
  String neighborNetworksCount(int count);

  /// No description provided for @reasonChannels.
  ///
  /// In pt, this message translates to:
  /// **'{same} no mesmo canal e {overlapping} (canal {channel}, {band})'**
  String reasonChannels(
      Object same, Object overlapping, Object channel, Object band);

  /// No description provided for @reasonInterferenceAmong.
  ///
  /// In pt, this message translates to:
  /// **'{interference} entre {neighbors}'**
  String reasonInterferenceAmong(Object interference, Object neighbors);

  /// No description provided for @reasonFreeChannel.
  ///
  /// In pt, this message translates to:
  /// **'O canal {channel} está mais livre'**
  String reasonFreeChannel(Object channel);

  /// No description provided for @reasonNoNeighbors.
  ///
  /// In pt, this message translates to:
  /// **'Redes vizinhas indisponíveis (permita a localização)'**
  String get reasonNoNeighbors;

  /// No description provided for @reasonWeakFailures.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 falha de {total} com sinal fraco} other{{count} falhas de {total} com sinal fraco}}'**
  String reasonWeakFailures(int count, Object total);

  /// No description provided for @reasonSignalNow.
  ///
  /// In pt, this message translates to:
  /// **'Sinal atual {rssi} dBm ({quality})'**
  String reasonSignalNow(Object rssi, Object quality);

  /// No description provided for @reasonNoInstability.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma instabilidade no Wi-Fi nas últimas 24 h'**
  String get reasonNoInstability;

  /// No description provided for @reasonUnexplained.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 verificação instável em {total}; parte não tem explicação observável} other{{count} verificações instáveis em {total}; parte não tem explicação observável}}'**
  String reasonUnexplained(int count, Object total);

  /// No description provided for @locationNow.
  ///
  /// In pt, this message translates to:
  /// **' Agora: roteador {router}, internet {internet}.'**
  String locationNow(Object router, Object internet);

  /// No description provided for @locationNoneTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum problema recente'**
  String get locationNoneTitle;

  /// No description provided for @locationNoneDetail.
  ///
  /// In pt, this message translates to:
  /// **'Sem instabilidade no Wi-Fi nas últimas 24 h.{now}'**
  String locationNoneDetail(Object now);

  /// No description provided for @locationUnknownTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ainda inconclusivo'**
  String get locationUnknownTitle;

  /// No description provided for @locationUnknownDetail.
  ///
  /// In pt, this message translates to:
  /// **'Escaneie a rede e mantenha o monitoramento ligado para comparar o roteador com a internet.'**
  String get locationUnknownDetail;

  /// No description provided for @locationLocalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Rede local (Wi-Fi/casa)'**
  String get locationLocalTitle;

  /// No description provided for @locationLocalDetail.
  ///
  /// In pt, this message translates to:
  /// **'O roteador também fica lento ou perde pacotes quando a conexão piora: sinal, interferência ou aparelhos da casa.{now}'**
  String locationLocalDetail(Object now);

  /// No description provided for @locationIspDetail.
  ///
  /// In pt, this message translates to:
  /// **'O Wi-Fi até o roteador segue bom quando a conexão piora. O gargalo está depois dele: operadora, rota ou a internet da casa saturada por algum aparelho.{now}'**
  String locationIspDetail(Object now);

  /// No description provided for @locationMixedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Dos dois lados'**
  String get locationMixedTitle;

  /// No description provided for @locationMixedDetail.
  ///
  /// In pt, this message translates to:
  /// **'Há falhas com o roteador lento e falhas com ele normal.{now}'**
  String locationMixedDetail(Object now);

  /// No description provided for @scanJustNow.
  ///
  /// In pt, this message translates to:
  /// **'agora mesmo'**
  String get scanJustNow;

  /// No description provided for @scanMinutesAgo.
  ///
  /// In pt, this message translates to:
  /// **'há {minutes} min'**
  String scanMinutesAgo(Object minutes);

  /// No description provided for @scanTodayAt.
  ///
  /// In pt, this message translates to:
  /// **'hoje às {time}'**
  String scanTodayAt(Object time);

  /// No description provided for @scanOnDate.
  ///
  /// In pt, this message translates to:
  /// **'em {date} {time}'**
  String scanOnDate(Object date, Object time);

  /// No description provided for @sourceHistory.
  ///
  /// In pt, this message translates to:
  /// **'histórico'**
  String get sourceHistory;

  /// No description provided for @scanPreparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando'**
  String get scanPreparing;

  /// No description provided for @scanNeedsWifi.
  ///
  /// In pt, this message translates to:
  /// **'Conecte o celular a um Wi-Fi para escanear a rede.'**
  String get scanNeedsWifi;

  /// No description provided for @scanFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível escanear a rede.'**
  String get scanFailed;

  /// No description provided for @scanUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Escaneamento indisponível'**
  String get scanUnavailable;

  /// No description provided for @neighborsHidden.
  ///
  /// In pt, this message translates to:
  /// **'Redes vizinhas ocultas'**
  String get neighborsHidden;

  /// No description provided for @neighborsLocationOff.
  ///
  /// In pt, this message translates to:
  /// **'Ligue a localização do aparelho: o Android exige isso para listar as redes Wi-Fi vizinhas.'**
  String get neighborsLocationOff;

  /// No description provided for @neighborsPermission.
  ///
  /// In pt, this message translates to:
  /// **'O Android só mostra as redes vizinhas com a permissão de localização precisa e o app aberto.'**
  String get neighborsPermission;

  /// No description provided for @probableContribution.
  ///
  /// In pt, this message translates to:
  /// **'Contribuição provável'**
  String get probableContribution;

  /// No description provided for @noMeasurementsLower.
  ///
  /// In pt, this message translates to:
  /// **'sem medições'**
  String get noMeasurementsLower;

  /// No description provided for @unstableOfTotal.
  ///
  /// In pt, this message translates to:
  /// **'{unstable}/{total} instáveis em 24 h'**
  String unstableOfTotal(Object unstable, Object total);

  /// No description provided for @devicesOnNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Aparelhos na rede'**
  String get devicesOnNetwork;

  /// No description provided for @devicesOnNetworkCount.
  ///
  /// In pt, this message translates to:
  /// **'Aparelhos na rede ({count})'**
  String devicesOnNetworkCount(Object count);

  /// No description provided for @scannedAgo.
  ///
  /// In pt, this message translates to:
  /// **'escaneado {age}'**
  String scannedAgo(Object age);

  /// No description provided for @noScanTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum escaneamento ainda'**
  String get noScanTitle;

  /// No description provided for @noScanText.
  ///
  /// In pt, this message translates to:
  /// **'Toque em \"Escanear agora\" para listar os aparelhos conectados ao seu Wi-Fi.'**
  String get noScanText;

  /// No description provided for @wifiEnvironment.
  ///
  /// In pt, this message translates to:
  /// **'Ambiente Wi-Fi'**
  String get wifiEnvironment;

  /// No description provided for @howToReadTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como ler estes números'**
  String get howToReadTitle;

  /// No description provided for @howToReadMonitoring.
  ///
  /// In pt, this message translates to:
  /// **'O Android não deixa um app ver o consumo de banda de cada aparelho nem os endereços MAC da rede. Os percentuais são estimativas: cruzam as suas medições com a latência do roteador, as redes vizinhas e quais aparelhos estavam conectados em cada momento (inventário a cada 15 min enquanto o monitoramento está ligado).'**
  String get howToReadMonitoring;

  /// No description provided for @howToReadIdle.
  ///
  /// In pt, this message translates to:
  /// **'O Android não deixa um app ver o consumo de banda de cada aparelho nem os endereços MAC da rede. Os percentuais são estimativas: cruzam as suas medições com a latência do roteador, as redes vizinhas e quais aparelhos estavam conectados em cada momento. Ligue o monitoramento para registrar a presença dos aparelhos a cada 15 min.'**
  String get howToReadIdle;

  /// No description provided for @onlyRouterAndPhone.
  ///
  /// In pt, this message translates to:
  /// **'Só o roteador e este aparelho responderam.'**
  String get onlyRouterAndPhone;

  /// No description provided for @whereIsTheProblem.
  ///
  /// In pt, this message translates to:
  /// **'Onde está o problema'**
  String get whereIsTheProblem;

  /// No description provided for @localNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Rede local'**
  String get localNetwork;

  /// No description provided for @provider.
  ///
  /// In pt, this message translates to:
  /// **'Operadora'**
  String get provider;

  /// No description provided for @internet.
  ///
  /// In pt, this message translates to:
  /// **'Internet'**
  String get internet;

  /// No description provided for @scanNow.
  ///
  /// In pt, this message translates to:
  /// **'Escanear agora'**
  String get scanNow;

  /// No description provided for @lastScan.
  ///
  /// In pt, this message translates to:
  /// **'Último escaneamento {age}'**
  String lastScan(Object age);

  /// No description provided for @scanDuration.
  ///
  /// In pt, this message translates to:
  /// **'{seconds} s'**
  String scanDuration(Object seconds);

  /// No description provided for @scanning.
  ///
  /// In pt, this message translates to:
  /// **'Escaneando…'**
  String get scanning;

  /// No description provided for @scanTakesAbout.
  ///
  /// In pt, this message translates to:
  /// **'Leva cerca de 15 segundos. Mantenha o app aberto.'**
  String get scanTakesAbout;

  /// No description provided for @networkDevices.
  ///
  /// In pt, this message translates to:
  /// **'Aparelhos da rede'**
  String get networkDevices;

  /// No description provided for @largestShare.
  ///
  /// In pt, this message translates to:
  /// **'Maior parcela: {name} ({percent}%)'**
  String largestShare(Object name, Object percent);

  /// No description provided for @probableLower.
  ///
  /// In pt, this message translates to:
  /// **'provável'**
  String get probableLower;

  /// No description provided for @breakdownExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Maior contribuição estimada. Os percentuais somam 100% e mostram o peso provável de cada causa, não o consumo de banda.'**
  String get breakdownExplanation;

  /// No description provided for @yourRouter.
  ///
  /// In pt, this message translates to:
  /// **'Seu roteador'**
  String get yourRouter;

  /// No description provided for @thisDevice.
  ///
  /// In pt, this message translates to:
  /// **'Este aparelho'**
  String get thisDevice;

  /// No description provided for @localLatency.
  ///
  /// In pt, this message translates to:
  /// **'local {value}'**
  String localLatency(Object value);

  /// No description provided for @jitterMs.
  ///
  /// In pt, this message translates to:
  /// **'jitter {value} ms'**
  String jitterMs(Object value);

  /// No description provided for @absent.
  ///
  /// In pt, this message translates to:
  /// **'ausente'**
  String get absent;

  /// No description provided for @showLess.
  ///
  /// In pt, this message translates to:
  /// **'Menos'**
  String get showLess;

  /// No description provided for @why.
  ///
  /// In pt, this message translates to:
  /// **'Por quê?'**
  String get why;

  /// No description provided for @onlyKindWeight.
  ///
  /// In pt, this message translates to:
  /// **'Só o peso do tipo de aparelho; sem outras evidências.'**
  String get onlyKindWeight;

  /// No description provided for @sources.
  ///
  /// In pt, this message translates to:
  /// **'Fontes: {list}'**
  String sources(Object list);

  /// No description provided for @noNeighborsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados das redes vizinhas'**
  String get noNeighborsTitle;

  /// No description provided for @noNeighborsScan.
  ///
  /// In pt, this message translates to:
  /// **'Escaneie a rede para analisar canal, sinal e interferência.'**
  String get noNeighborsScan;

  /// No description provided for @noNeighborsAndroid.
  ///
  /// In pt, this message translates to:
  /// **'O Android não liberou a lista de redes Wi-Fi neste escaneamento.'**
  String get noNeighborsAndroid;

  /// No description provided for @yourWifi.
  ///
  /// In pt, this message translates to:
  /// **'Seu Wi-Fi'**
  String get yourWifi;

  /// No description provided for @cachedData.
  ///
  /// In pt, this message translates to:
  /// **'dados em cache'**
  String get cachedData;

  /// No description provided for @wifiBand.
  ///
  /// In pt, this message translates to:
  /// **'Faixa'**
  String get wifiBand;

  /// No description provided for @wifiChannel.
  ///
  /// In pt, this message translates to:
  /// **'Canal'**
  String get wifiChannel;

  /// No description provided for @neighborsSummary.
  ///
  /// In pt, this message translates to:
  /// **'{same} no mesmo canal · {partial} sobrepostas · {total} redes vizinhas'**
  String neighborsSummary(Object same, Object partial, Object total);

  /// No description provided for @channelTip.
  ///
  /// In pt, this message translates to:
  /// **'Dica: o canal {channel} está mais livre. Mude nas configurações do roteador.'**
  String channelTip(Object channel);

  /// No description provided for @diagNoNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem rede ativa no aparelho'**
  String get diagNoNetwork;

  /// No description provided for @diagCaptivePortal.
  ///
  /// In pt, this message translates to:
  /// **'Rede exige login (portal cativo)'**
  String get diagCaptivePortal;

  /// No description provided for @diagDns.
  ///
  /// In pt, this message translates to:
  /// **'Falha ao resolver o endereço do servidor (DNS)'**
  String get diagDns;

  /// No description provided for @diagNoInternet.
  ///
  /// In pt, this message translates to:
  /// **'Rede conectada, mas sem acesso à internet'**
  String get diagNoInternet;

  /// No description provided for @diagWeakWifiOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sinal Wi-Fi fraco demais para manter a conexão'**
  String get diagWeakWifiOffline;

  /// No description provided for @diagServerNoResponse.
  ///
  /// In pt, this message translates to:
  /// **'Servidor ou rota sem resposta'**
  String get diagServerNoResponse;

  /// No description provided for @diagWeakWifiStable.
  ///
  /// In pt, this message translates to:
  /// **'Sinal Wi-Fi fraco, mas conexão estável'**
  String get diagWeakWifiStable;

  /// Native diagnosis stored in Portuguese; also used to translate history.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma anomalia detectada'**
  String get diagNoAnomaly;

  /// No description provided for @diagWeakWifi.
  ///
  /// In pt, this message translates to:
  /// **'Sinal Wi-Fi fraco'**
  String get diagWeakWifi;

  /// No description provided for @diagPacketLoss.
  ///
  /// In pt, this message translates to:
  /// **'Perda de pacotes na rota'**
  String get diagPacketLoss;

  /// No description provided for @diagHighJitter.
  ///
  /// In pt, this message translates to:
  /// **'Oscilação alta na rota'**
  String get diagHighJitter;

  /// No description provided for @diagRegionalDistance.
  ///
  /// In pt, this message translates to:
  /// **'Distância até {target} influencia a latência'**
  String diagRegionalDistance(Object target);

  /// No description provided for @diagCongested.
  ///
  /// In pt, this message translates to:
  /// **'Rota congestionada ou servidor distante'**
  String get diagCongested;

  /// No description provided for @eventStable.
  ///
  /// In pt, this message translates to:
  /// **'Conexão estável'**
  String get eventStable;

  /// No description provided for @eventUnstable.
  ///
  /// In pt, this message translates to:
  /// **'Conexão instável'**
  String get eventUnstable;

  /// No description provided for @eventOffline.
  ///
  /// In pt, this message translates to:
  /// **'Internet indisponível'**
  String get eventOffline;

  /// No description provided for @eventRestored.
  ///
  /// In pt, this message translates to:
  /// **'Conexão restabelecida'**
  String get eventRestored;

  /// No description provided for @eventBackUnstable.
  ///
  /// In pt, this message translates to:
  /// **'Conexão voltou, mas instável'**
  String get eventBackUnstable;

  /// No description provided for @eventChecking.
  ///
  /// In pt, this message translates to:
  /// **'Verificando conexão'**
  String get eventChecking;

  /// No description provided for @transportMobileData.
  ///
  /// In pt, this message translates to:
  /// **'Dados móveis'**
  String get transportMobileData;

  /// No description provided for @transportNoNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem rede'**
  String get transportNoNetwork;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
