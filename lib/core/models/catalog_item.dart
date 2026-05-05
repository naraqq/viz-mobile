import 'genre.dart';
import 'json_helpers.dart';

class CatalogItem {
  final int id;
  final String title;
  final String slug;
  final String? posterUrl;
  final String? backdropUrl;
  final String contentType; // 'movie' or 'show'
  final double? popularity;
  final double? voteAverage;
  final List<Genre> genres;
  final String? accessModel; // 'free', 'sub', 'rent'

  const CatalogItem({
    required this.id,
    required this.title,
    required this.slug,
    this.posterUrl,
    this.backdropUrl,
    required this.contentType,
    this.popularity,
    this.voteAverage,
    this.genres = const [],
    this.accessModel,
  });

  bool get isMovie => contentType == 'movie';
  bool get isShow => contentType == 'show';

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: readInt(json['id']) ?? 0,
        title: json['title'] as String,
        slug: json['slug'] as String,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        contentType: json['content_type'] as String? ?? 'movie',
        popularity: readDouble(json['popularity']),
        voteAverage: readDouble(json['vote_average']),
        genres: (json['genres'] as List<dynamic>? ?? [])
            .map((g) => Genre.fromJson(g as Map<String, dynamic>))
            .toList(),
        accessModel: json['access_model'] as String?,
      );
}
