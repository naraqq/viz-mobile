import 'package:flutter/widgets.dart';

/// Vertical feed paging that feels like the big short-video apps: a short flick is enough
/// to change page, and the page settles fast with no wobble.
class SnappyPagePhysics extends PageScrollPhysics {
  const SnappyPagePhysics({super.parent});

  @override
  SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      SnappyPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.4,
    stiffness: 160,
    ratio: 1.05,
  );

  @override
  double get minFlingVelocity => 60;

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}
