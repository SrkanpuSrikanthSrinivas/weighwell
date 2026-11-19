import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/coach_client.dart';
import '../services/energy.dart';
import '../services/health/health_service.dart';
import '../services/health_sync.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/units.dart';
import 'checkin_screen.dart';

/// Calories in vs. out, weight trend, phone health sync and AI review.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  CoachInsights? _insights;
  bool _asking = false;
  String? _coachError;
  HealthConnectState? _healthState;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refreshHealthState();
  }

  Future<void> _refreshHealthState() async {
    final s = await context.read<HealthService>().status();
    if (mounted) setState(() => _healthState = s);
  }

  Future<void> _connectHealth() async {
    final health = context.read<HealthService>();
    final state = context.read<AppState>();
    setState(() => _syncing = true);
    if (_healthState == HealthConnectState.needsInstall) {
      await health.install();
    } else if (_healthState != HealthConnectState.connected) {
      await health.connect();
    }
    final ok = await syncHealth(state, health, days: 7);
    await _refreshHealthState();
    if (!mounted) return;
    setState(() => _syncing = false);
    showMessage(context, ok ? 'Synced from ${health.sourceName}' : 'No new health data found');
  }

  Future<void> _askCoach() async {
    final coach = context.read<CoachClient>();
    final summary = context.read<AppState>().weekSummaryForCoach();
    setState(() {
      _asking = true;
      _coachError = null;
    });
    try {
      final r = await coach.insights(summary);
      if (!mounted) return;
      setState(() {
        _insights = r;
        _asking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _coachError = coach.isConfigured
            ? 'Could not reach the coach. Check your internet and try again.'
            : 'The AI coach is not switched on in this build yet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final health = Provider.of<HealthService>(context, listen: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final energies = [for (final d in week) state.energyOn(d)];
    final loggedDays = [for (var i = 0; i < 7; i++) if (state.entriesOn(week[i]).isNotEmpty) i];
    final balanceLogged = loggedDays.fold<double>(0, (s, i) => s + energies[i].balance);
    final perWeekKg = loggedDays.isEmpty ? null : expectedWeightChangeKg(balanceLogged / loggedDays.length * 7);
    final todayE = energies.last;
    final useKg = state.profile.useKg;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('How am I doing?', style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: w700)),
        const Text('Progress', style: TextStyle(fontSize: 32, fontWeight: w800)),
        const SizedBox(height: 14),

        // AI coach
        AppCard(
          color: AppColors.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFA9C6FF)),
                  SizedBox(width: 8),
                  Text('AI health coach', style: TextStyle(fontSize: 19, fontWeight: w800, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Looks at your last 7 days of food, steps, workouts, weight, water and sleep.',
                  style: TextStyle(fontSize: 15, color: Color(0xFFBFD3C7))),
              const SizedBox(height: 12),
              if (_insights != null) _InsightsView(_insights!),
              if (_coachError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_coachError!, style: const TextStyle(fontSize: 15, color: Color(0xFFFFC9A8), fontWeight: w700)),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                onPressed: _asking ? null : _askCoach,
                icon: _asking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.chat_bubble_outline),
                label: Text(_asking ? 'Reading your week…' : (_insights == null ? 'Review my week' : 'Review again')),
              ),
              const SizedBox(height: 6),
              const Text('General wellness tips, not medical advice.',
                  style: TextStyle(fontSize: 13, color: Color(0xFFBFD3C7))),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Today in / out
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Today: calories in and out', style: TextStyle(fontSize: 19, fontWeight: w800)),
              const SizedBox(height: 10),
              _line('Eaten', todayE.eaten.kcal, bold: true),
              const Divider(color: AppColors.chip),
              _line('Resting body (BMR)', todayE.resting),
              _line('Daily living', todayE.dailyLiving),
              _line(
                'Walking${todayE.steps > 0 ? ' (${fmtInt(todayE.steps)} steps, ${todayE.distanceKm.toStringAsFixed(1)} km)' : ''}',
                todayE.walking,
              ),
              _line('Exercise', todayE.exercise),
              const Divider(color: AppColors.chip),
              _line('Burned', todayE.burned, bold: true),
              const SizedBox(height: 6),
              _BalanceChip(todayE.balance),
              if (todayE.usedHealthData)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Active calories measured by ${health.sourceName}.',
                      style: const TextStyle(fontSize: 14, color: AppColors.green, fontWeight: w700)),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(day: today))),
                icon: const Icon(Icons.edit_note),
                label: const Text('Daily check-in'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Week table
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Last 7 days', style: TextStyle(fontSize: 19, fontWeight: w800)),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(flex: 3, child: Text('Day', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700))),
                  Expanded(flex: 3, child: Text('In', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700))),
                  Expanded(flex: 3, child: Text('Out', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700))),
                  Expanded(flex: 3, child: Text('Steps', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: w700))),
                ],
              ),
              for (var i = 0; i < 7; i++)
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(day: week[i]))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(i == 6 ? 'Today' : DateFormat('EEE d').format(week[i]),
                              style: const TextStyle(fontSize: 16, fontWeight: w800)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(loggedDays.contains(i) ? fmtInt(energies[i].eaten.kcal) : '—',
                              textAlign: TextAlign.right, style: const TextStyle(fontSize: 16)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(fmtInt(energies[i].burned), textAlign: TextAlign.right, style: const TextStyle(fontSize: 16)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(energies[i].steps > 0 ? fmtInt(energies[i].steps) : '—',
                              textAlign: TextAlign.right, style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(color: AppColors.chip),
              Text(
                perWeekKg == null
                    ? 'Log your food to see where your weight is heading.'
                    : 'At this pace: about ${perWeekKg >= 0 ? '+' : '−'}${weightText(perWeekKg.abs(), useKg, decimals: 2)} a week '
                        '(based on ${loggedDays.length} day${loggedDays.length == 1 ? '' : 's'} with food logged).',
                style: const TextStyle(fontSize: 15, fontWeight: w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Weight trend
        _WeightCard(points: state.weightHistory(), useKg: useKg),
        const SizedBox(height: 14),

        // Phone health
        if (health.isSupported)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_outline, color: Color(0xFFA3324F)),
                    const SizedBox(width: 8),
                    Text(health.sourceName, style: const TextStyle(fontSize: 19, fontWeight: w800)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  switch (_healthState) {
                    HealthConnectState.connected => 'Connected. Steps, walking distance, active calories and weight sync automatically.',
                    HealthConnectState.needsInstall => 'Install Health Connect to sync steps automatically.',
                    _ => 'Connect to fill in your steps, walking distance and active calories automatically.',
                  },
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _syncing ? null : _connectHealth,
                  icon: _syncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Icon(_healthState == HealthConnectState.connected ? Icons.sync : Icons.link),
                  label: Text(switch (_healthState) {
                    HealthConnectState.connected => 'Sync now',
                    HealthConnectState.needsInstall => 'Install Health Connect',
                    _ => 'Connect ${health.sourceName}',
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Calories burned are estimates from your age, height, weight, steps and exercise. '
          'Body weight naturally moves up and down by 1–2 kg from day to day, so look at the trend over weeks.',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: widget.wide ? const EdgeInsets.fromLTRB(32, 28, 32, 40) : const EdgeInsets.fromLTRB(18, 20, 18, 30),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content)),
      ),
    );
  }

  static Widget _line(String label, double kcal, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? w800 : FontWeight.w600))),
            Text('${fmtInt(kcal)} kcal', style: TextStyle(fontSize: 16, fontWeight: bold ? w800 : w700)),
          ],
        ),
      );
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip(this.balance);
  final double balance;

  @override
  Widget build(BuildContext context) {
    final surplus = balance > 0;
    final text = balance.abs() < 50
        ? 'Balanced: eaten ≈ burned'
        : surplus
            ? '${fmtInt(balance)} kcal more eaten than burned'
            : '${fmtInt(-balance)} kcal more burned than eaten';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surplus ? const Color(0xFFFFF1E0) : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 16, fontWeight: w800, color: surplus ? const Color(0xFF8A3A0B) : AppColors.greenDark)),
    );
  }
}

class _InsightsView extends StatelessWidget {
  const _InsightsView(this.i);
  final CoachInsights i;

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<String> items, IconData icon, Color color) => items.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: w800, color: color)),
                const SizedBox(height: 4),
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 16, color: Colors.white))),
                      ],
                    ),
                  ),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i.score != null)
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Text('${i.score}/10', style: const TextStyle(fontSize: 17, fontWeight: w800, color: Colors.white)),
              ),
            Expanded(
              child: Text(i.headline, style: const TextStyle(fontSize: 18, fontWeight: w800, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        section('Going well', i.goingWell, Icons.check_circle, const Color(0xFF8EE3B0)),
        section('Try next', i.tryNext, Icons.arrow_forward, const Color(0xFFA9C6FF)),
        section('Keep an eye on', i.watchOut, Icons.info_outline, const Color(0xFFFFC9A8)),
      ],
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.points, required this.useKg});
  final List<(DateTime, double)> points;
  final bool useKg;

  @override
  Widget build(BuildContext context) {
    final change = points.length >= 2 ? points.last.$2 - points.first.$2 : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('My weight (30 days)', style: TextStyle(fontSize: 19, fontWeight: w800)),
          const SizedBox(height: 6),
          if (points.isEmpty)
            const Text('No weigh-ins yet. Add your weight in the daily check-in.',
                style: TextStyle(fontSize: 15, color: AppColors.muted))
          else ...[
            Text(
              change == null
                  ? 'Latest: ${weightText(points.last.$2, useKg)}'
                  : 'Latest: ${weightText(points.last.$2, useKg)} · ${change >= 0 ? '+' : '−'}${weightText(change.abs(), useKg)} since ${DateFormat('MMM d').format(points.first.$1)}',
              style: const TextStyle(fontSize: 16, fontWeight: w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Semantics(
                label: 'Weight chart with ${points.length} weigh-ins',
                child: CustomPaint(painter: _WeightPainter(points)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.points);
  final List<(DateTime, double)> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final ws = points.map((p) => p.$2).toList();
    var lo = ws.reduce(math.min);
    var hi = ws.reduce(math.max);
    if (hi - lo < 2) {
      final mid = (hi + lo) / 2;
      lo = mid - 1;
      hi = mid + 1;
    }
    final first = points.first.$1;
    final spanDays = math.max(1, points.last.$1.difference(first).inDays);
    Offset at((DateTime, double) p) => Offset(
          points.length == 1 ? size.width / 2 : size.width * p.$1.difference(first).inDays / spanDays,
          size.height - (p.$2 - lo) / (hi - lo) * (size.height - 16) - 8,
        );

    final grid = Paint()
      ..color = AppColors.chip
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.blue;
    for (final p in points) {
      canvas.drawCircle(at(p), 4.5, dot);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.points != points;
}
