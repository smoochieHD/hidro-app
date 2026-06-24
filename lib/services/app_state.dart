import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fasting_session.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Estado central da app: sessão de jejum atual, água do ciclo atual,
/// definições. Todos os ecrãs leem e escrevem através desta única fonte
/// de verdade, o que evita inconsistências entre os diferentes temas
/// visuais.
class AppState extends ChangeNotifier {
  final StorageService storage;
  final NotificationService _notifications = NotificationService();

  FastingSession? activeSession;
  int defaultProtocolMinutes;
  HomeThemeId selectedTheme;
  bool isPremium;

  /// Quando ligado, ao terminar um jejum (manualmente ou automaticamente
  /// ao atingir a meta), o próximo jejum é agendado automaticamente para
  /// o fim da janela de alimentação — sem precisar de tocar em nada.
  bool autoScheduleNextCycle;

  /// Índice da aba ativa no MainShell (0=Início, 1=Estatísticas,
  /// 2=Histórico, 3=Definições). Vive aqui, em vez de no MainShell, para
  /// que qualquer ecrã (ex: o ícone de definições nos temas do ecrã
  /// principal) possa trocar de aba sem precisar de importar o MainShell
  /// e sem criar um ciclo de dependências entre ficheiros.
  int activeTabIndex = 0;

  AppState._({
    required this.storage,
    required this.activeSession,
    required this.defaultProtocolMinutes,
    required this.selectedTheme,
    required this.isPremium,
    required this.autoScheduleNextCycle,
  });

  static Future<AppState> create() async {
    final storage = await StorageService.create();
    final state = AppState._(
      storage: storage,
      activeSession: storage.loadActiveSession(),
      defaultProtocolMinutes: storage.loadDefaultProtocolMinutes(),
      selectedTheme: HomeThemeIdX.fromId(storage.loadSelectedTheme()),
      isPremium: storage.loadPremiumStatus(),
      autoScheduleNextCycle: storage.loadAutoScheduleNextCycle(),
    );
    // Não bloqueia o arranque da app: a inicialização do plugin de
    // notificações (e o pedido de permissões ao sistema) corre em
    // paralelo, para o primeiro ecrã aparecer imediatamente.
    unawaited(state._notifications.init());
    await state.checkScheduledNextFast();
    return state;
  }

  /// Relê do armazenamento partilhado os campos que podem ter mudado
  /// (ex: jejum agendado que já deve ter começado). Chamado
  /// periodicamente pelos ecrãs do tema principal.
  Future<void> refreshFromStorage() async {
    await checkScheduledNextFast();
    activeSession = storage.loadActiveSession();
    notifyListeners();
  }

  /// Chamado periodicamente pela UI (ver _ticker nos ecrãs do tema
  /// principal) e ao voltar ao primeiro plano. Deteta se o jejum ativo já
  /// passou da meta e, nesse caso, termina-o automaticamente e mostra a
  /// notificação de fim. Se [autoScheduleNextCycle] estiver ligado,
  /// agenda também o início do próximo jejum para o fim da janela de
  /// alimentação.
  Future<void> checkFastCompletion() async {
    final session = activeSession;
    if (session == null) return;
    if (!session.goalReached) return;
    if (_fastCompletionNotifiedFor == session.startTime) return;
    _fastCompletionNotifiedFor = session.startTime;

    // Termina automaticamente no instante planeado (não na hora em que a
    // verificação correu), para o histórico ficar com a duração exata.
    final finished = session.copyWith(endTime: session.plannedEndTime);
    await storage.appendToHistory(finished);
    activeSession = null;
    await storage.saveActiveSession(null);
    await storage.saveLastFinishedProtocolMinutes(session.goalDuration.inMinutes);
    await _notifications.cancelFastEndNotification();
    await _notifications.showFastEndNotificationNow();

    if (autoScheduleNextCycle) {
      await _scheduleNextCycle(session.goalDuration.inMinutes);
    }

    notifyListeners();
  }

  /// Agenda o início do próximo jejum para o fim da janela de
  /// alimentação configurada, usando [protocolMinutes] no novo ciclo.
  Future<void> _scheduleNextCycle(int protocolMinutes) async {
    final eatingWindowMinutes = storage.loadEatingWindowMinutes();
    final nextStart =
        DateTime.now().add(Duration(minutes: eatingWindowMinutes));
    await storage.saveScheduledNextFast(nextStart, protocolMinutes);
    await _notifications.scheduleFastStartNotification(nextStart);
  }

  Future<void> setAutoScheduleNextCycle(bool value) async {
    autoScheduleNextCycle = value;
    await storage.saveAutoScheduleNextCycle(value);
    notifyListeners();
  }

  DateTime? _fastCompletionNotifiedFor;

  // ---- Jejum ----

  Future<void> startFasting({int? minutes}) async {
    final goalMinutes = minutes ?? defaultProtocolMinutes;
    // Qualquer água registada enquanto não havia jejum ativo (durante a
    // janela de alimentação) passa a contar para este novo jejum, em vez
    // de se perder.
    final carriedWater = storage.loadPendingWater();
    activeSession = FastingSession(
      startTime: DateTime.now(),
      goalDuration: Duration(minutes: goalMinutes),
      waterMl: carriedWater,
    );
    await storage.clearPendingWater();
    await storage.saveActiveSession(activeSession);
    await _notifications.scheduleFastEndNotification(
      activeSession!.plannedEndTime,
    );
    // Se havia um próximo jejum agendado via notificação (janela de
    // alimentação em curso) e o utilizador decidiu começar manualmente
    // antes disso, esse agendamento deixa de fazer sentido.
    await storage.saveScheduledNextFast(null, null);
    await _notifications.cancelFastStartNotification();
    notifyListeners();
  }

  /// Termina o jejum ativo manualmente. A água registada durante este
  /// jejum fica guardada com ele no histórico; a partir daqui, qualquer
  /// água nova registada antes do próximo jejum começar fica "pendente"
  /// e é absorvida por esse próximo jejum.
  ///
  /// Cancela também a notificação de fim de jejum agendada, já que deixa
  /// de fazer sentido avisar sobre um jejum que já foi terminado.
  Future<void> endFasting() async {
    if (activeSession == null) return;
    final finished = activeSession!.copyWith(endTime: DateTime.now());
    await storage.appendToHistory(finished);
    activeSession = null;
    await storage.saveActiveSession(null);
    await _notifications.cancelFastEndNotification();
    notifyListeners();
  }

  /// Chamado ao arrancar a app (ou sempre que se torna visível): verifica
  /// se há um jejum agendado (janela de alimentação) cuja hora de início
  /// já passou — o que acontece se a app esteve fechada quando a segunda
  /// notificação ("O seu jejum começou") disparou — e, nesse caso, inicia
  /// o jejum agora, com a hora de início real planeada (não a hora atual),
  /// para que o tempo decorrido fique correto.
  Future<void> checkScheduledNextFast() async {
    final scheduledTime = storage.loadScheduledNextFastTime();
    if (scheduledTime == null) return;
    if (DateTime.now().isBefore(scheduledTime)) return;
    if (activeSession != null) return; // já há um jejum ativo, não duplicar

    final minutes = storage.loadScheduledNextFastMinutes();
    final carriedWater = storage.loadPendingWater();
    activeSession = FastingSession(
      startTime: scheduledTime,
      goalDuration: Duration(minutes: minutes),
      waterMl: carriedWater,
    );
    await storage.clearPendingWater();
    await storage.saveActiveSession(activeSession);
    await storage.saveScheduledNextFast(null, null);
    await _notifications.scheduleFastEndNotification(
      activeSession!.plannedEndTime,
    );
    notifyListeners();
  }

  // ---- Água ----
  //
  // A água é contabilizada por ciclo de jejum, não por dia civil: cada
  // FastingSession guarda a sua própria água (waterMl). Quando não há
  // jejum ativo, a água registada fica "pendente" e é absorvida pelo
  // próximo jejum que começar. A meta (goalMl) é uma definição única e
  // global, igual em todos os ciclos até o utilizador a alterar.

  int get waterGoalMl => storage.loadWaterGoal();

  /// Água já registada no ciclo atual: do jejum ativo, se houver, ou da
  /// água pendente acumulada durante a janela de alimentação.
  int get currentWaterMl =>
      activeSession?.waterMl ?? storage.loadPendingWater();

  double get currentWaterProgress {
    final goal = waterGoalMl;
    if (goal == 0) return 0.0;
    return (currentWaterMl / goal).clamp(0.0, 1.0);
  }

  Future<void> addWater(int ml) async {
    if (activeSession != null) {
      activeSession!.addWater(ml);
      await storage.saveActiveSession(activeSession);
    } else {
      final updated = (storage.loadPendingWater() + ml).clamp(0, 1 << 30);
      await storage.savePendingWater(updated);
    }
    notifyListeners();
  }

  Future<void> setWaterGoal(int ml) async {
    await storage.saveWaterGoal(ml);
    notifyListeners();
  }

  // ---- Definições ----

  Future<void> setDefaultProtocolMinutes(int minutes) async {
    defaultProtocolMinutes = minutes;
    await storage.saveDefaultProtocolMinutes(minutes);
    notifyListeners();
  }

  /// Define o protocolo de jejum e recalcula automaticamente o tempo de
  /// comer como 24h - jejum (ex: 16h jejum -> 8h comer). Usado pelos
  /// presets (16:8, 18:6, 20:4); a duração personalizada continua a
  /// permitir definir os dois valores de forma independente, para ciclos
  /// curtos repetidos.
  Future<void> setDefaultProtocolMinutesWithAutoWindow(int minutes) async {
    defaultProtocolMinutes = minutes;
    await storage.saveDefaultProtocolMinutes(minutes);
    final autoWindow = (24 * 60 - minutes).clamp(1, 24 * 60 - 1);
    await storage.saveEatingWindowMinutes(autoWindow);
    notifyListeners();
  }

  int get eatingWindowMinutes => storage.loadEatingWindowMinutes();

  Future<void> setEatingWindowMinutes(int minutes) async {
    await storage.saveEatingWindowMinutes(minutes);
    notifyListeners();
  }

  Future<void> setSelectedTheme(HomeThemeId theme) async {
    if (theme.isPremium && !isPremium) return;
    selectedTheme = theme;
    await storage.saveSelectedTheme(theme.id);
    notifyListeners();
  }

  /// Usado apenas para simular/testar o estado premium nesta fase inicial,
  /// antes de ligarmos o Google Play Billing real.
  Future<void> setPremiumStatus(bool value) async {
    isPremium = value;
    await storage.savePremiumStatus(value);
    notifyListeners();
  }

  // ---- Navegação entre abas ----

  static const tabIndexHome = 0;
  static const tabIndexStats = 1;
  static const tabIndexHistory = 2;
  static const tabIndexSettings = 3;

  void goToTab(int index) {
    if (activeTabIndex == index) return;
    activeTabIndex = index;
    notifyListeners();
  }

  void goToSettings() => goToTab(tabIndexSettings);

  /// Hora em que o próximo jejum está agendado para começar
  /// automaticamente (fim da janela de alimentação), ou null se não há
  /// nenhum agendamento pendente.
  DateTime? get scheduledNextFastTime => storage.loadScheduledNextFastTime();

  List<FastingSession> get history => storage.loadHistory();
}
