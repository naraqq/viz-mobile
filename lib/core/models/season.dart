import 'episode.dart';
import 'json_helpers.dart';

class Season {
  final int id;
  final int seasonNumber;
  final String name;
  final String? posterUrl;
  final List<Episode> episodes;

  const Season({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.posterUrl,
    this.episodes = const [],
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        id: readInt(json['id']) ?? 0,
        seasonNumber: readInt(json['season_number']) ?? 0,
        name: json['name'] as String? ?? '${readInt(json['season_number']) ?? 0}-р бүлэг',
        posterUrl: json['poster_url'] as String?,
        episodes: (json['episodes'] as List<dynamic>? ?? [])
            .map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
