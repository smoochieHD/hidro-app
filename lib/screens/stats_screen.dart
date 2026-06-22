import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;
    final streak = _currentStreak(history);
    final avgMinutes = _averageFastMinutes(history);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estatísticas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _statTile('Sequência atual', '$streak dias'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  'Média jejum',
                  avgMinutes == null
                      ? '--'
                      : '${avgMinutes ~/ 60}:${(avgMinutes % 60).toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Histórico recente',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text(
              'Ainda não tens jejuns terminados. Conclui o teu primeiro jejum para veres dados aqui.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ...history.reversed.take(7).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${s.startTime.day}/${s.startTime.month}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${s.elapsed.inHours}h ${s.elapsed.inMinutes % 60}m',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (!state.isPremium) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderTertiary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Análises avançadas',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Tendências e correlações',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  if (!state.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('premium',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.warning)),
                    )
                  else
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Conta dias consecutivos com jejum terminado, terminando na sequência
  /// mais recente. Se o último jejum registado não foi hoje nem ontem, a
  /// sequência já foi quebrada e o resultado correto é 0 — mostrar um
  /// número antigo aqui seria um dado enganador para o utilizador.
  int _currentStreak(List<FastingSession> history) {
    if (history.isEmpty) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final sorted = [...history]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final mostRecentDay = DateTime(sorted.first.startTime.year,
        sorted.first.startTime.month, sorted.first.startTime.day);
    final daysSinceLast = todayOnly.difference(mostRecentDay).inDays;
    if (daysSinceLast > 1) return 0;

    var streak = 1;
    DateTime lastDay = mostRecentDay;
    for (final session in sorted.skip(1)) {
      final day = DateTime(session.startTime.year, session.startTime.month,
          session.startTime.day);
      final diff = lastDay.difference(day).inDays;
      if (diff == 1) {
        streak++;
        lastDay = day;
      } else if (diff == 0) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  int? _averageFastMinutes(List<FastingSession> history) {
    if (history.isEmpty) return null;
    final totalMinutes =
        history.fold<int>(0, (sum, s) => sum + s.elapsed.inMinutes);
    return totalMinutes ~/ history.length;
  }
}
