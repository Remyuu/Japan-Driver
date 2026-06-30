import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/answer_choice.dart';
import 'models/account_user.dart';
import 'models/app_settings.dart';
import 'models/practice_draft.dart';
import 'models/practice_record.dart';
import 'models/progress_store.dart';
import 'models/question_bank.dart';
import 'models/question_comment.dart';
import 'repositories/account_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/question_repository.dart';
import 'repositories/settings_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return const AccountRepository();
});

final accountUserProvider = StreamProvider<AccountUser?>((ref) {
  return ref.watch(accountRepositoryProvider).authStateChanges();
});

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return const QuestionRepository();
});

final questionBanksProvider = FutureProvider<List<QuestionBank>>((ref) async {
  return ref.watch(questionRepositoryProvider).loadBanks();
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return const ProgressRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SettingsRepository();
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

final progressControllerProvider =
    AsyncNotifierProvider<ProgressController, ProgressStore>(
      ProgressController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> _saveSettings(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.watch(settingsRepositoryProvider).save(settings);
  }

  Future<void> setDarkMode(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(darkMode: value));
  }

  Future<void> setAutoAdvance(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(autoAdvance: value));
  }

  Future<void> setShowRuby(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(showRuby: value));
  }
}

class ProgressController extends AsyncNotifier<ProgressStore> {
  @override
  Future<ProgressStore> build() {
    return ref.watch(progressRepositoryProvider).load();
  }

  Future<void> recordAnswer({
    required String questionId,
    required AnswerChoice selectedAnswer,
    required AnswerChoice correctAnswer,
  }) async {
    final current = state.value ?? ProgressStore.empty();
    final next = current.recordAnswer(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
      correctAnswer: correctAnswer,
    );
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }

  Future<void> saveDraft(PracticeDraft draft) async {
    final current = state.value ?? ProgressStore.empty();
    final next = current.saveDraft(draft);
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }

  Future<void> removeDraft(String sessionId) async {
    final current = state.value ?? ProgressStore.empty();
    final next = current.removeDraft(sessionId);
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }

  Future<void> saveRecord(PracticeRecord record) async {
    final current = state.value ?? ProgressStore.empty();
    final next = current.addRecord(record);
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }

  Future<void> addComment({
    required String questionId,
    required String text,
    required String authorLabel,
    String? authorId,
  }) async {
    final createdAt = DateTime.now();
    final current = state.value ?? ProgressStore.empty();
    final next = current.addComment(
      QuestionComment(
        id: '$questionId|${createdAt.microsecondsSinceEpoch}',
        questionId: questionId,
        text: text,
        authorLabel: authorLabel,
        authorId: authorId,
        createdAt: createdAt,
      ),
    );
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }

  Future<void> removeComment({
    required String questionId,
    required String commentId,
  }) async {
    final current = state.value ?? ProgressStore.empty();
    final next = current.removeComment(
      questionId: questionId,
      commentId: commentId,
    );
    state = AsyncData(next);
    await ref.watch(progressRepositoryProvider).save(next);
  }
}
