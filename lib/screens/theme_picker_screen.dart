import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escolher tema'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: HomeThemeId.values.map((theme) {
            final locked = theme.isPremium && !state.isPremium;
            final selected = state.selectedTheme == theme;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (locked) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  } else {
                    state.setSelectedTheme(theme);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(color: AppColors.info, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(theme.label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (theme == HomeThemeId.diario)
                              const Text('Grátis',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (locked)
                        const Icon(Icons.lock_outline,
                            size: 18, color: AppColors.warning)
                      else if (selected)
                        const Icon(Icons.check_circle,
                            color: AppColors.info)
                      else
                        const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
