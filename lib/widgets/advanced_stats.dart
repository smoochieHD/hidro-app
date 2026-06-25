import 'package:flutter/material.dart';
import '../models/fasting_session.dart';
import '../theme/app_theme.dart';

/// Heatmap de consistência: um quadrado por dia, dos últimos [weeks]
/// semanas, mostrando se houve jejum terminado nesse dia e se a meta foi
/// cumprida (cor cheia) ou terminado antes do tempo (cor mais clara).
/// Dias sem jejum ficam neutros.
class ConsistencyHeatmap extends StatelessWidget {
  final List<FastingSession> history;
  final int weeks;

  const ConsistencyHeatmap({
    super.key,
    required this.history,
    this.weeks = 10,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final totalDays = weeks * 7;
    final startDay = todayOnly.subtract(Duration(days: totalDays - 1));

    // Para cada dia, guarda se houve sessão e se atingiu a meta. Se houver
    // mais que uma sessão no mesmo dia, considera o melhor resultado
    // (qualquer uma com meta cumprida marca o dia como "cumprido").
    final dayStatus = <DateTime, bool>{};
    for (final s in history) {
      final day =
          DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      if (day.isBefore(startDay)) continue;
      final current = dayStatus[day];
      if (current == true) continue;
      dayStatus[day] = s.goalReached;
    }

    final completedCount = dayStatus.values.where((v) => v).length;
    final trackedCount = dayStatus.length;
    final percentage =
        trackedCount == 0 ? 0 : (completedCount / totalDays * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Consistência · últimas $weeks semanas',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: weeks,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: totalDays,
          itemBuilder: (context, index) {
            // Preenche por colunas (cada coluna = 1 semana, de cima para
            // baixo), por isso percorremos por linha-dentro-de-semana.
            final week = index % weeks;
            final dayInWeek = index ~/ weeks;
            final dayOffset = week * 7 + dayInWeek;
            final day = startDay.add(Duration(days: dayOffset));

            Color color;
            if (day.isAfter(todayOnly)) {
              color = Colors.transparent;
            } else if (!dayStatus.containsKey(day)) {
              color = AppColors.borderTertiary;
            } else if (dayStatus[day] == true) {
              color = AppColors.info;
            } else {
              color = AppColors.info.withValues(alpha: 0.35);
            }

            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          trackedCount == 0
              ? 'Ainda sem dados suficientes neste período.'
              : '$percentage% dos dias com meta cumprida',
          style:
              const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
