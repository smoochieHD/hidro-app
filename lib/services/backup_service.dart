import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/fasting_session.dart';
import '../models/fasting_profile.dart';
import 'storage_service.dart';

/// Versão do formato de backup. Incrementar se a estrutura mudar de
/// forma incompatível, para podermos detetar backups antigos no import.
const int backupFormatVersion = 1;

/// Exporta e importa um backup em JSON com os dados essenciais da app:
/// histórico de jejuns, perfis guardados, e definições principais. Não
/// inclui estado efémero (sessão ativa, água pendente, agendamentos
/// futuros), que não faz sentido restaurar de um backup antigo.
class BackupService {
  final StorageService storage;

  BackupService(this.storage);

  Map<String, dynamic> _buildBackupJson() {
    return {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'history': storage.loadHistory().map((s) => s.toJson()).toList(),
      'profiles': storage.loadFastingProfiles().map((p) => p.toJson()).toList(),
      'settings': {
        'defaultProtocolMinutes': storage.loadDefaultProtocolMinutes(),
        'eatingWindowMinutes': storage.loadEatingWindowMinutes(),
        'waterGoalMl': storage.loadWaterGoal(),
        'selectedTheme': storage.loadSelectedTheme(),
        'weeklyReportEnabled': storage.loadWeeklyReportEnabled(),
        'waterRemindersEnabled': storage.loadWaterRemindersEnabled(),
        'autoScheduleNextCycle': storage.loadAutoScheduleNextCycle(),
      },
    };
  }

  /// Gera o ficheiro de backup e abre o partilhador nativo do Android,
  /// para o utilizador guardar onde quiser (Google Drive, email, etc.).
  Future<void> exportAndShare() async {
    final json = const JsonEncoder.withIndent('  ').convert(_buildBackupJson());
    final dir = await getTemporaryDirectory();
    final dateStamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/hidro-backup-$dateStamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Backup Hidro',
      text: 'Backup dos teus dados Hidro.',
    );
  }

  /// Resultado de uma tentativa de importação: sucesso, ou motivo de
  /// falha numa string simples para mostrar ao utilizador.
  Future<String?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) {
      return null; // utilizador cancelou, não é erro
    }

    final path = result.files.single.path;
    if (path == null) return 'Não foi possível ler o ficheiro escolhido.';

    try {
      final content = await File(path).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await _restoreFromJson(data);
      return null; // sucesso
    } catch (_) {
      return 'O ficheiro escolhido não é um backup válido do Hidro.';
    }
  }

  Future<void> _restoreFromJson(Map<String, dynamic> data) async {
    final historyJson = data['history'] as List<dynamic>? ?? [];
    final imported = historyJson
        .map((e) => FastingSession.fromJson(e as Map<String, dynamic>))
        .toList();

    final existingStartTimes =
        storage.loadHistory().map((s) => s.startTime).toSet();
    for (final session in imported) {
      if (existingStartTimes.contains(session.startTime)) continue;
      await storage.appendToHistory(session);
    }

    final profilesJson = data['profiles'] as List<dynamic>? ?? [];
    final profiles = profilesJson
        .map((e) => FastingProfile.fromJson(e as Map<String, dynamic>))
        .toList();
    if (profiles.isNotEmpty) {
      await storage.saveFastingProfiles(profiles);
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      if (settings['defaultProtocolMinutes'] != null) {
        await storage.saveDefaultProtocolMinutes(
            settings['defaultProtocolMinutes'] as int);
      }
      if (settings['eatingWindowMinutes'] != null) {
        await storage.saveEatingWindowMinutes(
            settings['eatingWindowMinutes'] as int);
      }
      if (settings['waterGoalMl'] != null) {
        await storage.saveWaterGoal(settings['waterGoalMl'] as int);
      }
      if (settings['selectedTheme'] != null) {
        await storage.saveSelectedTheme(settings['selectedTheme'] as String);
      }
      if (settings['weeklyReportEnabled'] != null) {
        await storage.saveWeeklyReportEnabled(
            settings['weeklyReportEnabled'] as bool);
      }
      if (settings['waterRemindersEnabled'] != null) {
        await storage.saveWaterRemindersEnabled(
            settings['waterRemindersEnabled'] as bool);
      }
      if (settings['autoScheduleNextCycle'] != null) {
        await storage.saveAutoScheduleNextCycle(
            settings['autoScheduleNextCycle'] as bool);
      }
    }
  }
}
