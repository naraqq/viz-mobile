import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/genre_item.dart';
import '../../core/providers/genres_provider.dart';
import '../../core/theme/app_theme.dart';

class GenreListScreen extends ConsumerWidget {
  const GenreListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Жанрууд',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: genresAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Жанрыг ачаалж чадсангүй',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(genresProvider),
                child: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
        data: (genres) => ListView.builder(
          itemCount: genres.length,
          itemBuilder: (_, i) => _GenreTile(genre: genres[i]),
        ),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final GenreItem genre;

  const _GenreTile({required this.genre});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(
        genre.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white38,
      ),
      onTap: () => context.push(
        Uri(
          path: '/genres/${genre.slug}',
          queryParameters: {'label': genre.name},
        ).toString(),
      ),
    );
  }
}
