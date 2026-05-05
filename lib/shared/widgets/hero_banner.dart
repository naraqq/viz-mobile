import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog_item.dart';
import '../../core/theme/app_theme.dart';

class HeroBanner extends StatefulWidget {
  final List<CatalogItem> items;

  const HeroBanner({super.key, required this.items});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    if (widget.items.length > 1) {
      _autoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted) return;
        final next = (_currentPage + 1) % widget.items.length;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final screenH = MediaQuery.of(context).size.height;
    final bannerH = (screenH * 0.62).clamp(440.0, 580.0);

    return SizedBox(
      height: bannerH,
      child: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _HeroPage(item: widget.items[i]),
          ),

          // Dots
          if (widget.items.length > 1)
            Positioned(
              bottom: 76,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  final CatalogItem item;
  const _HeroPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop
          if (item.backdropUrl != null)
            CachedNetworkImage(
              imageUrl: item.backdropUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
            )
          else if (item.posterUrl != null)
            CachedNetworkImage(
              imageUrl: item.posterUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(color: AppTheme.surface),

          // Gradient — sides + bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x44000000),
                  Colors.transparent,
                  Color(0xAA000000),
                  AppTheme.background,
                ],
                stops: [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),

          // Info + buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Genres
                  if (item.genres.isNotEmpty)
                    Text(
                      item.genres.take(3).map((g) => g.name).join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeroButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Үзэх',
                        filled: true,
                        onTap: () => _navigate(context),
                      ),
                      const SizedBox(width: 12),
                      _HeroButton(
                        icon: Icons.info_outline_rounded,
                        label: 'Дэлгэрэнгүй',
                        filled: false,
                        onTap: () => _navigate(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context) {
    if (item.isMovie) {
      context.push('/movies/${item.slug}');
    } else {
      context.push('/shows/${item.slug}');
    }
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: filled ? null : Border.all(color: Colors.white38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: filled ? Colors.black : Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
