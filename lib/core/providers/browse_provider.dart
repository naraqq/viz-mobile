import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/json_helpers.dart';
import '../models/catalog_item.dart';
import 'auth_provider.dart';

const _unset = Object();

class BrowseFilters {
  final String? search;
  final String? genre;
  final String sort;
  final String? type; // 'movie', 'show', or null for all
  final int page;

  const BrowseFilters({
    this.search,
    this.genre,
    this.sort = 'popular',
    this.type,
    this.page = 1,
  });

  Map<String, dynamic> toQueryParams() => {
    if (search != null && search!.isNotEmpty) 'search': search!,
    if (genre != null && genre!.isNotEmpty) 'genre': genre!,
    'sort': sort,
    if (type != null) 'type': type!,
    'page': page,
  };

  BrowseFilters copyWith({
    Object? search = _unset,
    Object? genre = _unset,
    Object? sort = _unset,
    Object? type = _unset,
    Object? page = _unset,
  }) => BrowseFilters(
    search: identical(search, _unset) ? this.search : search as String?,
    genre: identical(genre, _unset) ? this.genre : genre as String?,
    sort: identical(sort, _unset) ? this.sort : sort as String,
    type: identical(type, _unset) ? this.type : type as String?,
    page: identical(page, _unset) ? this.page : page as int,
  );

  bool get isEmpty => (search == null || search!.isEmpty) && (genre == null || genre!.isEmpty);
}

class BrowseData {
  final List<CatalogItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool isLoadingMore;

  const BrowseData({
    this.items = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.isLoadingMore = false,
  });

  bool get hasMore => currentPage < lastPage;
}

class BrowseNotifier extends StateNotifier<AsyncValue<BrowseData>> {
  final Ref _ref;
  BrowseFilters _filters = const BrowseFilters();
  int _requestId = 0;

  BrowseNotifier(this._ref) : super(const AsyncValue.data(BrowseData()));

  BrowseFilters get filters => _filters;

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    _filters = _filters.copyWith(page: 1);
    await _load(replace: true, requestId: ++_requestId);
  }

  Future<void> applyFilters(BrowseFilters filters) async {
    _filters = filters.copyWith(page: 1);
    await fetch();
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
    _filters = _filters.copyWith(page: current.currentPage + 1);
    await _load(replace: false, requestId: ++_requestId);
  }

  Future<void> _load({required bool replace, required int requestId}) async {
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.get<Map<String, dynamic>>(
        ApiEndpoints.content,
        queryParameters: _filters.toQueryParams(),
      );

      if (requestId != _requestId) return;

      final data = res.data!;
      final items = (data['items'] as List)
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>;
      final currentPage = readInt(meta['current_page']) ?? 1;
      final lastPage = readInt(meta['last_page']) ?? 1;
      final total = readInt(meta['total']) ?? 0;

      final existing = replace ? <CatalogItem>[] : (state.valueOrNull?.items ?? []);

      state = AsyncValue.data(BrowseData(
        items: [...existing, ...items],
        currentPage: currentPage,
        lastPage: lastPage,
        total: total,
      ));
    } catch (e, st) {
      if (requestId != _requestId) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final browseProvider = StateNotifierProvider<BrowseNotifier, AsyncValue<BrowseData>>(
  (ref) => BrowseNotifier(ref),
);
