import 'json_helpers.dart';

class ContinueWatchingItem {
  final String type; // 'movie' or 'episode'
  final int id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final int positionSeconds;
  final int durationSeconds;
  final String? accessModel; // 'free', 'sub', 'rent'
  final DateTime? rentedUntil;

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
    this.accessModel,
    this.rentedUntil,
    this.episodeNumber,
    this.seasonNumber,
    this.showTitle,
    this.showSlug,
  });

  bool get isMovie => type == 'movie';
  bool get isEpisode => type == 'episode';

  bool get isFree => accessModel == 'free' || accessModel == null;
  bool get requiresSub => accessModel == 'sub';
  bool get isRental => accessModel == 'rent';

  bool get rentalActive =>
      rentedUntil != null && rentedUntil!.isAfter(DateTime.now());

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
      accessModel: json['access_model'] as String?,
      rentedUntil: json['rented_until'] != null
          ? DateTime.tryParse(json['rented_until'].toString())
          : null,
      episodeNumber: readInt(json['episode_number']),
      seasonNumber: readInt(json['season_number']),
      showTitle: json['show_title'] as String?,
      showSlug: json['show_slug'] as String?,
    );
  }
}
