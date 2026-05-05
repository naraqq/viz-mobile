import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/browse_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _syncInitialFilters();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyCurrentFilters();
    });
  }

  @override
  void didUpdateWidget(covariant BrowseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.initialSearch != widget.initialSearch ||
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
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
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

  void _applySearch(String value) {
    setState(() {});
    _applyCurrentFilters();
  }

  void _applySort(String sort) {
    setState(() => _selectedSort = sort);
    _applyCurrentFilters();
  }

  void _applyType(String? type) {
    setState(() => _selectedType = type);
    _applyCurrentFilters();
  }

  void _clearGenre() {
    setState(() {
      _selectedGenre = null;
      _selectedGenreLabel = null;
    });
    _applyCurrentFilters();
  }

  void _applyCurrentFilters() {
    ref.read(browseProvider.notifier).applyFilters(_currentFilters());
  }

  BrowseFilters _currentFilters() {
    return BrowseFilters(
      search: _blankToNull(_searchCtrl.text.trim()),
      genre: _selectedGenre,
      sort: _selectedSort,
      type: _selectedType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final browseAsync = ref.watch(browseProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Кино, цуврал хайх...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.zero,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applySearch('');
                    },
                  )
                : null,
          ),
          onChanged: _applySearch,
          onSubmitted: _applySearch,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ..._typeOptions.map((opt) {
                  final isSelected = _selectedType == opt.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt.$2),
                      selected: isSelected,
                      onSelected: (_) => _applyType(opt.$1),
                      backgroundColor: AppTheme.surface,
                      selectedColor: Colors.white,
                      checkmarkColor: Colors.black,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide.none,
                    ),
                  );
                }),
                if (_selectedGenre != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(
                        _selectedGenreLabel ??
                            _genreLabelFromSlug(_selectedGenre!),
                      ),
                      selected: true,
                      onDeleted: _clearGenre,
                      deleteIconColor: Colors.white,
                      backgroundColor: AppTheme.primary,
                      selectedColor: AppTheme.primary,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),

          // Sort chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _sortOptions.map((opt) {
                final isSelected = _selectedSort == opt.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt.$2),
                    selected: isSelected,
                    onSelected: (_) => _applySort(opt.$1),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),

          // Results
          Expanded(
            child: browseAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(16),
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
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(browseProvider.notifier).fetch(),
                      child: const Text('Дахин оролдох'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Илэрц олдсонгүй',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return GridView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: data.items.length + (data.hasMore ? 3 : 0),
                  itemBuilder: (context, index) {
                    if (index >= data.items.length) {
                      return const ShimmerBox(borderRadius: BorderRadius.zero);
                    }
                    return ContentCard(
                      item: data.items[index],
                      width: double.infinity,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _normalizeSort(String? value) {
  return switch (value) {
    'new' => 'new',
    'rating' => 'rating',
    _ => 'popular',
  };
}

String? _normalizeType(String? value) {
  return switch (value) {
    'movie' => 'movie',
    'show' => 'show',
    _ => null,
  };
}

String _genreLabelFromSlug(String slug) {
  return slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
