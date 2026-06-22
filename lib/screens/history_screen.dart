import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _today;
  late DateTime _visibleMonth;
  DateTime? _selectedDay;
  Timer? _midnightTicker;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _visibleMonth = DateTime(_today.year, _today.month);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTicker?.cancel();
    super.dispose();
  }

  /// Normaliza um DateTime para meia-noite local, removendo a componente
  /// de hora. Importante para comparar dias de forma fiável independente
  /// da hora do dia ou do fuso horário do dispositivo (DateTime.now() já
  /// devolve a hora local do telemóvel, por isso isto segue o fuso do
  /// utilizador automaticamente).
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Agenda uma atualização automática à próxima meia-noite, para que o
  /// destaque do "dia de hoje" avance sozinho sem precisar de reiniciar
  /// a app, mesmo que o ecrã fique aberto a passar a data.
  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTicker = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _today = _dateOnly(DateTime.now());
        // Se o mês visível era o mês "atual" antes da troca de dia,
        // acompanha automaticamente o novo mês/ano (ex: 31 Dez -> 1 Jan).
        _visibleMonth = DateTime(_today.year, _today.month);
      });
      _scheduleMidnightRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;

    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // weekday: 1 = Segunda ... 7 = Domingo.
    final leadingEmpty = firstDayOfMonth.weekday - 1;

    final completedDays = <DateTime>{};
    final partialDays = <DateTime>{};
    for (final s in history) {
      final day = _dateOnly(s.startTime);
      if (s.goalReached) {
        completedDays.add(day);
      } else {
        partialDays.add(day);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textSecondary),
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  });
                },
              ),
              Row(
                children: [
                  Text(
                    DateFormat.yMMMM('pt_PT').format(_visibleMonth),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (!_isSameDay(
                      DateTime(_visibleMonth.year, _visibleMonth.month, 1),
                      DateTime(_today.year, _today.month, 1)))
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _visibleMonth = DateTime(_today.year, _today.month);
                        }),
                        child: const Text('Hoje',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: leadingEmpty + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingEmpty) return const SizedBox.shrink();
              final day = index - leadingEmpty + 1;
              final date =
                  DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final isToday = _isSameDay(date, _today);
              final completed = completedDays.contains(date);
              final partial = partialDays.contains(date);
              final selected =
                  _selectedDay != null && _isSameDay(_selectedDay!, date);

              Color? bg;
              Color textColor = AppColors.textSecondary;
              if (completed) {
                bg = AppColors.infoBackground;
                textColor = AppColors.info;
              } else if (partial) {
                bg = AppColors.warningBackground;
                textColor = AppColors.warning;
              }
              if (isToday) {
                textColor = AppColors.info;
              }

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.infoBackground : bg,
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(color: AppColors.info, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor,
                      fontWeight: completed || partial || isToday
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(AppColors.info, 'Meta cumprida'),
              const SizedBox(width: 14),
              _legendDot(AppColors.warning, 'Abaixo da meta'),
            ],
          ),
          const SizedBox(height: 16),
          _selectedDayDetails(context, history),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  /// Mostra os detalhes do dia selecionado, ou do dia de hoje por defeito
  /// quando ainda não houve nenhuma seleção manual.
  Widget _selectedDayDetails(
      BuildContext context, List<FastingSession> history) {
    final day = _selectedDay ?? _today;
    final sessionsOfDay =
        history.where((s) => _isSameDay(s.startTime, day)).toList();

    final state = context.read<AppState>();
    final isToday = _isSameDay(day, _today);
    final goalMl = state.waterGoalMl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderTertiary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday ? 'Hoje' : DateFormat("d 'de' MMMM", 'pt_PT').format(day),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (sessionsOfDay.isEmpty)
            Text(
              isToday
                  ? 'Ainda sem jejum registado hoje.'
                  : 'Sem jejum registado neste dia.',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            ...sessionsOfDay.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(
                        Icons.schedule,
                        'Jejum: ${s.elapsed.inHours}h ${s.elapsed.inMinutes % 60}m',
                      ),
                      _detailRow(
                        Icons.water_drop_outlined,
                        'Água nesse ciclo: ${(s.waterMl / 1000).toStringAsFixed(1)}L de ${(goalMl / 1000).toStringAsFixed(1)}L',
                      ),
                    ],
                  ),
                )),
          if (isToday && sessionsOfDay.isEmpty)
            _detailRow(
              Icons.water_drop_outlined,
              'Água: ${(state.currentWaterMl / 1000).toStringAsFixed(1)}L de ${(goalMl / 1000).toStringAsFixed(1)}L',
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
