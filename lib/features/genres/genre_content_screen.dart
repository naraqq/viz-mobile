import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/genre_content_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class GenreContentScreen extends ConsumerStatefulWidget {
  final String slug;
  final String label;

  const GenreContentScreen({
    super.key,
    required this.slug,
    required this.label,
  });

  @override
  ConsumerState<GenreContentScreen> createState() => _GenreContentScreenState();
}

class _GenreContentScreenState extends ConsumerState<GenreContentScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(genreContentProvider(widget.slug).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(genreContentProvider(widget.slug));

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
        title: Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: contentAsync.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2 / 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (_, __) =>
              const ShimmerBox(borderRadius: BorderRadius.zero),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(genreContentProvider(widget.slug).notifier)
                    .retry(),
                child: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const Center(
              child: Text(
                'Контент олдсонгүй',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              if (data.total > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${data.total} илэрц',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i >= data.items.length) {
                        return const ShimmerBox(borderRadius: BorderRadius.zero);
                      }
                      return ContentCard(
                        item: data.items[i],
                        width: double.infinity,
                      );
                    },
                    childCount: data.items.length + (data.hasMore ? 3 : 0),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
