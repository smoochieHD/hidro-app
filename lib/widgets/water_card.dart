import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// Cartão de água: barra de copos preenchidos + botões rápidos.
/// Usado igualmente nos três temas do ecrã principal.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key});

  static const int _segments = 8;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final amountMl = state.currentWaterMl;
    final goalMl = state.waterGoalMl;
    final filledSegments =
        (state.currentWaterProgress * _segments).round().clamp(0, _segments);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Água',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(amountMl / 1000).toStringAsFixed(2)} / ${(goalMl / 1000).toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_segments, (i) {
              final filled = i < filledSegments;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == _segments - 1 ? 0 : 5),
                  height: 6,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.info : AppColors.borderTertiary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => state.addWater(250),
                  child: const Text('+250ml', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => state.addWater(500),
                  child: const Text('+500ml', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCustomAmountSheet(context, state),
                  child: const Text('+ outro', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomAmountSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [100, 150, 200, 300, 350, 750];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adicionar quantidade',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((ml) {
                    return OutlinedButton(
                      onPressed: () {
                        state.addWater(ml);
                        Navigator.of(ctx).pop();
                      },
                      child: Text('${ml}ml'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
