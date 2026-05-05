import 'json_helpers.dart';

class ContinueWatchingItem {
  final String type; // 'movie' or 'episode'
  final int id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final int positionSeconds;
  final int durationSeconds;

  // Episode-specific
  final int? episodeNumber;
  final int? seasonNumber;
  final String? showTitle;
  final String? showSlug;

  const ContinueWatchingItem({
    required this.type,
    required this.id,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    required this.positionSeconds,
    required this.durationSeconds,
    this.episodeNumber,
    this.seasonNumber,
    this.showTitle,
    this.showSlug,
  });

  bool get isMovie => type == 'movie';
  bool get isEpisode => type == 'episode';

  double get progress =>
      durationSeconds > 0 ? positionSeconds / durationSeconds : 0.0;

  String get subtitle {
    if (isEpisode) {
      return 'S${seasonNumber ?? '?'} E${episodeNumber ?? '?'} · $title';
    }
    return title;
  }

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return ContinueWatchingItem(
      type: type,
      id: readInt(json['id']) ?? 0,
      title: type == 'movie'
          ? (json['title'] as String)
          : (json['name'] as String? ?? json['title'] as String? ?? ''),
      slug: type == 'movie'
          ? (json['slug'] as String)
          : (json['show_slug'] as String? ?? ''),
      thumbnailUrl: json['thumbnail_url'] as String?,
      positionSeconds: readInt(json['position_seconds']) ?? 0,
      durationSeconds: readInt(json['duration_seconds']) ?? 0,
      episodeNumber: readInt(json['episode_number']),
      seasonNumber: readInt(json['season_number']),
      showTitle: json['show_title'] as String?,
      showSlug: json['show_slug'] as String?,
    );
  }
}
