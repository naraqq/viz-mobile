import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog_item.dart';
import '../../core/models/content_row.dart';
import '../../core/models/continue_watching_item.dart';
import '../../core/models/genre_item.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/genres_provider.dart';
import '../../core/providers/home_provider.dart';
import '../../core/providers/notifications_provider.dart';
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
    final unreadCount = ref.watch(notificationsProvider).unreadCount;
    final genresAsync = ref.watch(genresProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(
        mode: _mode,
        onModeChanged: (mode) => setState(() => _mode = mode),
        onCategoryTap: () => context.push('/genres'),
        unreadCount: unreadCount,
        genres: genresAsync.valueOrNull ?? [],
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
              final featuredItems =
                  home.featuredItems.where(_matchesCatalogMode).toList();
              final continueWatching =
                  home.continueWatching.where(_matchesContinueWatchingMode).toList();
              final rows = _filteredRows(home.rows);
              final hasContent = featuredItems.isNotEmpty ||
                  continueWatching.isNotEmpty ||
                  rows.isNotEmpty;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: CustomScrollView(
                  key: ValueKey(_mode),
                  slivers: [
                    // ── Hero banner ──────────────────────────────────────────
                    if (featuredItems.isNotEmpty)
                      SliverToBoxAdapter(child: HeroBanner(items: featuredItems))
                    else
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.paddingOf(context).top + 120,
                        ),
                      ),

                    // ── Continue watching ────────────────────────────────────
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
                              final user = ref.read(authProvider).user;
                              final hasAccess = item.isFree ||
                                  (item.requiresSub &&
                                      (user?.hasActiveSubscription == true)) ||
                                  (item.isRental && item.rentalActive);
                              return WideContentCard(
                                imageUrl: item.thumbnailUrl,
                                title: item.isEpisode
                                    ? '${item.showTitle ?? item.title} · S${item.seasonNumber}E${item.episodeNumber}'
                                    : item.title,
                                progress: item.progress,
                                onTap: () {
                                  if (!hasAccess && item.requiresSub) {
                                    context.push('/plans');
                                    return;
                                  }
                                  item.isMovie
                                      ? context.push('/movies/${item.slug}')
                                      : context.push('/shows/${item.slug}');
                                },
                              );
                            },
                          ),
                        ),
                      ),

                    // ── Content rows ─────────────────────────────────────────
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesCatalogMode(CatalogItem item) => switch (_mode) {
        _HomeMode.all => true,
        _HomeMode.movies => item.isMovie,
        _HomeMode.shows => item.isShow,
      };

  bool _matchesContinueWatchingMode(ContinueWatchingItem item) =>
      switch (_mode) {
        _HomeMode.all => true,
        _HomeMode.movies => item.isMovie,
        _HomeMode.shows => item.isEpisode,
      };

  List<ContentRow> _filteredRows(List<ContentRow> rows) {
    return rows
        .map((row) => ContentRow(
              label: row.label,
              items: row.items.where(_matchesCatalogMode).toList(),
            ))
        .where((row) => row.items.isNotEmpty)
        .toList();
  }
}

// ─── App bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final _HomeMode mode;
  final ValueChanged<_HomeMode> onModeChanged;
  final VoidCallback onCategoryTap;
  final int unreadCount;
  final List<GenreItem> genres;

  const _HomeAppBar({
    required this.mode,
    required this.onModeChanged,
    required this.onCategoryTap,
    required this.unreadCount,
    required this.genres,
  });

  @override
  Size get preferredSize => const Size.fromHeight(108);

  @override
  ConsumerState<_HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends ConsumerState<_HomeAppBar> {
  void _showFilterDropdown(BuildContext context, RenderBox chipBox) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final router = GoRouter.of(context);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        chipBox.localToGlobal(Offset.zero, ancestor: overlay),
        chipBox.localToGlobal(
            chipBox.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240, maxHeight: 280),
      items: widget.genres
          .map((g) => PopupMenuItem<String>(
                value: g.slug,
                height: 40,
                child: Text(
                  g.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ))
          .toList(),
    ).then((slug) {
      if (slug == null || !mounted) return;
      final genre = widget.genres.firstWhere((g) => g.slug == slug);
      router.push(
        '/genres/${genre.slug}?label=${Uri.encodeComponent(genre.name)}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD000000), Color(0x88000000), Colors.transparent],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: Bell + search ───────────────────────────────────
              SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Search
                    GestureDetector(
                      onTap: () => context.push('/browse'),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    // Notification bell
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                            if (widget.unreadCount > 0)
                              Positioned(
                                top: 4,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Text(
                                    widget.unreadCount > 99
                                        ? '99+'
                                        : '${widget.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ── Row 2: Filter chips ─────────────────────────────────────
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(
                      label: 'Бүгд',
                      selected: widget.mode == _HomeMode.all,
                      onTap: () => widget.onModeChanged(_HomeMode.all),
                    ),
                    const SizedBox(width: 7),
                    _Chip(
                      label: 'Кино',
                      selected: widget.mode == _HomeMode.movies,
                      onTap: () => widget.onModeChanged(_HomeMode.movies),
                    ),
                    const SizedBox(width: 7),
                    _Chip(
                      label: 'Цуврал',
                      selected: widget.mode == _HomeMode.shows,
                      onTap: () => widget.onModeChanged(_HomeMode.shows),
                    ),
                    const SizedBox(width: 7),
                    Builder(
                      builder: (ctx) => _Chip(
                        label: 'Ангилал',
                        icon: Icons.keyboard_arrow_down_rounded,
                        selected: false,
                        onTap: () => _showFilterDropdown(
                          context,
                          ctx.findRenderObject() as RenderBox,
                        ),
                      ),
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

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.07 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 32,
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 10 : 13,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, size: 16, color: selected ? Colors.black : Colors.white),
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
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

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
            const Icon(Icons.movie_filter_outlined,
                color: AppTheme.textSecondary, size: 48),
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
          const Icon(Icons.wifi_off_rounded,
              color: AppTheme.textSecondary, size: 52),
          const SizedBox(height: 16),
          const Text('Контент ачаалж чадсангүй',
              style: TextStyle(color: Colors.white, fontSize: 16)),
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

// ─── Enums / helpers ─────────────────────────────────────────────────────────

enum _HomeMode {
  all,
  movies,
  shows;

  String? get queryValue => switch (this) {
        _HomeMode.all => null,
        _HomeMode.movies => 'movie',
        _HomeMode.shows => 'show',
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
