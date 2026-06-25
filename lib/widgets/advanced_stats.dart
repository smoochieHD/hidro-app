import 'package:fl_chart/fl_chart.dart';
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

/// Gráfico de tendência da duração real do jejum, com toggle entre vista
/// semanal (média de cada semana) e diária (cada jejum individualmente).
class DurationTrendChart extends StatefulWidget {
  final List<FastingSession> history;

  const DurationTrendChart({super.key, required this.history});

  @override
  State<DurationTrendChart> createState() => _DurationTrendChartState();
}

class _DurationTrendChartState extends State<DurationTrendChart> {
  bool _weekly = true;

  @override
  Widget build(BuildContext context) {
    final points = _weekly ? _weeklyAverages() : _dailyValues();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tendência da duração',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _modeButton('Semanal', true),
                  _modeButton('Diário', false),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (points.length < 2)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Termina mais alguns jejuns para veres a tendência.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i]),
                    ],
                    isCurved: true,
                    color: AppColors.info,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.info.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _modeButton(String label, bool weeklyValue) {
    final selected = _weekly == weeklyValue;
    return GestureDetector(
      onTap: () => setState(() => _weekly = weeklyValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Duração real (elapsed) de cada jejum terminado, em horas, na ordem
  /// cronológica, limitado aos últimos 30 para não sobrecarregar o gráfico.
  List<double> _dailyValues() {
    final sorted = [...widget.history]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final recent = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;
    return recent.map((s) => s.elapsed.inMinutes / 60.0).toList();
  }

  /// Média da duração real por semana civil (Segunda a Domingo), nas
  /// últimas 8 semanas com dados.
  List<double> _weeklyAverages() {
    final sorted = [...widget.history]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sorted.isEmpty) return [];

    final byWeek = <DateTime, List<double>>{};
    for (final s in sorted) {
      final weekStart = _mondayOf(s.startTime);
      byWeek.putIfAbsent(weekStart, () => []).add(s.elapsed.inMinutes / 60.0);
    }

    final weeks = byWeek.keys.toList()..sort();
    final recentWeeks = weeks.length > 8 ? weeks.sublist(weeks.length - 8) : weeks;
    return recentWeeks.map((w) {
      final values = byWeek[w]!;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList();
  }

  DateTime _mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }
}

/// Insights automáticos calculados a partir do histórico: relação entre a
/// hora de início e a probabilidade de completar a meta, e relação entre
/// água bebida e taxa de sucesso. Exige um mínimo de sessões terminadas
/// para evitar conclusões precipitadas com poucos dados.
class SmartInsights extends StatelessWidget {
  final List<FastingSession> history;
  static const _minSessions = 5;

  const SmartInsights({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < _minSessions) {
      return Text(
        'Continua a registar jejuns para veres os teus padrões '
        '(faltam ${_minSessions - history.length}).',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    final startTimeInsight = _startTimeInsight();
    final waterInsight = _waterInsight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startTimeInsight != null) ...[
          _insightRow(Icons.schedule, startTimeInsight),
          const SizedBox(height: 10),
        ],
        if (waterInsight != null) _insightRow(Icons.water_drop_outlined, waterInsight),
        if (startTimeInsight == null && waterInsight == null)
          const Text(
            'Ainda não encontrámos um padrão claro nos teus dados.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  Widget _insightRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: AppColors.tealBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.3)),
        ),
      ],
    );
  }

  /// Divide os jejuns em "começados antes" vs "começados depois" da
  /// mediana das horas de início (em minutos desde a meia-noite), e
  /// compara a taxa de sucesso (meta atingida) entre os dois grupos.
  /// Usar a mediana dos próprios dados, em vez de um corte fixo (ex:
  /// 20h), torna o insight relevante mesmo que todos os jejuns comecem
  /// tipicamente à noite.
  String? _startTimeInsight() {
    final minutesOfDay = history
        .map((s) => s.startTime.hour * 60 + s.startTime.minute)
        .toList()
      ..sort();
    if (minutesOfDay.length < _minSessions) return null;

    final medianMinute = minutesOfDay[minutesOfDay.length ~/ 2];

    final earlier = history.where(
        (s) => (s.startTime.hour * 60 + s.startTime.minute) < medianMinute);
    final later = history.where(
        (s) => (s.startTime.hour * 60 + s.startTime.minute) >= medianMinute);

    if (earlier.isEmpty || later.isEmpty) return null;

    final earlierRate =
        earlier.where((s) => s.goalReached).length / earlier.length;
    final laterRate = later.where((s) => s.goalReached).length / later.length;

    final diff = (earlierRate - laterRate) * 100;
    if (diff.abs() < 5) return null; // diferença pequena, não vale destacar

    final hour = medianMinute ~/ 60;
    final minute = medianMinute % 60;
    final cutoff =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    if (diff > 0) {
      return 'Jejuns iniciados antes das $cutoff têm ${diff.round()}% mais '
          'probabilidade de completar a meta.';
    } else {
      return 'Jejuns iniciados depois das $cutoff têm ${(-diff).round()}% '
          'mais probabilidade de completar a meta.';
    }
  }

  /// Compara a taxa de sucesso entre sessões com água acima da mediana de
  /// água bebida e sessões com água abaixo dela.
  String? _waterInsight() {
    final waterAmounts = history.map((s) => s.waterMl).toList()..sort();
    if (waterAmounts.length < _minSessions) return null;

    final medianWater = waterAmounts[waterAmounts.length ~/ 2];
    if (medianWater == 0) return null; // sem variação suficiente nos dados

    final moreWater = history.where((s) => s.waterMl >= medianWater);
    final lessWater = history.where((s) => s.waterMl < medianWater);

    if (moreWater.isEmpty || lessWater.isEmpty) return null;

    final moreRate =
        moreWater.where((s) => s.goalReached).length / moreWater.length;
    final lessRate =
        lessWater.where((s) => s.goalReached).length / lessWater.length;

    final diff = (moreRate - lessRate) * 100;
    if (diff.abs() < 5) return null;

    final liters = (medianWater / 1000).toStringAsFixed(1);
    if (diff > 0) {
      return 'Dias com mais de ${liters}L de água têm ${diff.round()}% mais '
          'taxa de sucesso.';
    } else {
      return 'Dias com menos de ${liters}L de água têm ${(-diff).round()}% '
          'mais taxa de sucesso.';
    }
  }
}
