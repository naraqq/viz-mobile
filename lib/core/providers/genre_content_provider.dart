import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/catalog_item.dart';
import '../models/json_helpers.dart';
import 'auth_provider.dart';
import 'browse_provider.dart';

class GenreContentNotifier extends StateNotifier<AsyncValue<BrowseData>> {
  final Ref _ref;
  final String _genre;
  int _page = 1;
  int _lastPage = 1;
  int _requestId = 0;

  GenreContentNotifier(this._ref, this._genre) : super(const AsyncValue.loading()) {
    _load(replace: true, requestId: ++_requestId);
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    _page = 1;
    await _load(replace: true, requestId: ++_requestId);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncValue.data(BrowseData(
      items: current.items,
      currentPage: current.currentPage,
      lastPage: current.lastPage,
      total: current.total,
      isLoadingMore: true,
    ));
    _page = current.currentPage + 1;
    await _load(replace: false, requestId: ++_requestId);
  }

  Future<void> _load({required bool replace, required int requestId}) async {
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.get<Map<String, dynamic>>(
        ApiEndpoints.content,
        queryParameters: {'genre': _genre, 'sort': 'popular', 'page': _page},
      );

      if (requestId != _requestId) return;

      final data = res.data!;
      final items = (data['items'] as List)
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>;
      _page = readInt(meta['current_page']) ?? _page;
      _lastPage = readInt(meta['last_page']) ?? 1;
      final total = readInt(meta['total']) ?? 0;

      final existing = replace ? <CatalogItem>[] : (state.valueOrNull?.items ?? []);
      state = AsyncValue.data(BrowseData(
        items: [...existing, ...items],
        currentPage: _page,
        lastPage: _lastPage,
        total: total,
      ));
    } catch (e, st) {
      if (requestId != _requestId) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final genreContentProvider = StateNotifierProvider.family<
    GenreContentNotifier, AsyncValue<BrowseData>, String>(
  (ref, slug) => GenreContentNotifier(ref, slug),
);
