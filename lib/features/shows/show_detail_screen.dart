import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/episode.dart';
import '../../core/models/season.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/show_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/trailer_card.dart';

class ShowDetailScreen extends ConsumerStatefulWidget {
  final String slug;

  const ShowDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  int _selectedSeasonIndex = 0;

  bool _hasReadyVideo(Episode episode) =>
      episode.isReleased && episode.streamVideo?.isReady == true;

  Episode? _findResumeEpisode(ShowDetailData detail) {
    for (final season in detail.show.seasons) {
      for (final episode in season.episodes) {
        final progress = detail.episodeProgress[episode.id];
        if (progress != null && progress > 0 && _hasReadyVideo(episode)) {
          return episode;
        }
      }
    }
    return null;
  }

  Episode? _findFirstReadyEpisode(List<Episode> episodes) {
    for (final episode in episodes) {
      if (_hasReadyVideo(episode)) return episode;
    }
    return null;
  }

  void _openEpisode(
    BuildContext context,
    ShowDetailData detail,
    String showTitle,
    int seasonNumber,
    Episode episode,
  ) {
    if (!_hasReadyVideo(episode)) return;

    context.push(
      '/player',
      extra: {
        'hlsUrl': episode.streamVideo!.hlsUrl ?? '',
        'title': '$showTitle · S${seasonNumber}E${episode.episodeNumber}',
        'seriesTitle': showTitle,
        'watchableType': 'episode',
        'watchableId': episode.id,
        'currentEpisodeId': episode.id,
        'currentSeasonNumber': seasonNumber,
        'startPosition': detail.episodeProgress[episode.id] ?? 0,
        'subtitleTracks': episode.streamVideo!.subtitleTracks,
        'seasons': detail.show.seasons,
        'episodeProgress': detail.episodeProgress,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(showDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: detailAsync.when(
        loading: () => const _DetailLoading(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Дэлгэрэнгүй мэдээлэл ачаалж чадсангүй',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(showDetailProvider(widget.slug)),
                    child: const Text('Дахин оролдох'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (detail) {
          final show = detail.show;
          final canWatch =
              detail.canWatch ||
              (ref.watch(authProvider).user?.hasActiveSubscription == true);
          final seasons = show.seasons;
          final currentSeason = seasons.isNotEmpty
              ? seasons[_selectedSeasonIndex
                    .clamp(0, seasons.length - 1)
                    .toInt()]
              : null;
          final featuredEpisode =
              _findResumeEpisode(detail) ??
              _findFirstReadyEpisode(currentSeason?.episodes ?? const []);
          final featuredSeason = featuredEpisode != null
              ? seasons.firstWhere(
                  (season) => season.episodes.contains(featuredEpisode),
                  orElse: () => currentSeason ?? seasons.first,
                )
              : currentSeason;
          final overview = show.overviewMn ?? show.overview;
          final heroImage = show.backdropUrl ?? show.posterUrl;
          final trailerKey = normalizeTrailerKey(show.trailerKey);

          return CustomScrollView(
            slivers: [
              // Backdrop app bar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppTheme.background,
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (heroImage != null)
                        CachedNetworkImage(
                          imageUrl: heroImage,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(color: AppTheme.surface),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppTheme.background],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      show.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ShowMetaLine(
                      year: show.year,
                      numberOfSeasons: show.numberOfSeasons,
                      voteAverage: show.voteAverage,
                    ),

                    if (show.genres.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: show.genres
                            .map(
                              (g) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  g.name,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _PrimaryWatchButton(
                      canWatch: canWatch,
                      episode: featuredEpisode,
                      progress: featuredEpisode != null
                          ? detail.episodeProgress[featuredEpisode.id]
                          : null,
                      onPressed: () {
                        if (!canWatch) {
                          context.push('/plans');
                          return;
                        }
                        if (featuredEpisode != null && featuredSeason != null) {
                          _openEpisode(
                            context,
                            detail,
                            show.title,
                            featuredSeason.seasonNumber,
                            featuredEpisode,
                          );
                        }
                      },
                    ),

                    if (featuredEpisode != null &&
                        detail.episodeProgress[featuredEpisode.id] != null) ...[
                      const SizedBox(height: 14),
                      _ContinueStatus(
                        episode: featuredEpisode,
                        seasonNumber: featuredSeason?.seasonNumber,
                        progress: detail.episodeProgress[featuredEpisode.id]!,
                      ),
                    ],

                    if (trailerKey != null) ...[
                      const SizedBox(height: 14),
                      TrailerCard(title: show.title, trailerKey: trailerKey),
                    ],

                    if (overview != null && overview.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        overview,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],

                    if (seasons.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionTab(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _SeasonDropdown(
                            selectedIndex: _selectedSeasonIndex,
                            seasons: seasons,
                            onChanged: (index) =>
                                setState(() => _selectedSeasonIndex = index),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Мэдээлэл',
                            onPressed: null,
                            icon: const Icon(
                              Icons.info_outline,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (currentSeason != null) ...[
                        ...currentSeason.episodes.map(
                          (ep) => _EpisodeTile(
                            episode: ep,
                            progress: detail.episodeProgress[ep.id],
                            canWatch: canWatch,
                            onTap: () {
                              if (!canWatch) {
                                context.push('/plans');
                                return;
                              }
                              _openEpisode(
                                context,
                                detail,
                                show.title,
                                currentSeason.seasonNumber,
                                ep,
                              );
                            },
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDuration(int? seconds, int? fallbackMinutes) {
  if (seconds != null && seconds > 0) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours > 0 && rest > 0) return '$hours цаг $rest мин';
    if (hours > 0) return '$hours цаг';
    return '$minutes мин';
  }
  if (fallbackMinutes != null && fallbackMinutes > 0) {
    return '$fallbackMinutes мин';
  }
  return '';
}

String? _remainingText(Episode episode, int? progress) {
  final duration = episode.streamVideo?.durationSeconds;
  if (duration == null || duration <= 0 || progress == null || progress <= 0) {
    return null;
  }
  final remaining = duration - progress;
  if (remaining <= 0) return null;
  return '${_formatDuration(remaining, null)} үлдсэн';
}

double? _progressValue(Episode episode, int? progress) {
  final duration = episode.streamVideo?.durationSeconds;
  if (duration == null || duration <= 0 || progress == null || progress <= 0) {
    return null;
  }
  final value = progress / duration;
  return value.clamp(0.0, 1.0).toDouble();
}

class _ShowMetaLine extends StatelessWidget {
  final String? year;
  final int? numberOfSeasons;
  final double? voteAverage;

  const _ShowMetaLine({
    required this.year,
    required this.numberOfSeasons,
    required this.voteAverage,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (year != null) items.add(Text(year!, style: _metaStyle));
    if (numberOfSeasons != null) {
      items.add(Text('$numberOfSeasons бүлэг', style: _metaStyle));
    }
    if (voteAverage != null) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const SizedBox(width: 4),
            Text(voteAverage!.toStringAsFixed(1), style: _metaStyle),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }

  static const _metaStyle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}

class _PrimaryWatchButton extends StatelessWidget {
  final bool canWatch;
  final Episode? episode;
  final int? progress;
  final VoidCallback onPressed;

  const _PrimaryWatchButton({
    required this.canWatch,
    required this.episode,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgress = progress != null && progress! > 0;
    final canPlay = canWatch && episode != null;
    final label = !canWatch
        ? 'Үзэхийн тулд багц авах'
        : hasProgress
        ? 'Үргэлжлүүлэх'
        : 'Тоглуулах';

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canPlay || !canWatch ? onPressed : null,
        icon: Icon(!canWatch ? Icons.lock_outline : Icons.play_arrow),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppTheme.surface,
          disabledForegroundColor: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ContinueStatus extends StatelessWidget {
  final Episode episode;
  final int? seasonNumber;
  final int progress;

  const _ContinueStatus({
    required this.episode,
    required this.seasonNumber,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final progressValue = _progressValue(episode, progress);
    final remaining = _remainingText(episode, progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'S${seasonNumber ?? episode.seasonNumber ?? '?'}:E${episode.episodeNumber} ${episode.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (progressValue != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.white24,
                  color: AppTheme.primary,
                  minHeight: 3,
                ),
              ),
              if (remaining != null) ...[
                const SizedBox(width: 10),
                Text(
                  remaining,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SeasonDropdown extends StatelessWidget {
  final int selectedIndex;
  final List<Season> seasons;
  final ValueChanged<int> onChanged;

  const _SeasonDropdown({
    required this.selectedIndex,
    required this.seasons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final clampedIndex = selectedIndex.clamp(0, seasons.length - 1).toInt();

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: clampedIndex,
          dropdownColor: AppTheme.surface,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (var i = 0; i < seasons.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text('${seasons[i].seasonNumber}-р бүлэг'),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Divider(color: AppTheme.primary, height: 1, thickness: 3),
        ),
        SizedBox(height: 8),
        Text(
          'Ангиуд',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final int? progress;
  final bool canWatch;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    this.progress,
    required this.canWatch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = episode.streamVideo?.isReady == true;
    final released = episode.isReleased;
    final description = episode.overviewMn ?? episode.overview;
    final progressValue = _progressValue(episode, progress);
    final remaining = _remainingText(episode, progress);
    final duration = _formatDuration(
      episode.streamVideo?.durationSeconds,
      episode.runtime,
    );

    return GestureDetector(
      onTap: (released && hasVideo) || !canWatch ? onTap : null,
      child: Container(
        foregroundDecoration: released
            ? null
            : BoxDecoration(color: Colors.black.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 118,
                        height: 66,
                        child: episode.stillUrl != null
                            ? CachedNetworkImage(
                                imageUrl: episode.stillUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppTheme.surface,
                                  child: const Icon(
                                    Icons.movie_outlined,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppTheme.surface,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white70),
                            ),
                            child: Icon(
                              !released
                                  ? Icons.schedule
                                  : canWatch && hasVideo
                                  ? Icons.play_arrow
                                  : Icons.lock_outline,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                      if (progressValue != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.white24,
                            color: AppTheme.primary,
                            minHeight: 3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${episode.episodeNumber}. ${episode.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!released && episode.availableLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.availableLabel!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (duration.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          duration,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (remaining != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          remaining,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (released && description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (released && !hasVideo && canWatch) ...[
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 130, right: 8),
                child: Text(
                  'Тоглуулах файл бэлэн биш байна',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(
          width: double.infinity,
          height: 280,
          borderRadius: BorderRadius.zero,
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 220, height: 28),
              SizedBox(height: 12),
              ShimmerBox(width: 160, height: 16),
              SizedBox(height: 20),
              ShimmerBox(width: double.infinity, height: 80),
            ],
          ),
        ),
      ],
    );
  }
}
