import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'home_diario_screen.dart';
import 'home_relogio_screen.dart';
import 'home_linha_do_tempo_screen.dart';

/// Escolhe qual variante visual do ecrã principal mostrar,
/// com base no tema selecionado nas definições.
class HomeRouterScreen extends StatelessWidget {
  const HomeRouterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().selectedTheme;
    switch (theme) {
      case HomeThemeId.relogio:
        return const HomeRelogioScreen();
      case HomeThemeId.linhaDoTempo:
        return const HomeLinhaDoTempoScreen();
      case HomeThemeId.diario:
        return const HomeDiarioScreen();
    }
  }
}
