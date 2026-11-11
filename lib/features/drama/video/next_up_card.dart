import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/widgets/lemony_logo.dart';
import '../drama_models.dart';
import '../widgets/coin_store.dart';
import '../widgets/drama_widgets.dart';

/// "Next episode in 3…" card for the last seconds of an episode. Slides up when
/// [showWithin] remains; the player advances by itself when the video ends (unless the
/// viewer taps Болих). Tapping the card goes on right away.
class NextUpCard extends StatefulWidget {
  final VideoPlayerController? controller;
  final DramaEpisode next;
  final String? fallbackImage;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;
  final Duration showWithin;

  const NextUpCard({
    super.key,
    required this.controller,
    required this.next,
    required this.onPlayNow,
    required this.onCancel,
    this.fallbackImage,
    this.showWithin = const Duration(seconds: 5),
  });

  @override
  State<NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<NextUpCard> {
  double _remaining = double.infinity; // seconds

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_tick);
  }

  @override
  void didUpdateWidget(covariant NextUpCard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_tick);
      widget.controller?.addListener(_tick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    final v = widget.controller?.value;
    if (v == null || !v.isInitialized || v.duration <= Duration.zero) return;
    final r = (v.duration - v.position).inMilliseconds / 1000;
    // Rebuild only around the visible window (and once when leaving it).
    final within = widget.showWithin.inMilliseconds / 1000;
    if (r <= within || _remaining <= within) {
      setState(() => _remaining = r < 0 ? 0 : r);
    } else {
      _remaining = r;
    }
  }

  @override
  Widget build(BuildContext context) {
    final within = widget.showWithin.inMilliseconds / 1000;
    final visible = _remaining <= within && _remaining > 0.05;
    final progress = visible ? 1 - (_remaining / within).clamp(0.0, 1.0) : 0.0;
    // _remaining is infinite until the video reports a position: never round that.
    final secs = _remaining.isFinite ? _remaining.ceil().clamp(1, 99) : 0;
    final next = widget.next;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.4),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: const Color(0xE61A1820),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPlayNow,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 54,
                        height: 72,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DramaImage(next.stillUrl ?? widget.fallbackImage),
                            if (next.isLocked)
                              const ColoredBox(
                                color: Color(0x88000000),
                                child: Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Дараагийн анги · $secs',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${next.number}-р анги',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (next.isLocked && next.coinPrice != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const CoinIcon(size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  '${next.coinPrice} зоосоор нээнэ',
                                  style: const TextStyle(
                                    color: DramaColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: widget.onCancel,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Болих',
                                style: TextStyle(
                                  color: DramaColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Countdown ring around a play button
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              backgroundColor: Colors.white12,
                              color: LemonyBrand.amber,
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LemonyBrand.gradient,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
