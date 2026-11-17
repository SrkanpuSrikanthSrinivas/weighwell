import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/nutrition.dart';
import '../services/scale/scale_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum WeighMode { scale, manual }

class WeighScreen extends StatefulWidget {
  const WeighScreen({super.key, required this.food, this.meal});
  final Food food;
  final Meal? meal;

  @override
  State<WeighScreen> createState() => _WeighScreenState();
}

class _WeighScreenState extends State<WeighScreen> {
  late double _grams = (widget.food.typicalServingGrams ?? 100).roundToDouble();
  late Meal _meal = widget.meal ?? MealLabel.forHour(DateTime.now().hour);
  late WeighMode _mode;

  late final ScaleService _scale;
  StreamSubscription<double>? _gramsSub;
  StreamSubscription<ScaleStatus>? _statusSub;
  ScaleStatus _status = ScaleStatus.idle;
  double _rawScale = 0;
  double _tare = 0;

  @override
  void initState() {
    super.initState();
    _scale = context.read<ScaleService>();
    _status = _scale.status;
    _mode = _scale.isSupported ? WeighMode.scale : WeighMode.manual;
    _statusSub = _scale.statusStream.listen((s) => setState(() => _status = s));
    _gramsSub = _scale.gramsStream.listen((g) {
      if (_mode != WeighMode.scale) return;
      setState(() {
        _rawScale = g;
        _grams = (g - _tare).clamp(0, 5000).toDouble();
      });
    });
  }

  @override
  void dispose() {
    _gramsSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _setGrams(double g) => setState(() => _grams = g.clamp(0, 5000).roundToDouble());

  Future<void> _typeGrams() async {
    final c = TextEditingController(text: _grams.round().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How many grams?', style: TextStyle(fontWeight: w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, fontWeight: w800),
          decoration: const InputDecoration(suffixText: 'g'),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
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
    if (result != null) _setGrams(result);
  }

  void _add() {
    context.read<AppState>().addEntry(
          food: widget.food,
          grams: _grams,
          meal: _meal,
          fromScale: _mode == WeighMode.scale && _status == ScaleStatus.connected,
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Added ${widget.food.name} to ${_meal.label}', style: const TextStyle(fontSize: 16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.food.forGrams(_grams);
    final serving = widget.food.typicalServingGrams;
    final quick = <double>{50, 100, 150, 200, if (serving != null) serving.roundToDouble()}.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How much?', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
            Text(widget.food.name, style: const TextStyle(fontSize: 24, fontWeight: w800)),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                if (_scale.isSupported) ...[
                  PillToggle<WeighMode>(
                    options: const {WeighMode.scale: 'Use my scale', WeighMode.manual: 'Type grams'},
                    value: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 14),
                ],
                AppCard(
                  child: Column(
                    children: [
                      if (_mode == WeighMode.scale) _scaleStatus() else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('Weigh on any scale, then set the grams',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _RoundButton(label: '−', semantics: '5 grams less', onTap: () => _setGrams(_grams - 5)),
                          Expanded(
                            child: Semantics(
                              label: '${_grams.round()} grams. Tap to type.',
                              button: true,
                              liveRegion: true,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _typeGrams,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('${_grams.round()}',
                                          style: const TextStyle(fontSize: 64, fontWeight: w800, height: 1.1)),
                                      const Text(' g',
                                          style: TextStyle(fontSize: 26, fontWeight: w800, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _RoundButton(label: '+', semantics: '5 grams more', onTap: () => _setGrams(_grams + 5)),
                        ],
                      ),
                      const Text('Tap the number to type it',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final q in quick)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(72, 46)),
                              onPressed: () => _setGrams(q),
                              child: Text(q == serving?.roundToDouble() ? '1 serving' : '${q.round()} g'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatTile(label: 'Calories', value: fmtInt(n.kcal), protein: false)),
                          const SizedBox(width: 12),
                          Expanded(child: StatTile(label: 'Protein', value: '${fmt1(n.protein)} g', protein: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text('Carbs  ${fmt1(n.carbs)} g', style: const TextStyle(fontSize: 16, fontWeight: w700))),
                          Expanded(child: Text('Fat  ${fmt1(n.fat)} g', style: const TextStyle(fontSize: 16, fontWeight: w700))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Add to', style: TextStyle(fontSize: 17, fontWeight: w800)),
                const SizedBox(height: 8),
                ChoicePills<Meal>(
                  options: {for (final m in Meal.values) m: m.label},
                  value: _meal,
                  onChanged: (m) => setState(() => _meal = m),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _grams > 0 ? _add : null,
                  child: Text('Add to ${_meal.label}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaleStatus() {
    final connected = _status == ScaleStatus.connected;
    final busy = _status == ScaleStatus.scanning || _status == ScaleStatus.connecting;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: connected ? AppColors.greenSoft : AppColors.chip,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth,
                    size: 20, color: connected ? AppColors.green : AppColors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(_status.message,
                    style: TextStyle(
                        fontSize: 15, fontWeight: w700, color: connected ? AppColors.greenDark : AppColors.ink)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!connected && !busy)
          OutlinedButton.icon(
            onPressed: _scale.connect,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Connect my scale'),
          ),
        if (connected)
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _tare = _rawScale;
              _grams = 0;
            }),
            icon: const Icon(Icons.exposure_zero),
            label: const Text('Zero (bowl on scale)'),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.semantics, required this.onTap});
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semantics,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: AppColors.chip,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Center(child: Text(label, style: const TextStyle(fontSize: 32, fontWeight: w800))),
            ),
          ),
        ),
      );
}
