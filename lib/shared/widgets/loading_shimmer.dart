import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerBox({super.key, this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class ContentRowShimmer extends StatelessWidget {
  const ContentRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: ShimmerBox(width: 120, height: 18),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) => const ShimmerBox(width: 120, height: 180),
          ),
        ),
      ],
    );
  }
}

class HeroBannerShimmer extends StatelessWidget {
  const HeroBannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(
      width: double.infinity,
      height: 520,
      borderRadius: BorderRadius.zero,
    );
  }
}
