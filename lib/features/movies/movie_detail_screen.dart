import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog_item.dart';
import '../../core/models/episode.dart';
import '../../core/models/movie.dart';
import '../../core/models/season.dart';
import '../../core/providers/movie_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../payment/qpay_sheet.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/trailer_card.dart';

class MovieDetailScreen extends ConsumerWidget {
  final String slug;

  const MovieDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(movieDetailProvider(slug));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: detailAsync.when(
        loading: () => const _DetailLoading(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
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
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(movieDetailProvider(slug)),
                  child: const Text('Дахин оролдох'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) {
          final movie = detail.movie;
          final hasActiveSubscription =
              ref.watch(authProvider).user?.hasActiveSubscription == true;
          final canPlay =
              detail.canWatch ||
              detail.hasRental ||
              movie.isFree ||
              hasActiveSubscription;
          final series = detail.series;
          final featuredEpisode = series != null
              ? _findResumeEpisode(series.seasons, detail.episodeProgress) ??
                    _findFirstReadyEpisode(series.seasons)
              : null;
          final featuredSeason = featuredEpisode != null && series != null
              ? _seasonForEpisode(series.seasons, featuredEpisode)
              : null;
          final trailerKey = normalizeTrailerKey(movie.trailerKey);

          return CustomScrollView(
            slivers: [
              // Backdrop + app bar
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
                      if (movie.backdropUrl != null)
                        CachedNetworkImage(
                          imageUrl: movie.backdropUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => movie.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: movie.posterUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: AppTheme.surface),
                                )
                              : Container(color: AppTheme.surface),
                        )
                      else if (movie.posterUrl != null)
                        CachedNetworkImage(
                          imageUrl: movie.posterUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: AppTheme.surface),
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
                    // Title
                    Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Meta row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (movie.year != null) ...[
                          Text(
                            movie.year!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (movie.runtimeFormatted.isNotEmpty) ...[
                          Text(
                            movie.runtimeFormatted,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (movie.voteAverage != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                movie.voteAverage!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Genres
                    if (movie.genres.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: movie.genres
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

                    const SizedBox(height: 20),

                    // Action buttons
                    if (movie.isSeries &&
                        canPlay &&
                        featuredEpisode != null &&
                        featuredEpisode.streamVideo?.isReady == true &&
                        featuredSeason != null)
                      ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/player',
                          extra: {
                            'hlsUrl': featuredEpisode.streamVideo!.hlsUrl ?? '',
                            'title':
                                '${movie.title} · S${featuredSeason.seasonNumber}E${featuredEpisode.episodeNumber}',
                            'seriesTitle': movie.title,
                            'watchableType': 'episode',
                            'watchableId': featuredEpisode.id,
                            'currentEpisodeId': featuredEpisode.id,
                            'currentSeasonNumber': featuredSeason.seasonNumber,
                            'startPosition':
                                detail.episodeProgress[featuredEpisode.id] ?? 0,
                            'subtitleTracks':
                                featuredEpisode.streamVideo!.subtitleTracks,
                            'seasons': series!.seasons,
                            'episodeProgress': detail.episodeProgress,
                          },
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          (detail.episodeProgress[featuredEpisode.id] ?? 0) > 0
                              ? 'Үргэлжлүүлэн үзэх'
                              : 'Үзэх',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    else if (canPlay && movie.streamVideo?.isReady == true)
                      ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/player',
                          extra: {
                            'hlsUrl': movie.streamVideo!.hlsUrl ?? '',
                            'title': movie.title,
                            'watchableType': 'movie',
                            'watchableId': movie.id,
                            'startPosition': detail.movieProgress ?? 0,
                            'subtitleTracks': movie.streamVideo!.subtitleTracks,
                          },
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          detail.movieProgress != null &&
                                  detail.movieProgress! > 0
                              ? 'Үргэлжлүүлэн үзэх'
                              : 'Үзэх',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    else if (!canPlay) ...[
                      if (movie.isRental)
                        OutlinedButton.icon(
                          onPressed: (movie.rentalPrice ?? 0) > 0
                              ? () => _startMovieRental(
                                  context: context,
                                  ref: ref,
                                  movie: movie,
                                  slug: slug,
                                )
                              : null,
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            (movie.rentalPrice ?? 0) > 0
                                ? '${_formatMnt(movie.rentalPrice!)}-өөр ${_rentalDurationLabel(movie.rentalDurationHours)} түрээслэх'
                                : 'Түрээсийн үнэ тохируулагдаагүй',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => context.push('/plans'),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Үзэхийн тулд багц авах'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                    ],

                    if (detail.hasRental && detail.rentalExpiresAt != null) ...[
                      const SizedBox(height: 10),
                      _RentalStatus(expiresAt: detail.rentalExpiresAt!),
                    ],

                    if (trailerKey != null) ...[
                      const SizedBox(height: 12),
                      TrailerCard(title: movie.title, trailerKey: trailerKey),
                    ],

                    const SizedBox(height: 20),

                    // Overview
                    if (movie.overview != null) ...[
                      Text(
                        movie.overviewMn ?? movie.overview!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Related
                    if (detail.related.isNotEmpty) ...[
                      const Text(
                        'Төстэй үзвэрүүд',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: detail.related.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => ContentCard(
                            item: CatalogItem(
                              id: detail.related[i].id,
                              title: detail.related[i].title,
                              slug: detail.related[i].slug,
                              posterUrl: detail.related[i].posterUrl,
                              backdropUrl: detail.related[i].backdropUrl,
                              contentType: 'movie',
                              genres: detail.related[i].genres,
                              accessModel: detail.related[i].accessModel,
                            ),
                            width: 120,
                          ),
                        ),
                      ),
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

Episode? _findResumeEpisode(
  List<Season> seasons,
  Map<int, int> episodeProgress,
) {
  for (final season in seasons) {
    for (final episode in season.episodes) {
      final progress = episodeProgress[episode.id] ?? 0;
      if (progress > 0 && episode.streamVideo?.isReady == true) {
        return episode;
      }
    }
  }
  return null;
}

Episode? _findFirstReadyEpisode(List<Season> seasons) {
  for (final season in seasons) {
    for (final episode in season.episodes) {
      if (episode.streamVideo?.isReady == true) return episode;
    }
  }
  return null;
}

Season? _seasonForEpisode(List<Season> seasons, Episode episode) {
  for (final season in seasons) {
    if (season.episodes.any((ep) => ep.id == episode.id)) return season;
  }
  return null;
}

Future<void> _startMovieRental({
  required BuildContext context,
  required WidgetRef ref,
  required Movie movie,
  required String slug,
}) async {
  final rentalPrice = movie.rentalPrice;
  if (rentalPrice == null || rentalPrice <= 0) return;

  final rentalDurationHours = movie.rentalDurationHours ?? 72;
  await QPaySheet.show(
    context: context,
    amount: rentalPrice,
    description:
        '${movie.title} · ${_rentalDurationLabel(rentalDurationHours)} түрээс',
    invoiceType: 'rental',
    rentableType: 'movie',
    rentableId: movie.id,
    rentalDurationHours: rentalDurationHours,
    onSuccess: () {
      ref.invalidate(movieDetailProvider(slug));
      ref.read(authProvider.notifier).refreshUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Кино түрээс амжилттай идэвхжлээ.'),
          backgroundColor: Colors.green,
        ),
      );
    },
  );
}

String _formatMnt(double amount) {
  final value = amount.toStringAsFixed(0);
  final formatted = value.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₮$formatted';
}

String _rentalDurationLabel(int? hours) {
  final normalized = hours == null || hours <= 0 ? 72 : hours;
  if (normalized % 24 == 0) {
    return '${normalized ~/ 24} хоног';
  }
  return '$normalized цаг';
}

String _formatRentalExpiry(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}-р сарын ${local.day} ${local.hour}:$minute хүртэл';
}

class _RentalStatus extends StatelessWidget {
  final DateTime expiresAt;

  const _RentalStatus({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Түрээс хүчинтэй: ${_formatRentalExpiry(expiresAt)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
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
              ShimmerBox(width: 140, height: 16),
              SizedBox(height: 20),
              ShimmerBox(width: double.infinity, height: 48),
              SizedBox(height: 20),
              ShimmerBox(width: double.infinity, height: 80),
            ],
          ),
        ),
      ],
    );
  }
}
