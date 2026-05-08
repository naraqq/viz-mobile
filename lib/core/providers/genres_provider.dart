import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_endpoints.dart';
import '../models/genre_item.dart';
import 'auth_provider.dart';

final genresProvider = FutureProvider<List<GenreItem>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(ApiEndpoints.genres);
  return (res.data!['genres'] as List)
      .map((g) => GenreItem.fromJson(g as Map<String, dynamic>))
      .toList();
});
