import '../state/app_state.dart';
import 'health/health_service.dart';

/// Pulls the last [days] days from Apple Health / Health Connect into the
/// daily check-ins. Returns true if anything was read.
Future<bool> syncHealth(AppState state, HealthService health, {int days = 2}) async {
  if (!health.isSupported) return false;
  if (await health.status() != HealthConnectState.connected) return false;
  final now = DateTime.now();
  var any = false;
  for (var i = days - 1; i >= 0; i--) {
    final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    final snap = await health.readDay(d);
    if (snap == null) continue;
    any = true;
    state.applyHealth(
      d,
      steps: snap.steps,
      distanceKm: snap.distanceKm,
      activeKcal: snap.activeKcal,
      weightKg: snap.weightKg,
    );
  }
  return any;
}
