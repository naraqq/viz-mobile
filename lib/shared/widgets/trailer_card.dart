import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

String? normalizeTrailerKey(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) {
    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) return videoId;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex >= 0 && uri.pathSegments.length > embedIndex + 1) {
      return uri.pathSegments[embedIndex + 1];
    }
  }

  return raw;
}

class TrailerCard extends StatelessWidget {
  final String title;
  final String trailerKey;

  const TrailerCard({super.key, required this.title, required this.trailerKey});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: 'https://img.youtube.com/vi/$trailerKey/hqdefault.jpg',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.white10),
              errorWidget: (_, __, ___) => Container(
                color: Colors.white10,
                child: const Icon(
                  Icons.ondemand_video_outlined,
                  color: AppTheme.textSecondary,
                  size: 42,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Трейлер · $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
