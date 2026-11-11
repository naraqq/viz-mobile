import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../shared/widgets/lemony_logo.dart';
import '../drama_models.dart';

/// Palette for the drama screens: near-black surfaces, soft greys, Lemony gradient accents.
class DramaColors {
  static const bg = Color(0xFF0B0A0F);
  static const surface = Color(0xFF17161C);
  static const surface2 = Color(0xFF22212A);
  static const muted = Color(0xFF9A98A6);
  static const faint = Color(0xFF5E5C69);
  static const accent = LemonyBrand.rose;
  static const gold = Color(0xFFF5B83D);
}

/// Image with a quiet placeholder and no flash on load.
class DramaImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  const DramaImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: DramaColors.surface2,
    );
    if (url == null || url!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// Vertical poster card: rounded poster, "N анги" badge, title (2 lines) and genre.
class DramaPoster extends StatelessWidget {
  final DramaCard drama;
  final double width;
  final bool showMeta;
  final Widget? overlay;
  final VoidCallback? onTap;

  /// Free badge and episode count on the poster (off for e.g. Continue Watching).
  final bool showBadges;

  /// Replaces the genre line under the title.
  final String? subtitle;
  const DramaPoster({
    super.key,
    required this.drama,
    this.width = 116,
    this.showMeta = true,
    this.overlay,
    this.onTap,
    this.showBadges = true,
    this.subtitle,
  });

  static const ratio = 3 / 4.2;

  static const _titleSize = 13.0;
  static const _subSize = 11.0;

  /// Height of the title + subtitle block, so horizontal rows can size themselves exactly
  /// (honours the system font size).
  static double metaHeight(BuildContext context) {
    final t = MediaQuery.textScalerOf(context);
    return 7 + t.scale(_titleSize) * 1.25 * 2 + 3 + t.scale(_subSize) * 1.4 + 2;
  }

  /// Full height of a poster card of [width] with its meta block.
  static double cardHeight(BuildContext context, double width) =>
      width / ratio + metaHeight(context);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/drama/${drama.slug}/watch'),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: ratio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DramaImage(drama.posterUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                        ),
                      ),
                    ),
                    if (showBadges && drama.isFree)
                      const Positioned(
                        top: 6,
                        left: 6,
                        child: _Chip('Үнэгүй', gradient: true),
                      ),
                    if (showBadges && drama.episodes > 0)
                      Positioned(
                        left: 7,
                        bottom: 6,
                        child: Text(
                          '${drama.episodes} анги',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ?overlay,
                  ],
                ),
              ),
            ),
            if (showMeta)
              SizedBox(
                height: metaHeight(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 7),
                    Text(
                      drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _titleSize,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty ||
                        drama.genres.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle ?? drama.genres.take(2).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DramaColors.muted,
                          fontSize: _subSize,
                          height: 1.3,
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
}

class _Chip extends StatelessWidget {
  final String text;
  final bool gradient;
  const _Chip(this.text, {this.gradient = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
    decoration: BoxDecoration(
      gradient: gradient ? LemonyBrand.gradient : null,
      color: gradient ? null : Colors.black54,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.onMore});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            style: TextButton.styleFrom(foregroundColor: DramaColors.muted),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Бүгд', style: TextStyle(fontSize: 13)),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Grey shimmer blocks while content loads.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height, this.radius = 10});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: DramaColors.surface,
    highlightColor: DramaColors.surface2,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DramaColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: DramaColors.faint,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DramaColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: DramaColors.faint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Дахин оролдох'),
          ),
        ],
      ),
    ),
  );
}

/// Pill button with the Lemony gradient.
class GradientPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  const GradientPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 48,
  });
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.5 : 1,
    child: Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          gradient: LemonyBrand.gradient,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Poster with a play button and a thin progress line; "N-р анги / total" underneath.
class ContinuePoster extends StatelessWidget {
  final ContinueItem item;
  const ContinuePoster({super.key, required this.item});

  static const width = 108.0;

  @override
  Widget build(BuildContext context) {
    final total = item.drama.episodes;
    return DramaPoster(
      drama: item.drama,
      width: width,
      showBadges: false,
      subtitle: total > 0
          ? '${item.episodeNumber}-р анги / $total'
          : '${item.episodeNumber}-р анги',
      onTap: () => context.push(item.watchPath),
      overlay: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: (item.progress / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white24,
              color: DramaColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
