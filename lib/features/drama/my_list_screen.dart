import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/lemony_logo.dart';
import 'drama_api.dart';
import 'drama_models.dart';
import 'widgets/drama_widgets.dart';

/// Жагсаалт: "Үргэлжлүүлэх" (continue watching) first, then the "Хадгалсан" (saved) grid.
class MyListScreen extends ConsumerWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myListProvider);
    final pad = MediaQuery.of(context).padding;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: DramaColors.bg,
          body: Column(
            children: [
              SizedBox(height: pad.top + 8),
              SizedBox(
                height: 48,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Үргэлжлүүлэх'),
                    Tab(text: 'Хадгалсан'),
                  ],
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  error: (e, _) => ErrorRetry(
                    message: 'Жагсаалтыг ачаалж чадсангүй.',
                    onRetry: () => ref.invalidate(myListProvider),
                  ),
                  data: (lib) => TabBarView(
                    children: [
                      _HistoryList(
                        items: lib.history,
                        onRefresh: () => ref.refresh(myListProvider.future),
                      ),
                      _SavedGrid(
                        items: lib.saved,
                        onRefresh: () => ref.refresh(myListProvider.future),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedGrid extends StatelessWidget {
  final List<DramaCard> items;
  final Future<Object?> Function() onRefresh;
  const _SavedGrid({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.bookmark_border_rounded,
        title: 'Хадгалсан драм алга',
        text: 'Драм үзэж байхдаа хадгалах товчийг дараарай.',
      );
    }
    final cell = (MediaQuery.sizeOf(context).width - 32 - 18) / 3;
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: DramaColors.surface,
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 9,
          mainAxisSpacing: 14,
          mainAxisExtent: DramaPoster.cardHeight(context, cell),
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => DramaPoster(drama: items[i], width: cell),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ContinueItem> items;
  final Future<Object?> Function() onRefresh;
  const _HistoryList({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.history_rounded,
        title: 'Үзсэн түүх хоосон',
        text: 'Үзсэн драмууд тань энд харагдана.',
      );
    }
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: DramaColors.surface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final total = it.drama.episodes;
          return InkWell(
            onTap: () => context.push(it.watchPath),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 78,
                      height: 104,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DramaImage(it.drama.posterUrl),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: (it.progress / 100).clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              color: LemonyBrand.rose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.drama.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          total > 0
                              ? '${it.episodeNumber}-р анги / $total'
                              : '${it.episodeNumber}-р анги',
                          style: const TextStyle(
                            color: DramaColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LemonyBrand.gradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Үзэх',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Empty({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DramaColors.faint, size: 54),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DramaColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: DramaColors.faint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Драм үзэх'),
          ),
        ],
      ),
    ),
  );
}
