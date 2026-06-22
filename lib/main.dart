import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');
  final appState = await AppState.create();
  runApp(HidroApp(appState: appState));
}

class HidroApp extends StatefulWidget {
  final AppState appState;

  const HidroApp({super.key, required this.appState});

  @override
  State<HidroApp> createState() => _HidroAppState();
}

class _HidroAppState extends State<HidroApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Sempre que a app volta ao primeiro plano, verifica se um jejum
    // agendado (janela de alimentação) já devia ter começado enquanto a
    // app estava em background — cobre o caso de a notificação de início
    // ter disparado sem o utilizador ter tocado nela.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => widget.appState.checkScheduledNextFast(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.appState,
      child: MaterialApp(
        title: 'Hidro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: widget.appState.storage.isOnboardingDone()
            ? const MainShell()
            : const OnboardingScreen(),
      ),
    );
  }
}
