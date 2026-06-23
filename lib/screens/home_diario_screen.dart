import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/water_card.dart';

/// Tema "Diário": feed cronológico do dia, em vez de um cronómetro.
/// Tema gratuito por defeito da v1.
class HomeDiarioScreen extends StatefulWidget {
  const HomeDiarioScreen({super.key});

  @override
  State<HomeDiarioScreen> createState() => _HomeDiarioScreenState();
}

class _HomeDiarioScreenState extends State<HomeDiarioScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Atualiza o ecrã a cada minuto para que o tempo decorrido/restante
    // do jejum se mantenha correto sem precisar de reiniciar a app.
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
    final lastSession = session ?? _lastFromHistory(state);

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
          if (session != null)
            _activeFastingCard(context, session)
          else
            _startFastingCard(state),
          const SizedBox(height: 20),
          const Text(
            'Hoje',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (lastSession != null)
            _timelineItem(
              icon: Icons.check_circle,
              title: 'Jejum iniciado',
              subtitle: DateFormat("HH:mm 'de' dd/MM")
                  .format(lastSession.startTime),
            ),
          if (lastSession != null && lastSession.endTime != null) ...[
            const SizedBox(height: 8),
            _timelineItem(
              icon: Icons.flag_outlined,
              title: 'Fim de jejum',
              subtitle: DateFormat("HH:mm 'de' dd/MM")
                  .format(lastSession.endTime!),
            ),
          ],
          const SizedBox(height: 8),
          _timelineItem(
            icon: Icons.water_drop_outlined,
            title: '${(state.currentWaterMl / 250).round()} copos de água',
            subtitle:
                '${state.currentWaterMl}ml de ${state.waterGoalMl}ml',
            trailing: TextButton(
              onPressed: () => state.addWater(250),
              child: const Text('+ copo'),
            ),
          ),
          const SizedBox(height: 8),
          if (session != null)
            _timelineItem(
              icon: Icons.schedule,
              title: 'Janela de alimentação',
              subtitle:
                  'Começa às ${DateFormat.Hm().format(session.plannedEndTime)}',
              dashed: true,
              muted: true,
            ),
          const SizedBox(height: 20),
          const WaterCard(),
          const SizedBox(height: 12),
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

  /// Última sessão de jejum conhecida: a ativa, se houver, ou a mais
  /// recente do histórico — para "Jejum iniciado"/"Fim de jejum"
  /// continuarem visíveis mesmo depois do jejum terminar.
  FastingSession? _lastFromHistory(AppState state) {
    final history = state.history;
    if (history.isEmpty) return null;
    return history.reduce(
      (a, b) => a.startTime.isAfter(b.startTime) ? a : b,
    );
  }

  Widget _activeFastingCard(BuildContext context, FastingSession session) {
    final isOver = session.goalReached;
    final rounded = session.remainingRounded;
    final hours = rounded.inHours;
    final minutes = rounded.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tealBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOver ? 'Meta atingida' : 'A meio do jejum',
            style: const TextStyle(fontSize: 12, color: AppColors.teal),
          ),
          const SizedBox(height: 4),
          Text(
            isOver
                ? 'Há mais $hours h $minutes min'
                : 'Faltam $hours h $minutes min',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Janela termina às ${DateFormat.Hm().format(session.plannedEndTime)}',
            style: const TextStyle(fontSize: 12, color: AppColors.teal),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmEndFasting(context),
              child: const Text('Terminar jejum agora'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startFastingCard(AppState state) {
    final scheduled = state.scheduledNextFastTime;

    if (scheduled != null) {
      final remaining = scheduled.difference(DateTime.now());
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Próximo jejum agendado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              remaining.isNegative
                  ? 'A começar...'
                  : 'Daqui a ${h}h ${m}min',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => state.startFasting(),
                child: const Text('Iniciar agora'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sem jejum ativo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Protocolo definido: ${formatDurationMinutes(state.defaultProtocolMinutes)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => state.startFasting(),
              child: const Text('Iniciar jejum'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEndFasting(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar jejum?'),
        content: const Text('Isto regista o fim da sessão atual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              state.endFasting();
              Navigator.of(ctx).pop();
            },
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool dashed = false,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: muted ? Colors.transparent : AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: dashed ? Border.all(color: AppColors.borderTertiary) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: muted
                  ? AppColors.backgroundSecondary
                  : AppColors.infoBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: muted ? AppColors.textSecondary : AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
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
