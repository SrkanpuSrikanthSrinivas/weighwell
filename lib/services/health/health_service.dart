// Real health sync on iOS/Android; a stub on the web.
export 'health_types.dart';
export 'health_stub.dart' if (dart.library.io) 'health_impl.dart';
