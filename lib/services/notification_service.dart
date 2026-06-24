import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'storage_service.dart';
import '../models/fasting_session.dart';

/// IDs fixos das notificações geridas por este serviço. Como só existe,
/// no máximo, um jejum ativo e um próximo jejum agendado de cada vez,
/// reutilizar sempre o mesmo ID substitui/cancela automaticamente a
/// notificação anterior em vez de acumular notificações antigas.
const int fastEndNotificationId = 1001;
const int fastStartNotificationId = 1002;

/// Serviço responsável por mostrar e agendar as notificações de
/// fim/início de jejum. O agendamento automático do próximo ciclo é
/// controlado pelo toggle "Agendar ciclo" em AppState, não por ações
/// dentro das notificações.
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

    await _plugin.initialize(initSettings);

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

  /// Mostra (sem agendamento) a notificação de fim de jejum. Sem ações:
  /// agendar o próximo ciclo passou a ser feito diretamente na app
  /// (toggle "Agendar ciclo"), porque os botões de ação em notificações
  /// não se mostraram fiáveis em todos os dispositivos Android testados.
  Future<void> showFastEndNotificationNow() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'fast_end_channel',
      'Fim de jejum',
      channelDescription: 'Avisa quando o jejum atual termina.',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      fastEndNotificationId,
      'O seu jejum terminou',
      'Abra a app para ver o resumo.',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Mostra a notificação imediata "Jejum iniciado", como confirmação
  /// visual ao tocar em "Iniciar jejum".
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
