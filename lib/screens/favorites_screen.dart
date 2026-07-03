import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/liquid_glass.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../providers.dart';
import '../question_stage.dart';
import '../widgets/account_gate.dart';
import 'practice_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key, required this.stageId});

  final String stageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = switch (stageId) {
      'karimen' => '仮免のお気に入り',
      'sotsuken' => '本免のお気に入り',
      _ => null,
    };
    if (title == null) {
      return const Scaffold(
        body: LiquidBackground(child: Center(child: Text('お気に入りが見つかりません'))),
      );
    }

    final userAsync = ref.watch(accountUserProvider);
    if (userAsync.isLoading) {
      return const Scaffold(
        body: LiquidBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (userAsync.value == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: LiquidBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const AccountRequiredCard(
                  title: 'お気に入りにはアカウント連携が必要です',
                  message: '保存した問題は連携したアカウントごとに管理されます。',
                  icon: Icons.bookmark_outline_rounded,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final progress =
        ref.watch(progressControllerProvider).value ?? ProgressStore.empty();
    final favoriteIds = progress.favoritesForStage(stageId);
    return ref
        .watch(questionBanksProvider)
        .when(
          data: (banks) {
            final byId = <String, DriverQuestion>{};
            for (final bank in banks) {
              for (final question in bank.questions) {
                if (favoriteIds.contains(question.canonicalId) &&
                    questionStageId(question) == stageId) {
                  byId.putIfAbsent(question.canonicalId, () => question);
                }
              }
            }
            final questions = byId.values.toList()
              ..sort((a, b) => a.questionKey.compareTo(b.questionKey));
            return QuestionPracticeRunner(
              title: title,
              subtitle: '${questions.length}問',
              questions: questions,
              feedbackMode: PracticeFeedbackMode.instant,
              sessionId: 'favorites:$stageId',
              emptyMessage: 'お気に入りはまだありません',
            );
          },
          loading: () => const Scaffold(
            body: LiquidBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => Scaffold(
            body: LiquidBackground(child: Center(child: Text('$error'))),
          ),
        );
  }
}
