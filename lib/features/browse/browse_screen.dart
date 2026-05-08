import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/genre_item.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/genres_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialGenre;
  final String? initialGenreLabel;
  final String? initialSort;
  final String? initialType;

  const BrowseScreen({
    super.key,
    this.initialSearch,
    this.initialGenre,
    this.initialGenreLabel,
    this.initialSort,
    this.initialType,
  });

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late String _selectedSort;
  String? _selectedType;
  String? _selectedGenre;
  String? _selectedGenreLabel;

  static const _typeOptions = [
    (null, 'Бүгд'),
    ('movie', 'Кино'),
    ('show', 'Цуврал'),
  ];

  static const _sortOptions = [
    ('popular', 'Алдартай'),
    ('new', 'Шинэ'),
    ('rating', 'Өндөр үнэлгээтэй'),
  ];

  bool get _hasActiveFilter =>
      _searchCtrl.text.trim().isNotEmpty || _selectedGenre != null;

  @override
  void initState() {
    super.initState();
    _syncInitialFilters();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant BrowseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.initialSearch != widget.initialSearch ||
        oldWidget.initialGenre != widget.initialGenre ||
        oldWidget.initialGenreLabel != widget.initialGenreLabel ||
        oldWidget.initialSort != widget.initialSort ||
        oldWidget.initialType != widget.initialType;
    if (!changed) return;
    _syncInitialFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyCurrentFilters();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(browseProvider.notifier).loadMore();
    }
  }

  void _syncInitialFilters() {
    _searchCtrl.text = widget.initialSearch ?? '';
    _selectedSort = _normalizeSort(widget.initialSort);
    _selectedType = _normalizeType(widget.initialType);
    _selectedGenre = _blankToNull(widget.initialGenre);
    _selectedGenreLabel = _blankToNull(widget.initialGenreLabel);
  }

  void _applyCurrentFilters() {
    ref.read(browseProvider.notifier).applyFilters(_currentFilters());
  }

  BrowseFilters _currentFilters() => BrowseFilters(
        search: _blankToNull(_searchCtrl.text.trim()),
        genre: _selectedGenre,
        sort: _selectedSort,
        type: _selectedType,
      );

  void _selectGenre(GenreItem genre) {
    setState(() {
      _selectedGenre = genre.slug;
      _selectedGenreLabel = genre.name;
    });
    _applyCurrentFilters();
  }

  void _clearGenre() {
    setState(() {
      _selectedGenre = null;
      _selectedGenreLabel = null;
    });
    _applyCurrentFilters();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {});
    _applyCurrentFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() {});
                _applyCurrentFilters();
              },
              onClear: _clearSearch,
            ),
            _FilterRow(
              typeOptions: _typeOptions,
              sortOptions: _sortOptions,
              selectedType: _selectedType,
              selectedSort: _selectedSort,
              selectedGenreLabel: _selectedGenreLabel,
              onTypeChanged: (t) {
                setState(() => _selectedType = t);
                _applyCurrentFilters();
              },
              onSortChanged: (s) {
                setState(() => _selectedSort = s);
                _applyCurrentFilters();
              },
              onClearGenre: _clearGenre,
            ),
            Expanded(
              child: _hasActiveFilter ? _ResultsView(scrollCtrl: _scrollCtrl) : _DiscoverView(onGenreTap: _selectGenre),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Кино, цуврал хайх...',
          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
          filled: true,
          fillColor: const Color(0xFF222222),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<(String?, String)> typeOptions;
  final List<(String, String)> sortOptions;
  final String? selectedType;
  final String selectedSort;
  final String? selectedGenreLabel;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onClearGenre;

  const _FilterRow({
    required this.typeOptions,
    required this.sortOptions,
    required this.selectedType,
    required this.selectedSort,
    required this.selectedGenreLabel,
    required this.onTypeChanged,
    required this.onSortChanged,
    required this.onClearGenre,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Type chips
          ...typeOptions.map((opt) {
            final isSelected = selectedType == opt.$1;
            return _Chip(
              label: opt.$2,
              selected: isSelected,
              onTap: () => onTypeChanged(opt.$1),
              selectedBg: Colors.white,
              selectedText: Colors.black,
            );
          }),
          const SizedBox(width: 4),
          const _Divider(),
          const SizedBox(width: 4),
          // Sort chips
          ...sortOptions.map((opt) {
            final isSelected = selectedSort == opt.$1;
            return _Chip(
              label: opt.$2,
              selected: isSelected,
              onTap: () => onSortChanged(opt.$1),
              selectedBg: AppTheme.primary,
              selectedText: Colors.white,
            );
          }),
          // Active genre chip
          if (selectedGenreLabel != null) ...[
            const SizedBox(width: 4),
            const _Divider(),
            const SizedBox(width: 4),
            _Chip(
              label: selectedGenreLabel!,
              selected: true,
              onTap: onClearGenre,
              selectedBg: AppTheme.primary,
              selectedText: Colors.white,
              trailing: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color selectedText;
  final Widget? trailing;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBg,
    required this.selectedText,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? selectedBg : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedText : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Colors.white12,
      );
}

// ─── Discover view (genre grid) ────────────────────────────────────────────────

class _DiscoverView extends ConsumerWidget {
  final ValueChanged<GenreItem> onGenreTap;

  const _DiscoverView({required this.onGenreTap});

  static const _palette = [
    Color(0xFFB91C1C), Color(0xFF1D4ED8), Color(0xFF15803D),
    Color(0xFFB45309), Color(0xFF7C3AED), Color(0xFF0E7490),
    Color(0xFFBE185D), Color(0xFF047857), Color(0xFFC2410C),
    Color(0xFF4338CA), Color(0xFF0F766E), Color(0xFF9D174D),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);

    return genresAsync.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => const ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      error: (_, __) => const Center(
        child: Text('Жанрыг ачаалж чадсангүй', style: TextStyle(color: AppTheme.textSecondary)),
      ),
      data: (genres) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Жанраар үзэх',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _GenreTile(
                  genre: genres[i],
                  color: _palette[i % _palette.length],
                  onTap: () => onGenreTap(genres[i]),
                ),
                childCount: genres.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final GenreItem genre;
  final Color color;
  final VoidCallback onTap;

  const _GenreTile({required this.genre, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.6)],
          ),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          genre.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// ─── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final ScrollController scrollCtrl;

  const _ResultsView({required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseAsync = ref.watch(browseProvider);

    return browseAsync.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => const ShimmerBox(borderRadius: BorderRadius.zero),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.textSecondary, size: 48),
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
                Icon(Icons.search_off_rounded, color: Colors.white24, size: 56),
                SizedBox(height: 12),
                Text('Илэрц олдсонгүй', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: scrollCtrl,
          slivers: [
            if (data.total > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${data.total} илэрц',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2 / 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= data.items.length) {
                      return const ShimmerBox(borderRadius: BorderRadius.zero);
                    }
                    return ContentCard(item: data.items[index], width: double.infinity);
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String? _blankToNull(String? value) {
  final t = value?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

String _normalizeSort(String? value) => switch (value) {
      'new' => 'new',
      'rating' => 'rating',
      _ => 'popular',
    };

String? _normalizeType(String? value) => switch (value) {
      'movie' => 'movie',
      'show' => 'show',
      _ => null,
    };
