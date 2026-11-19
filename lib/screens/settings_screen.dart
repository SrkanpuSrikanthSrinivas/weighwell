import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/food_lookup.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: w800)),
        content: Text(body, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes, style: const TextStyle(color: Color(0xFFA3324F), fontWeight: w800)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final p = state.profile;
    final t = state.targets;
    final photoOn = Provider.of<PhotoRecognizer>(context, listen: false).isConfigured;

    final syncText = switch (state.syncStatus) {
      SyncStatus.synced => state.lastSynced == null
          ? 'All changes saved to your account'
          : 'All changes saved · ${DateFormat('h:mm a').format(state.lastSynced!)}',
      SyncStatus.syncing => 'Saving…',
      SyncStatus.offline => 'Offline — ${state.pendingChanges} change(s) will save when you are back online',
      SyncStatus.off => 'Saved on this device only',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Account and settings', style: TextStyle(fontWeight: w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                // Account
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.greenSoft,
                            child: Text(
                              auth.displayName.isEmpty ? '?' : auth.displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 22, fontWeight: w800, color: AppColors.greenDark),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.enabled ? auth.displayName : 'Not signed in',
                                    style: const TextStyle(fontSize: 19, fontWeight: w800)),
                                if (auth.email.isNotEmpty && auth.email != auth.displayName)
                                  Text(auth.email, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            state.syncStatus == SyncStatus.offline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                            color: state.syncStatus == SyncStatus.offline ? const Color(0xFFB4530B) : AppColors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(syncText, style: const TextStyle(fontSize: 15, fontWeight: w700))),
                        ],
                      ),
                      if (!auth.enabled)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Accounts are not set up in this build yet (see docs/ACCOUNTS.md), so data stays on this device.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF8A3A0B), fontWeight: w700),
                          ),
                        ),
                      if (auth.enabled) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await _confirm(context, 'Sign out?',
                                'Your data stays safe in your account. Sign in again any time to see it.', 'Sign out');
                            if (!ok || !context.mounted) return;
                            Navigator.of(context).popUntil((r) => r.isFirst);
                            await auth.signOut();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SectionHeader('My goals'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${fmtInt(t.kcal)} kcal and ${t.protein} g protein a day',
                          style: const TextStyle(fontSize: 17, fontWeight: w800)),
                      const SizedBox(height: 4),
                      const Text('Worked out from your age, height, weight, activity and goal.',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SetupScreen(firstRun: false)),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Change my details or goal'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Daily steps', style: TextStyle(fontSize: 16, fontWeight: w800)),
                      const SizedBox(height: 8),
                      ChoicePills<int>(
                        options: const {5000: '5,000', 7000: '7,000', 8000: '8,000', 10000: '10,000'},
                        value: p.stepGoal,
                        onChanged: (v) => state.updateProfile(p.copyWith(stepGoal: v)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Glasses of water', style: TextStyle(fontSize: 16, fontWeight: w800)),
                      const SizedBox(height: 8),
                      ChoicePills<int>(
                        options: const {6: '6', 8: '8', 10: '10', 12: '12'},
                        value: p.waterGoal,
                        onChanged: (v) => state.updateProfile(p.copyWith(waterGoal: v)),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Easy reading'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Text size', style: TextStyle(fontSize: 16, fontWeight: w800)),
                      const SizedBox(height: 8),
                      ChoicePills<double>(
                        options: {1.0: 'Normal', 1.2: 'Large', 1.4: 'Extra large'},
                        value: p.textScale,
                        onChanged: (v) => state.updateProfile(p.copyWith(textScale: v)),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('About the numbers'),
                AppCard(
                  child: Text(
                    'Fresh foods use typical values from USDA data. Packaged foods come from Open Food Facts. '
                    'Photo recognition and the AI coach are ${photoOn ? 'on' : 'off in this build (see docs/ACCOUNTS.md)'}. '
                    'All numbers are estimates — real foods and bodies vary. This app does not give medical advice.',
                    style: const TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await _confirm(
                      context,
                      auth.enabled ? 'Delete my account?' : 'Delete all my data?',
                      auth.enabled
                          ? 'This permanently deletes your account and everything you have logged, on all devices. This cannot be undone.'
                          : 'This removes your goal and everything you logged on this device.',
                      'Delete',
                    );
                    if (!ok || !context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    try {
                      if (auth.enabled) {
                        await auth.deleteAccount();
                      } else {
                        await state.resetAll();
                      }
                    } catch (_) {
                      messenger.showSnackBar(const SnackBar(content: Text('Could not delete. Check your internet and try again.')));
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFA3324F)),
                  label: Text(auth.enabled ? 'Delete my account' : 'Delete all my data',
                      style: const TextStyle(color: Color(0xFFA3324F), fontSize: 16, fontWeight: w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
