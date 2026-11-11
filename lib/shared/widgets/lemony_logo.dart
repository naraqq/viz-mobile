import 'package:flutter/material.dart';

/// Lemony brand colours (same as the web BrandLogo: rose-400 -> amber-500).
class LemonyBrand {
  static const Color rose = Color(0xFFFB7185);
  static const Color amber = Color(0xFFF59E0B);
  static const LinearGradient gradient = LinearGradient(
    colors: [rose, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Lemony mark (play card) with an optional "lemony" wordmark underneath.
class LemonyLogo extends StatelessWidget {
  const LemonyLogo({super.key, this.size = 96, this.showWordmark = true});

  /// Height of the mark in logical pixels; the wordmark scales with it.
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/images/lemony_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
    if (!showWordmark) return mark;

    final textStyle = TextStyle(
      fontSize: size * 0.36,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      height: 1,
      color: Colors.white,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('lemon', style: textStyle),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => LemonyBrand.gradient.createShader(r),
              child: Text('y', style: textStyle),
            ),
          ],
        ),
      ],
    );
  }
}
