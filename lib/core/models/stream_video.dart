import 'json_helpers.dart';
import 'subtitle_track.dart';

class StreamVideo {
  final int id;
  final String? hlsUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String status;
  final List<SubtitleTrack> subtitleTracks;

  const StreamVideo({
    required this.id,
    this.hlsUrl,
    this.playbackUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.status,
    this.subtitleTracks = const [],
  });

  bool get isReady => status == 'ready' || hlsUrl != null;

  factory StreamVideo.fromJson(Map<String, dynamic> json) => StreamVideo(
        id: readInt(json['id']) ?? 0,
        hlsUrl: json['hls_url'] as String?,
        playbackUrl: json['playback_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        durationSeconds: readInt(json['duration_seconds']),
        status: json['status'] as String? ?? 'draft',
        subtitleTracks: (json['subtitle_tracks'] as List<dynamic>? ?? [])
            .map((t) => SubtitleTrack.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
