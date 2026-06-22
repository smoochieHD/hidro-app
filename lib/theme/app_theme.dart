import 'package:flutter/material.dart';

/// Cores e constantes visuais partilhadas por toda a app,
/// para manter consistência entre os três temas do ecrã principal.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const backgroundSecondary = Color(0xFFF5F6F8);
  static const textPrimary = Color(0xFF1A1D1F);
  static const textSecondary = Color(0xFF6F7780);
  static const borderTertiary = Color(0xFFE5E7EA);

  static const info = Color(0xFF3B82C4);
  static const infoBackground = Color(0xFFEAF2FA);

  static const teal = Color(0xFF2F8F84);
  static const tealBackground = Color(0xFFE6F3F1);

  static const warning = Color(0xFFB8860B);
  static const warningBackground = Color(0xFFFBF1DC);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.info,
        brightness: Brightness.light,
        primary: AppColors.info,
        surface: AppColors.background,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.infoBackground,
          foregroundColor: AppColors.info,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderTertiary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.info,
        ),
      ),
    );
  }
}

/// Identificadores dos três temas visuais do ecrã principal.
enum HomeThemeId { diario, relogio, linhaDoTempo }

extension HomeThemeIdX on HomeThemeId {
  String get id {
    switch (this) {
      case HomeThemeId.diario:
        return 'diario';
      case HomeThemeId.relogio:
        return 'relogio';
      case HomeThemeId.linhaDoTempo:
        return 'linha_do_tempo';
    }
  }

  String get label {
    switch (this) {
      case HomeThemeId.diario:
        return 'Diário';
      case HomeThemeId.relogio:
        return 'Relógio';
      case HomeThemeId.linhaDoTempo:
        return 'Linha do tempo';
    }
  }

  bool get isPremium => this != HomeThemeId.diario;

  static HomeThemeId fromId(String id) {
    switch (id) {
      case 'relogio':
        return HomeThemeId.relogio;
      case 'linha_do_tempo':
        return HomeThemeId.linhaDoTempo;
      default:
        return HomeThemeId.diario;
    }
  }
}
