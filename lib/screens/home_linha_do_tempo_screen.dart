import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/water_card.dart';
import '../widgets/today_water_row.dart';

/// Tema "Linha do tempo": barra de progresso horizontal. Tema premium.
class HomeLinhaDoTempoScreen extends StatefulWidget {
  const HomeLinhaDoTempoScreen({super.key});

  @override
  State<HomeLinhaDoTempoScreen> createState() =>
      _HomeLinhaDoTempoScreenState();
}

class _HomeLinhaDoTempoScreenState extends State<HomeLinhaDoTempoScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      context.read<AppState>().checkFastCompletion();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.activeSession;
    final progress = session?.progress ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
              IconButton(
                onPressed: () => context.read<AppState>().goToSettings(),
                icon: const Icon(Icons.settings_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('A jejuar há',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            session != null ? _formatElapsed(session.elapsed) : '--h --m',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.borderTertiary,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                session != null
                    ? 'Início · ${DateFormat.Hm().format(session.startTime)}'
                    : 'Sem jejum ativo',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              if (session != null)
                Text(
                  'Meta · ${formatDurationMinutes(session.goalDuration.inMinutes)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: session != null
                ? ElevatedButton(
                    onPressed: () => state.endFasting(),
                    child: const Text('Terminar jejum'),
                  )
                : ElevatedButton(
                    onPressed: () => state.startFasting(),
                    child: const Text('Iniciar jejum'),
                  ),
          ),
          const SizedBox(height: 20),
          const Text('Hoje',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const TodayWaterRow(),
          const SizedBox(height: 8),
          const WaterCard(),
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }
}
