import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool get _hasSearch => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(browseProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    final q = value.trim();
    ref.read(browseProvider.notifier).applyFilters(
      BrowseFilters(search: q.isEmpty ? null : q),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Кино, цуврал хайх...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _hasSearch
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _hasSearch
                  ? _ResultsView(scrollCtrl: _scrollCtrl)
                  : const _EmptyState(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, color: Colors.white10, size: 64),
          SizedBox(height: 14),
          Text(
            'Кино эсвэл цуврал хайх',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Results view ─────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final ScrollController scrollCtrl;

  const _ResultsView({required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseAsync = ref.watch(browseProvider);

    return browseAsync.when(
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
              onPressed: () => ref.read(browseProvider.notifier).fetch(),
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded, color: Colors.white10, size: 56),
                SizedBox(height: 12),
                Text(
                  'Илэрц олдсонгүй',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: scrollCtrl,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
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
    );
  }
}
