// Picks the Bluetooth scale on iOS/Android and a stub on the web.
export 'scale_types.dart';
export 'scale_stub.dart' if (dart.library.io) 'scale_ble.dart';
