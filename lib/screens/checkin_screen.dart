import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fitness.dart';
import '../services/energy.dart';
import '../services/health/health_service.dart';
import '../services/health_sync.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/units.dart';

/// Daily check-in: body weight, steps, water, sleep and simple habits.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, required this.day});
  final DateTime day;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late DayCheckIn _c;
  late double? _weightKg;
  late final TextEditingController _steps;
  late final TextEditingController _note;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _c = state.checkInOn(widget.day);
    _weightKg = _c.bodyWeightKg;
    _steps = TextEditingController(text: _c.steps?.toString() ?? '');
    _note = TextEditingController(text: _c.note);
  }

  @override
  void dispose() {
    _steps.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final state = context.read<AppState>();
    final health = context.read<HealthService>();
    setState(() => _syncing = true);
    var st = await health.status();
    if (st == HealthConnectState.notConnected) {
      await health.connect();
      st = await health.status();
    }
    final snap = st == HealthConnectState.connected ? await health.readDay(widget.day) : null;
    if (!mounted) return;
    setState(() {
      _syncing = false;
      if (snap != null) {
        _c = _c.copyWith(
          steps: snap.steps,
          distanceKm: snap.distanceKm,
          healthActiveKcal: snap.activeKcal,
          stepsFromHealth: snap.steps != null,
        );
        if (snap.steps != null) _steps.text = '${snap.steps}';
        _weightKg ??= snap.weightKg;
      }
    });
    if (snap == null) {
      showMessage(
        context,
        st == HealthConnectState.needsInstall
            ? 'Please install Health Connect first (Settings → Health data).'
            : 'No health data found for this day.',
      );
    } else {
      // Also refresh yesterday in the background.
      syncHealth(state, health);
    }
  }

  void _save() {
    final steps = int.tryParse(_steps.text.trim());
    final manualSteps = steps != null && steps != _c.steps;
    final state = context.read<AppState>();
    state.saveCheckIn(DayCheckIn(
      day: _c.day,
      bodyWeightKg: _weightKg,
      steps: steps,
      // Typed steps replace the phone's distance, which may not match.
      distanceKm: manualSteps ? null : _c.distanceKm,
      healthActiveKcal: manualSteps ? null : _c.healthActiveKcal,
      water: _c.water,
      sleepHours: _c.sleepHours,
      habits: _c.habits,
      note: _note.text.trim(),
      stepsFromHealth: !manualSteps && _c.stepsFromHealth,
    ));
    Navigator.of(context).pop();
    showMessage(context, 'Check-in saved');
  }

  Future<void> _typeWeight(bool useKg) async {
    final c = TextEditingController(
      text: _weightKg == null ? '' : fromKg(_weightKg!, useKg).toStringAsFixed(1),
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My weight today', style: TextStyle(fontWeight: w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 28, fontWeight: w800),
          decoration: InputDecoration(suffixText: useKg ? 'kg' : 'lb'),
          onSubmitted: (t) => Navigator.pop(ctx, double.tryParse(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => _weightKg = toKg(v, useKg).clamp(25, 300).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final health = Provider.of<HealthService>(context, listen: false);
    final isToday = dayKey(widget.day) == dayKey(DateTime.now());
    final shownWeight = _weightKg ?? state.weightOn(widget.day);
    final steps = int.tryParse(_steps.text);
    final km = _c.distanceKm ?? (steps == null ? null : stepsToKm(steps, p.heightCm));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily check-in', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
            Text(isToday ? 'Today' : DateFormat('EEEE, MMM d').format(widget.day),
                style: const TextStyle(fontSize: 24, fontWeight: w800)),
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
                // Weight
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My weight', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Less',
                            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(56, 56)),
                            onPressed: () => setState(() =>
                                _weightKg = (shownWeight - (p.useKg ? 0.1 : 0.1 / lbPerKg)).clamp(25, 300).toDouble()),
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _typeWeight(p.useKg),
                              child: Column(
                                children: [
                                  Text(weightText(shownWeight, p.useKg),
                                      style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: w800,
                                          color: _weightKg == null ? AppColors.muted : AppColors.ink)),
                                  Text(_weightKg == null ? 'Tap to enter today\'s weight' : 'Tap to type',
                                      style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'More',
                            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(56, 56)),
                            onPressed: () => setState(() =>
                                _weightKg = (shownWeight + (p.useKg ? 0.1 : 0.1 / lbPerKg)).clamp(25, 300).toDouble()),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Weigh yourself at the same time each day, ideally in the morning.',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Steps
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Walking', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _steps,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 20, fontWeight: w800),
                        decoration: const InputDecoration(labelText: 'Steps', suffixText: 'steps'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      if (km != null)
                        Text(
                          'About ${km.toStringAsFixed(1)} km · ${fmtInt(walkingKcal(km: km, weightKg: shownWeight))} kcal burned walking',
                          style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700),
                        ),
                      if (_c.stepsFromHealth)
                        Text('From ${health.sourceName}', style: const TextStyle(fontSize: 14, color: AppColors.green, fontWeight: w700)),
                      if (health.isSupported) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _syncing ? null : _sync,
                          icon: _syncing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Icon(Icons.sync),
                          label: Text('Get from ${health.sourceName}'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Water and sleep
                AppCard(
                  child: Column(
                    children: [
                      _counter(
                        icon: Icons.water_drop_outlined,
                        label: 'Water',
                        value: '${_c.water} glasses',
                        onMinus: () => setState(() => _c = _c.copyWith(water: (_c.water - 1).clamp(0, 20).toInt())),
                        onPlus: () => setState(() => _c = _c.copyWith(water: (_c.water + 1).clamp(0, 20).toInt())),
                      ),
                      const Divider(height: 20, color: AppColors.chip),
                      _counter(
                        icon: Icons.bedtime_outlined,
                        label: 'Sleep',
                        value: _c.sleepHours == null ? '— h' : '${_c.sleepHours!.toStringAsFixed(1)} h',
                        onMinus: () => setState(
                            () => _c = _c.copyWith(sleepHours: ((_c.sleepHours ?? 7) - 0.5).clamp(0, 16).toDouble())),
                        onPlus: () => setState(
                            () => _c = _c.copyWith(sleepHours: ((_c.sleepHours ?? 7) + 0.5).clamp(0, 16).toDouble())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Habits
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Food habits today', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final h in dailyHabits)
                            FilterChip(
                              label: Text(h, style: const TextStyle(fontSize: 16, fontWeight: w700)),
                              selected: _c.habits.contains(h),
                              showCheckmark: true,
                              selectedColor: AppColors.greenSoft,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              onSelected: (on) => setState(() {
                                final s = Set<String>.of(_c.habits);
                                on ? s.add(h) : s.remove(h);
                                _c = _c.copyWith(habits: s);
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 17),
                        decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'e.g. felt hungry after lunch'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: _save, child: const Text('Save check-in')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _counter({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.blue, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: w800))),
        IconButton(
          tooltip: '$label less',
          onPressed: onMinus,
          style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 104,
          child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: w800)),
        ),
        IconButton(
          tooltip: '$label more',
          onPressed: onPlus,
          style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
