import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fasting_session.dart';

/// Camada única responsável por guardar e ler todos os dados da app
/// localmente no telemóvel. Nenhum dado é enviado para qualquer servidor.
class StorageService {
  static const _keyActiveSession = 'active_fasting_session';
  static const _keySessionHistory = 'fasting_session_history';
  static const _keyWaterGoal = 'water_goal_ml';
  static const _keyDefaultProtocolHours = 'default_protocol_hours';
  static const _keySelectedTheme = 'selected_theme';
  static const _keyIsPremium = 'is_premium';
  static const _keyOnboardingDone = 'onboarding_done';
  static const _keyScheduledNextFastTime = 'scheduled_next_fast_time';
  static const _keyScheduledNextFastHours = 'scheduled_next_fast_hours';
  static const _keyPendingWaterMl = 'pending_water_ml';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ---- Água pendente (sem jejum ativo no momento) ----

  /// Água acumulada fora de qualquer jejum ativo. É absorvida pelo
  /// próximo jejum que começar (ver AppState.startFasting), para que o
  /// utilizador não perca o registo de água bebida nesse intervalo.
  Future<void> savePendingWater(int ml) async {
    await _prefs.setInt(_keyPendingWaterMl, ml);
  }

  int loadPendingWater() => _prefs.getInt(_keyPendingWaterMl) ?? 0;

  Future<void> clearPendingWater() async {
    await _prefs.remove(_keyPendingWaterMl);
  }

  // ---- Próximo jejum agendado (janela de alimentação em curso) ----

  /// Guarda a hora em que o próximo jejum deve começar automaticamente,
  /// junto com o protocolo (horas) a usar nesse jejum. `null` para limpar.
  Future<void> saveScheduledNextFast(DateTime? time, int? hours) async {
    if (time == null) {
      await _prefs.remove(_keyScheduledNextFastTime);
      await _prefs.remove(_keyScheduledNextFastHours);
      return;
    }
    await _prefs.setString(_keyScheduledNextFastTime, time.toIso8601String());
    await _prefs.setInt(_keyScheduledNextFastHours, hours ?? 16);
  }

  DateTime? loadScheduledNextFastTime() {
    final raw = _prefs.getString(_keyScheduledNextFastTime);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  int loadScheduledNextFastHours() =>
      _prefs.getInt(_keyScheduledNextFastHours) ?? 16;

  // ---- Sessão de jejum ativa ----

  Future<void> saveActiveSession(FastingSession? session) async {
    if (session == null) {
      await _prefs.remove(_keyActiveSession);
      return;
    }
    await _prefs.setString(_keyActiveSession, jsonEncode(session.toJson()));
  }

  FastingSession? loadActiveSession() {
    final raw = _prefs.getString(_keyActiveSession);
    if (raw == null) return null;
    try {
      return FastingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Dados corrompidos não devem impedir a app de arrancar.
      return null;
    }
  }

  // ---- Histórico de jejuns terminados ----

  Future<void> appendToHistory(FastingSession session) async {
    final history = loadHistory();
    history.add(session);
    final encoded = history.map((s) => s.toJson()).toList();
    await _prefs.setString(_keySessionHistory, jsonEncode(encoded));
  }

  List<FastingSession> loadHistory() {
    final raw = _prefs.getString(_keySessionHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FastingSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- Definições gerais ----

  Future<void> saveWaterGoal(int ml) async {
    await _prefs.setInt(_keyWaterGoal, ml);
  }

  int loadWaterGoal() => _prefs.getInt(_keyWaterGoal) ?? 2000;

  Future<void> saveDefaultProtocolHours(int hours) async {
    await _prefs.setInt(_keyDefaultProtocolHours, hours);
  }

  int loadDefaultProtocolHours() =>
      _prefs.getInt(_keyDefaultProtocolHours) ?? 16;

  Future<void> saveSelectedTheme(String themeId) async {
    await _prefs.setString(_keySelectedTheme, themeId);
  }

  String loadSelectedTheme() => _prefs.getString(_keySelectedTheme) ?? 'diario';

  Future<void> savePremiumStatus(bool isPremium) async {
    await _prefs.setBool(_keyIsPremium, isPremium);
  }

  bool loadPremiumStatus() => _prefs.getBool(_keyIsPremium) ?? false;

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(_keyOnboardingDone, true);
  }

  bool isOnboardingDone() => _prefs.getBool(_keyOnboardingDone) ?? false;
}
