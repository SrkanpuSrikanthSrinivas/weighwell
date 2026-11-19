import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'services/coach_client.dart';
import 'services/food_lookup.dart';
import 'services/health/health_service.dart';
import 'services/scale/scale_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
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
      home: state.setupDone ? const HomeShell() : const SetupScreen(firstRun: true),
    );
  }
}
