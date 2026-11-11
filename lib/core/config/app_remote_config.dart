import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AppRemoteConfig {
  static const _fallback = 'https://www.viz24.net/';
  static String _apiBaseUrl = _normalizeUrl(_fallback);

  // Normalized site root — no trailing slash, no /api suffix.
  // ApiClient appends /api itself.
  static String get apiBaseUrl => _apiBaseUrl;

  // Dev override: flutter run --dart-define=API_BASE_URL=http://18.140.235.103
  // When set, it wins over Firebase Remote Config and the fallback.
  static const _override = String.fromEnvironment('API_BASE_URL');

  static Future<void> init() async {
    if (_override.isNotEmpty) {
      _apiBaseUrl = _normalizeUrl(_override);
      debugPrint(
        '[RemoteConfig] using --dart-define API_BASE_URL=$_apiBaseUrl',
      );
      return;
    }
    try {
      final rc = FirebaseRemoteConfig.instance;

      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );

      await rc.setDefaults({'api_base_url': _fallback});

      final fetched = await rc.fetchAndActivate();
      final raw = rc.getString('api_base_url').trim();
      _apiBaseUrl = _normalizeUrl(raw.isEmpty ? _fallback : raw);

      debugPrint(
        '[RemoteConfig] fetch succeeded=$fetched api_base_url=$_apiBaseUrl',
      );
    } catch (e) {
      _apiBaseUrl = _normalizeUrl(_fallback);
      debugPrint(
        '[RemoteConfig] fetch failed, using fallback api_base_url=$_apiBaseUrl — $e',
      );
    }
  }

  static void useFallback({Object? reason}) {
    _apiBaseUrl = _normalizeUrl(_override.isNotEmpty ? _override : _fallback);
    debugPrint('[RemoteConfig] using fallback api_base_url=$_apiBaseUrl');
    if (reason != null) debugPrint('[RemoteConfig] fallback reason: $reason');
  }

  static String _normalizeUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.isEmpty ? 'https://www.viz24.net' : normalized;
  }
}
