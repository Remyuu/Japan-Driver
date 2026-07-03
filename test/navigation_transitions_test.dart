import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/navigation_transitions.dart';

void main() {
  test('web routes use the official Material fade-forwards transition', () {
    for (final platform in TargetPlatform.values) {
      final builder = webPageTransitionsTheme.builders[platform];
      expect(builder, isA<FadeForwardsPageTransitionsBuilder>());
      expect(
        builder!.transitionDuration,
        const Duration(
          milliseconds:
              FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
        ),
      );
    }
  });
}
