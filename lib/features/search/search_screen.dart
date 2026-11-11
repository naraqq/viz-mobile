import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/genres_provider.dart';
import '../../shared/widgets/lemony_logo.dart';
import '../drama/drama_api.dart';
import '../drama/drama_models.dart';
import '../drama/widgets/drama_widgets.dart';

/// Recent search terms, newest first, kept on the device.
class _Recents {
  static const _key = 'recent_searches';
  static const _max = 10;
  static const _storage = FlutterSecureStorage();

  static Future<List<String>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => '$e').toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<String> items) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(items));
    } catch (_) {}
  }
}

/// Most popular dramas, shown as "trending" before the user types.
final _trendingProvider = FutureProvider.autoDispose<List<DramaCard>>((
  ref,
) async {
  final r = await ref.read(dramaApiProvider).catalog(sort: 'popular');
  return r.items.take(10).toList();
});

/// Dedicated search: recent searches, trending and genres when empty; live results while
/// typing (debounced), paged as the list scrolls.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<String> _recents = [];
  String _query = '';
  final List<DramaCard> _results = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _Recents.load().then((r) {
      if (mounted) setState(() => _recents = r);
    });
    _scroll.addListener(() {
      if (_query.isNotEmpty &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {}); // clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(text));
  }

  void _run(String text) {
    final q = text.trim();
    if (q == _query) return;
    _generation++;
    setState(() {
      _query = q;
      _results.clear();
      _page = 1;
      _hasMore = q.isNotEmpty;
      _error = null;
      _loading = false;
    });
    if (q.isNotEmpty) _fetch();
  }

  Future<void> _fetch() async {
    if (_loading || !_hasMore || _query.isEmpty) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(dramaApiProvider)
          .catalog(page: _page, search: _query);
      if (!mounted || gen != _generation) return;
      setState(() {
        _results.addAll(r.items);
        _hasMore = r.hasMore;
        _page++;
      });
    } on DramaException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _remember(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final next = [
      t,
      ..._recents.where((r) => r.toLowerCase() != t.toLowerCase()),
    ].take(_Recents._max).toList();
    setState(() => _recents = next);
    _Recents.save(next);
  }

  void _useTerm(String term) {
    _field.text = term;
    _field.selection = TextSelection.collapsed(offset: term.length);
    _debounce?.cancel();
    _run(term);
    _remember(term);
    _focus.unfocus();
  }

  void _open(DramaCard d) {
    _remember(_query);
    _focus.unfocus();
    context.push('/drama/${d.slug}/watch');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DramaColors.bg,
        body: Column(
          children: [
            SizedBox(height: pad.top + 8),
            _searchBar(),
            Expanded(
              child: GestureDetector(
                onTap: () => _focus.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _query.isEmpty
                      ? _Discover(
                          key: const ValueKey('discover'),
                          recents: _recents,
                          onTerm: _useTerm,
                          onRemove: (t) {
                            final next = [..._recents]..remove(t);
                            setState(() => _recents = next);
                            _Recents.save(next);
                          },
                          onClear: () {
                            setState(() => _recents = []);
                            _Recents.save(const []);
                          },
                          onOpen: _open,
                        )
                      : _resultsView(pad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        Expanded(
          child: Hero(
            tag: 'drama-search',
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (t) {
                  _debounce?.cancel();
                  _run(t);
                  _remember(t);
                },
                textInputAction: TextInputAction.search,
                cursorColor: LemonyBrand.rose,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Драмын нэрээр хайх',
                  hintStyle: const TextStyle(color: DramaColors.faint),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: DramaColors.muted,
                  ),
                  suffixIcon: _field.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: DramaColors.muted,
                            size: 20,
                          ),
                          onPressed: () {
                            _field.clear();
                            _debounce?.cancel();
                            _run('');
                            _focus.requestFocus();
                          },
                        ),
                  filled: true,
                  fillColor: DramaColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: LemonyBrand.rose.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _resultsView(EdgeInsets pad) {
    if (_results.isEmpty && _loading) {
      return ListView(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: List.generate(
          6,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SkeletonBox(width: 72, height: 100),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 14),
                      SizedBox(height: 10),
                      SkeletonBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty && _error != null) {
      return ErrorRetry(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: () {
          final q = _query;
          _query = '';
          _run(q);
        },
      );
    }
    if (_results.isEmpty) {
      return _NoResults(key: const ValueKey('empty'), query: _query);
    }
    return ListView.builder(
      key: ValueKey('results-$_query'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 4, 16, pad.bottom + 24),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }
        final d = _results[i];
        return _ResultTile(drama: d, query: _query, onTap: () => _open(d));
      },
    );
  }
}

// ─── Before typing: recent, trending, genres ────────────────────────────────

class _Discover extends ConsumerWidget {
  final List<String> recents;
  final ValueChanged<String> onTerm;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final ValueChanged<DramaCard> onOpen;
  const _Discover({
    super.key,
    required this.recents,
    required this.onTerm,
    required this.onRemove,
    required this.onClear,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(_trendingProvider);
    final genres = ref.watch(genresProvider).valueOrNull ?? const [];
    final pad = MediaQuery.of(context).padding;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: pad.bottom + 24),
      children: [
        if (recents.isNotEmpty) ...[
          _Title(
            'Сүүлд хайсан',
            action: TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: DramaColors.muted),
              child: const Text('Арилгах', style: TextStyle(fontSize: 13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in recents)
                  _RecentChip(
                    text: r,
                    onTap: () => onTerm(r),
                    onRemove: () => onRemove(r),
                  ),
              ],
            ),
          ),
        ],
        const _Title('Түгээмэл'),
        ...trending.when(
          loading: () => List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SkeletonBox(height: 64),
            ),
          ),
          error: (_, __) => const [],
          data: (items) => [
            for (var i = 0; i < items.length; i++)
              _TrendingRow(
                rank: i + 1,
                drama: items[i],
                onTap: () => onOpen(items[i]),
              ),
          ],
        ),
        if (genres.isNotEmpty) ...[
          const _Title('Төрлөөр хайх'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genres)
                  ActionChip(
                    label: Text(g.name),
                    onPressed: () => context.go(
                      '/dramas?genre=${Uri.encodeComponent(g.slug)}',
                    ),
                    backgroundColor: DramaColors.surface,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Title(this.text, {this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 22, action == null ? 16 : 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _RecentChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _RecentChip({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              color: DramaColors.faint,
              size: 16,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: DramaColors.faint,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrendingRow extends StatelessWidget {
  final int rank;
  final DramaCard drama;
  final VoidCallback onTap;
  const _TrendingRow({
    required this.rank,
    required this.drama,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    final number = Text(
      '$rank',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: top
                  ? ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) =>
                          LemonyBrand.gradient.createShader(r),
                      child: number,
                    )
                  : Opacity(opacity: 0.45, child: number),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 60,
                child: DramaImage(drama.posterUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (drama.episodes > 0) '${drama.episodes} анги',
                      ...drama.genres.take(2),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DramaColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (top)
              const Icon(
                Icons.local_fire_department_rounded,
                color: LemonyBrand.rose,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Results ────────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final DramaCard drama;
  final String query;
  final VoidCallback onTap;
  const _ResultTile({
    required this.drama,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 100,
              child: DramaImage(drama.posterUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Highlighted(text: drama.title, query: query),
                const SizedBox(height: 5),
                if (drama.genres.isNotEmpty)
                  Text(
                    drama.genres.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DramaColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (drama.isFree) ...[
                      const _Tag('Үнэгүй', highlight: true),
                      const SizedBox(width: 6),
                    ],
                    if (drama.episodes > 0) _Tag('${drama.episodes} анги'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LemonyBrand.gradient,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Title with the matched part of [query] in the brand colour.
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;
  const _Highlighted({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final i = query.isEmpty
        ? -1
        : text.toLowerCase().indexOf(query.toLowerCase());
    if (i < 0) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + query.length),
            style: const TextStyle(color: LemonyBrand.rose),
          ),
          TextSpan(text: text.substring(i + query.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool highlight;
  const _Tag(this.text, {this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: highlight ? LemonyBrand.gradient : null,
      color: highlight ? null : DramaColors.surface2,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({super.key, required this.query});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: DramaColors.faint,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            '"$query" олдсонгүй',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Өөр үгээр, эсвэл драмын англи нэрээр хайгаад үзээрэй.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DramaColors.muted, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
