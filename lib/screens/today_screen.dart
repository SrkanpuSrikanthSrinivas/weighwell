import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/goals.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'checkin_screen.dart';
import 'settings_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onAddFood, required this.onOpenTab, required this.wide});

  final Future<void> Function([Meal? meal]) onAddFood;
  final ValueChanged<int> onOpenTab;
  final bool wide;

  static String _hello() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final today = DateTime.now();
    final total = state.totalOn(today);
    final t = state.targets;
    final name = auth.firstName;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE, MMMM d').format(today),
                  style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
              Text(name.isEmpty ? _hello() : '${_hello()}, $name',
                  style: const TextStyle(fontSize: 26, fontWeight: w800)),
            ],
          ),
        ),
        _SyncDot(status: state.syncStatus),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Account and settings',
          iconSize: 26,
          style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.line), minimumSize: const Size(50, 50)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.person_outline, color: AppColors.ink),
        ),
      ],
    );

    final goals = _GoalsCard(onAddFood: onAddFood, onOpenTab: onOpenTab);
    final summary = _SummaryCard(total: total, targets: t);
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
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: goals),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 20),
                            const _WeekCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader('My meals'),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          header,
          const SizedBox(height: 16),
          goals,
          const SectionHeader('Calories and protein'),
          summary,
          const SectionHeader('My meals'),
          meals,
          const SectionHeader('This week'),
          const _WeekCard(),
        ],
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.off) return const SizedBox.shrink();
    final (icon, color, text) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, AppColors.green, 'Saved to your account'),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, AppColors.muted, 'Saving…'),
      _ => (Icons.cloud_off_outlined, const Color(0xFFB4530B), 'Offline — will save when back online'),
    };
    return Tooltip(message: text, child: Icon(icon, color: color, semanticLabel: text));
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.onAddFood, required this.onOpenTab});
  final Future<void> Function([Meal? meal]) onAddFood;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final goals = dailyGoals(state, today);
    final done = goals.where((g) => g.done).length;

    void openCheckIn() =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(day: today)));

    VoidCallback actionFor(GoalId id) => switch (id) {
          GoalId.calories || GoalId.protein => () => onAddFood(),
          GoalId.exercise => () => onOpenTab(1),
          GoalId.water => () => state.addWater(today, 1),
          GoalId.steps || GoalId.sleep || GoalId.weighIn => openCheckIn,
        };

    String actionLabel(GoalId id) => switch (id) {
          GoalId.calories || GoalId.protein => 'Add food',
          GoalId.exercise => 'Open',
          GoalId.water => '+1 glass',
          GoalId.steps => 'Update',
          GoalId.sleep || GoalId.weighIn => 'Log',
        };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: done / goals.length,
                        strokeWidth: 7,
                        backgroundColor: AppColors.greenSoft,
                        color: AppColors.green,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text('$done/${goals.length}', style: const TextStyle(fontSize: 18, fontWeight: w800)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's goals", style: TextStyle(fontSize: 21, fontWeight: w800)),
                    Text(
                      done == goals.length
                          ? 'Everything done. Great day!'
                          : done == 0
                              ? 'Seven simple steps to a healthy day'
                              : '${goals.length - done} left to complete today',
                      style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, g) in goals.indexed) ...[
            if (i > 0) const Divider(height: 1),
            _GoalRow(goal: g, action: actionLabel(g.id), onAction: actionFor(g.id)),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.action, required this.onAction});
  final DailyGoal goal;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final (icon, color, soft) = switch (goal.id) {
      GoalId.calories => (Icons.local_fire_department_outlined, const Color(0xFFB4530B), const Color(0xFFFFF1E0)),
      GoalId.protein => (Icons.egg_alt_outlined, AppColors.blue, AppColors.blueSoft),
      GoalId.steps => (Icons.directions_walk, AppColors.green, AppColors.greenSoft),
      GoalId.exercise => (Icons.fitness_center, const Color(0xFF6B3FA0), const Color(0xFFF0E8F8)),
      GoalId.water => (Icons.water_drop_outlined, const Color(0xFF0E7490), const Color(0xFFE0F4F8)),
      GoalId.sleep => (Icons.bedtime_outlined, const Color(0xFF3B4A8C), const Color(0xFFEEF0F7)),
      GoalId.weighIn => (Icons.monitor_weight_outlined, AppColors.ink, AppColors.chip),
    };
    return Semantics(
      label: '${goal.title}. ${goal.valueText}. ${goal.done ? 'Done' : goal.statusText}',
      child: InkWell(
        onLongPress: () => showMessage(context, goal.why),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: goal.done ? AppColors.green : soft, borderRadius: BorderRadius.circular(14)),
                child: Icon(goal.done ? Icons.check : icon, color: goal.done ? Colors.white : color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: const TextStyle(fontSize: 17, fontWeight: w800)),
                    const SizedBox(height: 2),
                    Text(
                      goal.done ? goal.valueText : '${goal.valueText} · ${goal.statusText}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: w700,
                        color: goal.done ? AppColors.greenDark : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ProgressBar(
                      value: goal.progress,
                      color: goal.done ? AppColors.green : color,
                      background: soft,
                      height: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              goal.done && goal.id != GoalId.water
                  ? const SizedBox(width: 8)
                  : TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        backgroundColor: AppColors.ground,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: onAction,
                      child: Text(action, style: const TextStyle(fontSize: 14, fontWeight: w800)),
                    ),
            ],
          ),
        ),
      ),
    );
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
