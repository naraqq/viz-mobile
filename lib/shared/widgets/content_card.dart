import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog_item.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/theme/app_theme.dart';
import 'loading_shimmer.dart';

class ContentCard extends ConsumerWidget {
  final CatalogItem item;
  final double width;

  const ContentCard({
    super.key,
    required this.item,
    this.width = 110,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = item.posterUrl ?? item.backdropUrl;
    final reviewMode = ref.watch(reviewModeProvider);

    return GestureDetector(
      onTap: () => item.isMovie
          ? context.push('/movies/${item.slug}')
          : context.push('/shows/${item.slug}'),
      child: SizedBox(
        width: width,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final resolvedWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : width;
            final posterHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight.clamp(0.0, resolvedWidth * 1.5)
                : resolvedWidth * 1.5;

            return ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: resolvedWidth,
                height: posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => const ShimmerBox(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),

                    if (!reviewMode) ...[
                      if (item.accessModel == 'free')
                        Positioned(
                          top: 5,
                          left: 5,
                          child: _Badge(
                            label: 'ҮНЭГҮЙ',
                            color: Colors.green.shade700,
                          ),
                        )
                      else if (item.accessModel == 'rent')
                        Positioned(
                          top: 5,
                          left: 5,
                          child: _Badge(
                            label: 'ТҮРЭЭС',
                            color: Colors.orange.shade700,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.movie_outlined, color: AppTheme.textSecondary, size: 28),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Wide card for continue watching row ─────────────────────────────────────

class WideContentCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double progress;
  final VoidCallback onTap;

  const WideContentCard({
    super.key,
    this.imageUrl,
    required this.title,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  SizedBox(
                    width: 160,
                    height: 90, // 16:9
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ShimmerBox(),
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  // Play icon
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white60),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  // Progress bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      color: AppTheme.primary,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.play_circle_outline,
              color: AppTheme.textSecondary, size: 28),
        ),
      );
}
