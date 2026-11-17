import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'plan_screen.dart';
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
  int _tab = 0; // 0 = Today, 1 = Plan

  static const wideBreakpoint = 900.0;

  Future<void> _scan([Meal? meal]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanScreen(meal: meal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = _tab == 0
        ? TodayScreen(onAddFood: _scan, wide: wide)
        : PlanScreen(wide: wide);

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
                NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Meal plan')),
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
            const SizedBox(width: 90),
            _NavItem(icon: Icons.calendar_month_outlined, label: 'Plan', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
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
              Text(label, style: TextStyle(color: color, fontWeight: selected ? w800 : w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
