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
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      final appState = context.read<AppState>();
      appState.checkFastCompletion();
      appState.refreshFromStorage();
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
              Text(
                _greeting(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                onPressed: () => context.read<AppState>().goToSettings(),
                icon: const Icon(Icons.settings_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            session != null
                ? (session.goalReached ? 'Meta atingida' : 'A meio do jejum')
                : 'Sem jejum ativo',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            session != null ? _formatRemaining(session) : '--h --m',
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
          _autoScheduleToggle(state),
          const SizedBox(height: 12),
          const Text('Hoje',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_lastSession(state) != null) ...[
            ..._lastSessionRows(_lastSession(state)!),
            const SizedBox(height: 8),
          ],
          if (session != null)
            const TodayWaterRow()
          else if (_lastSession(state) != null)
            _waterSummaryRow(state, _lastSession(state)!),
          const SizedBox(height: 8),
          const WaterCard(),
        ],
      ),
    );
  }

  Widget _autoScheduleToggle(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Agendar ciclo automaticamente',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: state.autoScheduleNextCycle,
            onChanged: (v) => state.setAutoScheduleNextCycle(v),
          ),
        ],
      ),
    );
  }

  Widget _waterSummaryRow(AppState state, FastingSession session) {
    return _infoRow(
      Icons.water_drop_outlined,
      '${(session.waterMl / 250).round()} copos de água (resumo)',
      '${session.waterMl}ml de ${state.waterGoalMl}ml neste ciclo',
    );
  }

  FastingSession? _lastSession(AppState state) {
    if (state.activeSession != null) return null;
    final history = state.history;
    if (history.isEmpty) return null;
    return history.reduce(
      (a, b) => a.startTime.isAfter(b.startTime) ? a : b,
    );
  }

  List<Widget> _lastSessionRows(FastingSession session) {
    return [
      _infoRow(Icons.check_circle, 'Jejum iniciado',
          DateFormat("HH:mm 'de' dd/MM").format(session.startTime)),
      if (session.endTime != null) ...[
        const SizedBox(height: 8),
        _infoRow(Icons.flag_outlined, 'Fim de jejum',
            DateFormat("HH:mm 'de' dd/MM").format(session.endTime!)),
      ],
    ];
  }

  Widget _infoRow(IconData icon, String title, String subtitle) {
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 19) return 'Boa tarde';
    return 'Boa noite';
  }

  String _formatRemaining(FastingSession session) {
    final r = session.remainingRounded;
    return '${r.inHours}h ${r.inMinutes % 60}m';
  }
}
