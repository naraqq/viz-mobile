import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/genres_provider.dart';
import 'drama_api.dart';
import 'drama_models.dart';
import 'widgets/drama_widgets.dart';

/// Драмууд: popular/new, genre chips and a 3-column poster grid with infinite scroll.
/// The search pill on top opens the dedicated search screen.
class DramasScreen extends ConsumerStatefulWidget {
  final String? initialGenre;
  const DramasScreen({super.key, this.initialGenre});

  @override
  ConsumerState<DramasScreen> createState() => _DramasScreenState();
}

class _DramasScreenState extends ConsumerState<DramasScreen> {
  final _scroll = ScrollController();

  String _sort = 'popular';
  String? _genre;
  final List<DramaCard> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0; // ignores stale responses after the filters change

  @override
  void initState() {
    super.initState();
    _genre = widget.initialGenre;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600)
        _fetch();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    _generation++;
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(dramaApiProvider)
          .catalog(page: _page, genre: _genre, sort: _sort);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(r.items);
        _hasMore = r.hasMore;
        _page++;
      });
    } on DramaException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  /// 3 columns; row height = poster + title block exactly, so nothing overflows.
  SliverGridDelegate _gridDelegate(BuildContext context) {
    final cell = (MediaQuery.sizeOf(context).width - 32 - 20) / 3;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 10,
      mainAxisExtent: DramaPoster.cardHeight(context, cell),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genres = ref.watch(genresProvider).valueOrNull ?? const [];
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: DramaColors.bg,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: DramaColors.surface,
        onRefresh: () async => _reload(),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, 0),
                child: Hero(
                  tag: 'drama-search',
                  child: Material(
                    color: DramaColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.push('/search'),
                      child: const SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(width: 12),
                            Icon(
                              Icons.search_rounded,
                              color: DramaColors.muted,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Драмын нэрээр хайх',
                              style: TextStyle(
                                color: DramaColors.faint,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    _SortTab('Алдартай', _sort == 'popular', () {
                      _sort = 'popular';
                      _reload();
                    }),
                    const SizedBox(width: 18),
                    _SortTab('Шинэ', _sort == 'new', () {
                      _sort = 'new';
                      _reload();
                    }),
                  ],
                ),
              ),
            ),
            if (genres.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _GenreChip('Бүгд', _genre == null, () {
                        _genre = null;
                        _reload();
                      }),
                      for (final g in genres)
                        _GenreChip(g.name, _genre == g.slug, () {
                          _genre = g.slug;
                          _reload();
                        }),
                    ],
                  ),
                ),
              ),
            if (_items.isEmpty && _loading)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: _gridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const SkeletonBox(),
                    childCount: 9,
                  ),
                ),
              )
            else if (_items.isEmpty && _error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorRetry(message: _error!, onRetry: _reload),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Илэрц олдсонгүй',
                    style: TextStyle(color: DramaColors.muted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: _gridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => LayoutBuilder(
                      builder: (_, c) =>
                          DramaPoster(drama: _items[i], width: c.maxWidth),
                    ),
                    childCount: _items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24,
                child: _loading && _items.isNotEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortTab(this.label, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : DramaColors.muted,
            fontSize: 16,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 18 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: DramaColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  );
}

class _GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenreChip(this.label, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : DramaColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
