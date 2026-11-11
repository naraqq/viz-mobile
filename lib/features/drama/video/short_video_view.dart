import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/widgets/lemony_logo.dart';
import '../widgets/drama_widgets.dart';
import 'video_pool.dart';

/// One full-screen vertical video page:
///  - the poster stays on screen until the first frame renders (no black flash)
///  - tap to pause / resume, with a large play icon while paused
///  - a buffering spinner only when playback actually stalls
///  - a thin progress bar at the bottom that can be dragged to seek
///  - double-tap: ❤️ burst where the finger was (and [onDoubleTap], e.g. like)
///  - press and hold: 2× speed while held
/// Overlays (actions, title) are drawn by the caller on top of this.
class ShortVideoView extends StatefulWidget {
  final VideoPlayerController? controller;
  final String? posterUrl;
  final bool active;
  final VoidCallback? onEnded;
  final VoidCallback? onDoubleTap;

  /// Space to leave under the progress bar (e.g. the bottom navigation bar).
  final double bottomInset;

  const ShortVideoView({
    super.key,
    required this.controller,
    required this.posterUrl,
    required this.active,
    this.onEnded,
    this.onDoubleTap,
    this.bottomInset = 0,
  });

  @override
  State<ShortVideoView> createState() => _ShortVideoViewState();
}

class _ShortVideoViewState extends State<ShortVideoView> {
  VideoPlayerController? _c;
  bool _firstFrame = false;
  bool _showPoster = true;
  bool _userPaused = false;
  bool _endedFired = false;
  bool _fast = false;
  final List<({Key key, Offset at})> _hearts = [];

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(covariant ShortVideoView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) _attach(widget.controller);
    if (old.active != widget.active && !widget.active) _userPaused = false;
    // Always re-sync: within one frame the page can go active → inactive → active
    // (quick back-and-forth swipe) and the flag looks unchanged, but the player must
    // still end up playing.
    _sync();
  }

  void _attach(VideoPlayerController? c) {
    _c?.removeListener(_onTick);
    _c = c;
    // A warmed-up neighbour already has its first frame on screen: no poster needed.
    _firstFrame =
        c != null &&
        c.value.isInitialized &&
        (c.value.position > Duration.zero || VideoPool.warmed[c] == true);
    _showPoster = !_firstFrame;
    _endedFired = false;
    c?.addListener(_onTick);
    _sync();
  }

  void _sync() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && !_userPaused) {
      if (!c.value.isPlaying) c.play();
    } else if (c.value.isPlaying) {
      c.pause();
    }
  }

  void _onTick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (!_firstFrame && v.isPlaying && v.position > Duration.zero) {
      setState(() => _firstFrame = true);
      // Drop the poster once its fade-out is done.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _firstFrame) setState(() => _showPoster = false);
      });
    }
    final ended =
        v.isInitialized &&
        v.duration > Duration.zero &&
        !v.isLooping &&
        v.position >= v.duration - const Duration(milliseconds: 300);
    if (ended && !_endedFired && widget.active) {
      _endedFired = true;
      widget.onEnded?.call();
    }
    if (!ended) _endedFired = false;
    setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    super.dispose();
  }

  void _togglePause() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    setState(() => _userPaused = !_userPaused);
    _sync();
  }

  void _heart(Offset at) {
    HapticFeedback.lightImpact();
    final key = UniqueKey();
    setState(() => _hearts.add((key: key, at: at)));
    widget.onDoubleTap?.call();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hearts.removeWhere((h) => h.key == key));
    });
  }

  void _setFast(bool on) {
    final c = _c;
    if (c == null || !c.value.isInitialized || _fast == on) return;
    if (on) HapticFeedback.selectionClick();
    c.setPlaybackSpeed(on ? 2.0 : 1.0);
    setState(() => _fast = on);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final v = c?.value;
    final size = ready ? v!.size : Size.zero;
    final portrait = size.height >= size.width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePause,
      onDoubleTapDown: (d) => _heart(d.localPosition),
      onDoubleTap: () {},
      onLongPressStart: (_) => _setFast(true),
      onLongPressEnd: (_) => _setFast(false),
      onLongPressCancel: () => _setFast(false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (ready)
            FittedBox(
              // Vertical videos fill the screen; landscape ones are shown whole.
              fit: portrait ? BoxFit.cover : BoxFit.contain,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(c),
              ),
            ),
          // Poster until the first frame — avoids a black flash between videos.
          if (_showPoster)
            AnimatedOpacity(
              opacity: _firstFrame ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(child: DramaImage(widget.posterUrl)),
            ),
          if (widget.active &&
              (!ready ||
                  (v!.isBuffering && !_userPaused) ||
                  (!_firstFrame && !_userPaused)))
            const Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),
          if (_userPaused)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.4, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // 2× while held
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _fast ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '2×',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.fast_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Double-tap hearts
          for (final h in _hearts)
            Positioned(
              key: h.key,
              left: h.at.dx - 50,
              top: h.at.dy - 50,
              child: const IgnorePointer(child: _HeartBurst()),
            ),
          // Seek bar: slim while playing; thumb + times when paused or touched.
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomInset,
            child: _SeekBar(
              controller: ready ? c : null,
              emphasize: _userPaused,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-hand action button (icon + small label), like the big short-video apps.
class RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const RailButton({
    super.key,
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
            shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dark gradient behind bottom/top overlays so text stays readable on any frame.
class ScrimGradient extends StatelessWidget {
  final bool top;
  final double height;
  const ScrimGradient({super.key, this.top = false, this.height = 260});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0xCC000000), Colors.transparent],
        ),
      ),
    ),
  );
}

/// A heart that pops, tilts slightly and floats up while fading.
class _HeartBurst extends StatelessWidget {
  const _HeartBurst();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 850),
    builder: (_, t, _) {
      final pop = t < 0.25
          ? Curves.easeOutBack.transform(t / 0.25) * 1.15
          : 1.15 - (t - 0.25) * 0.2;
      final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
      return Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -60 * Curves.easeIn.transform(t)),
          child: Transform.rotate(
            angle: -0.18,
            child: Transform.scale(
              scale: pop,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LemonyBrand.gradient.createShader(r),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 100,
                  shadows: [Shadow(blurRadius: 18, color: Colors.black38)],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// One-line caption with "дэлгэрэнгүй": tap to read the whole text over the video
/// (scrolls if long), tap "хураах" to fold it back.
class ExpandableCaption extends StatefulWidget {
  final String text;
  const ExpandableCaption(this.text, {super.key});

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _open = false;

  static const _style = TextStyle(
    color: Colors.white70,
    fontSize: 13.5,
    height: 1.4,
    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
  );
  static const _link = TextStyle(
    color: Colors.white,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
  );

  @override
  void didUpdateWidget(covariant ExpandableCaption old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomLeft,
        child: _open
            ? Container(
                // Dark panel so the full text stays readable on bright frames.
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: widget.text, style: _style),
                        const TextSpan(text: '  хураах', style: _link),
                      ],
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, c) {
                  // Show "дэлгэрэнгүй" only when the text doesn't fit on one line.
                  final tp = TextPainter(
                    text: TextSpan(text: widget.text, style: _style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: c.maxWidth);
                  if (!tp.didExceedMaxLines) {
                    return Text(widget.text, maxLines: 1, style: _style);
                  }
                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style,
                        ),
                      ),
                      const Text(' дэлгэрэнгүй', style: _link),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Progress / seek bar for the vertical player.
///  - playing: a 2px line along the bottom edge (played + buffered)
///  - paused or touched: thicker track, round thumb, elapsed / total times
///  - drag: big time bubble follows the finger, seeks on release; tap seeks directly
class _SeekBar extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool emphasize;
  const _SeekBar({required this.controller, required this.emphasize});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag; // 0..1 while the finger is on the bar

  static const _hPad = 14.0;

  double _fracAt(double dx, double width) =>
      ((dx - _hPad) / (width - _hPad * 2)).clamp(0.0, 1.0);

  void _seek(double f) {
    final c = widget.controller;
    if (c == null) return;
    final ms = (f * c.value.duration.inMilliseconds).round();
    c.seekTo(Duration(milliseconds: ms));
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static const _timeStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c?.value;
    final total = v?.duration ?? Duration.zero;
    final ready = c != null && total > Duration.zero;
    final played = ready
        ? (v!.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    var buffered = 0.0;
    if (ready) {
      for (final r in v!.buffered) {
        final e = r.end.inMilliseconds / total.inMilliseconds;
        if (e > buffered) buffered = e;
      }
    }
    final value = _drag ?? played;
    final active = _drag != null || widget.emphasize;
    final at = Duration(milliseconds: (value * total.inMilliseconds).round());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time bubble while dragging
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _drag != null ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _fmt(at),
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: '  /  ${_fmt(total)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                ),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: ready
                ? (d) {
                    HapticFeedback.selectionClick();
                    _seek(_fracAt(d.localPosition.dx, box.maxWidth));
                  }
                : null,
            onHorizontalDragStart: ready
                ? (d) {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _drag = _fracAt(d.localPosition.dx, box.maxWidth),
                    );
                  }
                : null,
            onHorizontalDragUpdate: ready
                ? (d) => setState(
                    () => _drag = _fracAt(d.localPosition.dx, box.maxWidth),
                  )
                : null,
            onHorizontalDragEnd: ready
                ? (_) {
                    final f = _drag;
                    setState(() => _drag = null);
                    if (f != null) _seek(f);
                  }
                : null,
            onHorizontalDragCancel: () => setState(() => _drag = null),
            // The whole block (line + times) takes the drag, so it's easy to grab.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 34,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: active ? 1 : 0),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    builder: (_, t, _) => CustomPaint(
                      size: Size(box.maxWidth, 34),
                      painter: _SeekPainter(
                        played: value,
                        buffered: buffered,
                        t: t,
                        hPad: _hPad,
                      ),
                    ),
                  ),
                ),
                // Elapsed / total when paused (while dragging the bubble shows it).
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  child: widget.emphasize && _drag == null && ready
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _hPad,
                            0,
                            _hPad,
                            8,
                          ),
                          child: Row(
                            children: [
                              Text(_fmt(at), style: _timeStyle),
                              const Spacer(),
                              Text(_fmt(total), style: _timeStyle),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeekPainter extends CustomPainter {
  final double played;
  final double buffered;
  final double t; // 0 = slim line, 1 = full control
  final double hPad;
  _SeekPainter({
    required this.played,
    required this.buffered,
    required this.t,
    required this.hPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Slim: edge to edge on the very bottom. Full: inset, thicker, with a thumb.
    final left = hPad * t;
    final right = size.width - hPad * t;
    final h = 2 + 3 * t;
    final y = size.height - 2 - (size.height / 2 - 2) * t;
    final w = right - left;
    final r = Radius.circular(h / 2);

    RRect bar(double from, double to) => RRect.fromLTRBR(
      left + w * from,
      y - h / 2,
      left + w * to,
      y + h / 2,
      r,
    );

    canvas.drawRRect(bar(0, 1), Paint()..color = Colors.white24);
    canvas.drawRRect(
      bar(0, buffered.clamp(0.0, 1.0)),
      Paint()..color = Colors.white38,
    );
    canvas.drawRRect(
      bar(0, played.clamp(0.0, 1.0)),
      Paint()..color = Colors.white,
    );
    if (t > 0) {
      final x = left + w * played.clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        7 * t,
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(Offset(x, y), 6.5 * t, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_SeekPainter o) =>
      o.played != played || o.buffered != buffered || o.t != t;
}
