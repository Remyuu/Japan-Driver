import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/navigation_transitions.dart';

void main() {
  test('route pop exits right', () {
    expect(routeTransitionOffset(AnimationStatus.reverse, 1), Offset.zero);
    expect(
      routeTransitionOffset(AnimationStatus.reverse, 0.5).dx,
      greaterThan(0),
    );
    expect(
      routeTransitionOffset(AnimationStatus.reverse, 0),
      backRouteExitOffset,
    );
  });

  test('route push enters from the right and moves left', () {
    expect(
      routeTransitionOffset(AnimationStatus.forward, 0),
      forwardRouteEntryOffset,
    );
    expect(
      routeTransitionOffset(AnimationStatus.forward, 0.5).dx,
      greaterThan(0),
    );
    expect(routeTransitionOffset(AnimationStatus.forward, 1), Offset.zero);
  });
}
