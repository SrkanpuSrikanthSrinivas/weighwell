import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'scale_types.dart';

/// Connects to any kitchen scale that uses the standard Bluetooth
/// Weight Scale profile (service 0x181D, characteristic 0x2A9D).
///
/// Many low-cost scales use their own private protocol instead. To support
/// one, add its service/characteristic IDs and a parser here — see
/// docs/ADDING_A_SCALE.md.
class BleScaleService extends ScaleService {
  static final Guid weightScaleService = Guid('181D');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _valueSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  bool get isSupported => true;

  static bool _is(Guid id, String short) =>
      id.toString().toLowerCase().contains(short.toLowerCase());

  @override
  Future<void> connect() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        setStatus(ScaleStatus.unsupported);
        return;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (_) {}
        }
        // Give the adapter a moment to report its real state.
        final state = await FlutterBluePlus.adapterState
            .where((s) => s != BluetoothAdapterState.unknown)
            .first
            .timeout(const Duration(seconds: 4), onTimeout: () => BluetoothAdapterState.off);
        if (state != BluetoothAdapterState.on) {
          setStatus(ScaleStatus.bluetoothOff);
          return;
        }
      }

      setStatus(ScaleStatus.scanning);
      final found = Completer<BluetoothDevice?>();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (results.isNotEmpty && !found.isCompleted) {
          found.complete(results.last.device);
        }
      });
      await FlutterBluePlus.startScan(
        withServices: [weightScaleService],
        timeout: const Duration(seconds: 12),
      );
      final device = await found.future
          .timeout(const Duration(seconds: 13), onTimeout: () => null);
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

      if (device == null) {
        setStatus(ScaleStatus.notFound);
        return;
      }

      setStatus(ScaleStatus.connecting);
      await device.connect(timeout: const Duration(seconds: 15));
      _device = device;
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && status == ScaleStatus.connected) {
          setStatus(ScaleStatus.idle);
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? weightChar;
      for (final s in services) {
        if (!_is(s.uuid, '181d')) continue;
        for (final c in s.characteristics) {
          if (_is(c.uuid, '2a9d')) weightChar = c;
        }
      }
      if (weightChar == null) {
        await device.disconnect();
        setStatus(ScaleStatus.error);
        return;
      }

      _valueSub = weightChar.onValueReceived.listen((bytes) {
        final g = parseWeightMeasurement(bytes);
        if (g != null) emitGrams(g);
      });
      device.cancelWhenDisconnected(_valueSub!);
      await weightChar.setNotifyValue(true);
      setStatus(ScaleStatus.connected);
    } catch (e) {
      debugPrint('Scale connect failed: $e');
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      setStatus(ScaleStatus.error);
    }
  }

  @override
  Future<void> disconnect() async {
    await _valueSub?.cancel();
    await _connSub?.cancel();
    await _scanSub?.cancel();
    _valueSub = null;
    _connSub = null;
    _scanSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    setStatus(ScaleStatus.idle);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

ScaleService createScaleService() => BleScaleService();
