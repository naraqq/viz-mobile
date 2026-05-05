import 'json_helpers.dart';

class SubtitleTrack {
  final int id;
  final String languageCode;
  final String label;
  final String? playbackUrl;
  final bool isDefault;

  const SubtitleTrack({
    required this.id,
    required this.languageCode,
    required this.label,
    this.playbackUrl,
    this.isDefault = false,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        id: readInt(json['id']) ?? 0,
        languageCode: json['language_code'] as String,
        label: json['label'] as String,
        playbackUrl: json['playback_url'] as String?,
        isDefault: readBool(json['is_default']),
      );
}
