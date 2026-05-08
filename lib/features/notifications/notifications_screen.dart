import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/notification_item.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Мэдэгдэлүүд',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => _markAllRead(ref, state.items),
              child: const Text('Бүгдийг уншсан',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : state.items.isEmpty
              ? _Empty()
              : RefreshIndicator(
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  onRefresh: () => ref.read(notificationsProvider.notifier).fetch(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, i) =>
                        _NotificationTile(item: state.items[i]),
                  ),
                ),
    );
  }

  Future<void> _markAllRead(WidgetRef ref, List<NotificationItem> items) async {
    for (final item in items.where((n) => !n.isRead)) {
      await ref.read(notificationsProvider.notifier).markRead(item.id);
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationItem item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (!item.isRead) {
          ref.read(notificationsProvider.notifier).markRead(item.id);
        }
        if (item.link != null) {
          _openLink(context, item.link!);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isRead ? Colors.transparent : AppTheme.primary,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.4),
                  ),
                  if (item.imageUrl != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 160,
                          color: Colors.white10,
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (item.link != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openLink(context, item.link!),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new,
                              size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            _shortUrl(item.link!),
                            style: const TextStyle(
                                color: AppTheme.primary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (diff.inHours < 24) return '${diff.inHours}ц';
    if (diff.inDays < 7) return '${diff.inDays}өд';
    return DateFormat('MM/dd').format(dt);
  }

  String _shortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 20 ? '${uri.path.substring(0, 20)}…' : uri.path);
    } catch (_) {
      return url.length > 40 ? '${url.substring(0, 40)}…' : url;
    }
  }

  void _openLink(BuildContext context, String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 64, color: Colors.white24),
            SizedBox(height: 12),
            Text('Мэдэгдэл байхгүй байна',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
}
