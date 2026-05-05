import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/catalog_item.dart';
import '../models/json_helpers.dart';
import '../models/movie.dart';
import '../models/show.dart';
import 'auth_provider.dart';

class MovieDetailData {
  final Movie movie;
  final Show? series;
  final List<CatalogItem> related;
  final bool canWatch;
  final bool hasRental;
  final DateTime? rentalExpiresAt;
  final int? movieProgress;
  final Map<int, int> episodeProgress;

  const MovieDetailData({
    required this.movie,
    this.series,
    this.related = const [],
    this.canWatch = false,
    this.hasRental = false,
    this.rentalExpiresAt,
    this.movieProgress,
    this.episodeProgress = const {},
  });
}

final movieDetailProvider = FutureProvider.family<MovieDetailData, String>((
  ref,
  slug,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(
    ApiEndpoints.movieDetail(slug),
  );
  final data = res.data!;
  final episodeProgress = <int, int>{};
  final rawProgress = data['episode_progress'];
  if (rawProgress is Map) {
    rawProgress.forEach((k, v) {
      final episodeId = readInt(k);
      final position = readInt(v);
      if (episodeId != null && position != null) {
        episodeProgress[episodeId] = position;
      }
    });
  }

  return MovieDetailData(
    movie: Movie.fromJson(data['movie'] as Map<String, dynamic>),
    series: data['series'] != null
        ? Show.fromJson(data['series'] as Map<String, dynamic>)
        : null,
    related: (data['related'] as List<dynamic>? ?? [])
        .map((m) => CatalogItem.fromJson(m as Map<String, dynamic>))
        .toList(),
    canWatch: readBool(data['can_watch']),
    hasRental: readBool(data['has_rental']),
    rentalExpiresAt: data['rental_expires_at'] != null
        ? DateTime.tryParse(data['rental_expires_at'].toString())
        : null,
    movieProgress: readInt(data['movie_progress']),
    episodeProgress: episodeProgress,
  );
});
