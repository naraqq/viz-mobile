import 'genre.dart';
import 'json_helpers.dart';
import 'stream_video.dart';

class Movie {
  final int id;
  final String title;
  final String? originalTitle;
  final String slug;
  final String? overview;
  final String? overviewMn;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerKey;
  final DateTime? releaseDate;
  final int? runtime;
  final double? voteAverage;
  final String type; // 'film' or 'series'
  final String accessModel; // 'free', 'sub', 'rent'
  final double? rentalPrice;
  final int? rentalDurationHours;
  final bool isFeatured;
  final bool reviewFriendly;
  final List<Genre> genres;
  final StreamVideo? streamVideo;

  const Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.slug,
    this.overview,
    this.overviewMn,
    this.posterUrl,
    this.backdropUrl,
    this.trailerKey,
    this.releaseDate,
    this.runtime,
    this.voteAverage,
    required this.type,
    required this.accessModel,
    this.rentalPrice,
    this.rentalDurationHours,
    this.isFeatured = false,
    this.reviewFriendly = false,
    this.genres = const [],
    this.streamVideo,
  });

  bool get isFilm => type == 'film';
  bool get isSeries => type == 'series';
  bool get isFree => accessModel == 'free';
  bool get requiresSub => accessModel == 'sub';
  bool get isRental => accessModel == 'rent';

  String? get year => releaseDate?.year.toString();

  String get runtimeFormatted {
    if (runtime == null) return '';
    final h = runtime! ~/ 60;
    final m = runtime! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
        id: readInt(json['id']) ?? 0,
        title: json['title'] as String,
        originalTitle: json['original_title'] as String?,
        slug: json['slug'] as String,
        overview: json['overview'] as String?,
        overviewMn: json['overview_mn'] as String?,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        trailerKey: json['trailer_key'] as String?,
        releaseDate: json['release_date'] != null
            ? DateTime.tryParse(json['release_date'] as String)
            : null,
        runtime: readInt(json['runtime']),
        voteAverage: readDouble(json['vote_average']),
        type: json['type'] as String? ?? 'film',
        accessModel: json['access_model'] as String? ?? 'sub',
        rentalPrice: readDouble(json['rental_price']),
        rentalDurationHours: readInt(json['rental_duration_hours']),
        isFeatured: readBool(json['is_featured']),
        reviewFriendly: readBool(json['review_friendly']),
        genres: (json['genres'] as List<dynamic>? ?? [])
            .map((g) => Genre.fromJson(g as Map<String, dynamic>))
            .toList(),
        streamVideo: json['stream_video'] != null
            ? StreamVideo.fromJson(json['stream_video'] as Map<String, dynamic>)
            : null,
      );
}
