import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/catalog_item.dart';
import '../models/content_row.dart';
import '../models/continue_watching_item.dart';
import 'auth_provider.dart';

class HomeData {
  final List<CatalogItem> featuredItems;
  final List<ContentRow> rows;
  final List<ContinueWatchingItem> continueWatching;

  const HomeData({
    this.featuredItems = const [],
    this.rows = const [],
    this.continueWatching = const [],
  });
}

final homeProvider = FutureProvider<HomeData>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(ApiEndpoints.home);
  final data = res.data!;

  final featuredItems =
      (data['featured_items'] as List<dynamic>? ?? [])
          .map((i) => CatalogItem.fromJson(i as Map<String, dynamic>))
          .toList();

  final rawRows = data['rows'] as List<dynamic>? ?? [];
  // ignore: avoid_print
  print('[HomeProvider] API returned ${rawRows.length} rows');
  final rows = rawRows.map((r) {
    final row = ContentRow.fromJson(r as Map<String, dynamic>);
    // ignore: avoid_print
    print('[HomeProvider] row "${row.label}": ${row.items.length} items');
    return row;
  }).toList();

  final continueWatching =
      (data['continue_watching'] as List<dynamic>? ?? [])
          .map((c) => ContinueWatchingItem.fromJson(c as Map<String, dynamic>))
          .toList();

  return HomeData(
    featuredItems: featuredItems,
    rows: rows,
    continueWatching: continueWatching,
  );
});
