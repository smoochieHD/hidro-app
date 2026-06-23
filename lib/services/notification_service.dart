import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'storage_service.dart';
import '../models/fasting_session.dart';

/// IDs das ações dentro da notificação de fim de jejum.
const String actionScheduleNext = 'schedule_next_fast';
const String actionDismiss = 'dismiss_fast_notification';

/// IDs fixos das notificações geridas por este serviço. Como só existe,
/// no máximo, um jejum ativo e um próximo jejum agendado de cada vez,
/// reutilizar sempre o mesmo ID substitui/cancela automaticamente a
/// notificação anterior em vez de acumular notificações antigas.
const int fastEndNotificationId = 1001;
const int fastStartNotificationId = 1002;

/// Mensagens trocadas entre o handler de background e a UI em primeiro
/// plano (quando a app está aberta no momento em que a ação é tocada).
/// Usado só para a UI poder reagir de imediato; o handler de background
/// já grava os dados de forma autossuficiente, por isso a app continua
/// correta mesmo que nenhum listener esteja a ouvir este stream.
final StreamController<String> notificationActionStream =
    StreamController<String>.broadcast();

/// Handler usado quando a app está em primeiro plano (UI já ativa, todos
/// os plugins já registados normalmente por main()). Mais simples que o
/// handler de background: não precisa de inicializar plugins manualmente.
void _notificationForegroundHandler(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null) return;
  // Reaproveita a mesma lógica de negócio do handler de background,
  // já que ambos têm de produzir o mesmo resultado.
  notificationBackgroundHandler(response);
}

/// Handler que corre em background, possivelmente num isolate totalmente
/// separado da UI (app fechada). NÃO pode tocar em AppState — qualquer
/// instância viva nesse isolate não existe ou está desincronizada. Por
/// isso grava diretamente no armazenamento partilhado (SharedPreferences),
/// que é seguro de aceder de qualquer isolate.
///
/// TEM de ser uma função de topo (fora de qualquer classe) e marcada com
/// @pragma('vm:entry-point') para que o Android consiga invocá-la mesmo
/// com a app completamente fechada.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null) return;

  // DartPluginRegistrant só é necessário quando este handler corre num
  // isolate novo (app fechada). Chamá-lo no isolate principal (app
  // aberta) é redundante mas inofensivo — confirmado pela documentação
  // oficial do plugin como seguro em ambos os casos.
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final notifications = NotificationService();
  await notifications.init();

  if (actionId == actionScheduleNext) {
    // Termina o jejum atual (se existir) e regista-o no histórico.
    final active = storage.loadActiveSession();
    if (active != null) {
      final finished = active.copyWith(endTime: DateTime.now());
      await storage.appendToHistory(finished);
      await storage.saveActiveSession(null);
    }
    await notifications.cancelFastEndNotification();

    // Agenda o início do próximo jejum para o fim da janela de
    // alimentação, definida de forma independente pelo utilizador (não é
    // sempre 24h - jejum, para permitir ciclos curtos repetidos).
    final protocolMinutes = active?.goalDuration.inMinutes ??
        storage.loadLastFinishedProtocolMinutes() ??
        storage.loadDefaultProtocolMinutes();
    final eatingWindowMinutes = storage.loadEatingWindowMinutes();
    final nextStart =
        DateTime.now().add(Duration(minutes: eatingWindowMinutes));

    await storage.saveScheduledNextFast(nextStart, protocolMinutes);
    await notifications.scheduleFastStartNotification(nextStart);
  } else if (actionId == actionDismiss) {
    // "Agora não": apenas termina o jejum atual, sem agendar o próximo.
    final active = storage.loadActiveSession();
    if (active != null) {
      final finished = active.copyWith(endTime: DateTime.now());
      await storage.appendToHistory(finished);
      await storage.saveActiveSession(null);
    }
    await notifications.cancelFastEndNotification();
  }

  // Só agora, com toda a escrita já concluída, avisa a UI em primeiro
  // plano (caso esteja a escutar) para reler o estado atualizado.
  notificationActionStream.add(actionId);
}

/// Serviço responsável por agendar, cancelar, e reagir às notificações de
/// fim/início de jejum. Não sabe nada sobre AppState — apenas notifica
/// através de [notificationActionStream] quando uma ação é escolhida,
/// mantendo a separação entre lógica de notificações e lógica de negócio.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Verifica se a app foi aberta a partir do toque numa ação da
  /// notificação de fim de jejum (ex: o Android entregou o toque ao abrir
  /// a app em vez de processar em background). Chamado no arranque da
  /// app como rede de segurança extra.
  Future<void> consumePendingLaunchAction() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      await notificationBackgroundHandler(response);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tzdata.initializeTimeZones();
    _setLocalTimeZoneFromDeviceOffset();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: notificationBackgroundHandler,
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundHandler,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'fast_end_channel',
      'Fim de jejum',
      description: 'Avisa quando o jejum atual termina.',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'fast_start_channel',
      'Início de jejum',
      description: 'Avisa quando um jejum agendado começa.',
      importance: Importance.high,
    ));
  }

  /// O package timezone assume UTC como fuso local por defeito, o que
  /// fazia os agendamentos ficarem desviados pelo offset do dispositivo
  /// (ex: notificações nunca dispararem, por ficarem "no passado" assim
  /// que comparadas com a hora local real). Em vez de depender de um
  /// plugin extra só para obter o nome IANA do fuso, procuramos na base
  /// de dados já carregada uma localização cujo offset atual coincida
  /// com o offset que o próprio Dart já conhece (DateTime.timeZoneOffset).
  void _setLocalTimeZoneFromDeviceOffset() {
    final deviceOffset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final offset =
          Duration(milliseconds: location.currentTimeZone.offset);
      if (offset == deviceOffset) {
        tz.setLocalLocation(location);
        return;
      }
    }
    // Não encontrou nenhuma correspondência exata (muito improvável) —
    // mantém UTC, melhor do que rebentar.
  }

  /// Mostra (sem agendamento) a notificação de fim de jejum, com as
  /// ações "Marcar próximo" / "Agora não". É a única fonte desta
  /// notificação — chamada por AppState.checkFastCompletion() a cada 30s
  /// enquanto a app está aberta, em vez de depender de zonedSchedule
  /// (fonte de inconsistência com fuso horário e o modo Doze do Android).
  Future<void> showFastEndNotificationNow() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'fast_end_channel',
      'Fim de jejum',
      channelDescription: 'Avisa quando o jejum atual termina.',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          actionScheduleNext,
          'Marcar próximo',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          actionDismiss,
          'Agora não',
          showsUserInterface: false,
        ),
      ],
    );
    await _plugin.show(
      fastEndNotificationId,
      'O seu jejum terminou',
      'Quer agendar o próximo jejum?',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> scheduleFastEndNotification(DateTime endTime) async {
    await init();
    await _plugin.show(
      9999,
      'Jejum iniciado',
      'O seu jejum está a contar. Boa sorte!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fast_end_channel',
          'Fim de jejum',
          channelDescription: 'Avisa quando o jejum atual termina.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    // A notificação de fim de jejum, com as ações "Marcar próximo" /
    // "Agora não", já não é agendada aqui via zonedSchedule — em vez
    // disso, é mostrada de forma imediata e fiável por
    // AppState.checkFastCompletion() (ver showFastEndNotificationNow),
    // que corre a cada 30s enquanto a app está aberta. Isto evita
    // inconsistências de fuso horário e do modo Doze do Android que
    // afetavam notificações agendadas com ações interativas.
  }

  /// Cancela a notificação de fim de jejum agendada (ex: quando o jejum é
  /// terminado manualmente antes do tempo, ou cancelado).
  Future<void> cancelFastEndNotification() async {
    await init();
    await _plugin.cancel(fastEndNotificationId);
  }

  /// Agenda a notificação simples (sem ações) que avisa que o próximo
  /// jejum começou, no momento exato em que a janela de alimentação
  /// termina. Não depende de o utilizador abrir a app.
  Future<void> scheduleFastStartNotification(DateTime startTime) async {
    await init();
    if (startTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(startTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'fast_start_channel',
      'Início de jejum',
      channelDescription: 'Avisa quando um jejum agendado começa.',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      fastStartNotificationId,
      'O seu jejum começou',
      'A janela de alimentação terminou. Bom jejum!',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelFastStartNotification() async {
    await init();
    await _plugin.cancel(fastStartNotificationId);
  }
}
