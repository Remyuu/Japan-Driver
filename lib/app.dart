import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final background = isDark ? const Color(0xFF111312) : const Color(0xFFFAFAF8);
  final surface = isDark ? const Color(0xFF1B1E1D) : Colors.white;
  final foreground = isDark ? const Color(0xFFF3F2EE) : const Color(0xFF1D1D1F);
  final border = isDark ? const Color(0xFF343938) : const Color(0xFFE3E1DC);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Hiragino Sans',
    pageTransitionsTheme: kIsWeb
        ? webPageTransitionsTheme
        : const PageTransitionsTheme(),
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6F73),
      brightness: brightness,
      surface: surface,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: background,
      foregroundColor: foreground,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
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
  );
}
