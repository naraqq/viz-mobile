import 'package:flutter/material.dart';
import '../../core/models/content_row.dart';
import '../../core/theme/app_theme.dart';
import 'content_card.dart';

class ContentRowWidget extends StatelessWidget {
  final ContentRow row;

  const ContentRowWidget({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            row.label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: row.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ContentCard(
              item: row.items[index],
              width: 120,
            ),
          ),
        ),
      ],
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final double progress;
  final VoidCallback onTap;

  const ContinueWatchingCard({
    super.key,
    this.thumbnailUrl,
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
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: thumbnailUrl != null
                        ? Image.network(
                            thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: AppTheme.primary,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
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
              color: AppTheme.textSecondary, size: 32),
        ),
      );
}
