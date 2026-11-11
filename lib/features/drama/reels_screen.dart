import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../shared/widgets/lemony_logo.dart';
import '../rewards/rewards_api.dart';
import 'drama_api.dart';
import 'drama_models.dart';
import 'video/short_video_view.dart';
import 'video/snappy_page_physics.dart';
import 'video/video_pool.dart';
import 'widgets/drama_widgets.dart';

/// Reels: swipe through the first episode of every drama. Each one loops; "Бүх анги үзэх"
/// continues in the full player from where the viewer is.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver {
  final _pool = VideoPool();
  final _page = PageController();
  final List<FeedItem> _items = [];
  final Map<int, VideoPlayerController> _ctrls = {};

  /// Provider-hosted episodes (APIShort) come without a stream in the feed: their link is
  /// resolved by /episodes/{id}/play on demand. Resolved links (short-lived, so dropped
  /// whenever Reels is covered) and episodes that turned out unplayable, by episode id.
  final Map<int, String> _resolved = {};
  final Set<int> _resolving = {};
  final Set<int> _unplayable = {};
  final Set<int> _retried = {};
  final Map<int, bool> _liked = {};
  final Map<int, bool> _saved = {};
  int? _nextPage = 1;
  bool _loadingMore = false;
  String? _error;
  int _index = 0;
  bool _covered = false; // another screen is on top
  bool _appPaused = false;

  // Read once: progress is also saved from dispose, when `ref` can't be used.
  late final DramaApi _api = ref.read(dramaApiProvider);
  late final RewardsApi _rewards = ref.read(rewardsApiProvider);

  /// Watch-time heartbeat for reward tasks: only while a video is really playing.
  Timer? _beatTimer;
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api; // initialise while `ref` is usable
    _rewards;
    _beatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_covered || _items.isEmpty || _index >= _items.length) return;
      if (_ctrls[_key(_index)]?.value.isPlaying ?? false) _rewards.heartbeat();
    });
    _container = ProviderScope.containerOf(context, listen: false);
    WakelockPlus.enable();
    _loadMore();
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    // Save the position, then refresh Continue Watching / lists so they're current the
    // moment the viewer is back (ref can't be used after dispose, hence the container).
    final container = _container;
    _saveProgress(_index).whenComplete(() => refreshWatchState(container));
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pool.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = state != AppLifecycleState.resumed;
    if (paused) _pool.pauseAll();
    if (mounted) setState(() => _appPaused = paused);
  }

  Future<void> _loadMore() async {
    final page = _nextPage;
    if (page == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final r = await _api.feed(page: page);
      if (!mounted) return;
      final wasEmpty = _items.isEmpty;
      setState(() {
        _items.addAll(r.items);
        _nextPage = r.nextPage;
        _error = null;
      });
      if (wasEmpty && _items.isNotEmpty) _activate(0);
    } on DramaException catch (e) {
      if (mounted && _items.isEmpty) setState(() => _error = e.message);
    } finally {
      _loadingMore = false;
    }
  }

  int _key(int i) => _items[i].episode.id;

  /// Halfway through a swipe: only switch which reel plays (cheap). Creating and freeing
  /// players waits until the swipe settles ([_onScroll]) so the animation stays smooth.
  void _onPage(int i) {
    if (i == _index) return;
    _saveProgress(_index);
    HapticFeedback.selectionClick();
    setState(() => _index = i); // pages pause/play themselves via `active`
    if (!_ctrls.containsKey(_key(i))) _ensure(i);
    if (i >= _items.length - 3) _loadMore();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification && n.depth == 0 && _items.isNotEmpty) {
      _activate(_index);
    }
    return false;
  }

  /// Heavy part, once settled: free far players, buffer the neighbours.
  void _activate(int i) {
    _index = i;
    // Previous, current and next hold a video decoder (phones have only a few).
    final keep = <int>{};
    for (final j in [i - 1, i, i + 1]) {
      if (j >= 0 && j < _items.length) keep.add(_key(j));
    }
    _pool.pauseOthers(_key(i));
    _ctrls.removeWhere((k, _) => !keep.contains(k));
    _pool.keepOnly(keep);
    _ensure(i).then((_) {
      if (!mounted || _index != i) return;
      _ensure(i + 1);
      _ensure(i - 1);
    });
    if (i >= _items.length - 3) _loadMore();
    setState(() {});
  }

  Future<void> _ensure(int i) async {
    if (i < 0 || i >= _items.length) return;
    final item = _items[i];
    final id = item.episode.id;
    if (item.episode.isLocked ||
        _unplayable.contains(id) ||
        _ctrls.containsKey(id)) {
      return;
    }
    var url = item.stream?.hlsUrl ?? item.stream?.playbackUrl ?? _resolved[id];
    if (url == null) {
      if (!_resolving.add(id)) return;
      try {
        final play = await _api.play(id);
        url = play.locked
            ? null
            : (play.stream?.hlsUrl ?? play.stream?.playbackUrl);
      } catch (_) {
        url = null;
      } finally {
        _resolving.remove(id);
      }
      if (!mounted) return;
      if (url == null) {
        setState(() => _unplayable.add(id));
        return;
      }
      _resolved[id] = url;
      if (_covered || ((i - _index).abs() > 1)) return;
    }
    final c = await _pool.obtain(
      item.episode.id,
      url,
      looping: true,
      warm: i != _index,
    );
    if (!mounted) return;
    if (c == null) {
      if (_covered || (i - _index).abs() > 1) return; // released, not failed
      // Retry once (a dropped connection), then show the poster instead of spinning.
      if (_retried.add(id)) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _resolved.remove(id);
        if (mounted) return _ensure(i);
        return;
      }
      setState(() => _unplayable.add(id));
      return;
    }
    if (_covered || ((i - _index).abs() > 1)) {
      // Swiped past (or covered) while it was buffering: free its decoder now.
      _pool.keepOnly(_covered ? const {} : _window());
      return;
    }
    setState(() => _ctrls[item.episode.id] = c);
  }

  Set<int> _window() => {
    for (final j in [_index - 1, _index, _index + 1])
      if (j >= 0 && j < _items.length) _key(j),
  };

  Future<void> _saveProgress(int i) async {
    if (i < 0 || i >= _items.length) return;
    final c = _ctrls[_key(i)];
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inSeconds;
    if (pos >= 3) {
      await _api.saveProgress(_key(i), pos, c.value.duration.inSeconds);
    }
  }

  /// Open another screen on top. Reels frees its players meanwhile (the new screen needs
  /// the decoders) and re-buffers the current reel when the viewer comes back.
  Future<void> _push(String location) async {
    _saveProgress(_index);
    setState(() {
      _covered = true;
      _ctrls.clear();
      _resolved.clear();
    });
    _pool.releaseAll();
    await context.push(location);
    if (!mounted) return;
    setState(() => _covered = false);
    if (_items.isNotEmpty) _activate(_index);
  }

  Future<void> _toggleLike(FeedItem item) async {
    HapticFeedback.lightImpact();
    final id = item.drama.id;
    setState(() => _liked[id] = !(_liked[id] ?? false));
    try {
      final r = await _api.toggleLike(id);
      if (mounted) setState(() => _liked[id] = r.liked);
    } catch (_) {}
  }

  Future<void> _toggleSave(FeedItem item) async {
    HapticFeedback.lightImpact();
    final id = item.drama.id;
    setState(() => _saved[id] = !(_saved[id] ?? false));
    try {
      final s = await _api.toggleSave(id);
      if (mounted) setState(() => _saved[id] = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    // The bottom navigation bar is drawn over this screen.
    // The tab bar sits below this screen now (not over the video): small inset only.
    const navInset = 6.0;

    Widget body;
    if (_items.isEmpty) {
      body = _error != null
          ? ErrorRetry(
              message: _error!,
              onRetry: () {
                setState(() => _error = null);
                _nextPage = 1;
                _loadMore();
              },
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _page,
          scrollDirection: Axis.vertical,
          itemCount: _items.length,
          physics: const SnappyPagePhysics(),
          onPageChanged: _onPage,
          itemBuilder: (context, i) => _reel(_items[i], i, pad, navInset),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: body),
            Positioned(
              top: pad.top + 10,
              left: 0,
              right: 0,
              child: const IgnorePointer(
                child: Center(
                  child: Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reel(FeedItem item, int i, EdgeInsets pad, double navInset) {
    final d = item.drama;
    final playable =
        !item.episode.isLocked && !_unplayable.contains(item.episode.id);
    final liked = _liked[d.id] ?? false;
    final saved = _saved[d.id] ?? false;
    final watchAll = '/drama/${d.slug}/watch?ep=${item.episode.id}';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (playable)
          ShortVideoView(
            controller: _ctrls[item.episode.id],
            posterUrl: d.posterUrl,
            active: i == _index && !_covered && !_appPaused,
            onDoubleTap: () {
              if (!(_liked[d.id] ?? false)) _toggleLike(item);
            },
            bottomInset: navInset,
          )
        else
          GestureDetector(
            onTap: () => _push('/drama/${d.slug}/watch'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DramaImage(d.posterUrl),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 72,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        const Align(
          alignment: Alignment.topCenter,
          child: ScrimGradient(top: true, height: 120),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: ScrimGradient(height: 320),
        ),

        Positioned(
          right: 8,
          bottom: navInset + 124,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _push('/drama/${d.slug}/watch'),
                child: Container(
                  width: 46,
                  height: 62,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DramaImage(d.posterUrl),
                ),
              ),
              RailButton(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: liked ? DramaColors.accent : Colors.white,
                label: 'Таалагдсан',
                onTap: () => _toggleLike(item),
              ),
              RailButton(
                icon: saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: saved ? DramaColors.gold : Colors.white,
                label: saved ? 'Хадгалсан' : 'Хадгалах',
                onTap: () => _toggleSave(item),
              ),
              RailButton(
                icon: Icons.video_library_rounded,
                label: 'Ангиуд',
                onTap: () => _push('/drama/${d.slug}/watch'),
              ),
            ],
          ),
        ),

        Positioned(
          left: 16,
          right: 80,
          bottom: navInset + 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _push('/drama/${d.slug}/watch'),
                child: Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (d.genres.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final g in d.genres.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if ((d.overview ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                ExpandableCaption(d.overview!),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _push(watchAll),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) =>
                            LemonyBrand.gradient.createShader(r),
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        d.episodes > 0
                            ? 'Бүх анги үзэх · ${d.episodes} анги'
                            : 'Бүх анги үзэх',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
