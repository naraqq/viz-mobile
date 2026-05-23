import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const _method = MethodChannel('viz/screen_security');
  static const _events = EventChannel('viz/screen_security_events');

  static Future<void> enable() => _method.invokeMethod('enable');
  static Future<void> disable() => _method.invokeMethod('disable');

  // iOS only — emits true when screen is being captured/recorded
  static Stream<bool> get captureStream =>
      _events.receiveBroadcastStream().map((v) => v as bool);
}
