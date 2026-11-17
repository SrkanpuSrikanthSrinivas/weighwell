import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _dayOffset = 0; // 0 = today, 1 = tomorrow

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final t = state.targets;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
    final plan = dailyPlan(t, dayIndex: day.difference(DateTime(2026)).inDays);
    final eaten = _dayOffset == 0 ? state : null;

    final goalCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What is your goal?', style: TextStyle(fontSize: 18, fontWeight: w800)),
          const SizedBox(height: 12),
          ChoicePills<Goal>(
            options: {for (final g in Goal.values) g: g.label},
            value: p.goal,
            height: 54,
            onChanged: (g) => state.updateProfile(p.copyWith(goal: g)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Eat each day', value: '${fmtInt(t.kcal)} kcal', protein: false)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(label: 'Protein', value: '${t.protein} g', protein: true)),
            ],
          ),
        ],
      ),
    );

    final mealCards = Column(
      children: [
        for (final m in plan) ...[
          _PlannedMealCard(
            planned: m,
            eatenKcal: eaten?.totalFor(day, m.meal).kcal,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Simple and easy', style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: w700)),
        const Text('My daily plan', style: TextStyle(fontSize: 32, fontWeight: w800)),
        const SizedBox(height: 14),
        goalCard,
        const SizedBox(height: 18),
        PillToggle<int>(
          options: const {0: 'Today', 1: 'Tomorrow'},
          value: _dayOffset,
          onChanged: (v) => setState(() => _dayOffset = v),
        ),
        const SizedBox(height: 12),
        mealCards,
        const SizedBox(height: 6),
        const Text(
          'These are general targets for healthy adults. Children, pregnant women and anyone with a health condition should check with a doctor before changing their diet.',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: widget.wide ? const EdgeInsets.fromLTRB(32, 28, 32, 40) : const EdgeInsets.fromLTRB(18, 20, 18, 30),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content),
        ),
      ),
    );
  }
}

class _PlannedMealCard extends StatelessWidget {
  const _PlannedMealCard({required this.planned, this.eatenKcal});
  final PlannedMeal planned;
  final double? eatenKcal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MealIcon(planned.meal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planned.meal.label, style: const TextStyle(fontSize: 18, fontWeight: w800)),
                    Text(planned.time, style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmtInt(planned.kcal)} kcal', style: const TextStyle(fontSize: 17, fontWeight: w800)),
                  Text('${planned.protein} g protein',
                      style: const TextStyle(fontSize: 14, color: AppColors.blue, fontWeight: w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Ideas: ${planned.ideas.join('  ·  ')}', style: const TextStyle(fontSize: 16)),
          if (eatenKcal != null && eatenKcal! > 0) ...[
            const SizedBox(height: 10),
            ProgressBar(
              value: eatenKcal! / planned.kcal,
              color: AppColors.green,
              background: AppColors.greenSoft,
              height: 10,
            ),
            const SizedBox(height: 4),
            Text('Eaten so far: ${fmtInt(eatenKcal!)} kcal',
                style: const TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700)),
          ],
        ],
      ),
    );
  }
}
