import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/json_helpers.dart';
import '../models/show.dart';
import 'auth_provider.dart';

class ShowDetailData {
  final Show show;
  final bool canWatch;
  final Map<int, int> episodeProgress; // episodeId -> positionSeconds

  const ShowDetailData({
    required this.show,
    this.canWatch = false,
    this.episodeProgress = const {},
  });
}

final showDetailProvider =
    FutureProvider.family<ShowDetailData, String>((ref, slug) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(
    ApiEndpoints.showDetail(slug),
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

  return ShowDetailData(
    show: Show.fromJson(data['show'] as Map<String, dynamic>),
    canWatch: readBool(data['can_watch']),
    episodeProgress: episodeProgress,
  );
});
