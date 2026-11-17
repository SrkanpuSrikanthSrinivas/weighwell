import 'scale_types.dart';

/// Web build: browsers cannot reliably talk to kitchen scales, so the web
/// app always uses typed grams.
class _UnsupportedScale extends ScaleService {
  @override
  bool get isSupported => false;

  @override
  Future<void> connect() async => setStatus(ScaleStatus.unsupported);

  @override
  Future<void> disconnect() async => setStatus(ScaleStatus.idle);
}

ScaleService createScaleService() => _UnsupportedScale();
