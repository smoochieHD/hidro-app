import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// Bloco "Hoje · X copos de água · + copo", idêntico em todos os temas.
/// Extraído do tema Diário para garantir que os três temas mostram
/// exatamente o mesmo visual, em vez de versões ligeiramente diferentes.
class TodayWaterRow extends StatelessWidget {
  const TodayWaterRow({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _timelineItem(
      icon: Icons.water_drop_outlined,
      title: '${(state.currentWaterMl / 250).round()} copos de água',
      subtitle: '${state.currentWaterMl}ml de ${state.waterGoalMl}ml',
      trailing: TextButton(
        onPressed: () => state.addWater(250),
        child: const Text('+ copo'),
      ),
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.infoBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: AppColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
