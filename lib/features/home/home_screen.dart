import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog_item.dart';
import '../../core/models/content_row.dart';
import '../../core/models/continue_watching_item.dart';
import '../../core/providers/home_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/content_row_widget.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeMode _mode = _HomeMode.all;

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(
        mode: _mode,
        onModeChanged: (mode) => setState(() => _mode = mode),
        onCategoryTap: () => _showGenreSheet(context),
      ),
      body: homeAsync.when(
        loading: () => const _HomeLoading(),
        error: (error, __) => _HomeError(
          error: error,
          onRetry: () => ref.invalidate(homeProvider),
        ),
        data: (home) => RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () => ref.refresh(homeProvider.future),
          child: Builder(
            builder: (context) {
              final featuredItems = home.featuredItems
                  .where(_matchesCatalogMode)
                  .toList();
              final continueWatching = home.continueWatching
                  .where(_matchesContinueWatchingMode)
                  .toList();
              final rows = _filteredRows(home.rows);
              final hasContent =
                  featuredItems.isNotEmpty ||
                  continueWatching.isNotEmpty ||
                  rows.isNotEmpty;

              return CustomScrollView(
                slivers: [
                  // ── Hero banner ─────────────────────────────────────────────
                  if (featuredItems.isNotEmpty)
                    SliverToBoxAdapter(child: HeroBanner(items: featuredItems))
                  else
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).top + 112,
                      ),
                    ),

                  // ── Continue watching ────────────────────────────────────────
                  if (continueWatching.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _SectionLabel(label: 'Үргэлжлүүлэн үзэх'),
                    ),
                  if (continueWatching.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: continueWatching.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final item = continueWatching[i];
                            return WideContentCard(
                              imageUrl: item.thumbnailUrl,
                              title: item.isEpisode
                                  ? '${item.showTitle ?? item.title} · S${item.seasonNumber}E${item.episodeNumber}'
                                  : item.title,
                              progress: item.progress,
                              onTap: () => item.isMovie
                                  ? context.push('/movies/${item.slug}')
                                  : context.push('/shows/${item.slug}'),
                            );
                          },
                        ),
                      ),
                    ),

                  // ── Content rows ─────────────────────────────────────────────
                  SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => ContentRowWidget(row: rows[i]),
                  ),

                  if (!hasContent)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyModeState(
                        label: _mode.emptyLabel,
                        onBrowse: () =>
                            context.go(_browseLocation(mode: _mode)),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesCatalogMode(CatalogItem item) {
    return switch (_mode) {
      _HomeMode.all => true,
      _HomeMode.movies => item.isMovie,
      _HomeMode.shows => item.isShow,
    };
  }

  bool _matchesContinueWatchingMode(ContinueWatchingItem item) {
    return switch (_mode) {
      _HomeMode.all => true,
      _HomeMode.movies => item.isMovie,
      _HomeMode.shows => item.isEpisode,
    };
  }

  List<ContentRow> _filteredRows(List<ContentRow> rows) {
    return rows
        .map(
          (row) => ContentRow(
            label: row.label,
            items: row.items.where(_matchesCatalogMode).toList(),
          ),
        )
        .where((row) => row.items.isNotEmpty)
        .toList();
  }

  void _showGenreSheet(BuildContext context) => context.push('/genres');

}

// ─── App bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final _HomeMode mode;
  final ValueChanged<_HomeMode> onModeChanged;
  final VoidCallback onCategoryTap;

  const _HomeAppBar({
    required this.mode,
    required this.onModeChanged,
    required this.onCategoryTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(106);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () => context.go('/browse'),
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _HomeFilterChip(
                      label: 'Бүгд',
                      selected: mode == _HomeMode.all,
                      onTap: () => onModeChanged(_HomeMode.all),
                    ),
                    const SizedBox(width: 8),
                    _HomeFilterChip(
                      label: 'Кино',
                      selected: mode == _HomeMode.movies,
                      onTap: () => onModeChanged(_HomeMode.movies),
                    ),
                    const SizedBox(width: 8),
                    _HomeFilterChip(
                      label: 'Цуврал',
                      selected: mode == _HomeMode.shows,
                      onTap: () => onModeChanged(_HomeMode.shows),
                    ),
                    const SizedBox(width: 8),
                    _HomeFilterChip(
                      label: 'Ангилал',
                      icon: Icons.keyboard_arrow_down_rounded,
                      selected: false,
                      onTap: onCategoryTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _HomeFilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.white : Colors.white54,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.black : Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyModeState extends StatelessWidget {
  final String label;
  final VoidCallback onBrowse;

  const _EmptyModeState({required this.label, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.movie_filter_outlined,
              color: AppTheme.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onBrowse,
              child: const Text('Бүгдийг үзэх'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading state ────────────────────────────────────────────────────────────

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeroBannerShimmer(),
          const SizedBox(height: 4),
          ...List.generate(3, (_) => const ContentRowShimmer()),
        ],
      ),
    );
  }
}

enum _HomeMode {
  all,
  movies,
  shows;

  String? get queryValue => switch (this) {
    _HomeMode.all => null,
    _HomeMode.movies => 'movie',
    _HomeMode.shows => 'show',
  };

  String get categoryTitle => switch (this) {
    _HomeMode.all => 'Бүх',
    _HomeMode.movies => 'Киноны',
    _HomeMode.shows => 'Цувралын',
  };

  String get emptyLabel => switch (this) {
    _HomeMode.all => 'Одоогоор контент алга',
    _HomeMode.movies => 'Одоогоор кино алга',
    _HomeMode.shows => 'Одоогоор цуврал алга',
  };
}

String _browseLocation({_HomeMode mode = _HomeMode.all}) {
  final type = mode.queryValue;
  final params = type != null ? {'type': type} : <String, String>{};
  return Uri(
    path: '/browse',
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _HomeError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _HomeError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'Контент ачаалж чадсангүй',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Интернэт холболтоо шалгаад дахин оролдоно уу',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Дахин оролдох'),
          ),
        ],
      ),
    );
  }
}
