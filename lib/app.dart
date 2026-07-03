import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/liquid_glass.dart';
import 'navigation_transitions.dart';
import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/records_screen.dart';
import 'screens/stage_screen.dart';
import 'screens/stats_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            platformRoutePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/stage/:stageId',
        pageBuilder: (context, state) => platformRoutePage(
          state,
          StageScreen(stageId: state.pathParameters['stageId']!),
        ),
      ),
      GoRoute(
        path: '/stage/:stageId/:sectionId',
        pageBuilder: (context, state) => platformRoutePage(
          state,
          StageScreen(
            stageId: state.pathParameters['stageId']!,
            sectionId: state.pathParameters['sectionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/practice/:bankId',
        pageBuilder: (context, state) {
          final chapter = int.tryParse(
            state.uri.queryParameters['chapter'] ?? '',
          );
          final workbook = int.tryParse(
            state.uri.queryParameters['workbook'] ?? '',
          );
          final rangeStep = int.tryParse(
            state.uri.queryParameters['rangeStep'] ?? '',
          );
          return platformRoutePage(
            state,
            PracticeScreen(
              bankId: state.pathParameters['bankId']!,
              feedbackMode: PracticeFeedbackMode.fromQuery(
                state.uri.queryParameters['mode'],
              ),
              chapterNumber: chapter,
              workbookNumber: workbook,
              rangeStep: rangeStep,
              stageId: state.uri.queryParameters['stage'],
              stageSectionId: state.uri.queryParameters['section'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/review/wrong',
        pageBuilder: (context, state) =>
            platformRoutePage(state, const WrongReviewScreen()),
      ),
      GoRoute(
        path: '/favorites/:stageId',
        pageBuilder: (context, state) => platformRoutePage(
          state,
          FavoritesScreen(stageId: state.pathParameters['stageId']!),
        ),
      ),
      GoRoute(
        path: '/records',
        pageBuilder: (context, state) =>
            platformRoutePage(state, const RecordsScreen()),
      ),
      GoRoute(
        path: '/records/:recordId',
        pageBuilder: (context, state) => platformRoutePage(
          state,
          RecordDetailScreen(
            recordId: Uri.decodeComponent(state.pathParameters['recordId']!),
          ),
        ),
      ),
      GoRoute(
        path: '/stats',
        pageBuilder: (context, state) =>
            platformRoutePage(state, const StatsScreen()),
      ),
    ],
  );
});

class JapanDriverApp extends ConsumerWidget {
  const JapanDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsControllerProvider).value;

    return MaterialApp.router(
      title: 'Japan Driver',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings?.darkMode == true ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF101513) : LiquidColors.paper;
  final surface = isDark ? const Color(0xFF1B2322) : Colors.white;
  final foreground = isDark ? const Color(0xFFF3F6F3) : LiquidColors.ink;
  final border = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : const Color(0xFFDCE5E1);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: LiquidColors.primary,
    brightness: brightness,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Hiragino Sans',
    pageTransitionsTheme: kIsWeb
        ? webPageTransitionsTheme
        : const PageTransitionsTheme(),
    scaffoldBackgroundColor: background,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark
          ? surface.withValues(alpha: 0.78)
          : surface.withValues(alpha: 0.72),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.66),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
    ),
  );
}
