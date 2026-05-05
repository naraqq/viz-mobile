import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class VizBottomNav extends StatelessWidget {
  final Widget child;

  const VizBottomNav({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Нүүр', path: '/'),
    (icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Хайх', path: '/browse'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Профайл', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/browse')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
          ),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF0A0A0A),
          indicatorColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: (i) {
            context.go(_tabs[i].path);
          },
          destinations: _tabs.map((tab) {
            final isSelected = _tabs.indexOf(tab) == index;
            return NavigationDestination(
              icon: Icon(tab.icon,
                  color: isSelected ? Colors.white : const Color(0xFF808080)),
              selectedIcon: Icon(tab.activeIcon, color: Colors.white),
              label: tab.label,
            );
          }).toList(),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
        ),
      ),
    );
  }
}
