import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'home_router_screen.dart';
import 'stats_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Estrutura principal da app: 4 ecrãs acessíveis pela barra de navegação
/// inferior (Início, Estatísticas, Histórico, Definições).
///
/// A aba ativa vive em [AppState.activeTabIndex], não num estado local,
/// para que qualquer ecrã (ex: o ícone de definições nos temas do ecrã
/// principal) possa trocar de aba através de `context.read<AppState>()`,
/// sem precisar de importar este ficheiro.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeRouterScreen(),
    StatsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = context.watch<AppState>().activeTabIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: activeIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          currentIndex: activeIndex,
          onTap: (i) => context.read<AppState>().goToTab(i),
        ),
      ),
    );
  }
}
