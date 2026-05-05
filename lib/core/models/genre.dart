import 'json_helpers.dart';

class Genre {
  final int id;
  final String name;
  final String slug;

  const Genre({required this.id, required this.name, required this.slug});

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
        id: readInt(json['id']) ?? 0,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}
