import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/notification_item.dart';
import 'auth_provider.dart';

class NotificationsState {
  final List<NotificationItem> items;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiClient _api;

  NotificationsNotifier(this._api, {bool skipFetch = false})
      : super(const NotificationsState()) {
    if (!skipFetch) fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final res =
          await _api.get<Map<String, dynamic>>(ApiEndpoints.notifications);
      final data = res.data!;
      final items = (data['data'] as List)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = NotificationsState(
        items: items,
        unreadCount: data['unread_count'] as int,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markRead(int id) async {
    final notif = state.items.where((n) => n.id == id).firstOrNull;
    if (notif == null || notif.isRead) return;
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
      unreadCount: (state.unreadCount - 1).clamp(0, 99999),
    );
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.notificationRead(id),
      );
      state = state.copyWith(unreadCount: res.data!['unread_count'] as int);
    } catch (_) {}
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final isAuth = ref.watch(authProvider).isAuthenticated;
  final api = ref.watch(apiClientProvider);
  return NotificationsNotifier(api, skipFetch: !isAuth);
});
