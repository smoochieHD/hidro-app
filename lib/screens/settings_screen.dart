import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';
import 'theme_picker_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    context.read<AppState>().goToTab(AppState.tabIndexHome),
                icon: const Icon(Icons.arrow_back,
                    size: 22, color: AppColors.textPrimary),
                tooltip: 'Voltar ao início',
              ),
              const SizedBox(width: 12),
              const Text('Definições',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          if (!state.isPremium)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hidro Premium',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal)),
                        SizedBox(height: 2),
                        Text('Desbloqueia todos os temas',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.teal)),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.teal),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          _sectionLabel('Aparência'),
          _settingRow(
            context,
            label: 'Tema',
            value: state.selectedTheme.label,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemePickerScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Jejum'),
          _settingRow(
            context,
            label: 'Protocolo',
            value: '${state.defaultProtocolHours}h jejum',
            onTap: () => _showProtocolPicker(context, state),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Água'),
          _settingRow(
            context,
            label: 'Meta por ciclo',
            value: '${(state.waterGoalMl / 1000).toStringAsFixed(1)} L',
            onTap: () => _showWaterGoalPicker(context, state),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _settingRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderTertiary)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProtocolPicker(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [16, 18, 20];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Protocolo de jejum',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                ...options.map((h) => ListTile(
                      title: Text('$h:${24 - h}'),
                      trailing: state.defaultProtocolHours == h
                          ? const Icon(Icons.check, color: AppColors.info)
                          : null,
                      onTap: () {
                        state.setDefaultProtocolHours(h);
                        Navigator.of(ctx).pop();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWaterGoalPicker(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [1500, 2000, 2500, 3000];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meta de água por ciclo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                ...options.map((ml) => ListTile(
                      title: Text('${(ml / 1000).toStringAsFixed(1)} L'),
                      trailing: state.waterGoalMl == ml
                          ? const Icon(Icons.check, color: AppColors.info)
                          : null,
                      onTap: () {
                        state.setWaterGoal(ml);
                        Navigator.of(ctx).pop();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
