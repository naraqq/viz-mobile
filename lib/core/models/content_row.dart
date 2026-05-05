import 'catalog_item.dart';

class ContentRow {
  final String label;
  final List<CatalogItem> items;

  const ContentRow({required this.label, required this.items});

  factory ContentRow.fromJson(Map<String, dynamic> json) => ContentRow(
        label: _localizeLabel(json['label'] as String? ?? ''),
        items: (json['items'] as List<dynamic>)
            .map((i) => CatalogItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

String _localizeLabel(String label) {
  return switch (label) {
    'Trending' => 'Тренд',
    'Action & Adventure' => 'Адал явдалт',
    'Sci-Fi & Fantasy' => 'Шинжлэх ухааны уран зөгнөлт',
    'Drama' => 'Драм',
    'Crime' => 'Гэмт хэрэг',
    _ => label,
  };
}
