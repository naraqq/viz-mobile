import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'drama_api.dart';
import 'drama_models.dart';
import 'drama_player_screen.dart';
import 'widgets/drama_widgets.dart';

class DramaDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const DramaDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<DramaDetailScreen> createState() => _DramaDetailScreenState();
}

class _DramaDetailScreenState extends ConsumerState<DramaDetailScreen> {
  bool? _saved;
  bool? _liked;
  int? _likes;
  bool _expanded = false;
  int _range = 0;
  static const _chunk = 30;

  Future<void> _watch(DramaDetail d, DramaEpisode ep) async {
    await context.push('/drama/${d.drama.slug}/watch?ep=${ep.id}');
    // Progress and unlocks may have changed while watching.
    if (mounted) ref.invalidate(dramaDetailProvider(widget.slug));
  }

  Future<void> _toggleSave(DramaDetail d) async {
    HapticFeedback.lightImpact();
    setState(() => _saved = !(_saved ?? d.saved));
    try {
      final s = await ref.read(dramaApiProvider).toggleSave(d.drama.id);
      if (mounted) setState(() => _saved = s);
    } catch (_) {}
  }

  Future<void> _toggleLike(DramaDetail d) async {
    HapticFeedback.lightImpact();
    final now = !(_liked ?? d.liked);
    setState(() {
      _liked = now;
      _likes = (_likes ?? d.likes) + (now ? 1 : -1);
    });
    try {
      final r = await ref.read(dramaApiProvider).toggleLike(d.drama.id);
      if (mounted) {
        setState(() {
          _liked = r.liked;
          _likes = r.likes;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dramaDetailProvider(widget.slug));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DramaColors.bg,
        body: async.when(
          loading: () => const _DetailSkeleton(),
          error: (e, _) => SafeArea(
            child: Stack(
              children: [
                ErrorRetry(
                  message: '$e',
                  onRetry: () =>
                      ref.invalidate(dramaDetailProvider(widget.slug)),
                ),
                const BackButton(color: Colors.white),
              ],
            ),
          ),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(DramaDetail d) {
    final pad = MediaQuery.of(context).padding;
    final eps = d.episodes;
    final resume = d.resumeEpisode;
    final resumed = resume != null && d.progress.containsKey(resume.id);
    final saved = _saved ?? d.saved;
    final liked = _liked ?? d.liked;
    final likes = _likes ?? d.likes;
    final ranges = (eps.length / _chunk).ceil();
    final start = _range * _chunk;
    final slice = eps.isEmpty
        ? <DramaEpisode>[]
        : eps.sublist(start, (start + _chunk).clamp(0, eps.length));
    final freeCount = d.access.isVip
        ? eps.length
        : eps.where((e) => !e.isLocked).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              // Blurred poster as the backdrop
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.transparent],
                    stops: [0.45, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Opacity(
                      opacity: 0.55,
                      child: DramaImage(d.drama.posterUrl),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, pad.top + 52, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 124,
                        child: AspectRatio(
                          aspectRatio: DramaPoster.ratio,
                          child: DramaImage(d.drama.posterUrl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.drama.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              '${eps.length} анги',
                              if (d.access.isVip)
                                'VIP: бүгд нээлттэй'
                              else if (freeCount > 0)
                                '$freeCount анги үнэгүй',
                            ].join('  ·  '),
                            style: const TextStyle(
                              color: DramaColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          if (d.drama.genres.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final g in d.drama.genres.take(4))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      g,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: pad.top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ),

        // Play + actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: GradientPill(
                    icon: Icons.play_arrow_rounded,
                    label: resume == null
                        ? 'Анги алга'
                        : resumed
                        ? '${resume.number}-р анги үзэх'
                        : 'Үзэх',
                    onTap: resume == null ? null : () => _watch(d, resume),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundAction(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? DramaColors.gold : Colors.white,
                  onTap: () => _toggleSave(d),
                ),
                const SizedBox(width: 8),
                _RoundAction(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? DramaColors.accent : Colors.white,
                  badge: likes > 0 ? '$likes' : null,
                  onTap: () => _toggleLike(d),
                ),
              ],
            ),
          ),
        ),

        if ((d.drama.overview ?? '').isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: Text(
                    d.drama.overview!,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCFCDD8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Ангиуд',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${eps.length}',
                  style: const TextStyle(
                    color: DramaColors.muted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (ranges > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ranges,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, r) {
                  final a = r * _chunk + 1;
                  final b = ((r + 1) * _chunk).clamp(0, eps.length);
                  final sel = r == _range;
                  return ChoiceChip(
                    label: Text('$a-$b'),
                    selected: sel,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _range = r),
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : DramaColors.muted,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    backgroundColor: DramaColors.surface,
                    selectedColor: DramaColors.surface2,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  );
                },
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, pad.bottom + 24),
          sliver: SliverToBoxAdapter(
            child: EpisodeGrid(
              episodes: slice,
              offset: start,
              current: resumed ? eps.indexOf(resume) : -1,
              scrollable: false,
              onPick: (i) => _watch(d, eps[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.surface,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            if (badge != null)
              Positioned(
                bottom: 5,
                child: Text(
                  badge!,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 52, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 124, height: 174, radius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 22),
                    SizedBox(height: 10),
                    SkeletonBox(width: 120, height: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBox(height: 48, radius: 24),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: List.generate(15, (_) => const SkeletonBox(radius: 8)),
          ),
        ],
      ),
    );
  }
}
