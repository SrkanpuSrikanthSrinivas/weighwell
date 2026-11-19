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

/// Phone: bottom bar with a big Scan button in the middle.
/// Wide screens (web, tablets): a side menu and a dashboard layout.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0; // 0 Today, 1 Move, 2 Meal plan, 3 Progress

  static const wideBreakpoint = 900.0;

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

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = switch (_tab) {
      1 => MoveScreen(wide: wide),
      2 => PlanScreen(wide: wide),
      3 => ProgressScreen(wide: wide),
      _ => TodayScreen(onAddFood: _scan, wide: wide),
    };

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.scale_outlined, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text('WeighWell', style: TextStyle(fontWeight: w800, fontSize: 14)),
                    const SizedBox(height: 22),
                    FloatingActionButton.extended(
                      heroTag: 'add',
                      onPressed: _scan,
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text('Add', style: TextStyle(fontWeight: w800, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Today')),
                NavigationRailDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: Text('Exercise')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Meal plan')),
                NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('Progress')),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 74,
        height: 74,
        child: FloatingActionButton(
          heroTag: 'scan',
          onPressed: _scan,
          tooltip: 'Scan food',
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 5)),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          child: const Icon(Icons.center_focus_strong, size: 32),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        height: 76,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(icon: Icons.home_outlined, label: 'Today', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
            _NavItem(icon: Icons.fitness_center_outlined, label: 'Exercise', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
            const SizedBox(width: 84),
            _NavItem(icon: Icons.restaurant_menu, label: 'Meals', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
            _NavItem(icon: Icons.insights_outlined, label: 'Progress', selected: _tab == 3, onTap: () => setState(() => _tab = 3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              FittedBox(child: Text(label, style: TextStyle(color: color, fontWeight: selected ? w800 : w700, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }
}
