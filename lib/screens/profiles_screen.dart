import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Perfis de jejum')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Definições atuais',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDurationMinutes(state.defaultProtocolMinutes)} jejum · '
                          '${formatDurationMinutes(state.eatingWindowMinutes)} comer · '
                          '${(state.waterGoalMl / 1000).toStringAsFixed(1)}L água',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showSaveDialog(context, state),
                    child: const Text('Guardar como perfil'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Os teus perfis',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (state.profiles.isEmpty)
              const Text(
                'Ainda não guardaste nenhum perfil. Ajusta as definições '
                'que quiseres e toca em "Guardar como perfil".',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: state.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final profile = state.profiles[index];
                    final isActive = state.activeProfileId == profile.id;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(color: AppColors.info, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatDurationMinutes(profile.protocolMinutes)} jejum · '
                                  '${formatDurationMinutes(profile.eatingWindowMinutes)} comer · '
                                  '${(profile.waterGoalMl / 1000).toStringAsFixed(1)}L',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (!isActive)
                            TextButton(
                              onPressed: () => state.applyProfile(profile.id),
                              child: const Text('Usar'),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.check_circle,
                                  color: AppColors.info, size: 20),
                            ),
                          IconButton(
                            onPressed: () =>
                                _confirmDelete(context, state, profile.id),
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(BuildContext context, AppState state) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar perfil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Dias de trabalho',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              state.saveCurrentAsProfile(name);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, String profileId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover perfil?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              state.deleteProfile(profileId);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
