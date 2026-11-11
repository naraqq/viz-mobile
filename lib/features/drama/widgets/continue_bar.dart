import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/lemony_logo.dart';
import '../drama_api.dart';
import '../drama_models.dart';
import 'drama_widgets.dart';

/// The item the viewer closed with ×; the bar stays hidden until something newer is watched.
final _dismissedProvider = StateProvider<String?>((ref) => null);

String _keyOf(ContinueItem i) => '${i.drama.id}:${i.episodeNumber}';

/// Slim "pick up where you left off" bar docked on top of the tab bar: poster, title,
/// episode and progress, one tap to resume exactly there. Fed by Home's continue-watching
/// data, which refreshes as soon as the viewer leaves the player.
class ContinueBar extends ConsumerWidget {
  const ContinueBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(dramaHomeProvider).valueOrNull ?? const [];
    final items = sections
        .where((s) => s.type == 'continue')
        .expand((s) => s.continueItems)
        .toList();
    final item = items.isEmpty ? null : items.first;
    final dismissed = ref.watch(_dismissedProvider);
    final show = item != null && _keyOf(item) != dismissed;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => SizeTransition(
        sizeFactor: a,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: show
          ? _Bar(
              key: ValueKey(_keyOf(item)),
              item: item,
              onClose: () {
                HapticFeedback.selectionClick();
                ref.read(_dismissedProvider.notifier).state = _keyOf(item);
              },
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Bar extends StatelessWidget {
  final ContinueItem item;
  final VoidCallback onClose;
  const _Bar({super.key, required this.item, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final total = item.drama.episodes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Material(
        color: const Color(0xFF1E1C24),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(item.watchPath);
          },
          child: SizedBox(
            height: 58,
            child: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 58,
                      child: DramaImage(item.drama.posterUrl),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.drama.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            total > 0
                                ? 'Үргэлжлүүлэх · ${item.episodeNumber}/$total анги'
                                : 'Үргэлжлүүлэх · ${item.episodeNumber}-р анги',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: DramaColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Resume
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LemonyBrand.gradient,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    // Hide
                    IconButton(
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: DramaColors.muted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Progress along the bottom edge
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: (item.progress / 100).clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: Colors.white10,
                    color: LemonyBrand.rose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
