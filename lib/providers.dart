import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/answer_choice.dart';
import 'models/account_user.dart';
import 'models/app_settings.dart';
import 'models/practice_draft.dart';
import 'models/practice_record.dart';
import 'models/progress_store.dart';
import 'models/question_bank.dart';
import 'models/question_comment.dart';
import 'models/question_translation.dart';
import 'models/translation_language.dart';
import 'repositories/account_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/question_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/translation_repository.dart';

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

final questionBankProvider = FutureProvider.family<QuestionBank, String>((
  ref,
  bankId,
) async {
  return ref.watch(questionRepositoryProvider).loadBank(bankId);
});

final questionBankSummariesProvider = FutureProvider<List<QuestionBankSummary>>(
  (ref) async {
    return ref.watch(questionRepositoryProvider).loadBankSummaries();
  },
);

final questionBankSummaryProvider =
    FutureProvider.family<QuestionBankSummary, String>((ref, bankId) async {
      return ref.watch(questionRepositoryProvider).loadBankSummary(bankId);
    });

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    idTokenProvider: ref.watch(accountRepositoryProvider).getIdToken,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SettingsRepository();
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository();
});

typedef QuestionTranslationLookup = ({
  DriverQuestion question,
  bool generateIfMissing,
  TranslationLanguage language,
});

final questionTranslationProvider = FutureProvider.autoDispose
    .family<QuestionTranslation?, QuestionTranslationLookup>((ref, lookup) {
      final question = lookup.question;
      final local = QuestionTranslation(
        question: lookup.language == TranslationLanguage.chinese
            ? question.questionChinese
            : null,
        explanation: lookup.language == TranslationLanguage.chinese
            ? question.explanationChinese
            : null,
        subquestions: [
          for (final subquestion in question.subquestions)
            lookup.language == TranslationLanguage.chinese
                ? subquestion.textChinese
                : null,
        ],
      );
      if (local.isComplete(
        hasExplanation: question.explanation.isNotEmpty,
        subquestionCount: question.subquestions.length,
      )) {
        return Future.value(local);
      }

      return ref
          .watch(translationRepositoryProvider)
          .getQuestionTranslation(
            question,
            language: lookup.language,
            generateIfMissing: lookup.generateIfMissing,
          )
          .then((remote) => local.merge(remote));
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

  Future<void> setShowChinese(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(showChinese: value));
  }

  Future<void> setShowEnglish(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(showEnglish: value));
  }

  Future<void> setShowVietnamese(bool value) async {
    final current = state.value ?? AppSettings.defaults();
    await _saveSettings(current.copyWith(showVietnamese: value));
  }
}

class ProgressController extends AsyncNotifier<ProgressStore> {
  static const _answerSaveDebounce = Duration(milliseconds: 900);

  String? _userId;
  Timer? _scheduledSaveTimer;
  ProgressStore? _scheduledSaveStore;
  Future<void> _saveQueue = Future<void>.value();

  @override
  Future<ProgressStore> build() async {
    ref.onDispose(() {
      _scheduledSaveTimer?.cancel();
    });
    final user = ref.watch(accountUserProvider).value;
    _userId = user?.id;
    if (_userId == null) {
      return ProgressStore.empty();
    }
    return ref.watch(progressRepositoryProvider).load(_userId!);
  }

  Future<void> _save(
    ProgressStore store, {
    bool debounceRemoteSave = false,
  }) async {
    final userId = ref.read(accountUserProvider).value?.id ?? _userId;
    if (userId == null) {
      state = AsyncData(ProgressStore.empty());
      return;
    }
    if (debounceRemoteSave) {
      state = AsyncData(store);
      _scheduleRemoteSave(userId, store);
      return;
    }
    final previous = state;
    _scheduledSaveTimer?.cancel();
    _scheduledSaveTimer = null;
    _scheduledSaveStore = null;
    state = AsyncData(store);
    try {
      await _persist(userId, store);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  void _scheduleRemoteSave(String userId, ProgressStore store) {
    _scheduledSaveStore = store;
    _scheduledSaveTimer?.cancel();
    _scheduledSaveTimer = Timer(_answerSaveDebounce, () {
      final pending = _scheduledSaveStore;
      _scheduledSaveStore = null;
      _scheduledSaveTimer = null;
      if (pending == null) {
        return;
      }
      unawaited(_persist(userId, pending).catchError((_) {}));
    });
  }

  Future<void> _persist(String userId, ProgressStore store) {
    final previousSaves = _saveQueue.catchError((_) {});
    final save = previousSaves.then(
      (_) => ref.read(progressRepositoryProvider).save(userId, store),
    );
    _saveQueue = save;
    return save;
  }

  Future<void> recordAnswer({
    required String questionId,
    required AnswerChoice? selectedAnswer,
    required AnswerChoice correctAnswer,
    bool? isCorrectOverride,
  }) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    final next = current.recordAnswer(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
      correctAnswer: correctAnswer,
      isCorrectOverride: isCorrectOverride,
    );
    await _save(next, debounceRemoteSave: true);
  }

  Future<void> recordAnswers(
    List<
      ({
        String questionId,
        AnswerChoice? selectedAnswer,
        AnswerChoice correctAnswer,
        bool isCorrect,
      })
    >
    answers,
  ) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null ||
        answers.isEmpty) {
      return;
    }
    var next = state.value ?? ProgressStore.empty();
    for (final answer in answers) {
      next = next.recordAnswer(
        questionId: answer.questionId,
        selectedAnswer: answer.selectedAnswer,
        correctAnswer: answer.correctAnswer,
        isCorrectOverride: answer.isCorrect,
      );
    }
    await _save(next);
  }

  Future<void> saveDraft(PracticeDraft draft) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    final next = current.saveDraft(draft);
    await _save(next);
  }

  Future<void> removeDraft(String sessionId) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    final next = current.removeDraft(sessionId);
    await _save(next);
  }

  Future<void> saveRecord(PracticeRecord record) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    final next = current.addRecord(record);
    await _save(next);
  }

  Future<void> toggleFavorite({
    required String stageId,
    required String questionId,
  }) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    await _save(
      current.toggleFavorite(stageId: stageId, questionId: questionId),
    );
  }

  Future<void> addComment({
    required String questionId,
    required String text,
    required String authorLabel,
    String? authorId,
  }) async {
    final userId = ref.read(accountUserProvider).value?.id ?? _userId;
    if (userId == null) {
      return;
    }
    final createdAt = DateTime.now();
    final current = state.value ?? ProgressStore.empty();
    final next = current.addComment(
      QuestionComment(
        id: '$questionId|${createdAt.microsecondsSinceEpoch}',
        questionId: questionId,
        text: text,
        authorLabel: authorLabel,
        authorId: authorId ?? userId,
        createdAt: createdAt,
      ),
    );
    await _save(next);
  }

  Future<void> removeComment({
    required String questionId,
    required String commentId,
  }) async {
    if ((ref.read(accountUserProvider).value?.id ?? _userId) == null) {
      return;
    }
    final current = state.value ?? ProgressStore.empty();
    final next = current.removeComment(
      questionId: questionId,
      commentId: commentId,
    );
    await _save(next);
  }
}
