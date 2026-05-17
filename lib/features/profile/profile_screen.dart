import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final reviewMode = ref.watch(reviewModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, user, ref, reviewMode),
          SliverToBoxAdapter(
            child: _buildBody(context, user, ref, reviewMode),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User user, WidgetRef ref, bool reviewMode) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A0000), Colors.black],
              stops: [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Avatar
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (!reviewMode) _SubscriptionBadge(user: user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, User user, WidgetRef ref, bool reviewMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subscription banner
          if (!reviewMode && user.hasActiveSubscription && user.subscriptionEndsAt != null) ...[
            const SizedBox(height: 16),
            _Banner(
              icon: Icons.calendar_today_rounded,
              text: '${_formatDate(user.subscriptionEndsAt!)} хүртэл идэвхтэй',
              color: Colors.green,
            ),
          ],
          if (!reviewMode && !user.hasActiveSubscription) ...[
            const SizedBox(height: 16),
            _Banner(
              icon: Icons.bolt_rounded,
              text: 'Бүх контент үзэхийн тулд багцаа сайжруулна уу',
              color: AppTheme.primary,
              onTap: () => context.push('/plans'),
            ),
          ],

          const SizedBox(height: 28),

          // Account card
          _SectionLabel('Бүртгэл'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _Tile(
                icon: Icons.person_outline_rounded,
                label: 'Профайл засах',
                onTap: () => context.push('/profile/edit'),
              ),
              if (!reviewMode) ...[
                _Divider(),
                _Tile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Захиалгын багцууд',
                  onTap: () => context.push('/plans'),
                ),
                _Divider(),
                _Tile(
                  icon: Icons.video_library_outlined,
                  label: 'Миний түрээс',
                  onTap: () => context.push('/profile/rentals'),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // App card
          _SectionLabel('Апп'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _Tile(
                icon: Icons.info_outline_rounded,
                label: 'Аппын тухай',
                onTap: () => context.push('/profile/about'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Sign out card
          _Card(
            children: [
              _Tile(
                icon: Icons.logout_rounded,
                label: 'Гарах',
                color: AppTheme.primary,
                showChevron: false,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Гарах',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Та бүртгэлээсээ гарахдаа итгэлтэй байна уу?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Болих', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Гарах',
              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ─── Subscription badge ────────────────────────────────────────────────────────

class _SubscriptionBadge extends StatelessWidget {
  final User user;
  const _SubscriptionBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.hasActiveSubscription) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 14),
            SizedBox(width: 6),
            Text(
              'Захиалагч',
              style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => context.push('/plans'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: AppTheme.textSecondary, size: 14),
            SizedBox(width: 4),
            Text(
              'Үнэгүй · Сайжруулах',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFF2A2A2A), indent: 52);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF555555), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _Banner({required this.icon, required this.text, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
