import 'dart:async';

enum ScaleStatus { idle, scanning, connecting, connected, notFound, bluetoothOff, unsupported, error }

extension ScaleStatusText on ScaleStatus {
  String get message => switch (this) {
        ScaleStatus.idle => 'Scale not connected',
        ScaleStatus.scanning => 'Looking for your scale…',
        ScaleStatus.connecting => 'Connecting…',
        ScaleStatus.connected => 'Kitchen scale connected',
        ScaleStatus.notFound => 'No scale found. Turn it on and try again.',
        ScaleStatus.bluetoothOff => 'Please turn on Bluetooth',
        ScaleStatus.unsupported => 'Scales need the phone app. Type grams instead.',
        ScaleStatus.error => 'Could not connect. Type grams instead.',
      };
}

/// A Bluetooth kitchen scale. On the web this is a stub that reports
/// [ScaleStatus.unsupported].
abstract class ScaleService {
  final _status = StreamController<ScaleStatus>.broadcast();
  final _grams = StreamController<double>.broadcast();
  ScaleStatus _current = ScaleStatus.idle;

  Stream<ScaleStatus> get statusStream => _status.stream;
  Stream<double> get gramsStream => _grams.stream;
  ScaleStatus get status => _current;
  bool get isSupported;

  void setStatus(ScaleStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  void emitGrams(double g) {
    if (!_grams.isClosed) _grams.add(g);
  }

  Future<void> connect();
  Future<void> disconnect();

  void dispose() {
    _status.close();
    _grams.close();
  }
}

/// Parses the standard Bluetooth "Weight Measurement" characteristic
/// (0x2A9D, Weight Scale service 0x181D) into grams.
///
/// Byte 0 = flags (bit 0: 0 = kilograms, 1 = pounds).
/// Bytes 1–2 = weight, unsigned 16-bit little-endian.
/// Resolution: 0.005 kg or 0.01 lb.
double? parseWeightMeasurement(List<int> data) {
  if (data.length < 3) return null;
  final flags = data[0];
  final raw = data[1] | (data[2] << 8);
  if (raw == 0xFFFF) return null; // "measurement unsuccessful"
  final imperial = (flags & 0x01) == 0x01;
  final grams = imperial ? raw * 0.01 * 453.59237 : raw * 0.005 * 1000;
  return double.parse(grams.toStringAsFixed(1));
}
