/// What we read from Apple Health / Google Health Connect for one day.
class HealthSnapshot {
  const HealthSnapshot({this.steps, this.distanceKm, this.activeKcal, this.weightKg});
  final int? steps;
  final double? distanceKm;
  final double? activeKcal;
  final double? weightKg;

  bool get isEmpty => steps == null && distanceKm == null && activeKcal == null && weightKg == null;
}

enum HealthConnectState { unsupported, needsInstall, notConnected, connected, denied }

abstract class HealthService {
  /// False on the web.
  bool get isSupported;

  /// Name shown to the user: "Apple Health" or "Health Connect".
  String get sourceName;

  Future<HealthConnectState> status();

  /// Shows the system permission sheet. Returns true if allowed.
  Future<bool> connect();

  /// Opens the store page to install Health Connect (older Android).
  Future<void> install();

  Future<HealthSnapshot?> readDay(DateTime day);
}
