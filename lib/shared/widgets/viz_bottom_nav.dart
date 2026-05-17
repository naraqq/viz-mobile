import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_theme.dart';

class VizBottomNav extends ConsumerWidget {
  final Widget child;

  const VizBottomNav({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Нүүр', path: '/'),
    (icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Хайх', path: '/browse'),
    (icon: Icons.notifications_none_outlined, activeIcon: Icons.notifications_rounded, label: 'Мэдэгдэл', path: '/notifications'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Профайл', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/browse')) return 1;
    if (location.startsWith('/notifications')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final unreadCount = ref.watch(notificationsProvider).unreadCount;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  return _NavItem(
                    icon: tab.icon,
                    activeIcon: tab.activeIcon,
                    label: tab.label,
                    isSelected: i == index,
                    badge: tab.path == '/notifications' ? unreadCount : 0,
                    onTap: () => context.go(tab.path),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWithBadge(
              icon: isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : const Color(0xFF5A5A5A),
              badge: badge,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badge;

  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 22),
        if (badge > 0)
          Positioned(
            top: -5,
            right: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
