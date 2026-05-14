import 'genre.dart';
import 'json_helpers.dart';
import 'season.dart';

class Show {
  final int id;
  final String title;
  final String? originalTitle;
  final String slug;
  final String? overview;
  final String? overviewMn;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerKey;
  final DateTime? firstAirDate;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final double? voteAverage;
  final bool isFeatured;
  final bool reviewFriendly;
  final List<Genre> genres;
  final List<Season> seasons;

  const Show({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.slug,
    this.overview,
    this.overviewMn,
    this.posterUrl,
    this.backdropUrl,
    this.trailerKey,
    this.firstAirDate,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.voteAverage,
    this.isFeatured = false,
    this.reviewFriendly = false,
    this.genres = const [],
    this.seasons = const [],
  });

  String? get year => firstAirDate?.year.toString();

  factory Show.fromJson(Map<String, dynamic> json) => Show(
    id: readInt(json['id']) ?? 0,
    title: json['title'] as String,
    originalTitle: json['original_title'] as String?,
    slug: json['slug'] as String,
    overview: json['overview'] as String?,
    overviewMn: json['overview_mn'] as String?,
    posterUrl: json['poster_url'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    trailerKey: json['trailer_key'] as String?,
    firstAirDate: json['first_air_date'] != null
        ? DateTime.tryParse(json['first_air_date'] as String)
        : null,
    numberOfSeasons: readInt(json['number_of_seasons']),
    numberOfEpisodes: readInt(json['number_of_episodes']),
    voteAverage: readDouble(json['vote_average']),
    isFeatured: readBool(json['is_featured']),
    reviewFriendly: readBool(json['review_friendly']),
    genres: (json['genres'] as List<dynamic>? ?? [])
        .map((g) => Genre.fromJson(g as Map<String, dynamic>))
        .toList(),
    seasons: (json['seasons'] as List<dynamic>? ?? [])
        .map((s) => Season.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
