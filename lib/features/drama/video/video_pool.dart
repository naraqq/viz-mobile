import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// Keeps at most a few initialized players alive — the current page and its neighbours —
/// so swiping to another video starts instantly, without growing memory.
class VideoPool {
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<VideoPlayerController?>> _pending = {};
  bool _disposed = false;

  /// Controllers whose first frame is already on their texture (see [_warmUp]), so the
  /// page can show the video immediately instead of the poster.
  static final warmed = Expando<bool>('warmed');

  VideoPlayerController? peek(int key) {
    final c = _controllers[key];
    return c != null && c.value.isInitialized ? c : null;
  }

  bool has(int key) => _controllers.containsKey(key);

  /// Returns an initialized controller for [key], creating and buffering it if needed.
  /// [warm] (for neighbours) also decodes the first frame, so swiping to it shows the
  /// picture straight away. Null when the stream can't be opened.
  Future<VideoPlayerController?> obtain(
    int key,
    String url, {
    bool looping = false,
    bool warm = false,
  }) {
    final existing = _controllers[key];
    if (existing != null && existing.value.isInitialized) {
      return Future.value(existing);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    // Only this load may clear its own entry: a load that was released (swiped away)
    // and finishes later must not remove the newer load for the same video.
    late final Future<VideoPlayerController?> f;
    f = _create(key, url, looping, warm).whenComplete(() {
      if (identical(_pending[key], f)) _pending.remove(key);
    });
    _pending[key] = f;
    return f;
  }

  Future<VideoPlayerController?> _create(
    int key,
    String url,
    bool looping,
    bool warm,
  ) async {
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: url.contains('.m3u8') ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _controllers[key] = c;
    try {
      await c.initialize();
      await c.setLooping(looping);
      if (warm && _controllers[key] == c && !_disposed) await _warmUp(c);
      if (_disposed || _controllers[key] != c) {
        await c.dispose();
        return null;
      }
      return c;
    } catch (_) {
      if (_controllers[key] == c) _controllers.remove(key);
      unawaited(c.dispose().catchError((_) {}));
      return null;
    }
  }

  /// Play muted until the first frame is decoded, then pause and rewind: the texture keeps
  /// that frame, so the page shows real video (not a poster) the moment it slides in.
  static Future<void> _warmUp(VideoPlayerController c) async {
    try {
      await c.setVolume(0);
      await c.play();
      final done = Completer<void>();
      void listener() {
        if (c.value.position > Duration.zero && !done.isCompleted) {
          done.complete();
        }
      }

      c.addListener(listener);
      await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      c.removeListener(listener);
      await c.pause();
      await c.seekTo(Duration.zero);
      await c.setVolume(1);
      warmed[c] = c.value.position >= Duration.zero && done.isCompleted;
    } catch (_) {
      // Disposed while warming (swiped far away) — nothing to do.
    }
  }

  /// Pause everything except [key].
  void pauseOthers(int? key) {
    _controllers.forEach((k, c) {
      if (k != key && c.value.isInitialized && c.value.isPlaying) c.pause();
    });
  }

  void pauseAll() => pauseOthers(null);

  /// Release every player whose key isn't in [keep]. Phones have only a few hardware
  /// video decoders, so idle players must be freed, not just paused.
  /// Disposal waits for the next frame, so a page still on screen never draws a dead player.
  void keepOnly(Set<int> keep) {
    final drop = _controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in drop) {
      final c = _controllers.remove(k);
      _pending.remove(k);
      if (c != null) {
        c.pause().catchError((_) {});
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => c.dispose().catchError((_) {}),
        );
        SchedulerBinding.instance.scheduleFrame();
      }
    }
  }

  /// Free every player (e.g. while another screen covers this one).
  void releaseAll() => keepOnly(const {});

  void dispose() {
    _disposed = true;
    for (final c in _controllers.values) {
      c.dispose().catchError((_) {});
    }
    _controllers.clear();
    _pending.clear();
  }
}
