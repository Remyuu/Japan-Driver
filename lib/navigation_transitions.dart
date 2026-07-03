import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const webPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
  },
);

enum RouteTransitionKind { backFallback }

Page<void> platformRoutePage(GoRouterState state, Widget child) {
  if (state.extra == RouteTransitionKind.backFallback) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }

  return MaterialPage<void>(key: state.pageKey, child: child);
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
