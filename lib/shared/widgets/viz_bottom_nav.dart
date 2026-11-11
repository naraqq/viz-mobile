import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/drama/widgets/coin_store.dart';
import '../../features/drama/widgets/continue_bar.dart';

/// Flat tab bar on solid black: outline icons with labels; the active tab turns white.
/// VIP keeps its gold coin icon so the "earn / buy" entry stands out.
class VizBottomNav extends StatelessWidget {
  final Widget child;

  const VizBottomNav({super.key, required this.child});

  static const _tabs = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Нүүр',
      path: '/',
    ),
    (
      icon: Icons.smart_display_outlined,
      activeIcon: Icons.smart_display_rounded,
      label: 'Shorts',
      path: '/reels',
    ),
    (
      icon: Icons.bookmarks_outlined,
      activeIcon: Icons.bookmarks_rounded,
      label: 'Жагсаалт',
      path: '/my-list',
    ),
    (
      icon: Icons.diamond_outlined,
      activeIcon: Icons.diamond_rounded,
      label: 'VIP',
      path: '/vip',
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Профайл',
      path: '/profile',
    ),
  ];

  /// Height of the bar itself (without the safe area).
  static const barHeight = 50.0;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/reels')) return 1;
    if (location.startsWith('/my-list')) return 2;
    if (location.startsWith('/vip')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: child,
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Continue" bar docked on the tab bar — not on Shorts, which is all video.
            if (index != 1) const ContinueBar(),
            SizedBox(
              height: barHeight,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  return _NavItem(
                    icon: i == index ? tab.activeIcon : tab.icon,
                    label: tab.label,
                    isSelected: i == index,
                    coin: tab.path == '/vip',
                    onTap: () {
                      if (i == index) return;
                      HapticFeedback.selectionClick();
                      context.go(tab.path);
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool coin;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.coin,
    required this.onTap,
  });

  static const _inactive = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : _inactive;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: Center(
                child: coin
                    ? AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: isSelected ? 1.1 : 1,
                        child: const CoinIcon(size: 21),
                      )
                    : Icon(icon, size: 23, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
