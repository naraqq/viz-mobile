class GenreItem {
  final int id;
  final String name;
  final String slug;

  const GenreItem({required this.id, required this.name, required this.slug});

  factory GenreItem.fromJson(Map<String, dynamic> json) => GenreItem(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}
