import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/episode.dart';
import '../../core/models/season.dart';
import '../../core/models/subtitle_track.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'subtitle_parser.dart';

enum _SeekSide { left, right }

enum _GestureType { seek, volume, brightness }

const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String _seriesTitleFromTitle(String title) {
  final parts = title.split(' · ');
  return parts.isNotEmpty ? parts.first : title;
}

String _formatRuntime(int? seconds, int? fallbackMinutes) {
  if (seconds != null && seconds > 0) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours > 0 && rest > 0) return '$hours цаг $rest мин';
    if (hours > 0) return '$hours цаг';
    return '$minutes мин';
  }
  if (fallbackMinutes != null && fallbackMinutes > 0) {
    return '$fallbackMinutes мин';
  }
  return '';
}

double? _episodeProgressValue(Episode episode, int? progress) {
  final duration = episode.streamVideo?.durationSeconds;
  if (duration == null || duration <= 0 || progress == null || progress <= 0) {
    return null;
  }
  return (progress / duration).clamp(0.0, 1.0).toDouble();
}

class PlayerScreen extends ConsumerStatefulWidget {
  final String hlsUrl;
  final String title;
  final String watchableType;
  final int watchableId;
  final int startPosition;
  final List<SubtitleTrack> subtitleTracks;
  final String? seriesTitle;
  final List<Season> seasons;
  final Map<int, int> episodeProgress;
  final int? currentEpisodeId;

  const PlayerScreen({
    super.key,
    required this.hlsUrl,
    required this.title,
    required this.watchableType,
    required this.watchableId,
    required this.startPosition,
    required this.subtitleTracks,
    this.seriesTitle,
    this.seasons = const [],
    this.episodeProgress = const {},
    this.currentEpisodeId,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late String _title;
  late String _watchableType;
  late int _watchableId;
  late String _seriesTitle;
  late List<Season> _seasons;
  late Map<int, int> _episodeProgress;
  int? _currentEpisodeId;

  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isBuffering = false;
  bool _isCropped = false;
  double _speed = 1.0;

  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _gestureOverlayTimer;

  // Double-tap seek flash
  _SeekSide? _seekSide;
  late AnimationController _seekAnim;

  // Subtitles
  List<SubtitleTrack> _tracks = [];
  SubtitleTrack? _selectedTrack;
  List<SubtitleCue> _cues = [];
  String? _currentCue;
  bool _loadingSubtitles = false;
  double _subtitleFontSize = 18.0;

  // Gesture state
  _GestureType? _activeGesture;
  Offset? _panStart;
  double _panStartProgress = 0.0;
  bool _isScrubbing = false;
  double _scrubProgress = 0.0;
  Duration _scrubTarget = Duration.zero;

  // Manual double-tap detection
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Timer? _singleTapTimer;

  // Volume / brightness
  double _volume = 1.0;
  double _brightness = 0.5;
  bool _showVolumeOverlay = false;
  bool _showBrightnessOverlay = false;
  bool _autoAdvancePending = false;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _watchableType = widget.watchableType;
    _watchableId = widget.watchableId;
    _seriesTitle = widget.seriesTitle ?? _seriesTitleFromTitle(widget.title);
    _seasons = widget.seasons;
    _episodeProgress = Map<int, int>.from(widget.episodeProgress);
    _currentEpisodeId = widget.currentEpisodeId;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.hlsUrl));
    _seekAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tracks = widget.subtitleTracks;
    FlutterVolumeController.updateShowSystemUI(false);
    _enterFullscreen();
    _initPlayer();
    _initGestureValues();
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initGestureValues() async {
    try {
      _volume = await FlutterVolumeController.getVolume() ?? 1.0;
    } catch (_) {}
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    debugPrint('[Player] HLS: "${widget.hlsUrl}"');
    if (widget.hlsUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'HLS URL is empty — video not configured';
        });
      }
      return;
    }
    try {
      await _controller.initialize();
      if (widget.startPosition > 0) {
        await _controller.seekTo(Duration(seconds: widget.startPosition));
      }
      _controller.play();
      _controller.addListener(_onVideoUpdate);
      if (mounted) setState(() => _isInitialized = true);
      _startProgressTimer();
      _scheduleHide();
      final defaultTrack =
          _tracks.where((t) => t.isDefault).firstOrNull ??
          _tracks.where((t) => t.languageCode == 'mn').firstOrNull;
      if (defaultTrack != null) _selectSubtitle(defaultTrack);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final buffering = _controller.value.isBuffering;
    final cue = _currentCueText();
    if (buffering != _isBuffering || cue != _currentCue) {
      setState(() {
        _isBuffering = buffering;
        _currentCue = cue;
      });
    }
    _maybeAutoAdvanceEpisode();
  }

  String? _currentCueText() {
    if (_cues.isEmpty) return null;
    final pos = _controller.value.position;
    for (final cue in _cues) {
      if (pos >= cue.start && pos <= cue.end) return cue.text;
    }
    return null;
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveProgress(),
    );
  }

  Future<void> _saveProgress() async {
    if (!_isInitialized) return;
    final pos = _controller.value.position.inSeconds;
    final dur = _controller.value.duration.inSeconds;
    if (dur <= 0) return;
    if (_watchableType == 'episode') {
      _episodeProgress[_watchableId] = pos;
    }
    try {
      await ref
          .read(apiClientProvider)
          .post<dynamic>(
            ApiEndpoints.watchProgress,
            data: {
              'watchable_type': _watchableType,
              'watchable_id': _watchableId,
              'position_seconds': pos,
              'duration_seconds': dur,
            },
          );
    } catch (_) {}
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_controller.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_isLocked && !_isScrubbing) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_isScrubbing) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    setState(() {});
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      _controller.play();
      _scheduleHide();
    }
  }

  void _seek(int seconds, _SeekSide side) {
    final raw = _controller.value.position + Duration(seconds: seconds);
    final clamped = raw < Duration.zero
        ? Duration.zero
        : raw > _controller.value.duration
        ? _controller.value.duration
        : raw;
    _controller.seekTo(clamped);
    setState(() => _seekSide = side);
    _seekAnim.forward(from: 0).then((_) {
      if (mounted) setState(() => _seekSide = null);
    });
    _scheduleHide();
  }

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    _controller.setPlaybackSpeed(speed);
    _scheduleHide();
  }

  // ─── Gesture handlers ───────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    if (!_isInitialized || _isLocked) return;
    _panStart = d.localPosition;
    _activeGesture = null;
    _panStartProgress = _controller.value.duration.inMilliseconds > 0
        ? _controller.value.position.inMilliseconds /
              _controller.value.duration.inMilliseconds
        : 0.0;
    _hideTimer?.cancel();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_isInitialized || _isLocked || _panStart == null) return;
    final size = MediaQuery.of(context).size;
    final dx = d.localPosition.dx - _panStart!.dx;
    final dy = d.localPosition.dy - _panStart!.dy;

    if (_activeGesture == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 12) {
        _activeGesture = _GestureType.seek;
      } else if (dy.abs() > dx.abs() && dy.abs() > 12) {
        _activeGesture = _panStart!.dx < size.width / 2
            ? _GestureType.brightness
            : _GestureType.volume;
      }
      return;
    }

    switch (_activeGesture) {
      case _GestureType.seek:
        final delta = dx / (size.width * 0.85);
        final newProg = (_panStartProgress + delta).clamp(0.0, 1.0);
        final ms = (newProg * _controller.value.duration.inMilliseconds)
            .round();
        setState(() {
          _isScrubbing = true;
          _scrubProgress = newProg;
          _scrubTarget = Duration(milliseconds: ms);
          _showControls = false;
        });

      case _GestureType.volume:
        final delta = -d.delta.dy / size.height * 3.5;
        _volume = (_volume + delta).clamp(0.0, 1.0);
        FlutterVolumeController.setVolume(_volume).catchError((_) {});
        setState(() => _showVolumeOverlay = true);
        _resetGestureTimer();

      case _GestureType.brightness:
        final delta = -d.delta.dy / size.height * 3.5;
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        ScreenBrightness().setScreenBrightness(_brightness).catchError((_) {});
        setState(() => _showBrightnessOverlay = true);
        _resetGestureTimer();

      default:
        break;
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_activeGesture == _GestureType.seek && _isScrubbing) {
      _controller.seekTo(_scrubTarget);
    }
    setState(() {
      _isScrubbing = false;
      _activeGesture = null;
    });
    _panStart = null;
    _scheduleHide();
  }

  void _handleTapUp(TapUpDetails d) {
    if (_isScrubbing) return;
    final now = DateTime.now();
    final x = d.localPosition.dx;
    final isDoubleTap =
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 280) &&
        _lastTapPosition != null;

    if (isDoubleTap) {
      _singleTapTimer?.cancel();
      _lastTapTime = null;
      _lastTapPosition = null;
      final w = MediaQuery.of(context).size.width;
      x < w / 2 ? _seek(-10, _SeekSide.left) : _seek(10, _SeekSide.right);
    } else {
      _lastTapTime = now;
      _lastTapPosition = d.localPosition;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted) _toggleControls();
      });
    }
  }

  void _resetGestureTimer() {
    _gestureOverlayTimer?.cancel();
    _gestureOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeOverlay = false;
          _showBrightnessOverlay = false;
        });
      }
    });
  }

  // ─── Subtitles ──────────────────────────────────────────────────────────────

  Future<void> _selectSubtitle(SubtitleTrack? track) async {
    setState(() {
      _selectedTrack = track;
      _cues = [];
      _currentCue = null;
    });
    if (track?.playbackUrl == null) return;
    setState(() => _loadingSubtitles = true);
    try {
      final res = await Dio().get<String>(
        track!.playbackUrl!,
        options: Options(responseType: ResponseType.plain),
      );
      if (res.data != null && mounted) {
        setState(() {
          _cues = SubtitleParser.parse(res.data!);
          _loadingSubtitles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubtitles = false);
    }
  }

  void _showSpeedSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SpeedSheet(
        current: _speed,
        onSelect: (s) {
          Navigator.pop(context);
          _setSpeed(s);
        },
      ),
    );
  }

  void _showSubtitleSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SubtitleSheet(
        tracks: _tracks,
        selected: _selectedTrack,
        fontSize: _subtitleFontSize,
        onSelect: (t) {
          Navigator.pop(context);
          _selectSubtitle(t);
          _scheduleHide();
        },
        onFontSizeChanged: (sz) => setState(() => _subtitleFontSize = sz),
      ),
    );
  }

  void _showEpisodesSheet() {
    if (_seasons.isEmpty) return;
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EpisodesSheet(
        seasons: _seasons,
        currentEpisodeId: _currentEpisodeId,
        progress: _episodeProgress,
        onSelect: (season, episode) {
          Navigator.pop(context);
          _switchToEpisode(season, episode);
        },
      ),
    ).whenComplete(_scheduleHide);
  }

  Future<void> _switchToEpisode(Season season, Episode episode) async {
    final hlsUrl = episode.streamVideo?.hlsUrl;
    if (hlsUrl == null || hlsUrl.isEmpty) return;

    await _saveProgress();

    final oldController = _controller;
    if (_isInitialized) {
      oldController.removeListener(_onVideoUpdate);
    }

    final nextController = VideoPlayerController.networkUrl(Uri.parse(hlsUrl));
    setState(() {
      _controller = nextController;
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
      _isBuffering = false;
      _autoAdvancePending = false;
      _title =
          '$_seriesTitle · S${season.seasonNumber}E${episode.episodeNumber}';
      _watchableType = 'episode';
      _watchableId = episode.id;
      _currentEpisodeId = episode.id;
      _tracks = episode.streamVideo?.subtitleTracks ?? const [];
      _selectedTrack = null;
      _cues = [];
      _currentCue = null;
      _showControls = true;
    });

    await oldController.pause().catchError((_) {});
    await oldController.dispose().catchError((_) {});

    try {
      await nextController.initialize();
      final startPosition = _episodeProgress[episode.id] ?? 0;
      if (startPosition > 0) {
        await nextController.seekTo(Duration(seconds: startPosition));
      }
      nextController.addListener(_onVideoUpdate);
      await nextController.play();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      final defaultTrack =
          _tracks.where((t) => t.isDefault).firstOrNull ??
          _tracks.where((t) => t.languageCode == 'mn').firstOrNull;
      if (defaultTrack != null) _selectSubtitle(defaultTrack);
      _scheduleHide();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _maybeAutoAdvanceEpisode() {
    if (_watchableType != 'episode' ||
        _autoAdvancePending ||
        _seasons.isEmpty ||
        !_isInitialized) {
      return;
    }
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration.inSeconds < 20) return;
    final remaining = duration - position;
    if (remaining.inSeconds > 1) return;

    final next = _nextEpisode();
    if (next == null) return;
    _autoAdvancePending = true;
    Future.microtask(() => _switchToEpisode(next.$1, next.$2));
  }

  (Season, Episode)? _nextEpisode() {
    if (_currentEpisodeId == null) return null;
    var foundCurrent = false;
    for (final season in _seasons) {
      for (final episode in season.episodes) {
        if (foundCurrent && episode.streamVideo?.isReady == true) {
          return (season, episode);
        }
        if (episode.id == _currentEpisodeId) {
          foundCurrent = true;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _gestureOverlayTimer?.cancel();
    _singleTapTimer?.cancel();
    _seekAnim.dispose();
    if (_isInitialized) {
      _controller.removeListener(_onVideoUpdate);
    }
    _controller.dispose();
    ScreenBrightness().resetScreenBrightness().catchError((_) {});
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTapUp,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ──────────────────────────────────────────────────────
            if (_isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: _isCropped ? BoxFit.cover : BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            else if (_hasError)
              _ErrorView(onBack: () => context.pop(), message: _errorMessage)
            else
              const _LoadingView(),

            // ── Double-tap seek flash ──────────────────────────────────────
            if (_seekSide != null)
              _SeekFlash(side: _seekSide!, animation: _seekAnim),

            // ── Horizontal scrub overlay ───────────────────────────────────
            if (_isScrubbing)
              _ScrubOverlay(
                progress: _scrubProgress,
                target: _scrubTarget,
                duration: _controller.value.duration,
              ),

            // ── Volume overlay ─────────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showVolumeOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _GestureIndicator(
                value: _volume,
                icon: _volume < 0.01
                    ? Icons.volume_off_rounded
                    : _volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
                alignment: Alignment.centerRight,
              ),
            ),

            // ── Brightness overlay ─────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showBrightnessOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _GestureIndicator(
                value: _brightness,
                icon: _brightness < 0.3
                    ? Icons.brightness_low_rounded
                    : _brightness < 0.7
                    ? Icons.brightness_medium_rounded
                    : Icons.brightness_high_rounded,
                alignment: Alignment.centerLeft,
              ),
            ),

            // ── Subtitle text ──────────────────────────────────────────────
            if (_currentCue != null && !_isScrubbing)
              Positioned(
                left: 24,
                right: 24,
                bottom: _showControls ? 80 : 28,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currentCue!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _subtitleFontSize,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Buffering spinner ──────────────────────────────────────────
            if (_isBuffering && _isInitialized && !_isScrubbing)
              const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),

            // ── Controls ───────────────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls && !_isScrubbing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls || _isScrubbing,
                child: _isLocked
                    ? _LockedOverlay(
                        onUnlock: () => setState(() => _isLocked = false),
                      )
                    : _ControlsOverlay(
                        controller: _controller,
                        title: _title,
                        isInitialized: _isInitialized,
                        hasTracks: _tracks.isNotEmpty,
                        hasEpisodes: _seasons.isNotEmpty,
                        loadingSubtitles: _loadingSubtitles,
                        speed: _speed,
                        isCropped: _isCropped,
                        onBack: () {
                          _saveProgress();
                          context.pop();
                        },
                        onPlayPause: _togglePlay,
                        onSeekBack: () => _seek(-10, _SeekSide.left),
                        onSeekForward: () => _seek(10, _SeekSide.right),
                        onSubtitlesTap: _showSubtitleSheet,
                        onEpisodesTap: _showEpisodesSheet,
                        onSpeedTap: _showSpeedSheet,
                        onLock: () => setState(() => _isLocked = true),
                        onZoomToggle: () =>
                            setState(() => _isCropped = !_isCropped),
                        onSliderChanged: (v) {
                          final target = Duration(
                            milliseconds:
                                (v * _controller.value.duration.inMilliseconds)
                                    .round(),
                          );
                          _controller.seekTo(target);
                          _scheduleHide();
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scrub overlay ─────────────────────────────────────────────────────────────

class _ScrubOverlay extends StatelessWidget {
  final double progress;
  final Duration target;
  final Duration duration;

  const _ScrubOverlay({
    required this.progress,
    required this.target,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmt(target),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '/ ${_fmt(duration)}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  color: AppTheme.primary,
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Gesture indicator (volume / brightness) ───────────────────────────────────

class _GestureIndicator extends StatelessWidget {
  final double value;
  final IconData icon;
  final Alignment alignment;

  const _GestureIndicator({
    required this.value,
    required this.icon,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 10),
              SizedBox(
                width: 4,
                height: 80,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Controls overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final String title;
  final bool isInitialized;
  final bool hasTracks;
  final bool hasEpisodes;
  final bool loadingSubtitles;
  final double speed;
  final bool isCropped;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onSubtitlesTap;
  final VoidCallback onEpisodesTap;
  final VoidCallback onSpeedTap;
  final VoidCallback onLock;
  final VoidCallback onZoomToggle;
  final ValueChanged<double> onSliderChanged;

  const _ControlsOverlay({
    required this.controller,
    required this.title,
    required this.isInitialized,
    required this.hasTracks,
    required this.hasEpisodes,
    required this.loadingSubtitles,
    required this.speed,
    required this.isCropped,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSubtitlesTap,
    required this.onEpisodesTap,
    required this.onSpeedTap,
    required this.onLock,
    required this.onZoomToggle,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final isPlaying = value.isPlaying;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    double buffered = 0.0;
    if (value.buffered.isNotEmpty && duration.inMilliseconds > 0) {
      buffered =
          (value.buffered.last.end.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xBB000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xBB000000),
          ],
          stops: [0.0, 0.22, 0.78, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SpeedBadge(speed: speed, onTap: onSpeedTap),
                  const SizedBox(width: 4),
                  if (hasEpisodes)
                    IconButton(
                      icon: const Icon(
                        Icons.video_library_outlined,
                        color: Colors.white,
                      ),
                      onPressed: onEpisodesTap,
                      tooltip: 'Ангиуд',
                    ),
                  if (loadingSubtitles)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white60,
                        ),
                      ),
                    )
                  else if (hasTracks)
                    IconButton(
                      icon: const Icon(
                        Icons.subtitles_outlined,
                        color: Colors.white,
                      ),
                      onPressed: onSubtitlesTap,
                    ),
                  IconButton(
                    icon: Icon(
                      isCropped
                          ? Icons.fit_screen_rounded
                          : Icons.crop_free_rounded,
                      color: isCropped ? AppTheme.primary : Colors.white,
                    ),
                    onPressed: onZoomToggle,
                    tooltip: isCropped ? 'Бүтэн дэлгэц' : 'Дүүргэх',
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline, color: Colors.white),
                    onPressed: onLock,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Center controls ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SeekButton(icon: Icons.replay_10_rounded, onTap: onSeekBack),
                const SizedBox(width: 36),
                _PlayPauseButton(isPlaying: isPlaying, onTap: onPlayPause),
                const SizedBox(width: 36),
                _SeekButton(
                  icon: Icons.forward_10_rounded,
                  onTap: onSeekForward,
                ),
              ],
            ),

            const Spacer(),

            // ── Bottom bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress + buffered
                  SizedBox(
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        LinearProgressIndicator(
                          value: buffered,
                          backgroundColor: Colors.white12,
                          color: Colors.white24,
                          minHeight: 2,
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: isInitialized ? onSliderChanged : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _fmt(duration),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _SpeedBadge extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const _SpeedBadge({required this.speed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCustom = speed != 1.0;
    final label = speed == speed.truncateToDouble()
        ? '${speed.toInt()}x'
        : '${speed}x';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isCustom
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCustom
                ? AppTheme.primary.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCustom ? AppTheme.primary : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SeekButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

class _SeekFlash extends StatelessWidget {
  final _SeekSide side;
  final AnimationController animation;

  const _SeekFlash({required this.side, required this.animation});

  @override
  Widget build(BuildContext context) {
    final isLeft = side == _SeekSide.left;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final opacity = (1.0 - animation.value).clamp(0.0, 1.0);
        return Positioned(
          left: isLeft ? 0 : null,
          right: isLeft ? null : 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.36,
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLeft
                        ? Icons.fast_rewind_rounded
                        : Icons.fast_forward_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '10 сек',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
}

class _LockedOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockedOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 28),
        child: GestureDetector(
          onTap: onUnlock,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_open_outlined, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Түгжээ тайлах',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Episodes sheet ───────────────────────────────────────────────────────────

class _EpisodesSheet extends StatelessWidget {
  final List<Season> seasons;
  final int? currentEpisodeId;
  final Map<int, int> progress;
  final void Function(Season season, Episode episode) onSelect;

  const _EpisodesSheet({
    required this.seasons,
    required this.currentEpisodeId,
    required this.progress,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current = _findCurrentEpisode();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ангиуд',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (current != null)
                    Text(
                      'Одоо: S${current.$1.seasonNumber}E${current.$2.episodeNumber}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                itemCount: seasons.length,
                itemBuilder: (context, seasonIndex) {
                  final season = seasons[seasonIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        child: Text(
                          '${season.seasonNumber}-р бүлэг',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...season.episodes.map(
                        (episode) => _EpisodeSheetRow(
                          season: season,
                          episode: episode,
                          progress: progress[episode.id],
                          isCurrent: episode.id == currentEpisodeId,
                          onTap: () => onSelect(season, episode),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Season, Episode)? _findCurrentEpisode() {
    if (currentEpisodeId == null) return null;
    for (final season in seasons) {
      for (final episode in season.episodes) {
        if (episode.id == currentEpisodeId) return (season, episode);
      }
    }
    return null;
  }
}

class _EpisodeSheetRow extends StatelessWidget {
  final Season season;
  final Episode episode;
  final int? progress;
  final bool isCurrent;
  final VoidCallback onTap;

  const _EpisodeSheetRow({
    required this.season,
    required this.episode,
    required this.progress,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = episode.streamVideo?.isReady == true;
    final progressValue = _episodeProgressValue(episode, progress);
    final runtime = _formatRuntime(
      episode.streamVideo?.durationSeconds,
      episode.runtime,
    );
    final description = episode.overviewMn ?? episode.overview;

    return InkWell(
      onTap: hasVideo ? onTap : null,
      child: Container(
        color: isCurrent ? AppTheme.primary.withValues(alpha: 0.12) : null,
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  SizedBox(
                    width: 104,
                    height: 58,
                    child: episode.stillUrl != null
                        ? Image.network(
                            episode.stillUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _episodeThumbFallback(),
                          )
                        : _episodeThumbFallback(),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70),
                        ),
                        child: Icon(
                          isCurrent
                              ? Icons.equalizer_rounded
                              : hasVideo
                              ? Icons.play_arrow_rounded
                              : Icons.lock_outline,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  if (progressValue != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor: Colors.white24,
                        color: AppTheme.primary,
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${episode.episodeNumber}. ${episode.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? AppTheme.primary : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (runtime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          runtime,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isCurrent
                        ? 'Одоо үзэж байна'
                        : (progress ?? 0) > 0
                        ? 'Үргэлжлүүлэх'
                        : 'S${season.seasonNumber}E${episode.episodeNumber}',
                    style: TextStyle(
                      color: isCurrent
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (description != null && description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _episodeThumbFallback() => Container(
    color: Colors.white10,
    child: const Icon(Icons.movie_outlined, color: Colors.white38),
  );
}

// ─── Speed sheet ───────────────────────────────────────────────────────────────

class _SpeedSheet extends StatelessWidget {
  final double current;
  final ValueChanged<double> onSelect;

  const _SpeedSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Тоглуулах хурд',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._speedOptions.map((s) {
            final selected = s == current;
            final label = s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x';
            return ListTile(
              leading: Icon(
                selected ? Icons.check_rounded : null,
                color: AppTheme.primary,
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () => onSelect(s),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Subtitle sheet ────────────────────────────────────────────────────────────

class _SubtitleSheet extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? selected;
  final double fontSize;
  final ValueChanged<SubtitleTrack?> onSelect;
  final ValueChanged<double> onFontSizeChanged;

  const _SubtitleSheet({
    required this.tracks,
    required this.selected,
    required this.fontSize,
    required this.onSelect,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const Text(
              'Хадмал',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Scrollable track list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: Icon(
                      selected == null ? Icons.check_rounded : null,
                      color: AppTheme.primary,
                    ),
                    title: const Text(
                      'Унтраах',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => onSelect(null),
                  ),
                  ...tracks.map((t) {
                    final sel = selected?.id == t.id;
                    return ListTile(
                      leading: Icon(
                        sel ? Icons.check_rounded : null,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        t.label,
                        style: TextStyle(
                          color: sel ? AppTheme.primary : Colors.white,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        t.languageCode,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => onSelect(t),
                    );
                  }),
                ],
              ),
            ),
            // Fixed footer — font size
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Хэмжээ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  _SizeChip(
                    label: 'S',
                    selected: fontSize == 14,
                    onTap: () => onFontSizeChanged(14),
                  ),
                  const SizedBox(width: 8),
                  _SizeChip(
                    label: 'M',
                    selected: fontSize == 18,
                    onTap: () => onFontSizeChanged(18),
                  ),
                  const SizedBox(width: 8),
                  _SizeChip(
                    label: 'L',
                    selected: fontSize == 22,
                    onTap: () => onFontSizeChanged(22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primary : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Loading / error ───────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Ачаалж байна…',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onBack;
  final String? message;

  const _ErrorView({required this.onBack, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white38, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Видео ачаалж чадсангүй',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            label: const Text('Буцах', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
