import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/lemony_logo.dart';
import 'drama_api.dart';
import 'drama_models.dart';
import 'widgets/drama_widgets.dart';

/// One tab of the home feed.
class _FeedTab {
  final String label;
  final String sort; // popular | new
  final String? genre;
  final bool ranking;
  const _FeedTab(
    this.label, {
    this.sort = 'popular',
    this.genre,
    this.ranking = false,
  });
}

/// Нүүр: a short-drama feed browsed by tabs — Онцлох / Шинэ / Эрэмбэ, then the genre
/// categories the admin picked for the web home. Each tab is a dense poster grid followed by
/// a 2-column staggered card feed that pages as it scrolls.
class DramaHomeScreen extends ConsumerStatefulWidget {
  const DramaHomeScreen({super.key});

  @override
  ConsumerState<DramaHomeScreen> createState() => _DramaHomeScreenState();
}

class _DramaHomeScreenState extends ConsumerState<DramaHomeScreen>
    with TickerProviderStateMixin {
  TabController? _tabs;
  List<_FeedTab> _tabList = const [];

  List<_FeedTab> _buildTabs(List<HomeSection> sections) {
    final cats = <_FeedTab>[];
    for (final s in sections.where((s) => s.type == 'genre_tabs')) {
      for (final t in s.tabs) {
        if (t.genre.isNotEmpty && !cats.any((c) => c.genre == t.genre)) {
          cats.add(_FeedTab(t.title, genre: t.genre));
        }
      }
    }
    return [
      const _FeedTab('Онцлох'),
      const _FeedTab('Шинэ', sort: 'new'),
      const _FeedTab('Эрэмбэ', ranking: true),
      ...cats,
    ];
  }

  void _syncTabs(List<_FeedTab> next) {
    final same =
        _tabs != null &&
        next.length == _tabList.length &&
        [
          for (var i = 0; i < next.length; i++)
            next[i].label == _tabList[i].label,
        ].every((x) => x);
    if (same) return;
    final keep = _tabs?.index ?? 0;
    _tabs?.dispose();
    _tabList = next;
    _tabs = TabController(
      length: next.length,
      vsync: this,
      initialIndex: keep.clamp(0, next.length - 1),
    );
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(dramaHomeProvider);
    final sections = home.valueOrNull ?? const <HomeSection>[];
    _syncTabs(_buildTabs(sections));

    final continueItems = sections
        .where((s) => s.type == 'continue')
        .expand((s) => s.continueItems)
        .toList();
    final titles = sections
        .expand((s) => s.items)
        .map((d) => d.title)
        .toSet()
        .take(8)
        .toList();
    final pad = MediaQuery.of(context).padding;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DramaColors.bg,
        body: Stack(
          children: [
            // Warm brand glow behind the header.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: pad.top + 190,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3A1422), DramaColors.bg],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: pad.top + 6),
                _Header(titles: titles),
                _TabStrip(controller: _tabs!, tabs: _tabList),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      for (var i = 0; i < _tabList.length; i++)
                        _tabList[i].ranking
                            ? const _RankingFeed(key: PageStorageKey('ranking'))
                            : _CatalogFeed(
                                key: PageStorageKey(
                                  'feed-${_tabList[i].sort}-${_tabList[i].genre}',
                                ),
                                sort: _tabList[i].sort,
                                genre: _tabList[i].genre,
                                continueItems: i == 0
                                    ? continueItems
                                    : const [],
                              ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header: logo · search · VIP ────────────────────────────────────────────

class _Header extends StatefulWidget {
  final List<String> titles;
  const _Header({required this.titles});
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The search pill cycles through drama titles as suggestions.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (widget.titles.length > 1 && mounted) {
        setState(() => _i = (_i + 1) % widget.titles.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.titles.isEmpty
        ? 'Драмын нэрээр хайх'
        : widget.titles[_i % widget.titles.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/lemony_icon.png',
              width: 38,
              height: 38,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Hero(
              tag: 'drama-search',
              child: Material(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(21),
                child: InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: () => context.push('/search'),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.4),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            child: Align(
                              key: ValueKey(hint),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.go('/vip'),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B2A12), Color(0xFF1E1609)],
                ),
                border: Border.all(color: const Color(0x88F5B83D)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.diamond_rounded,
                    color: DramaColors.gold,
                    size: 17,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'VIP',
                    style: TextStyle(
                      color: DramaColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final TabController controller;
  final List<_FeedTab> tabs;
  const _TabStrip({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      dividerColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      onTap: (_) => HapticFeedback.selectionClick(),
      tabs: [for (final t in tabs) Tab(text: t.label)],
    ),
  );
}

// ─── Catalog feed (Онцлох / Шинэ / genre) ───────────────────────────────────

class _CatalogFeed extends ConsumerStatefulWidget {
  final String sort;
  final String? genre;
  final List<ContinueItem> continueItems;
  const _CatalogFeed({
    super.key,
    required this.sort,
    this.genre,
    this.continueItems = const [],
  });

  @override
  ConsumerState<_CatalogFeed> createState() => _CatalogFeedState();
}

class _CatalogFeedState extends ConsumerState<_CatalogFeed>
    with AutomaticKeepAliveClientMixin {
  static const _gridCount = 6; // dense 3-column block before the staggered feed

  final List<DramaCard> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    ref.invalidate(dramaHomeProvider);
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(dramaApiProvider)
          .catalog(page: _page, genre: widget.genre, sort: widget.sort);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final grid = _items.take(_gridCount).toList();
    final rest = _items.skip(_gridCount).toList();

    if (_items.isEmpty && _loading) return const _FeedSkeleton();
    if (_items.isEmpty && _error != null) {
      return ErrorRetry(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('Драм алга', style: TextStyle(color: DramaColors.muted)),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 800) _fetch();
        return false;
      },
      child: RefreshIndicator(
        color: Colors.white,
        backgroundColor: DramaColors.surface,
        onRefresh: _reload,
        child: CustomScrollView(
          slivers: [
            if (widget.continueItems.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _MiniTitle('Үргэлжлүүлэн үзэх')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.continueItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) =>
                        _ContinueChip(item: widget.continueItems[i]),
                  ),
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 16,
                  mainAxisExtent: _GridPoster.height(
                    context,
                    (MediaQuery.sizeOf(context).width - 32 - 18) / 3,
                  ),
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GridPoster(drama: grid[i], rank: i),
                  childCount: grid.length,
                ),
              ),
            ),
            if (rest.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childCount: rest.length,
                  itemBuilder: (_, i) => _FeedCard(drama: rest[i], index: i),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 18, bottom: 24),
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-left corner badge: Шинэ (new), Онцлох (featured) or Үнэгүй (free).
class _CornerBadge extends StatelessWidget {
  final DramaCard drama;
  final bool hot;
  const _CornerBadge({required this.drama, this.hot = false});

  @override
  Widget build(BuildContext context) {
    final (String? text, Gradient? g, Color? c) = drama.isNew
        ? ('Шинэ', null, LemonyBrand.rose)
        : (drama.isFeatured || hot)
        ? ('Онцлох', LemonyBrand.gradient, null)
        : drama.isFree
        ? ('Үнэгүй', null, const Color(0xFF16A34A))
        : (null, null, null);
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c,
        gradient: g,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EpisodeCount extends StatelessWidget {
  final int episodes;
  const _EpisodeCount(this.episodes);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
      Text(
        '$episodes анги',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    ],
  );
}

/// Poster image with the bottom shade, corner badge and episode count.
class _PosterArt extends StatelessWidget {
  final DramaCard drama;
  final double aspect;
  final bool hot;
  final bool showBadge;
  final BorderRadius radius;
  const _PosterArt({
    required this.drama,
    required this.aspect,
    this.hot = false,
    this.showBadge = true,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspect,
    child: ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DramaImage(drama.posterUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.3),
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: 0,
              left: 0,
              child: _CornerBadge(drama: drama, hot: hot),
            ),
          if (drama.episodes > 0)
            Positioned(
              right: 6,
              bottom: 5,
              child: _EpisodeCount(drama.episodes),
            ),
        ],
      ),
    ),
  );
}

/// Dense 3-column poster: art, 2-line title, first genre.
class _GridPoster extends StatelessWidget {
  final DramaCard drama;
  final int rank;
  const _GridPoster({required this.drama, required this.rank});

  static const aspect = 3 / 4.1;

  static double height(BuildContext context, double width) {
    final t = MediaQuery.textScalerOf(context);
    return width / aspect +
        7 +
        t.scale(14) * 1.25 * 2 +
        3 +
        t.scale(12) * 1.35 +
        2;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/drama/${drama.slug}/watch'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PosterArt(drama: drama, aspect: aspect, hot: rank < 3),
        const SizedBox(height: 7),
        Text(
          drama.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 3),
        if (drama.genres.isNotEmpty)
          Text(
            drama.genres.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DramaColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
      ],
    ),
  );
}

/// Staggered 2-column card: poster (alternating heights), title, genre tags.
class _FeedCard extends StatelessWidget {
  final DramaCard drama;
  final int index;
  const _FeedCard({required this.drama, required this.index});

  @override
  Widget build(BuildContext context) {
    // Alternate poster heights so the two columns interlock.
    const aspects = [3 / 4.3, 3 / 3.6, 3 / 4.0, 3 / 4.5];
    return Material(
      color: DramaColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/drama/${drama.slug}/watch'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PosterArt(
              drama: drama,
              aspect: aspects[index % aspects.length],
              radius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (drama.genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _GenreTags(drama.genres),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreTags extends StatelessWidget {
  final List<String> genres;
  const _GenreTags(this.genres);
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final g in genres.take(2))
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: DramaColors.surface2,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            g,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ),
    ],
  );
}

class _MiniTitle extends StatelessWidget {
  final String text;
  const _MiniTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Compact "continue watching" pill: thumb, title, episode and progress.
class _ContinueChip extends StatelessWidget {
  final ContinueItem item;
  const _ContinueChip({required this.item});
  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.surface,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(item.watchPath),
      child: SizedBox(
        width: 210,
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 64,
              child: DramaImage(item.drama.posterUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.drama.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.episodeNumber}-р анги',
                    style: const TextStyle(
                      color: DramaColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (item.progress / 100).clamp(0.0, 1.0),
                      minHeight: 2.5,
                      backgroundColor: Colors.white12,
                      color: LemonyBrand.rose,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Эрэмбэ (ranking) ───────────────────────────────────────────────────────

final _rankingProvider = FutureProvider.autoDispose<List<DramaCard>>((
  ref,
) async {
  final api = ref.read(dramaApiProvider);
  final first = await api.catalog(sort: 'popular');
  if (!first.hasMore) return first.items;
  final second = await api.catalog(sort: 'popular', page: 2);
  return [...first.items, ...second.items].take(30).toList();
});

class _RankingFeed extends ConsumerWidget {
  const _RankingFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_rankingProvider);
    return async.when(
      loading: () => const _FeedSkeleton(),
      error: (e, _) => ErrorRetry(
        message: '$e',
        onRetry: () => ref.invalidate(_rankingProvider),
      ),
      data: (items) => RefreshIndicator(
        color: Colors.white,
        backgroundColor: DramaColors.surface,
        onRefresh: () => ref.refresh(_rankingProvider.future),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          itemBuilder: (_, i) => _RankRow(rank: i + 1, drama: items[i]),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final DramaCard drama;
  const _RankRow({required this.rank, required this.drama});

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    const numberStyle = TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
    );
    return InkWell(
      onTap: () => context.push('/drama/${drama.slug}/watch'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _PosterArt(drama: drama, aspect: 3 / 4, showBadge: false),
                  Positioned(
                    left: 7,
                    top: 5,
                    child: top
                        ? ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) =>
                                LemonyBrand.gradient.createShader(r),
                            child: Text('$rank', style: numberStyle),
                          )
                        : Text('$rank', style: numberStyle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if ((drama.overview ?? '').isNotEmpty)
                    Text(
                      drama.overview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DramaColors.muted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _GenreTags(drama.genres),
                ],
              ),
            ),
            if (top)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: LemonyBrand.rose,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 32 - 18) / 3;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        for (var r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 9),
                  SkeletonBox(width: w, height: w / _GridPoster.aspect + 40),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
