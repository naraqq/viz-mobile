import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/json_helpers.dart';
import '../models/catalog_item.dart';
import 'auth_provider.dart';

const _unset = Object();

class BrowseFilters {
  final String? search;
  final String? genre;
  final String? sort;
  final String? type; // 'movie', 'show', or null for both
  final int page;

  const BrowseFilters({
    this.search,
    this.genre,
    this.sort = 'popular',
    this.type,
    this.page = 1,
  });

  Map<String, dynamic> toQueryParams() => {
    if (search != null && search!.isNotEmpty) 'search': search,
    if (genre != null && genre!.isNotEmpty) 'genre': genre,
    if (sort != null) 'sort': sort,
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
    sort: identical(sort, _unset) ? this.sort : sort as String?,
    type: identical(type, _unset) ? this.type : type as String?,
    page: identical(page, _unset) ? this.page : page as int,
  );
}

class BrowseData {
  final List<CatalogItem> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  const BrowseData({
    this.items = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
  });

  bool get hasMore => currentPage < lastPage;
}

class BrowseNotifier extends StateNotifier<AsyncValue<BrowseData>> {
  final Ref _ref;
  BrowseFilters _filters = const BrowseFilters();
  int _requestId = 0;

  BrowseNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

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
    state = AsyncValue.data(
      BrowseData(
        items: current.items,
        currentPage: current.currentPage,
        lastPage: current.lastPage,
        isLoadingMore: true,
      ),
    );
    _filters = _filters.copyWith(page: current.currentPage + 1);
    await _load(replace: false, requestId: ++_requestId);
  }

  Future<void> _load({required bool replace, required int requestId}) async {
    try {
      final api = _ref.read(apiClientProvider);
      final filters = _filters;
      final includeMovies = filters.type != 'show';
      final includeShows = filters.type != 'movie';
      final pages = <Map<String, dynamic>>[];
      var movieItems = <CatalogItem>[];
      var showItems = <CatalogItem>[];

      if (includeMovies) {
        final moviesRes = await api.get<Map<String, dynamic>>(
          ApiEndpoints.movies,
          queryParameters: filters.toQueryParams(),
        );
        final moviesData = moviesRes.data!;
        final moviesPaginated = moviesData['movies'] as Map<String, dynamic>;
        pages.add(moviesPaginated);

        movieItems = (moviesPaginated['data'] as List<dynamic>)
            .map(
              (m) => CatalogItem.fromJson({
                ...(m as Map<String, dynamic>),
                'content_type': 'movie',
              }),
            )
            .toList();
      }

      if (includeShows) {
        final showsRes = await api.get<Map<String, dynamic>>(
          ApiEndpoints.shows,
          queryParameters: filters.toQueryParams(),
        );
        final showsData = showsRes.data!;
        final showsPaginated = showsData['shows'] as Map<String, dynamic>;
        pages.add(showsPaginated);

        showItems = (showsPaginated['data'] as List<dynamic>)
            .map(
              (s) => CatalogItem.fromJson({
                ...(s as Map<String, dynamic>),
                'content_type': 'show',
              }),
            )
            .toList();
      }

      final allItems = [...movieItems, ...showItems];

      final currentPage = pages.isEmpty
          ? 1
          : pages
                .map((page) => readInt(page['current_page']) ?? 1)
                .reduce((a, b) => a > b ? a : b);
      final lastPage = pages.isEmpty
          ? 1
          : pages
                .map((page) => readInt(page['last_page']) ?? 1)
                .reduce((a, b) => a > b ? a : b);

      final existing = replace
          ? <CatalogItem>[]
          : (state.valueOrNull?.items ?? []);

      if (requestId != _requestId) return;

      state = AsyncValue.data(
        BrowseData(
          items: [...existing, ...allItems],
          currentPage: currentPage,
          lastPage: lastPage,
        ),
      );
    } catch (e, st) {
      if (requestId != _requestId) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final browseProvider =
    StateNotifierProvider<BrowseNotifier, AsyncValue<BrowseData>>(
      (ref) => BrowseNotifier(ref),
    );
