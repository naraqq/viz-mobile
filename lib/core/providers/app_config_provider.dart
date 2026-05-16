import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/app_config.dart';
import 'auth_provider.dart';

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get<Map<String, dynamic>>(ApiEndpoints.config);
    return AppConfig.fromJson(res.data!);
  } catch (_) {
    return AppConfig.empty;
  }
});

final reviewModeProvider = Provider<bool>((ref) {
  return ref.watch(appConfigProvider).valueOrNull?.reviewMode ?? false;
});

// Set to true by AuthLoadingScreen after version check; triggers router redirect.
final forceUpdateProvider = StateProvider<bool>((ref) => false);
