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
  StreamSubscription<String>? _notificationActionSub;

  FastingSession? activeSession;
  int defaultProtocolHours;
  HomeThemeId selectedTheme;
  bool isPremium;

  /// Índice da aba ativa no MainShell (0=Início, 1=Estatísticas,
  /// 2=Histórico, 3=Definições). Vive aqui, em vez de no MainShell, para
  /// que qualquer ecrã (ex: o ícone de definições nos temas do ecrã
  /// principal) possa trocar de aba sem precisar de importar o MainShell
  /// e sem criar um ciclo de dependências entre ficheiros.
  int activeTabIndex = 0;

  AppState._({
    required this.storage,
    required this.activeSession,
    required this.defaultProtocolHours,
    required this.selectedTheme,
    required this.isPremium,
  }) {
    // Reage a ações tocadas na notificação de fim de jejum quando a app
    // está em primeiro plano. Quando a app está em background/fechada, a
    // ação ainda é processada pelo handler nativo (ver notification_service
    // .dart), mas este listener garante que a UI reflete a mudança de
    // imediato se a pessoa abrir a app pouco depois de tocar na ação.
    _notificationActionSub = notificationActionStream.stream.listen((action) {
      _handleNotificationAction(action);
    });
  }

  static Future<AppState> create() async {
    final storage = await StorageService.create();
    final state = AppState._(
      storage: storage,
      activeSession: storage.loadActiveSession(),
      defaultProtocolHours: storage.loadDefaultProtocolHours(),
      selectedTheme: HomeThemeIdX.fromId(storage.loadSelectedTheme()),
      isPremium: storage.loadPremiumStatus(),
    );
    await state._notifications.init();
    await state.checkScheduledNextFast();
    return state;
  }

  @override
  void dispose() {
    _notificationActionSub?.cancel();
    super.dispose();
  }

  // ---- Jejum ----

  Future<void> startFasting({int? hours}) async {
    final goalHours = hours ?? defaultProtocolHours;
    // Qualquer água registada enquanto não havia jejum ativo (durante a
    // janela de alimentação) passa a contar para este novo jejum, em vez
    // de se perder.
    final carriedWater = storage.loadPendingWater();
    activeSession = FastingSession(
      startTime: DateTime.now(),
      goalDuration: Duration(hours: goalHours),
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

  /// Reage a uma ação tocada na notificação de fim de jejum. A lógica de
  /// negócio (terminar sessão, agendar a próxima) já foi executada pelo
  /// handler de background (ver notification_service.dart), que escreve
  /// diretamente no armazenamento partilhado — mesmo com a app fechada.
  /// Aqui, este método só precisa de "reler" esse estado já atualizado
  /// para que a UI, se estiver visível, reflita a mudança imediatamente.
  Future<void> _handleNotificationAction(String actionId) async {
    if (actionId != actionScheduleNext && actionId != actionDismiss) return;
    activeSession = storage.loadActiveSession();
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

    final hours = storage.loadScheduledNextFastHours();
    final carriedWater = storage.loadPendingWater();
    activeSession = FastingSession(
      startTime: scheduledTime,
      goalDuration: Duration(hours: hours),
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

  Future<void> setDefaultProtocolHours(int hours) async {
    defaultProtocolHours = hours;
    await storage.saveDefaultProtocolHours(hours);
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
