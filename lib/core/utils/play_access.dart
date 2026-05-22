import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_endpoints.dart';
import '../models/json_helpers.dart';
import '../providers/auth_provider.dart';

/// Verifies play access right before launching the player.
///
/// Hits the detail endpoint + /auth/user in parallel for a fresh check.
/// Returns true if the user is allowed to play, false otherwise.
/// Falls back to cached auth state on network error so offline users aren't
/// unnecessarily blocked.
Future<bool> verifyPlayAccess({
  required WidgetRef ref,
  required String slug,
  required bool isMovie,
  bool isFree = false,
}) async {
  final api = ref.read(apiClientProvider);
  final endpoint =
      isMovie ? ApiEndpoints.movieDetail(slug) : ApiEndpoints.showDetail(slug);

  try {
    final results = await Future.wait<dynamic>([
      ref.read(authProvider.notifier).refreshUser(),
      api.get<Map<String, dynamic>>(endpoint),
    ]);

    final data =
        (results[1] as dynamic).data as Map<String, dynamic>;
    final canWatch = readBool(data['can_watch']);
    final hasRental = readBool(data['has_rental']);
    final user = ref.read(authProvider).user;

    return canWatch || hasRental || isFree || (user?.hasActiveSubscription == true);
  } catch (_) {
    // Network error — fall back to cached subscription status so a bad
    // connection doesn't lock out a legitimate subscriber.
    final user = ref.read(authProvider).user;
    return isFree || (user?.hasActiveSubscription == true);
  }
}

/// Shows a snackbar and navigates to /plans when access is denied.
void handleAccessDenied(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Энэ үзвэрийг үзэхийн тулд багц авах шаардлагатай.'),
      duration: Duration(seconds: 3),
    ),
  );
  context.push('/plans');
}
