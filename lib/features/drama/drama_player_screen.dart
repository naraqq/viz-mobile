import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'drama_api.dart';
import 'drama_models.dart';
import 'video/short_video_view.dart';
import 'video/snappy_page_physics.dart';
import 'video/video_pool.dart';
import 'widgets/coin_store.dart';
import 'widgets/drama_widgets.dart';

/// Full-screen vertical player for one drama: swipe up for the next episode.
///
/// Smooth swiping, both ways:
///  - the next episode is buffered with its first frame already decoded, so it appears
///    the instant it slides in; the previous one stays alive for swiping back
///  - stream links are fetched two episodes ahead, so fast swiping never waits on the API
///  - at most 3 decoders (previous, current, next) — phones only have a few
/// Locked episodes show an unlock card in place.
class DramaPlayerScreen extends ConsumerStatefulWidget {
  final String slug;
  final int? startEpisodeId;
  const DramaPlayerScreen({super.key, required this.slug, this.startEpisodeId});

  @override
  ConsumerState<DramaPlayerScreen> createState() => _DramaPlayerScreenState();
}

class _DramaPlayerScreenState extends ConsumerState<DramaPlayerScreen>
    with WidgetsBindingObserver {
  final _pool = VideoPool();
  DramaDetail? _detail;
  List<DramaEpisode> _eps = [];
  PageController? _page;
  int _index = 0;
  String? _loadError;

  final Map<int, EpisodePlay> _plays = {};
  final Map<int, VideoPlayerController> _ctrls = {};
  final Map<int, String> _errors = {};
  final Set<int> _fetching = {};
  final Set<int> _retried = {};

  bool _liked = false;
  bool _saved = false;
  int _likes = 0;
  bool _appPaused = false;
  bool _unlocking = false;
  String? _unlockError;
  Timer? _progressTimer;

  // Read once: progress is also saved from dispose/timers, when `ref` can't be used.
  late final DramaApi _api = ref.read(dramaApiProvider);
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api; // initialise while `ref` is usable
    _container = ProviderScope.containerOf(context, listen: false);
    WakelockPlus.enable();
    _load();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveProgress(_index),
    );
  }

  @override
  void dispose() {
    // Save the position, then refresh Continue Watching / lists so they're current the
    // moment the viewer is back (ref can't be used after dispose, hence the container).
    final container = _container;
    _saveProgress(_index).whenComplete(() => refreshWatchState(container));
    _progressTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pool.dispose();
    _page?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = state != AppLifecycleState.resumed;
    if (paused) {
      _saveProgress(_index);
      _pool.pauseAll();
    }
    if (mounted) setState(() => _appPaused = paused);
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final d = await _api.detail(widget.slug);
      if (!mounted) return;
      // A specific episode was asked for (Continue Watching, Shorts); otherwise resume
      // where the viewer left off.
      var start = d.resumeIndex;
      if (widget.startEpisodeId != null) {
        final i = d.episodes.indexWhere((e) => e.id == widget.startEpisodeId);
        if (i >= 0) start = i;
      }
      ref.read(coinBalanceProvider.notifier).state = d.access.coinBalance;
      setState(() {
        _detail = d;
        _eps = List.of(d.episodes);
        _liked = d.liked;
        _saved = d.saved;
        _likes = d.likes;
        _index = start;
        _page = PageController(initialPage: start);
      });
      _activate(start);
    } on DramaException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  // ── Paging & preloading ─────────────────────────────────────────────────

  Set<int> _window() => {
    for (final j in [_index - 1, _index, _index + 1])
      if (j >= 0 && j < _eps.length) _eps[j].id,
  };

  /// Fires at the halfway point of a swipe, while the page is still moving: only cheap
  /// work here (switch which episode plays). Anything that creates or frees players
  /// waits for [_onScroll] to see the swipe settle, so the animation never stutters.
  void _onPage(int i) {
    if (i == _index) return;
    _saveProgress(_index);
    HapticFeedback.selectionClick();
    // Pausing/playing is left to each page's `active` flag, so a quick back-and-forth
    // swipe can't leave the current episode paused.
    setState(() {
      _index = i;
      _unlockError = null;
    });
    // Not buffered yet (very fast swiping): start it now rather than after settling.
    if (!_ctrls.containsKey(_eps[i].id)) _ensure(i);
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification && n.depth == 0) _activate(_index);
    return false;
  }

  /// Heavy part, once the swipe has settled: free far players, buffer the neighbours.
  void _activate(int i) {
    _index = i;
    _unlockError = null;
    final keep = _window();
    _pool.pauseOthers(_eps[i].id);
    _ctrls.removeWhere((id, _) => !keep.contains(id));
    _pool.keepOnly(keep);
    // Current first, then the way people usually swipe (forward), then back.
    _ensure(i).then((_) {
      if (!mounted || _index != i) return;
      _ensure(i + 1);
      _ensure(i - 1);
    });
    _prefetchPlay(i + 2);
    setState(() {});
  }

  /// Fetch an episode's stream link ahead of time (no decoder), so it's ready to buffer.
  Future<void> _prefetchPlay(int i) async {
    if (i < 0 || i >= _eps.length) return;
    final ep = _eps[i];
    if (_plays.containsKey(ep.id) || _fetching.contains(ep.id)) return;
    _fetching.add(ep.id);
    try {
      final play = await _api.play(ep.id);
      _plays[ep.id] = play;
      if (play.locked != ep.isLocked && mounted) {
        setState(() => _eps[i] = ep.copyWith(isLocked: play.locked));
      }
    } catch (_) {
      // Fetched again normally when the viewer gets there.
    } finally {
      _fetching.remove(ep.id);
    }
  }

  Future<void> _ensure(int i) async {
    if (i < 0 || i >= _eps.length) return;
    final ep = _eps[i];
    if (_ctrls.containsKey(ep.id)) return;
    // A prefetch for this episode is in flight: wait for it instead of asking twice.
    while (_fetching.contains(ep.id)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    if (_ctrls.containsKey(ep.id)) return;

    var play = _plays[ep.id];
    if (play == null) {
      _fetching.add(ep.id);
      try {
        try {
          play = await _api.play(ep.id);
        } on DramaException {
          // The provider link sometimes fails once; a second ask usually works.
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          play = await _api.play(ep.id);
        }
        _plays[ep.id] = play;
        _errors.remove(ep.id);
        if (play.locked != ep.isLocked) {
          _eps[i] = ep.copyWith(isLocked: play.locked);
        }
      } on DramaException catch (e) {
        _errors[ep.id] = e.message;
      } finally {
        _fetching.remove(ep.id);
      }
      if (!mounted) return;
      setState(() {});
      if (play == null) return;
    }

    final url = play.url;
    if (play.locked || url == null) return;

    final c = await _pool.obtain(ep.id, url, warm: i != _index);
    if (!mounted) return;
    if (c == null) {
      // Released because the viewer swiped away — not a playback failure.
      if (!_window().contains(ep.id)) return;
      // Retry once with a fresh link (it may have expired), then show the error.
      if (_retried.add(ep.id)) {
        _plays.remove(ep.id);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) return _ensure(i);
        return;
      }
      setState(() => _errors[ep.id] = 'Видеог нээж чадсангүй.');
      return;
    }
    if ((i - _index).abs() > 1) {
      // Swiped far away while it was buffering: free its decoder now.
      _pool.keepOnly(_window());
      return;
    }
    // Resume where the viewer stopped (not in the last few seconds).
    final pos = play.positionSeconds;
    if (pos > 3 &&
        pos < c.value.duration.inSeconds - 5 &&
        c.value.position == Duration.zero) {
      await c.seekTo(Duration(seconds: pos));
    }
    if (!mounted) return;
    setState(() => _ctrls[ep.id] = c);
  }

  Future<void> _saveProgress(int i) async {
    if (i < 0 || i >= _eps.length) return;
    final c = _ctrls[_eps[i].id];
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inSeconds;
    if (pos < 2) return;
    await _api.saveProgress(_eps[i].id, pos, c.value.duration.inSeconds);
  }

  void _next() {
    if (_index + 1 < _eps.length) {
      _page?.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ── Unlock ──────────────────────────────────────────────────────────────

  Future<void> _unlock(DramaEpisode ep) async {
    setState(() {
      _unlocking = true;
      _unlockError = null;
    });
    try {
      final balance = await _api.unlock(ep.id);
      ref.read(coinBalanceProvider.notifier).state = balance;
      _plays.remove(ep.id);
      final i = _eps.indexWhere((e) => e.id == ep.id);
      if (i >= 0) _eps[i] = ep.copyWith(isLocked: false);
      await _ensure(i);
    } on DramaException catch (e) {
      if (e.code == 'insufficient_coins' && mounted) {
        await showCoinStoreSheet(context);
      } else if (mounted) {
        setState(() => _unlockError = e.message);
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  // ── Engagement ──────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    final d = _detail;
    if (d == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final r = await _api.toggleLike(d.drama.id);
      if (mounted) {
        setState(() {
          _liked = r.liked;
          _likes = r.likes;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final d = _detail;
    if (d == null) return;
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
    try {
      final s = await _api.toggleSave(d.drama.id);
      if (mounted) setState(() => _saved = s);
    } catch (_) {}
  }

  void _openEpisodes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DramaColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EpisodeGridSheet(
        title: _detail?.drama.title ?? '',
        overview: _detail?.drama.overview,
        posterUrl: _detail?.drama.posterUrl,
        genres: _detail?.drama.genres ?? const [],
        episodes: _eps,
        current: _index,
        onPick: (i) {
          Navigator.of(context).pop();
          _page?.jumpToPage(i);
        },
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final pad = MediaQuery.of(context).padding;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: d == null
            ? Stack(
                children: [
                  if (_loadError != null)
                    ErrorRetry(message: _loadError!, onRetry: _load)
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  _backButton(pad),
                ],
              )
            : _eps.isEmpty
            ? Stack(
                children: [
                  const Center(
                    child: Text(
                      'Анги одоогоор алга.',
                      style: TextStyle(color: DramaColors.muted),
                    ),
                  ),
                  _backButton(pad),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: PageView.builder(
                  controller: _page,
                  scrollDirection: Axis.vertical,
                  physics: const SnappyPagePhysics(),
                  itemCount: _eps.length,
                  onPageChanged: _onPage,
                  itemBuilder: (context, i) => _episodePage(d, i, pad),
                ),
              ),
      ),
    );
  }

  Widget _backButton(EdgeInsets pad) => Positioned(
    top: pad.top + 4,
    left: 4,
    child: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      onPressed: () => context.pop(),
    ),
  );

  Widget _episodePage(DramaDetail d, int i, EdgeInsets pad) {
    final ep = _eps[i];
    final play = _plays[ep.id];
    final locked = play?.locked ?? ep.isLocked;
    final poster = ep.stillUrl ?? d.drama.posterUrl;
    final balance = ref.watch(coinBalanceProvider) ?? d.access.coinBalance;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (locked)
          Stack(
            fit: StackFit.expand,
            children: [
              DramaImage(poster),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ],
          )
        else
          ShortVideoView(
            controller: _ctrls[ep.id],
            posterUrl: poster,
            // No spinner behind an error message.
            active: i == _index && !_appPaused && _errors[ep.id] == null,
            onEnded: _next,
            onDoubleTap: () {
              if (!_liked) _toggleLike();
            },
            bottomInset: pad.bottom,
          ),
        const Align(
          alignment: Alignment.topCenter,
          child: ScrimGradient(top: true, height: 140),
        ),
        const Align(alignment: Alignment.bottomCenter, child: ScrimGradient()),

        // Top bar
        Positioned(
          top: pad.top + 4,
          left: 4,
          right: 16,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  d.drama.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right action rail (hidden behind the unlock card on locked episodes)
        if (!locked)
          Positioned(
            right: 8,
            bottom: pad.bottom + 120,
            child: Column(
              children: [
                RailButton(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? DramaColors.accent : Colors.white,
                  label: _likes > 0 ? '$_likes' : 'Таалагдсан',
                  onTap: _toggleLike,
                ),
                RailButton(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _saved ? DramaColors.gold : Colors.white,
                  label: _saved ? 'Хадгалсан' : 'Хадгалах',
                  onTap: _toggleSave,
                ),
                RailButton(
                  icon: Icons.video_library_rounded,
                  label: 'Ангиуд',
                  onTap: _openEpisodes,
                ),
              ],
            ),
          ),

        // Bottom info
        Positioned(
          left: 16,
          right: 80,
          bottom: pad.bottom + 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _openEpisodes,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${ep.number}-р анги  ·  нийт ${_eps.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
              // The story pitch only on the first episode; later ones stay clean
              // (the full description is always in the episodes sheet).
              if (i == 0 && (d.drama.overview ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                ExpandableCaption(d.drama.overview!),
              ],
            ],
          ),
        ),

        if (locked)
          Center(
            child: UnlockPanel(
              episodeNumber: ep.number,
              price:
                  play?.episode.coinPrice ??
                  ep.coinPrice ??
                  d.access.episodeCoinPrice,
              balance: balance,
              busy: _unlocking,
              error: i == _index ? _unlockError : null,
              onUnlock: () => _unlock(ep),
              onBuyCoins: () => showCoinStoreSheet(context),
              onVip: () => context.go('/vip'),
            ),
          )
        else if (_errors[ep.id] != null && _ctrls[ep.id] == null)
          Center(
            child: ErrorRetry(
              message: _errors[ep.id]!,
              onRetry: () {
                setState(() {
                  _errors.remove(ep.id);
                  _plays.remove(ep.id);
                });
                _ensure(i);
              },
            ),
          ),
      ],
    );
  }
}

/// Episode picker: ranges of 30 with a 5-column grid; locked episodes show a lock.
class EpisodeGridSheet extends StatefulWidget {
  final String title;
  final String? overview;
  final String? posterUrl;
  final List<String> genres;
  final List<DramaEpisode> episodes;
  final int current;
  final ValueChanged<int> onPick;
  const EpisodeGridSheet({
    super.key,
    required this.title,
    this.overview,
    this.posterUrl,
    this.genres = const [],
    required this.episodes,
    required this.current,
    required this.onPick,
  });

  @override
  State<EpisodeGridSheet> createState() => _EpisodeGridSheetState();
}

class _EpisodeGridSheetState extends State<EpisodeGridSheet> {
  static const _chunk = 30;
  late int _range = widget.current ~/ _chunk;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final eps = widget.episodes;
    final ranges = (eps.length / _chunk).ceil();
    final start = _range * _chunk;
    final slice = eps.sublist(start, (start + _chunk).clamp(0, eps.length));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DramaColors.faint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Drama info (replaces the separate detail page).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.posterUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 54,
                        height: 74,
                        child: DramaImage(widget.posterUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [
                            'Нийт ${eps.length} анги',
                            ...widget.genres.take(2),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DramaColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((widget.overview ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Text(
                      widget.overview!,
                      maxLines: _expanded ? 12 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
              if (ranges > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ranges,
                    separatorBuilder: (_, __) => const SizedBox(width: 18),
                    itemBuilder: (_, r) {
                      final a = r * _chunk + 1;
                      final b = ((r + 1) * _chunk).clamp(0, eps.length);
                      final sel = r == _range;
                      return GestureDetector(
                        onTap: () => setState(() => _range = r),
                        child: Text(
                          '$a-$b',
                          style: TextStyle(
                            color: sel ? Colors.white : DramaColors.muted,
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: EpisodeGrid(
                  episodes: slice,
                  offset: start,
                  current: widget.current,
                  onPick: widget.onPick,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EpisodeGrid extends StatelessWidget {
  final List<DramaEpisode> episodes;
  final int offset;
  final int current;
  final ValueChanged<int> onPick;
  final bool scrollable;
  const EpisodeGrid({
    super.key,
    required this.episodes,
    required this.offset,
    required this.current,
    required this.onPick,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: !scrollable,
    physics: scrollable ? null : const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.15,
    ),
    itemCount: episodes.length,
    itemBuilder: (_, k) {
      final ep = episodes[k];
      final i = offset + k;
      final isCurrent = i == current;
      return Material(
        color: isCurrent ? null : DramaColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: isCurrent
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x55FB7185), Color(0x55F59E0B)],
                  ),
                  border: Border.all(color: DramaColors.accent),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onPick(i),
            child: Stack(
              children: [
                Center(
                  child: isCurrent
                      ? const Icon(
                          Icons.equalizer_rounded,
                          color: Colors.white,
                          size: 22,
                        )
                      : Text(
                          '${ep.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (ep.isLocked)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: DramaColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
