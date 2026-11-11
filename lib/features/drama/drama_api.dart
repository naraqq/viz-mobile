import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/providers/auth_provider.dart';
import 'drama_models.dart';

/// Thrown with a user-facing (Mongolian) message.
class DramaException implements Exception {
  final String message;
  final String? code;
  const DramaException(this.message, {this.code});
  @override
  String toString() => message;
}

class DramaApi {
  final ApiClient _api;
  DramaApi(this._api);

  String _msg(DioException e, String fallback) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Интернет холболтоо шалгана уу.';
    }
    return fallback;
  }

  Future<List<HomeSection>> home() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.dramaHome);
      return (res.data!['sections'] as List? ?? [])
          .map((s) => HomeSection.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Нүүр хуудсыг ачаалж чадсангүй.'));
    }
  }

  /// One page of the catalogue. Returns the dramas and whether more pages exist.
  Future<({List<DramaCard> items, bool hasMore})> catalog({
    int page = 1,
    String? search,
    String? genre,
    String sort = 'popular',
  }) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dramas,
        queryParameters: {
          'page': page,
          if (search != null && search.isNotEmpty) 'search': search,
          if (genre != null) 'genre': genre,
          if (sort == 'new') 'sort': 'new',
        },
      );
      final p = Map<String, dynamic>.from(res.data!['dramas'] as Map);
      final items = (p['data'] as List? ?? [])
          .map((d) => DramaCard.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();
      return (items: items, hasMore: p['next_page_url'] != null);
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Драмуудыг ачаалж чадсангүй.'));
    }
  }

  Future<DramaDetail> detail(String slug) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.showDetail(slug),
      );
      return DramaDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Драмыг ачаалж чадсангүй.'));
    }
  }

  /// 200 → stream; 402 → locked (paywall info). Both come back as [EpisodePlay].
  Future<EpisodePlay> play(int episodeId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.episodePlay(episodeId),
      );
      return EpisodePlay.fromJson(res.data!);
    } on DioException catch (e) {
      final d = e.response?.data;
      if (e.response?.statusCode == 402 && d is Map) {
        return EpisodePlay.fromJson(Map<String, dynamic>.from(d));
      }
      throw DramaException(_msg(e, 'Ангийг тоглуулж чадсангүй.'));
    }
  }

  /// Spend coins on an episode. Returns the new coin balance.
  Future<int> unlock(int episodeId) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.episodeUnlock(episodeId),
      );
      return (res.data!['coin_balance'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      final d = e.response?.data;
      throw DramaException(
        _msg(e, 'Ангийг нээж чадсангүй.'),
        code: d is Map ? d['code']?.toString() : null,
      );
    }
  }

  Future<({List<FeedItem> items, int? nextPage})> feed({int page = 1}) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.feed,
        queryParameters: {'page': page},
      );
      final items = (res.data!['items'] as List? ?? [])
          .map((i) => FeedItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
      return (
        items: items,
        nextPage: (res.data!['next_page'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Reels-ийг ачаалж чадсангүй.'));
    }
  }

  Future<bool> toggleSave(int showId) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.dramaSave(showId),
    );
    return res.data!['saved'] == true;
  }

  Future<({bool liked, int likes})> toggleLike(int showId) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.dramaLike(showId),
    );
    return (
      liked: res.data!['liked'] == true,
      likes: (res.data!['likes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<({int balance, List<CoinPackage> packages})> coins() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.coins);
      return (
        balance: (res.data!['balance'] as num?)?.toInt() ?? 0,
        packages: (res.data!['packages'] as List? ?? [])
            .map(
              (p) => CoinPackage.fromJson(Map<String, dynamic>.from(p as Map)),
            )
            .toList(),
      );
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Зоосны мэдээллийг ачаалж чадсангүй.'));
    }
  }

  /// Fire-and-forget: remember where the viewer is in an episode.
  Future<void> saveProgress(int episodeId, int position, int duration) async {
    try {
      await _api.post<dynamic>(
        ApiEndpoints.watchProgress,
        data: {
          'watchable_type': 'episode',
          'watchable_id': episodeId,
          'position_seconds': position,
          'duration_seconds': duration,
        },
      );
    } catch (_) {}
  }
}

final dramaApiProvider = Provider<DramaApi>(
  (ref) => DramaApi(ref.read(apiClientProvider)),
);

final dramaHomeProvider = FutureProvider.autoDispose<List<HomeSection>>(
  (ref) => ref.read(dramaApiProvider).home(),
);

final dramaDetailProvider = FutureProvider.autoDispose
    .family<DramaDetail, String>(
      (ref, slug) => ref.read(dramaApiProvider).detail(slug),
    );

/// The viewer's coin balance, refreshed after unlocks and purchases.
final coinBalanceProvider = StateProvider<int?>((ref) => null);

/// Saved dramas and watch history (GET /library?limit=60).
final myListProvider =
    FutureProvider.autoDispose<
      ({List<ContinueItem> history, List<DramaCard> saved})
    >((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            ApiEndpoints.library,
            queryParameters: {'limit': 60},
          );
      final d = res.data ?? const {};
      List<Map<String, dynamic>> list(dynamic v) => v is List
          ? v.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const [];
      return (
        history: list(d['history']).map(ContinueItem.fromJson).toList(),
        saved: list(d['saved']).map(DramaCard.fromJson).toList(),
      );
    });

/// After watching (player or Shorts closed): reload everything that shows watch history —
/// Home's "continue watching", Жагсаалт and Profile. Call it once the progress save has
/// finished, so the server already has the new position.
void refreshWatchState(ProviderContainer container) {
  container.invalidate(dramaHomeProvider);
  container.invalidate(myListProvider);
}
