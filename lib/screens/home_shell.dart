import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/health/health_service.dart';
import '../services/health_sync.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'move_screen.dart';
import 'plan_screen.dart';
import 'progress_screen.dart';
import 'scan_screen.dart';
import 'today_screen.dart';

/// Phone: a standard bottom navigation bar and an "Add food" button.
/// Wide screens (web, tablets): a side menu.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0; // 0 Today, 1 Exercise, 2 Meals, 3 Progress

  static const wideBreakpoint = 900.0;

  static const _destinations = [
    (Icons.today_outlined, Icons.today, 'Today'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Exercise'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Meals'),
    (Icons.insights_outlined, Icons.insights, 'Progress'),
  ];

  @override
  void initState() {
    super.initState();
    // Quietly pull today's steps etc. if the phone is already connected.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      syncHealth(context.read<AppState>(), context.read<HealthService>());
    });
  }

  Future<void> _scan([Meal? meal]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanScreen(meal: meal)),
    );
  }

  void _openTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = switch (_tab) {
      1 => MoveScreen(wide: wide),
      2 => PlanScreen(wide: wide),
      3 => ProgressScreen(wide: wide),
      _ => TodayScreen(onAddFood: _scan, onOpenTab: _openTab, wide: wide),
    };

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _tab,
              onDestinationSelected: _openTab,
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.greenSoft,
              minWidth: 100,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.monitor_weight_outlined, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text('WeighWell', style: TextStyle(fontWeight: w800, fontSize: 14)),
                    const SizedBox(height: 22),
                    FloatingActionButton.extended(
                      heroTag: 'add',
                      elevation: 0,
                      onPressed: _scan,
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text('Add food', style: TextStyle(fontWeight: w800, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.line),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: _tab == 0 || _tab == 2
          ? FloatingActionButton.extended(
              heroTag: 'scan',
              onPressed: _scan,
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add food', style: TextStyle(fontWeight: w800, fontSize: 16)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _openTab,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
