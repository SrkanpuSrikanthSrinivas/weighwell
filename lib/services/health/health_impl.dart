import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'health_types.dart';

/// Reads steps, walking distance, active calories and body weight from
/// Apple Health (iOS) or Google Health Connect (Android). Read-only.
class PhoneHealthService implements HealthService {
  final Health _health = Health();
  bool _configured = false;
  static const _kConnected = 'health_connected';

  List<HealthDataType> get _types => [
        HealthDataType.STEPS,
        Platform.isIOS ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.WEIGHT,
      ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  @override
  String get sourceName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Future<HealthConnectState> status() async {
    if (!isSupported) return HealthConnectState.unsupported;
    try {
      await _configure();
      if (Platform.isAndroid) {
        final sdk = await _health.getHealthConnectSdkStatus();
        if (sdk != HealthConnectSdkStatus.sdkAvailable) return HealthConnectState.needsInstall;
      }
      final prefs = await SharedPreferences.getInstance();
      // iOS never tells apps whether read access was granted, so we
      // remember that the user went through the permission sheet.
      if (prefs.getBool(_kConnected) ?? false) return HealthConnectState.connected;
      return HealthConnectState.notConnected;
    } catch (e) {
      debugPrint('Health status failed: $e');
      return HealthConnectState.notConnected;
    }
  }

  @override
  Future<bool> connect() async {
    try {
      await _configure();
      final types = _types;
      final ok = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kConnected, ok);
      return ok;
    } catch (e) {
      debugPrint('Health connect failed: $e');
      return false;
    }
  }

  @override
  Future<void> install() async {
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Install Health Connect failed: $e');
    }
  }

  @override
  Future<HealthSnapshot?> readDay(DateTime day) async {
    try {
      await _configure();
      final start = DateTime(day.year, day.month, day.day);
      final now = DateTime.now();
      var end = start.add(const Duration(days: 1));
      if (end.isAfter(now)) end = now;
      if (!end.isAfter(start)) return null;

      final steps = await _health.getTotalStepsInInterval(start, end);

      var points = await _health.getHealthDataFromTypes(
        types: _types.where((t) => t != HealthDataType.STEPS).toList(),
        startTime: start,
        endTime: end,
      );
      points = _health.removeDuplicates(points);

      double sumOf(bool Function(HealthDataType) match) {
        var total = 0.0;
        for (final p in points) {
          if (!match(p.type)) continue;
          final v = p.value;
          if (v is NumericHealthValue) total += v.numericValue.toDouble();
        }
        return total;
      }

      final metres = sumOf((t) => t == HealthDataType.DISTANCE_WALKING_RUNNING || t == HealthDataType.DISTANCE_DELTA);
      final kcal = sumOf((t) => t == HealthDataType.ACTIVE_ENERGY_BURNED);

      double? weight;
      DateTime? latest;
      for (final p in points) {
        if (p.type != HealthDataType.WEIGHT) continue;
        final v = p.value;
        if (v is NumericHealthValue && (latest == null || p.dateTo.isAfter(latest))) {
          latest = p.dateTo;
          weight = v.numericValue.toDouble();
        }
      }

      final snap = HealthSnapshot(
        steps: steps,
        distanceKm: metres > 0 ? metres / 1000 : null,
        activeKcal: kcal > 0 ? kcal : null,
        weightKg: weight,
      );
      return snap.isEmpty ? null : snap;
    } catch (e) {
      debugPrint('Health read failed: $e');
      return null;
    }
  }
}

HealthService createHealthService() => PhoneHealthService();
