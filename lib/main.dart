import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'services/auth_service.dart';
import 'services/coach_client.dart';
import 'services/food_lookup.dart';
import 'services/health/health_service.dart';
import 'services/scale/scale_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasAccounts) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  }
  final state = AppState();
  await state.load();
  final auth = AuthService(state)..start();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: auth),
        Provider<ScaleService>(
          create: (_) => createScaleService(),
          dispose: (_, s) => s.dispose(),
        ),
        Provider(create: (_) => OpenFoodFacts()),
        Provider(create: (_) => PhotoRecognizer()),
        Provider<HealthService>(create: (_) => createHealthService()),
        Provider(create: (_) => CoachClient()),
      ],
      child: const WeighWellApp(),
    ),
  );
}

class WeighWellApp extends StatelessWidget {
  const WeighWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();

    final Widget home;
    if (auth.restoring) {
      home = const _Loading();
    } else if (!auth.signedIn) {
      home = const LoginScreen();
    } else if (!state.setupDone) {
      home = const SetupScreen(firstRun: true);
    } else {
      home = const HomeShell();
    }

    return MaterialApp(
      title: 'WeighWell',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Text size setting (Normal / Large / Extra large) for easy reading.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(state.profile.textScale)),
          child: child!,
        );
      },
      home: home,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your data…', style: TextStyle(fontSize: 17, fontWeight: w700)),
            ],
          ),
        ),
      );
}
