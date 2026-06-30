import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const forwardRouteEntryOffset = Offset(1, 0);
const backRouteExitOffset = Offset(1, 0);

enum RouteTransitionKind { backFallback }

Page<void> directionalRoutePage(GoRouterState state, Widget child) {
  if (state.extra == RouteTransitionKind.backFallback) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }

  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _DirectionalSlideTransition(animation: animation, child: child);
    },
    child: child,
  );
}

Offset routeTransitionOffset(AnimationStatus status, double value) {
  final isReverse = status == AnimationStatus.reverse;
  final progress = isReverse ? 1 - value : value;
  final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
  final start = isReverse ? Offset.zero : forwardRouteEntryOffset;
  final end = isReverse ? backRouteExitOffset : Offset.zero;
  return Offset(
    start.dx + (end.dx - start.dx) * eased,
    start.dy + (end.dy - start.dy) * eased,
  );
}

class _DirectionalSlideTransition extends StatelessWidget {
  const _DirectionalSlideTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return FractionalTranslation(
          translation: routeTransitionOffset(animation.status, animation.value),
          child: child,
        );
      },
    );
  }
}

extension BackNavigation on BuildContext {
  void popOrGoBack(String location) {
    if (canPop()) {
      pop();
      return;
    }
    go(location, extra: RouteTransitionKind.backFallback);
  }
}
