import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
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

  // Avisa a UI em primeiro plano, caso esteja a escutar (não bloqueia se
  // não estiver — broadcast streams sem listeners não acumulam eventos).
  notificationActionStream.add(actionId);

  // Garante que este isolate tem acesso aos plugins (shared_preferences,
  // notificações), já que pode ser um isolate novo, sem o registo normal
  // que main() faz no isolate principal.
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
    // alimentação (24h - duração do protocolo), usando o mesmo protocolo
    // que o jejum que acabou de terminar (ou o valor por defeito das
    // definições, se por algum motivo não houver sessão anterior).
    final protocolMinutes = active?.goalDuration.inMinutes ??
        storage.loadDefaultProtocolMinutes();
    final eatingWindow = Duration(
      minutes: (24 * 60 - protocolMinutes).clamp(1, 24 * 60 - 1),
    );
    final nextStart = DateTime.now().add(eatingWindow);

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

  /// Agenda a notificação de fim de jejum para o instante exato [endTime],
  /// com as ações "Marcar próximo" e "Agora não".
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
    if (endTime.isBefore(DateTime.now())) {
      debugPrint('[Hidro] scheduleFastEndNotification: endTime ($endTime) '
          'já passou (agora: ${DateTime.now()}), notificação NÃO agendada.');
      return;
    }

    final scheduledDate = tz.TZDateTime.from(endTime, tz.local);
    debugPrint('[Hidro] A agendar fim de jejum para $scheduledDate '
        '(fuso local: ${tz.local.name})');

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
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionDismiss,
          'Agora não',
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin.zonedSchedule(
      fastEndNotificationId,
      'O seu jejum terminou',
      'Quer agendar o próximo jejum?',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('[Hidro] Notificação de fim de jejum agendada com sucesso.');
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
