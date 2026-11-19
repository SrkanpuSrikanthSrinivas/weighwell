import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_catalog.dart';
import '../models/fitness.dart';
import '../models/models.dart';
import '../services/coach_client.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/units.dart';
import 'workout_screens.dart';

/// Weekly exercise schedule + what was actually done.
class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  late DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _monday => _today().subtract(Duration(days: _today().weekday - 1));

  bool get _isFuture => _day.isAfter(_today());

  Future<void> _log(ExerciseType type, [PlannedExercise? planned]) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogWorkoutScreen(type: type, day: _day, planned: planned),
    ));
  }

  Future<void> _logOther() async {
    final type = await pickExercise(context);
    if (type != null && mounted) await _log(type);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final useKg = state.profile.useKg;
    final planned = state.plan.days[_day.weekday]!;
    final done = state.workoutsOn(_day);
    final doneNames = done.map((w) => w.name).toSet();

    // Week totals (Monday to Sunday).
    var weekCount = 0;
    var weekMinutes = 0.0;
    var weekKcal = 0.0;
    for (var i = 0; i < 7; i++) {
      final ws = state.workoutsOn(_monday.add(Duration(days: i)));
      weekCount += ws.length;
      weekMinutes += ws.fold<double>(0, (s, w) => s + w.minutes);
      weekKcal += ws.fold<double>(0, (s, w) => s + w.kcal);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: widget.wide ? const EdgeInsets.fromLTRB(32, 28, 32, 40) : const EdgeInsets.fromLTRB(18, 20, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Exercise', style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: w700)),
                const Text('My week', style: TextStyle(fontSize: 32, fontWeight: w800)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: _dayChip(state, _monday.add(Duration(days: i)))),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _day == _today() ? 'Planned for today' : 'Planned for ${weekdayLong[_day.weekday - 1]}',
                        style: const TextStyle(fontSize: 19, fontWeight: w800),
                      ),
                      const SizedBox(height: 6),
                      if (planned.isEmpty)
                        const Text('Rest day. Gentle walking or stretching is always welcome.',
                            style: TextStyle(fontSize: 16, color: AppColors.muted)),
                      for (final p in planned)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              kindIcon(findExercise(p.name)?.kind ?? ExerciseKind.cardio),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: w800)),
                                    Text(plannedText(p, useKg), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              if (doneNames.contains(p.name))
                                const Icon(Icons.check_circle, color: AppColors.green, size: 30)
                              else
                                FilledButton(
                                  style: FilledButton.styleFrom(minimumSize: const Size(84, 46)),
                                  onPressed: _isFuture
                                      ? null
                                      : () => _log(
                                            findExercise(p.name) ?? ExerciseType(p.name, ExerciseKind.cardio, 4),
                                            p,
                                          ),
                                  child: const Text('Log'),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PlanEditorScreen(initialDay: _day.weekday)),
                            ),
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Edit my week'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showSuggestPlan(context),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Suggest a plan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Done', style: TextStyle(fontSize: 19, fontWeight: w800)),
                      if (done.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Nothing logged yet.', style: TextStyle(fontSize: 16, color: AppColors.muted)),
                        ),
                      for (final w in done)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              kindIcon(w.kind),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w.name, style: const TextStyle(fontSize: 17, fontWeight: w800)),
                                    Text(_doneText(w, useKg), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Text('${fmtInt(w.kcal)} kcal', style: const TextStyle(fontSize: 16, fontWeight: w800)),
                              IconButton(
                                tooltip: 'Remove ${w.name}',
                                onPressed: () => state.removeWorkout(w.id),
                                icon: const Icon(Icons.close, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isFuture ? null : _logOther,
                        icon: const Icon(Icons.add),
                        label: const Text('Log an exercise'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(child: _weekStat('Workouts', '$weekCount')),
                      Expanded(child: _weekStat('Minutes', fmtInt(weekMinutes))),
                      Expanded(child: _weekStat('Burned', '${fmtInt(weekKcal)} kcal')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Calories burned are estimates from standard exercise tables.',
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayChip(AppState state, DateTime d) {
    final selected = d == _day;
    final hasPlan = state.plan.days[d.weekday]!.isNotEmpty;
    final hasDone = state.workoutsOn(d).isNotEmpty;
    return Semantics(
      selected: selected,
      button: true,
      label: weekdayLong[d.weekday - 1],
      child: Material(
        color: selected ? AppColors.green : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _day = d),
          child: Container(
            height: 66,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(weekdayShort[d.weekday - 1].substring(0, 1),
                    style: TextStyle(fontSize: 17, fontWeight: w800, color: selected ? Colors.white : AppColors.ink)),
                Text('${d.day}', style: TextStyle(fontSize: 13, color: selected ? Colors.white : AppColors.muted)),
                const SizedBox(height: 2),
                Icon(
                  hasDone ? Icons.check_circle : Icons.circle,
                  size: hasDone ? 12 : 6,
                  color: hasDone
                      ? (selected ? Colors.white : AppColors.green)
                      : (hasPlan ? (selected ? Colors.white70 : AppColors.muted) : Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _weekStat(String label, String value) => Column(
        children: [
          FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: w800))),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700)),
        ],
      );

  static String _doneText(WorkoutEntry w, bool useKg) {
    if (w.sets.isNotEmpty) {
      final top = w.sets.map((s) => s.weightKg ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
      final weight = top > 0 ? ' · up to ${weightText(top, useKg)}' : '';
      return '${w.sets.length} sets · ${w.sets.map((s) => s.reps).join('/')} reps$weight';
    }
    final dist = w.distanceKm == null ? '' : ' · ${w.distanceKm!.toStringAsFixed(1)} km';
    return '${w.minutes.round()} min$dist';
  }
}

// ------------------------------------------------------------ AI plan

Future<void> showSuggestPlan(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SuggestPlanSheet(),
  );
}

class _SuggestPlanSheet extends StatefulWidget {
  const _SuggestPlanSheet();

  @override
  State<_SuggestPlanSheet> createState() => _SuggestPlanSheetState();
}

class _SuggestPlanSheetState extends State<_SuggestPlanSheet> {
  int _days = 3;
  bool _gym = false;
  String _level = 'beginner';
  int _minutes = 30;
  bool _busy = false;
  String? _error;
  CoachPlan? _result;

  Future<void> _ask() async {
    final coach = context.read<CoachClient>();
    final p = context.read<AppState>().profile;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await coach.suggestPlan(
        goal: p.goal,
        daysPerWeek: _days,
        gym: _gym,
        level: _level,
        minutes: _minutes,
        age: p.age,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = r;
        if (r.plan.isEmpty) _error = 'The coach did not return a plan. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coach.isConfigured
            ? 'Could not reach the coach. Check your internet and try again.'
            : 'The AI coach is not switched on in this build yet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useKg = context.watch<AppState>().profile.useKg;
    final goal = context.watch<AppState>().profile.goal;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Suggest a weekly plan', style: TextStyle(fontSize: 24, fontWeight: w800)),
              Text('For your goal: ${goal.label}', style: const TextStyle(fontSize: 16, color: AppColors.muted)),
              const SizedBox(height: 14),
              if (_result == null) ...[
                const Text('Days per week', style: TextStyle(fontSize: 17, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<int>(
                  options: const {2: '2', 3: '3', 4: '4', 5: '5', 6: '6'},
                  value: _days,
                  onChanged: (v) => setState(() => _days = v),
                ),
                const SizedBox(height: 14),
                const Text('Where?', style: TextStyle(fontSize: 17, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<bool>(
                  options: const {false: 'At home', true: 'At the gym'},
                  value: _gym,
                  onChanged: (v) => setState(() => _gym = v),
                ),
                const SizedBox(height: 14),
                const Text('Experience', style: TextStyle(fontSize: 17, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<String>(
                  options: const {'beginner': 'New', 'intermediate': 'Some', 'advanced': 'Lots'},
                  value: _level,
                  onChanged: (v) => setState(() => _level = v),
                ),
                const SizedBox(height: 14),
                const Text('Minutes per session', style: TextStyle(fontSize: 17, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<int>(
                  options: const {20: '20', 30: '30', 45: '45', 60: '60'},
                  value: _minutes,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _ask,
                  icon: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_busy ? 'Making your plan…' : 'Make my plan'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 16, color: Color(0xFF8A3A0B), fontWeight: w700)),
              ],
              if (_result != null && !_result!.plan.isEmpty) ...[
                if (_result!.notes.isNotEmpty)
                  Text(_result!.notes, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                for (var d = 1; d <= 7; d++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(weekdayLong[d - 1], style: const TextStyle(fontSize: 17, fontWeight: w800)),
                          if (_result!.plan.days[d]!.isEmpty)
                            const Text('Rest', style: TextStyle(fontSize: 15, color: AppColors.muted)),
                          for (final p in _result!.plan.days[d]!)
                            Text('• ${p.name} — ${plannedText(p, useKg)}', style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    context.read<AppState>().savePlan(_result!.plan);
                    Navigator.of(context).pop();
                    showMessage(context, 'New weekly plan saved');
                  },
                  child: const Text('Use this plan'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    final draft = _result!.plan;
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(MaterialPageRoute(builder: (_) => PlanEditorScreen(draft: draft)));
                  },
                  child: const Text('Change it first'),
                ),
                TextButton(
                  onPressed: () => setState(() => _result = null),
                  child: const Text('Start over', style: TextStyle(fontSize: 16, fontWeight: w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
