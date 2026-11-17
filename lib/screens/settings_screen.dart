import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/food_lookup.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final t = state.targets;
    final photoOn = context.read<PhotoRecognizer>().isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My goal', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 6),
                      Text('${fmtInt(t.kcal)} kcal and ${t.protein} g protein a day',
                          style: const TextStyle(fontSize: 17)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SetupScreen(firstRun: false)),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Change my details or goal'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Text size', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 4),
                      const Text('Make everything bigger and easier to read.',
                          style: TextStyle(fontSize: 15, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      ChoicePills<double>(
                        options: {1.0: 'Normal', 1.2: 'Large', 1.4: 'Extra large'},
                        value: p.textScale,
                        onChanged: (v) => state.updateProfile(p.copyWith(textScale: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('About the numbers', style: TextStyle(fontSize: 18, fontWeight: w800)),
                      const SizedBox(height: 6),
                      Text(
                        'Fresh foods use typical values from USDA data. Packaged foods come from Open Food Facts. '
                        'Photo recognition is ${photoOn ? 'on' : 'off in this build'}. '
                        'All numbers are estimates — real foods vary. This app does not give medical advice.',
                        style: const TextStyle(fontSize: 15, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete all my data?'),
                        content: const Text('This removes your goal and everything you logged on this device.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      await state.resetAll();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFA3324F)),
                  label: const Text('Delete all my data',
                      style: TextStyle(color: Color(0xFFA3324F), fontSize: 16, fontWeight: w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
