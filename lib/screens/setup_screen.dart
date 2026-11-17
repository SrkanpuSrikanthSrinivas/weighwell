import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// First launch (and "Edit my goal"): a few big, simple questions.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.firstRun});
  final bool firstRun;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late Profile _p = context.read<AppState>().profile;

  static const _lbPerKg = 2.20462;

  void _save() {
    final state = context.read<AppState>();
    state.updateProfile(_p, finishSetup: true);
    if (!widget.firstRun) Navigator.of(context).pop();
  }

  Future<num?> _askNumber(String title, num current, String suffix) async {
    final c = TextEditingController(text: current.round().toString());
    return showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26, fontWeight: w800),
          decoration: InputDecoration(suffixText: suffix),
          onSubmitted: (v) => Navigator.pop(ctx, num.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
            onPressed: () => Navigator.pop(ctx, num.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = targetsFor(_p);
    final weightShown = _p.useKg ? _p.weightKg : _p.weightKg * _lbPerKg;
    final unit = _p.useKg ? 'kg' : 'lb';

    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(title: const Text('My goal', style: TextStyle(fontWeight: w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
              children: [
                if (widget.firstRun) ...[
                  const Text('Welcome! This takes 30 seconds.',
                      style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: w700)),
                  const Text('Tell us about you', style: TextStyle(fontSize: 30, fontWeight: w800)),
                  const SizedBox(height: 16),
                ],
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _StepperRow(
                        label: 'Age',
                        value: '${_p.age} yrs',
                        onMinus: () => setState(() => _p = _p.copyWith(age: (_p.age - 1).clamp(13, 100).toInt())),
                        onPlus: () => setState(() => _p = _p.copyWith(age: (_p.age + 1).clamp(13, 100).toInt())),
                        onTapValue: () async {
                          final v = await _askNumber('Your age', _p.age, 'yrs');
                          if (v != null) setState(() => _p = _p.copyWith(age: v.toInt().clamp(13, 100).toInt()));
                        },
                      ),
                      _StepperRow(
                        label: 'Weight',
                        value: '${weightShown.round()} $unit',
                        onMinus: () => setState(() => _p = _p.copyWith(
                            weightKg: (_p.weightKg - (_p.useKg ? 1 : 1 / _lbPerKg)).clamp(30, 250).toDouble())),
                        onPlus: () => setState(() => _p = _p.copyWith(
                            weightKg: (_p.weightKg + (_p.useKg ? 1 : 1 / _lbPerKg)).clamp(30, 250).toDouble())),
                        onTapValue: () async {
                          final v = await _askNumber('Your weight', weightShown, unit);
                          if (v != null) {
                            final kg = _p.useKg ? v.toDouble() : v / _lbPerKg;
                            setState(() => _p = _p.copyWith(weightKg: kg.clamp(30, 250).toDouble()));
                          }
                        },
                      ),
                      _StepperRow(
                        label: 'Height',
                        value: '${_p.heightCm.round()} cm',
                        last: true,
                        onMinus: () => setState(() => _p = _p.copyWith(heightCm: (_p.heightCm - 1).clamp(120, 220).toDouble())),
                        onPlus: () => setState(() => _p = _p.copyWith(heightCm: (_p.heightCm + 1).clamp(120, 220).toDouble())),
                        onTapValue: () async {
                          final v = await _askNumber('Your height', _p.heightCm, 'cm');
                          if (v != null) setState(() => _p = _p.copyWith(heightCm: v.toDouble().clamp(120, 220).toDouble()));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Weight in', style: TextStyle(fontSize: 16, fontWeight: w700))),
                    SizedBox(
                      width: 180,
                      child: ChoicePills<bool>(
                        options: const {true: 'kg', false: 'lb'},
                        value: _p.useKg,
                        height: 44,
                        onChanged: (v) => setState(() => _p = _p.copyWith(useKg: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('I am a', style: TextStyle(fontSize: 18, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<Sex>(
                  options: const {Sex.female: 'Woman', Sex.male: 'Man'},
                  value: _p.sex,
                  onChanged: (s) => setState(() => _p = _p.copyWith(sex: s)),
                ),
                const SizedBox(height: 18),
                const Text('How active are you?', style: TextStyle(fontSize: 18, fontWeight: w800)),
                const SizedBox(height: 8),
                for (final a in Activity.values) ...[
                  _BigChoice(
                    title: a.label,
                    subtitle: a.hint,
                    selected: _p.activity == a,
                    onTap: () => setState(() => _p = _p.copyWith(activity: a)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                const Text('My goal', style: TextStyle(fontSize: 18, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<Goal>(
                  options: {for (final g in Goal.values) g: g.label},
                  value: _p.goal,
                  height: 54,
                  onChanged: (g) => setState(() => _p = _p.copyWith(goal: g)),
                ),
                const SizedBox(height: 18),
                AppCard(
                  color: AppColors.ink,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your daily target (estimate)',
                          style: TextStyle(fontSize: 15, color: Color(0xFFBFD3C7), fontWeight: w700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 22,
                        children: [
                          Text('${fmtInt(t.kcal)} kcal',
                              style: const TextStyle(fontSize: 28, fontWeight: w800, color: Colors.white)),
                          Text('${t.protein} g protein',
                              style: const TextStyle(fontSize: 28, fontWeight: w800, color: Color(0xFFA9C6FF))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: Text(widget.firstRun ? 'Save and start' : 'Save')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTapValue,
    this.last = false,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapValue;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.chip)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: w800))),
          IconButton(
            tooltip: 'Less',
            onPressed: onMinus,
            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.remove),
          ),
          InkWell(
            onTap: onTapValue,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 96, minHeight: 48),
              alignment: Alignment.center,
              child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: w800)),
            ),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: onPlus,
            style: IconButton.styleFrom(backgroundColor: AppColors.chip, minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.green : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? AppColors.green : AppColors.chipBorder, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontSize: 18, fontWeight: w800, color: selected ? Colors.white : AppColors.ink)),
                      Text(subtitle,
                          style: TextStyle(fontSize: 15, color: selected ? const Color(0xFFDDEFE4) : AppColors.muted)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
