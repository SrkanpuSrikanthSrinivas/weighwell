import 'health_types.dart';

class _NoHealth implements HealthService {
  @override
  bool get isSupported => false;
  @override
  String get sourceName => 'Phone health';
  @override
  Future<HealthConnectState> status() async => HealthConnectState.unsupported;
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> install() async {}
  @override
  Future<HealthSnapshot?> readDay(DateTime day) async => null;
}

HealthService createHealthService() => _NoHealth();
