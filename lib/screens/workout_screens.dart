import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/exercise_catalog.dart';
import '../models/fitness.dart';
import '../services/energy.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/units.dart';

// ------------------------------------------------------------ Picker

/// Full-screen list of exercises with search. Returns the chosen one.
Future<ExerciseType?> pickExercise(BuildContext context) {
  return Navigator.of(context).push<ExerciseType>(
    MaterialPageRoute(builder: (_) => const _ExercisePicker()),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = searchExercises(_q);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose exercise', style: TextStyle(fontWeight: w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: TextField(
                    autofocus: false,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'e.g. squats, walking, yoga'),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      for (final kind in ExerciseKind.values) ...[
                        if (results.any((e) => e.kind == kind)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Text(kind.label,
                                style: const TextStyle(fontSize: 16, fontWeight: w800, color: AppColors.muted)),
                          ),
                          for (final e in results.where((e) => e.kind == kind))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: _KindIcon(e.kind),
                                  title: Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: w800)),
                                  trailing: const Icon(Icons.chevron_right, size: 28),
                                  onTap: () => Navigator.of(context).pop(e),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon(this.kind);
  final ExerciseKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = switch (kind) {
      ExerciseKind.strength => (Icons.fitness_center, AppColors.blue, AppColors.blueSoft),
      ExerciseKind.cardio => (Icons.directions_run, AppColors.green, AppColors.greenSoft),
      ExerciseKind.flexibility => (Icons.self_improvement, const Color(0xFF6B3FA0), const Color(0xFFF0E8F8)),
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: fg),
    );
  }
}

Widget kindIcon(ExerciseKind kind) => _KindIcon(kind);

// ------------------------------------------------------------ Log workout

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key, required this.type, required this.day, this.planned});
  final ExerciseType type;
  final DateTime day;
  final PlannedExercise? planned;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  late final bool _strength = widget.type.kind == ExerciseKind.strength;
  late List<WorkoutSet> _sets;
  late int _minutes;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    final p = widget.planned;
    _sets = List.generate(
      p?.sets ?? 3,
      (_) => WorkoutSet(reps: (p?.reps ?? 10) == 0 ? 10 : (p?.reps ?? 10), weightKg: p?.weightKg),
    );
    _minutes = p?.minutes ?? (_strength ? 0 : 30);
  }

  double get _bodyKg => Provider.of<AppState>(context, listen: false).weightOn(widget.day);

  double get _kcal => kcalForEntry(
        type: widget.type,
        weightKg: _bodyKg,
        minutes: _strength ? (_minutes > 0 ? _minutes.toDouble() : null) : _minutes.toDouble(),
        sets: _sets.length,
      );

  Future<void> _editWeight(int i, bool useKg) async {
    final current = _sets[i].weightKg;
    final c = TextEditingController(text: current == null ? '' : fromKg(current, useKg).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''));
    final v = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Weight for set ${i + 1}', style: const TextStyle(fontWeight: w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 26, fontWeight: w800),
          decoration: InputDecoration(suffixText: useKg ? 'kg' : 'lb', hintText: 'Leave empty for body weight'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, -1.0), child: const Text('Body weight')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text) ?? -1.0),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v == null) return;
    setState(() {
      final kg = v < 0 ? null : toKg(v, useKg);
      // Apply to this and all following sets — people usually keep the weight.
      for (var j = i; j < _sets.length; j++) {
        _sets[j] = WorkoutSet(reps: _sets[j].reps, weightKg: kg);
      }
    });
  }

  void _save() {
    final state = context.read<AppState>();
    final now = DateTime.now();
    final d = widget.day;
    final when = DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second);
    final mins = _strength ? (_minutes > 0 ? _minutes.toDouble() : strengthMinutes(_sets.length)) : _minutes.toDouble();
    state.addWorkout(WorkoutEntry(
      id: '${now.microsecondsSinceEpoch}',
      time: when,
      name: widget.type.name,
      kind: widget.type.kind,
      met: widget.type.met,
      sets: _strength ? List.of(_sets) : const [],
      minutes: mins,
      distanceKm: _distanceKm,
      kcal: _kcal,
    ));
    Navigator.of(context).pop(true);
    showMessage(context, 'Saved ${widget.type.name} · ${fmtInt(_kcal)} kcal');
  }

  @override
  Widget build(BuildContext context) {
    final useKg = context.watch<AppState>().profile.useKg;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.type.kind.label, style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
            Text(widget.type.name, style: const TextStyle(fontSize: 22, fontWeight: w800)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                if (_strength) ...[
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < _sets.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 17, fontWeight: w800)),
                                ),
                                IconButton(
                                  tooltip: 'Fewer reps',
                                  style: IconButton.styleFrom(backgroundColor: AppColors.chip),
                                  onPressed: () => setState(() => _sets[i] =
                                      WorkoutSet(reps: (_sets[i].reps - 1).clamp(1, 100).toInt(), weightKg: _sets[i].weightKg)),
                                  icon: const Icon(Icons.remove),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Column(
                                    children: [
                                      Text('${_sets[i].reps}', style: const TextStyle(fontSize: 22, fontWeight: w800)),
                                      const Text('reps', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'More reps',
                                  style: IconButton.styleFrom(backgroundColor: AppColors.chip),
                                  onPressed: () => setState(() => _sets[i] =
                                      WorkoutSet(reps: (_sets[i].reps + 1).clamp(1, 100).toInt(), weightKg: _sets[i].weightKg)),
                                  icon: const Icon(Icons.add),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    onPressed: () => _editWeight(i, useKg),
                                    child: Text(
                                      _sets[i].weightKg == null ? 'Body wt' : weightText(_sets[i].weightKg!, useKg),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _sets.add(_sets.isEmpty
                                    ? const WorkoutSet(reps: 10)
                                    : WorkoutSet(reps: _sets.last.reps, weightKg: _sets.last.weightKg))),
                                icon: const Icon(Icons.add),
                                label: const Text('Add set'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _sets.length > 1 ? () => setState(() => _sets.removeLast()) : null,
                                icon: const Icon(Icons.remove),
                                label: const Text('Remove set'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_strength ? 'Total time (optional)' : 'How long?',
                          style: const TextStyle(fontSize: 17, fontWeight: w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: '5 minutes less',
                            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(52, 52)),
                            onPressed: () => setState(() => _minutes = (_minutes - 5).clamp(0, 600).toInt()),
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: Text(
                              _minutes == 0 && _strength ? 'Auto (${strengthMinutes(_sets.length).round()} min)' : '$_minutes min',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26, fontWeight: w800),
                            ),
                          ),
                          IconButton(
                            tooltip: '5 minutes more',
                            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(52, 52)),
                            onPressed: () => setState(() => _minutes = (_minutes + 5).clamp(0, 600).toInt()),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (widget.type.hasDistance) ...[
                        const SizedBox(height: 12),
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(labelText: 'Distance (km, optional)'),
                          onChanged: (v) => _distanceKm = double.tryParse(v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: StatTile(label: 'Calories burned', value: '${fmtInt(_kcal)} kcal', protein: false)),
                    if (_strength) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: 'Total lifted',
                          value: weightText(_sets.fold<double>(0, (s, x) => s + x.reps * (x.weightKg ?? 0)), useKg, decimals: 0),
                          protein: true,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text('Estimate for ${weightText(_bodyKg, useKg)} body weight, extra calories above resting.',
                    style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 18),
                FilledButton(onPressed: _save, child: const Text('Save workout')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Plan editor

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, this.initialDay, this.draft});
  final int? initialDay;
  final WeeklyPlan? draft;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late WeeklyPlan _plan = WeeklyPlan(widget.draft?.days ?? Provider.of<AppState>(context, listen: false).plan.days);

  Future<void> _add(int day) async {
    final type = await pickExercise(context);
    if (type == null || !mounted) return;
    final p = await _editPlanned(context, type, null);
    if (p != null) setState(() => _plan.days[day]!.add(p));
  }

  Future<void> _edit(int day, int i) async {
    final item = _plan.days[day]![i];
    final type = findExercise(item.name) ?? ExerciseType(item.name, ExerciseKind.cardio, 4);
    final p = await _editPlanned(context, type, item);
    if (p != null) setState(() => _plan.days[day]![i] = p);
  }

  @override
  Widget build(BuildContext context) {
    final useKg = context.watch<AppState>().profile.useKg;
    return Scaffold(
      appBar: AppBar(title: const Text('My weekly schedule', style: TextStyle(fontWeight: w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                for (var d = 1; d <= 7; d++) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(weekdayLong[d - 1], style: const TextStyle(fontSize: 19, fontWeight: w800))),
                            if (_plan.days[d]!.isEmpty)
                              const Text('Rest day', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                          ],
                        ),
                        for (var i = 0; i < _plan.days[d]!.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                kindIcon((findExercise(_plan.days[d]![i].name)?.kind) ?? ExerciseKind.cardio),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _edit(d, i),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_plan.days[d]![i].name, style: const TextStyle(fontSize: 17, fontWeight: w800)),
                                        Text(plannedText(_plan.days[d]![i], useKg),
                                            style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => setState(() => _plan.days[d]!.removeAt(i)),
                                  icon: const Icon(Icons.close, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _add(d),
                            icon: const Icon(Icons.add),
                            label: const Text('Add exercise', style: TextStyle(fontSize: 16, fontWeight: w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    context.read<AppState>().savePlan(_plan);
                    Navigator.of(context).pop();
                    showMessage(context, 'Schedule saved');
                  },
                  child: const Text('Save schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String plannedText(PlannedExercise p, bool useKg) {
  final type = findExercise(p.name);
  final strength = type?.kind == ExerciseKind.strength;
  if (strength) {
    final w = p.weightKg == null ? '' : ' · ${weightText(p.weightKg!, useKg)}';
    final m = p.minutes == null ? '' : ' · ${p.minutes} min';
    return '${p.sets} sets × ${p.reps} reps$w$m';
  }
  return '${p.minutes ?? 30} min';
}

/// Dialog to set sets/reps/weight (strength) or minutes (others).
Future<PlannedExercise?> _editPlanned(BuildContext context, ExerciseType type, PlannedExercise? current) {
  final strength = type.kind == ExerciseKind.strength;
  final useKg = context.read<AppState>().profile.useKg;
  var sets = current?.sets ?? 3;
  var reps = (current?.reps ?? 10) == 0 ? 10 : (current?.reps ?? 10);
  var minutes = current?.minutes ?? (strength ? 0 : 30);
  final weightCtl = TextEditingController(
    text: current?.weightKg == null ? '' : fromKg(current!.weightKg!, useKg).toStringAsFixed(0),
  );

  Widget stepper(String label, String value, VoidCallback minus, VoidCallback plus) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: w800))),
            IconButton(onPressed: minus, style: IconButton.styleFrom(backgroundColor: AppColors.chip), icon: const Icon(Icons.remove)),
            SizedBox(width: 70, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: w800))),
            IconButton(onPressed: plus, style: IconButton.styleFrom(backgroundColor: AppColors.chip), icon: const Icon(Icons.add)),
          ],
        ),
      );

  return showDialog<PlannedExercise>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(type.name, style: const TextStyle(fontWeight: w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strength) ...[
                stepper('Sets', '$sets', () => setD(() => sets = (sets - 1).clamp(1, 10).toInt()),
                    () => setD(() => sets = (sets + 1).clamp(1, 10).toInt())),
                stepper('Reps', '$reps', () => setD(() => reps = (reps - 1).clamp(1, 100).toInt()),
                    () => setD(() => reps = (reps + 1).clamp(1, 100).toInt())),
                const SizedBox(height: 8),
                TextField(
                  controller: weightCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(labelText: 'Weight (${useKg ? 'kg' : 'lb'}, empty = body weight)'),
                ),
              ] else
                stepper('Minutes', '$minutes', () => setD(() => minutes = (minutes - 5).clamp(5, 300).toInt()),
                    () => setD(() => minutes = (minutes + 5).clamp(5, 300).toInt())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
            onPressed: () {
              final w = double.tryParse(weightCtl.text);
              Navigator.pop(
                ctx,
                PlannedExercise(
                  name: type.name,
                  sets: strength ? sets : 1,
                  reps: strength ? reps : 0,
                  weightKg: strength && w != null && w > 0 ? toKg(w, useKg) : null,
                  minutes: strength ? null : minutes,
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
