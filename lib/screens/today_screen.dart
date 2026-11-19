import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/units.dart';
import 'checkin_screen.dart';
import 'settings_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onAddFood, required this.wide});

  final Future<void> Function([Meal? meal]) onAddFood;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final total = state.totalOn(today);
    final t = state.targets;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE, MMM d').format(today),
                  style: const TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: w700)),
              Text(wide ? _greeting(total.kcal, t.kcal) : 'Today',
                  style: TextStyle(fontSize: wide ? 30 : 32, fontWeight: w800)),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'My goal and settings',
          iconSize: 26,
          style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(50, 50)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.person_outline, color: AppColors.ink),
        ),
      ],
    );

    final summary = _SummaryCard(total: total, targets: t);
    const activity = _ActivityCard();
    final meals = _MealsList(onAddFood: onAddFood);

    if (wide) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      SizedBox(width: 440, child: summary),
                      const SizedBox(width: 440, child: activity),
                      const SizedBox(width: 440, child: _WeekCard()),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('My meals', style: TextStyle(fontSize: 22, fontWeight: w800)),
                  const SizedBox(height: 10),
                  meals,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
        children: [
          header,
          const SizedBox(height: 14),
          summary,
          const SizedBox(height: 14),
          activity,
          const SizedBox(height: 20),
          const Text('My meals', style: TextStyle(fontSize: 22, fontWeight: w800)),
          const SizedBox(height: 10),
          meals,
          const SizedBox(height: 18),
          const _WeekCard(),
        ],
      ),
    );
  }

  static String _greeting(double eaten, int goal) {
    final left = goal - eaten;
    if (eaten == 0) return 'Nothing logged yet today.';
    if (left >= 0) return 'You have ${fmtInt(left)} kcal left today.';
    return 'You are ${fmtInt(-left)} kcal over today.';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.targets});
  final Nutrition total;
  final DailyTargets targets;

  @override
  Widget build(BuildContext context) {
    final proteinLeft = targets.protein - total.protein;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CalorieRing(eaten: total.kcal, goal: targets.kcal),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Eaten', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                    Text('${fmtInt(total.kcal)} kcal', style: const TextStyle(fontSize: 22, fontWeight: w800)),
                    const SizedBox(height: 10),
                    const Text('Daily goal', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                    Text('${fmtInt(targets.kcal)} kcal', style: const TextStyle(fontSize: 22, fontWeight: w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Text('Protein', style: TextStyle(fontSize: 17, fontWeight: w800))),
              Text('${total.protein.round()} g of ${targets.protein} g',
                  style: const TextStyle(fontSize: 17, fontWeight: w800, color: AppColors.blue)),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(
            value: targets.protein == 0 ? 0 : total.protein / targets.protein,
            color: AppColors.blue,
            background: AppColors.blueSoft,
          ),
          const SizedBox(height: 8),
          Text(
            proteinLeft > 0
                ? '${proteinLeft.round()} g more protein to reach your goal'
                : 'Protein goal reached — well done!',
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final e = state.energyOn(today);
    final checked = state.hasCheckIn(today);
    final c = state.checkInOn(today);

    Widget stat(IconData icon, String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: w800))),
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700)),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Activity', style: TextStyle(fontSize: 19, fontWeight: w800))),
              if (c.bodyWeightKg != null)
                Text(weightText(c.bodyWeightKg!, state.profile.useKg),
                    style: const TextStyle(fontSize: 16, fontWeight: w800, color: AppColors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(Icons.directions_walk, e.steps > 0 ? fmtInt(e.steps) : '—', 'steps', AppColors.green),
              stat(Icons.place_outlined, e.distanceKm > 0 ? '${e.distanceKm.toStringAsFixed(1)} km' : '—', 'walked', AppColors.green),
              stat(Icons.local_fire_department_outlined, fmtInt(e.active), 'active kcal', const Color(0xFFB4530B)),
              stat(Icons.balance, '${e.balance >= 0 ? '+' : '−'}${fmtInt(e.balance.abs())}', 'kcal balance', AppColors.blue),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.greenSoft,
              foregroundColor: AppColors.greenDark,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(day: today))),
            icon: Icon(checked ? Icons.edit_note : Icons.add_task),
            label: Text(checked ? 'Update today\'s check-in' : 'Daily check-in: weight, water, sleep',
                style: const TextStyle(fontSize: 16, fontWeight: w800)),
          ),
        ],
      ),
    );
  }
}

class _MealsList extends StatelessWidget {
  const _MealsList({required this.onAddFood});
  final Future<void> Function([Meal? meal]) onAddFood;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    return Column(
      children: [
        for (final meal in Meal.values) ...[
          _MealCard(
            meal: meal,
            entries: state.entriesFor(today, meal),
            total: state.totalFor(today, meal),
            onAdd: () => onAddFood(meal),
            onRemove: (id) => state.removeEntry(id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.entries,
    required this.total,
    required this.onAdd,
    required this.onRemove,
  });

  final Meal meal;
  final List<LogEntry> entries;
  final Nutrition total;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final names = entries.map((e) => e.food.name).join(', ');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              MealIcon(meal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.label, style: const TextStyle(fontSize: 18, fontWeight: w800)),
                    Text(entries.isEmpty ? 'Nothing yet' : names,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmtInt(total.kcal)} kcal', style: const TextStyle(fontSize: 17, fontWeight: w800)),
                      Text('${total.protein.round()} g protein',
                          style: const TextStyle(fontSize: 14, color: AppColors.blue, fontWeight: w700)),
                    ],
                  ),
                ),
              IconButton(
                tooltip: 'Add food to ${meal.label}',
                onPressed: onAdd,
                style: IconButton.styleFrom(backgroundColor: AppColors.greenSoft, minimumSize: const Size(46, 46)),
                icon: const Icon(Icons.add, color: AppColors.green),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${e.food.name} · ${e.grams.round()} g',
                          style: const TextStyle(fontSize: 15, fontWeight: w700)),
                    ),
                    Text('${fmtInt(e.nutrition.kcal)} kcal',
                        style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                    IconButton(
                      tooltip: 'Remove ${e.food.name}',
                      onPressed: () => onRemove(e.id),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final days = state.lastSevenDays();
    final goal = state.targets.kcal.toDouble();
    final maxV = [goal * 1.25, ...days.map((d) => d.$2)].reduce((a, b) => a > b ? a : b);
    const chartH = 150.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This week', style: TextStyle(fontSize: 20, fontWeight: w800)),
          const SizedBox(height: 4),
          Text('Goal ${fmtInt(goal)} kcal a day', style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 14),
          SizedBox(
            height: chartH + 26,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26 + chartH * goal / maxV,
                  child: Container(height: 2, color: const Color(0xFF9FB3A7)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, d) in days.indexed)
                      Expanded(
                        child: Tooltip(
                          message: '${DateFormat('EEEE').format(d.$1)}: ${fmtInt(d.$2)} kcal',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: (chartH * d.$2 / maxV).clamp(3, chartH).toDouble(),
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  color: i == 6 ? AppColors.green : const Color(0xFFA8D5BA),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 20,
                                child: Text(DateFormat('E').format(d.$1),
                                    style: const TextStyle(fontSize: 14, fontWeight: w700, color: Color(0xFF3E4F46))),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
