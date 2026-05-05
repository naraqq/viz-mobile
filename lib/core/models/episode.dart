import 'json_helpers.dart';
import 'stream_video.dart';

class Episode {
  final int id;
  final int episodeNumber;
  final int? seasonNumber;
  final String name;
  final String? overview;
  final String? overviewMn;
  final String? stillUrl;
  final int? runtime;
  final StreamVideo? streamVideo;

  const Episode({
    required this.id,
    required this.episodeNumber,
    this.seasonNumber,
    required this.name,
    this.overview,
    this.overviewMn,
    this.stillUrl,
    this.runtime,
    this.streamVideo,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: readInt(json['id']) ?? 0,
    episodeNumber: readInt(json['episode_number']) ?? 0,
    seasonNumber: readInt(json['season_number']),
    name: json['name'] as String,
    overview: json['overview'] as String?,
    overviewMn: json['overview_mn'] as String?,
    stillUrl: json['still_url'] as String?,
    runtime: readInt(json['runtime']),
    streamVideo: json['stream_video'] != null
        ? StreamVideo.fromJson(json['stream_video'] as Map<String, dynamic>)
        : null,
  );
}
