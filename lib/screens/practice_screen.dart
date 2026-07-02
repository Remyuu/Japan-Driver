import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account_access.dart';
import '../models/answer_choice.dart';
import '../models/app_settings.dart';
import '../models/practice_draft.dart';
import '../models/practice_record.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../models/question_comment.dart';
import '../models/question_translation.dart';
import '../models/translation_language.dart';
import '../navigation_transitions.dart';
import '../providers.dart';
import '../question_stage.dart';
import '../translation_messages.dart';
import '../widgets/account_gate.dart';
import '../widgets/ruby_text.dart';

enum PracticeFeedbackMode {
  instant,
  exam;

  static PracticeFeedbackMode fromQuery(String? value) {
    return value == 'exam'
        ? PracticeFeedbackMode.exam
        : PracticeFeedbackMode.instant;
  }
}

enum _ExitAction { save, discard, cancel }

enum _PracticeDetailMode { explanation, comments }

class _TranslationState {
  const _TranslationState({
    required this.value,
    required this.isLoading,
    required this.error,
  });

  final QuestionTranslation value;
  final bool isLoading;
  final Object? error;

  factory _TranslationState.fromQuestion(
    DriverQuestion? question,
    TranslationLanguage language,
  ) {
    final hasBundledTranslation = language == TranslationLanguage.chinese;
    return _TranslationState(
      value: QuestionTranslation(
        question: hasBundledTranslation ? question?.questionChinese : null,
        explanation: hasBundledTranslation
            ? question?.explanationChinese
            : null,
      ),
      isLoading: false,
      error: null,
    );
  }

  _TranslationState withAsync(
    AsyncValue<QuestionTranslation?> translationAsync,
  ) {
    return _TranslationState(
      value: value.merge(translationAsync.value),
      isLoading: translationAsync.isLoading,
      error: translationAsync.error,
    );
  }
}

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({
    super.key,
    required this.bankId,
    required this.feedbackMode,
    required this.chapterNumber,
    required this.workbookNumber,
    required this.rangeStep,
    required this.stageId,
    required this.stageSectionId,
  });

  final String bankId;
  final PracticeFeedbackMode feedbackMode;
  final int? chapterNumber;
  final int? workbookNumber;
  final int? rangeStep;
  final String? stageId;
  final String? stageSectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    if (userAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (userAsync.value == null &&
        !canGuestStartPractice(
          bankId: bankId,
          isInstantFeedback: feedbackMode == PracticeFeedbackMode.instant,
          workbookNumber: workbookNumber,
          chapterNumber: chapterNumber,
          rangeStep: rangeStep,
        )) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('アカウント連携'),
          leading: IconButton(
            tooltip: '戻る',
            onPressed: () => context.popOrGoBack('/'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const AccountRequiredCard(
                title: 'この問題にはアカウント連携が必要です',
                message: '未連携では、仮免・本免の一問一答「第1回」のみ利用できます。',
                icon: Icons.lock_outline_rounded,
              ),
            ),
          ),
        ),
      );
    }
    final banksAsync = ref.watch(questionBanksProvider);
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );

    return banksAsync.when(
      data: (banks) {
        final bank = banks.where((item) => item.id == bankId).firstOrNull;
        if (bank == null) {
          return const _MissingScreen(message: '問題集が見つかりません');
        }
        var questions = bank.questions;
        if (chapterNumber != null) {
          questions = questions
              .where(
                (question) => question.chapterNumbers.contains(chapterNumber),
              )
              .toList();
        }
        if (workbookNumber != null) {
          questions = questions
              .where((question) => question.workbookDisplayNo == workbookNumber)
              .toList();
        }
        if (rangeStep != null) {
          questions = questions
              .where((question) => question.rangeStep == rangeStep)
              .toList();
        }
        final chapter = chapterNumber == null
            ? null
            : bank.chapters
                  .where((item) => item.number == chapterNumber)
                  .firstOrNull;
        final subtitle = [
          bank.subtitle,
          if (workbookNumber != null) '第$workbookNumber回',
          if (chapter != null) '${chapter.number}. ${chapter.name}',
          if (rangeStep != null) rangeStep == 1 ? '第一段階' : '第二段階',
        ].join(' / ');
        final mode = feedbackMode == PracticeFeedbackMode.exam
            ? 'exam'
            : 'instant';
        final sessionId = practiceSessionId(
          bankId: bankId,
          mode: mode,
          workbookNumber: workbookNumber,
          chapterNumber: chapterNumber,
          rangeStep: rangeStep,
        );

        return QuestionPracticeRunner(
          title: bank.title,
          subtitle: subtitle,
          questions: questions,
          feedbackMode: feedbackMode,
          sessionId: sessionId,
          initialDraft: progress.drafts[sessionId],
          stageId: stageId,
          stageSectionId: stageSectionId,
          emptyMessage: '問題がありません',
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _MissingScreen(message: '$error'),
    );
  }
}

class WrongReviewScreen extends ConsumerWidget {
  const WrongReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final banksAsync = ref.watch(questionBanksProvider);
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );

    if (userAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('間違い復習'),
          leading: IconButton(
            tooltip: '戻る',
            onPressed: () => context.popOrGoBack('/'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AccountRequiredCard(
                title: '間違い復習にはアカウント連携が必要です',
                message: '間違えた問題は連携したアカウントに保存されます。',
                icon: Icons.replay_rounded,
              ),
            ),
          ),
        ),
      );
    }

    return banksAsync.when(
      data: (banks) {
        final byId = <String, DriverQuestion>{};
        for (final bank in banks) {
          for (final question in bank.questions) {
            byId.putIfAbsent(question.canonicalId, () => question);
          }
        }
        final wrongQuestions = [
          for (final id in progress.wrongQuestionIds)
            if (byId[id] != null) byId[id]!,
        ]..sort((a, b) => a.questionKey.compareTo(b.questionKey));

        return QuestionPracticeRunner(
          title: '間違い復習',
          subtitle: '${wrongQuestions.length}問',
          questions: wrongQuestions,
          feedbackMode: PracticeFeedbackMode.instant,
          sessionId: 'wrong-review',
          emptyMessage: '間違いはありません',
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _MissingScreen(message: '$error'),
    );
  }
}

class QuestionPracticeRunner extends ConsumerStatefulWidget {
  const QuestionPracticeRunner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.questions,
    required this.feedbackMode,
    required this.sessionId,
    required this.emptyMessage,
    this.stageId,
    this.stageSectionId,
    this.initialDraft,
  });

  final String title;
  final String subtitle;
  final List<DriverQuestion> questions;
  final PracticeFeedbackMode feedbackMode;
  final String sessionId;
  final String emptyMessage;
  final String? stageId;
  final String? stageSectionId;
  final PracticeDraft? initialDraft;

  @override
  ConsumerState<QuestionPracticeRunner> createState() =>
      _QuestionPracticeRunnerState();
}

class _QuestionPracticeRunnerState
    extends ConsumerState<QuestionPracticeRunner> {
  static const _examDurationSeconds = 30 * 60;

  int _index = 0;
  final Map<int, AnswerChoice> _selectedAnswers = {};
  bool _examSubmitted = false;
  bool _examResultsSaved = false;
  bool _practiceRecordSaved = false;
  Timer? _timer;
  int? _remainingSeconds;
  _PracticeDetailMode _detailMode = _PracticeDetailMode.explanation;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _index = draft.currentIndex
          .clamp(0, math.max(widget.questions.length - 1, 0))
          .toInt();
      _selectedAnswers.addAll(draft.answers);
      _remainingSeconds = draft.remainingSeconds;
    }
    if (_isExam) {
      _remainingSeconds ??= _examDurationSeconds;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DriverQuestion? get _currentQuestion {
    if (widget.questions.isEmpty) {
      return null;
    }
    _index = math.min(_index, widget.questions.length - 1);
    return widget.questions[_index];
  }

  Future<void> _choose(DriverQuestion question, AnswerChoice choice) async {
    final answeredIndex = _index;
    final alreadyAnswered = _selectedAnswers.containsKey(_index);
    if (widget.feedbackMode == PracticeFeedbackMode.instant &&
        alreadyAnswered) {
      return;
    }
    if (_examSubmitted) {
      return;
    }
    setState(() => _selectedAnswers[_index] = choice);
    if (widget.feedbackMode == PracticeFeedbackMode.instant) {
      await ref
          .read(progressControllerProvider.notifier)
          .recordAnswer(
            questionId: question.canonicalId,
            selectedAnswer: choice,
            correctAnswer: question.answer,
          );
    }
    await _maybeAutoAdvance(answeredIndex);
  }

  Future<void> _maybeAutoAdvance(int answeredIndex) async {
    final settings =
        ref.read(settingsControllerProvider).value ?? AppSettings.defaults();
    if (!settings.autoAdvance ||
        answeredIndex >= widget.questions.length - 1 ||
        _examSubmitted) {
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: _isExam ? 250 : 750));
    if (!mounted || _examSubmitted || _index != answeredIndex) {
      return;
    }
    if (!_selectedAnswers.containsKey(answeredIndex)) {
      return;
    }
    setState(() => _index = answeredIndex + 1);
  }

  Future<void> _saveExamResults() async {
    if (_examResultsSaved) {
      return;
    }
    final controller = ref.read(progressControllerProvider.notifier);
    for (var i = 0; i < widget.questions.length; i += 1) {
      final answer = _selectedAnswers[i];
      if (answer == null) {
        continue;
      }
      await controller.recordAnswer(
        questionId: widget.questions[i].canonicalId,
        selectedAnswer: answer,
        correctAnswer: widget.questions[i].answer,
      );
    }
    _examResultsSaved = true;
    await _savePracticeRecord();
    await ref
        .read(progressControllerProvider.notifier)
        .removeDraft(widget.sessionId);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isExam || _examSubmitted) {
        timer.cancel();
        return;
      }
      final remaining = _remainingSeconds ?? _examDurationSeconds;
      if (remaining <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
        _submitExam();
        return;
      }
      setState(() => _remainingSeconds = remaining - 1);
    });
  }

  Future<void> _submitExam() async {
    if (_examSubmitted) {
      return;
    }
    await _saveExamResults();
    if (!mounted) {
      return;
    }
    _timer?.cancel();
    setState(() => _examSubmitted = true);
  }

  Future<void> _next() async {
    if (widget.feedbackMode == PracticeFeedbackMode.exam &&
        !_examSubmitted &&
        _index == widget.questions.length - 1) {
      await _submitExam();
      return;
    }

    if (_index >= widget.questions.length - 1) {
      await _finish();
      return;
    }
    setState(() {
      _index += 1;
    });
  }

  void _previous() {
    if (_index == 0) {
      return;
    }
    setState(() {
      _index -= 1;
    });
  }

  Future<void> _finish() async {
    try {
      await _savePracticeRecord();
      await ref
          .read(progressControllerProvider.notifier)
          .removeDraft(widget.sessionId);
    } catch (error) {
      if (mounted) {
        _showSyncError(error);
      }
    } finally {
      if (mounted) {
        _leavePractice();
      }
    }
  }

  void _leavePractice() {
    final stageId = widget.stageId;
    final sectionId = widget.stageSectionId;
    context.popOrGoBack(
      stageId == null
          ? '/'
          : sectionId == null
          ? '/stage/$stageId'
          : '/stage/$stageId/$sectionId',
    );
  }

  Future<void> _savePracticeRecord() async {
    if (_practiceRecordSaved ||
        widget.questions.isEmpty ||
        _selectedAnswers.length != widget.questions.length) {
      return;
    }
    for (var i = 0; i < widget.questions.length; i += 1) {
      if (!_selectedAnswers.containsKey(i)) {
        return;
      }
    }
    final completedAt = DateTime.now();
    final record = PracticeRecord(
      id: '${widget.sessionId}|${completedAt.microsecondsSinceEpoch}',
      sessionId: widget.sessionId,
      title: widget.title,
      subtitle: widget.subtitle,
      mode: widget.feedbackMode.name,
      completedAt: completedAt,
      answers: [
        for (var i = 0; i < widget.questions.length; i += 1)
          PracticeRecordAnswer(
            questionId: widget.questions[i].canonicalId,
            selectedAnswer: _selectedAnswers[i]!,
            correctAnswer: widget.questions[i].answer,
          ),
      ],
    );
    await ref.read(progressControllerProvider.notifier).saveRecord(record);
    _practiceRecordSaved = true;
  }

  bool get _isExam => widget.feedbackMode == PracticeFeedbackMode.exam;

  bool get _revealAnswer => !_isExam || _examSubmitted;

  bool get _canGoNext {
    if (widget.questions.isEmpty) {
      return false;
    }
    if (_isExam && !_examSubmitted && _index == widget.questions.length - 1) {
      return _selectedAnswers.length == widget.questions.length;
    }
    return _selectedAnswers.containsKey(_index);
  }

  String get _nextLabel {
    if (_isExam && !_examSubmitted && _index == widget.questions.length - 1) {
      return '提出';
    }
    return _index == widget.questions.length - 1 ? '完了' : '次へ';
  }

  int get _correctCount {
    var count = 0;
    for (var i = 0; i < widget.questions.length; i += 1) {
      final answer = _selectedAnswers[i];
      if (answer != null && widget.questions[i].isCorrect(answer)) {
        count += 1;
      }
    }
    return count;
  }

  String get _timerText {
    final seconds = _remainingSeconds ?? _examDurationSeconds;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDraftAndLeave() async {
    try {
      await ref
          .read(progressControllerProvider.notifier)
          .saveDraft(
            PracticeDraft(
              sessionId: widget.sessionId,
              currentIndex: _index,
              answers: Map<int, AnswerChoice>.of(_selectedAnswers),
              savedAt: DateTime.now(),
              remainingSeconds: _isExam ? _remainingSeconds : null,
            ),
          );
    } catch (error) {
      if (mounted) {
        _showSyncError(error);
      }
      return;
    }
    if (mounted) {
      _leavePractice();
    }
  }

  Future<void> _discardDraftAndLeave() async {
    try {
      await ref
          .read(progressControllerProvider.notifier)
          .removeDraft(widget.sessionId);
    } catch (_) {
      // Discarding must never trap the user in the practice screen.
    } finally {
      if (mounted) {
        _leavePractice();
      }
    }
  }

  void _showSyncError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('保存できませんでした: $error')));
  }

  Future<void> _confirmExit() async {
    if (_examSubmitted) {
      await _finish();
      return;
    }
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('終了しますか'),
        content: const Text('途中までの回答を保存できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.discard),
            child: const Text('保存しない'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.save),
            child: const Text('保存して終了'),
          ),
        ],
      ),
    );
    switch (action) {
      case _ExitAction.save:
        await _saveDraftAndLeave();
        return;
      case _ExitAction.discard:
        await _discardDraftAndLeave();
        return;
      case _ExitAction.cancel:
      case null:
        return;
    }
  }

  void _jumpToQuestion(int index) {
    if (index < 0 || index >= widget.questions.length) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final selectedAnswer = _selectedAnswers[_index];
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults();
    final progress =
        ref.watch(progressControllerProvider).value ?? ProgressStore.empty();
    final commentCount = question == null
        ? 0
        : progress.commentsByQuestion[question.canonicalId]?.length ?? 0;
    final favoriteStageId = question == null ? null : questionStageId(question);
    final isFavorite =
        question != null &&
        favoriteStageId != null &&
        progress.isFavorite(
          stageId: favoriteStageId,
          questionId: question.canonicalId,
        );
    final userAsync = ref.watch(accountUserProvider);
    final translations = <TranslationLanguage, _TranslationState>{};
    final retryTranslations = <TranslationLanguage, VoidCallback>{};
    if (question != null) {
      for (final language in settings.enabledTranslationLanguages) {
        final lookup = (
          question: question,
          language: language,
          generateIfMissing: true,
        );
        final translationAsync = ref.watch(questionTranslationProvider(lookup));
        translations[language] = _TranslationState.fromQuestion(
          question,
          language,
        ).withAsync(translationAsync);
        retryTranslations[language] = () {
          ref.invalidate(questionTranslationProvider(lookup));
        };
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: '終了',
          onPressed: _confirmExit,
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          if (_isExam)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _TimerBadge(text: _timerText)),
            ),
          if (question != null && favoriteStageId != null)
            IconButton(
              tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
              onPressed: () {
                if (userAsync.value == null) {
                  showAccountDialog(context, ref);
                  return;
                }
                ref
                    .read(progressControllerProvider.notifier)
                    .toggleFavorite(
                      stageId: favoriteStageId,
                      questionId: question.canonicalId,
                    );
              },
              icon: Icon(
                isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          const _PracticeSettingsButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: question == null
          ? _EmptyPractice(message: widget.emptyMessage)
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final content = isWide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _QuestionPanel(
                                  question: question,
                                  title: widget.subtitle,
                                  index: _index,
                                  total: widget.questions.length,
                                  selectedAnswer: selectedAnswer,
                                  revealAnswer: _revealAnswer,
                                  showRuby: settings.showRuby,
                                  translations: translations,
                                  retryTranslations: retryTranslations,
                                  canChangeAnswer:
                                      !_examSubmitted &&
                                      widget.feedbackMode ==
                                          PracticeFeedbackMode.exam,
                                  canGoNext: _canGoNext,
                                  nextLabel: _nextLabel,
                                  onChoose: (choice) =>
                                      _choose(question, choice),
                                  onPrevious: _previous,
                                  onNext: () => _next(),
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 340,
                                child: _SidePanel(
                                  question: question,
                                  selectedAnswer: selectedAnswer,
                                  revealAnswer: _revealAnswer,
                                  showRuby: settings.showRuby,
                                  translations: translations,
                                  retryTranslations: retryTranslations,
                                  examSummary: _examSubmitted
                                      ? '結果 $_correctCount / ${widget.questions.length}'
                                      : null,
                                  index: _index,
                                  total: widget.questions.length,
                                  detailMode: _detailMode,
                                  commentCount: commentCount,
                                  onDetailModeChanged: (mode) {
                                    setState(() => _detailMode = mode);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _AnswerSheetCard(
                            questions: widget.questions,
                            answers: _selectedAnswers,
                            currentIndex: _index,
                            revealAnswer: _revealAnswer,
                            onJumpToQuestion: _jumpToQuestion,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _QuestionPanel(
                            question: question,
                            title: widget.subtitle,
                            index: _index,
                            total: widget.questions.length,
                            selectedAnswer: selectedAnswer,
                            revealAnswer: _revealAnswer,
                            showRuby: settings.showRuby,
                            translations: translations,
                            retryTranslations: retryTranslations,
                            canChangeAnswer:
                                !_examSubmitted &&
                                widget.feedbackMode ==
                                    PracticeFeedbackMode.exam,
                            canGoNext: _canGoNext,
                            nextLabel: _nextLabel,
                            onChoose: (choice) => _choose(question, choice),
                            onPrevious: _previous,
                            onNext: () => _next(),
                          ),
                          const SizedBox(height: 12),
                          if (_examSubmitted) ...[
                            _ExamSummaryCard(
                              text:
                                  '結果 $_correctCount / ${widget.questions.length}',
                            ),
                            const SizedBox(height: 12),
                          ],
                          _QuestionDetailPanel(
                            question: question,
                            selectedAnswer: selectedAnswer,
                            revealAnswer: _revealAnswer,
                            showRuby: settings.showRuby,
                            translations: translations,
                            retryTranslations: retryTranslations,
                            mode: _detailMode,
                            commentCount: commentCount,
                            onModeChanged: (mode) {
                              setState(() => _detailMode = mode);
                            },
                          ),
                          const SizedBox(height: 12),
                          _AnswerSheetCard(
                            questions: widget.questions,
                            answers: _selectedAnswers,
                            currentIndex: _index,
                            revealAnswer: _revealAnswer,
                            onJumpToQuestion: _jumpToQuestion,
                          ),
                        ],
                      );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: content,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.question,
    required this.title,
    required this.index,
    required this.total,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.canChangeAnswer,
    required this.canGoNext,
    required this.nextLabel,
    required this.onChoose,
    required this.onPrevious,
    required this.onNext,
  });

  final DriverQuestion question;
  final String title;
  final int index;
  final int total;
  final AnswerChoice? selectedAnswer;
  final bool revealAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final bool canChangeAnswer;
  final bool canGoNext;
  final String nextLabel;
  final ValueChanged<AnswerChoice> onChoose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: textTheme.titleMedium)),
                Text('${index + 1} / $total'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: (index + 1) / total),
            const SizedBox(height: 22),
            RubyText(
              text: question.questionText,
              rubyHtml: question.questionRubyHtml,
              showRuby: showRuby,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            for (final entry in translations.entries) ...[
              const SizedBox(height: 14),
              _TranslationCard(
                language: entry.key,
                text: entry.value.value.question,
                isLoading: entry.value.isLoading,
                error: entry.value.error,
                onRetry: retryTranslations[entry.key],
              ),
            ],
            if (question.questionImageAssetPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ImageList(paths: question.questionImageAssetPaths),
            ],
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 560;
                final buttons = [
                  _AnswerButton(
                    choice: AnswerChoice.circle,
                    selectedAnswer: selectedAnswer,
                    correctAnswer: question.answer,
                    revealAnswer: revealAnswer,
                    canChangeAnswer: canChangeAnswer,
                    onTap: () => onChoose(AnswerChoice.circle),
                  ),
                  _AnswerButton(
                    choice: AnswerChoice.cross,
                    selectedAnswer: selectedAnswer,
                    correctAnswer: question.answer,
                    revealAnswer: revealAnswer,
                    canChangeAnswer: canChangeAnswer,
                    onTap: () => onChoose(AnswerChoice.cross),
                  ),
                ];
                return twoColumns
                    ? Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 12),
                          Expanded(child: buttons[1]),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buttons[0],
                          const SizedBox(height: 12),
                          buttons[1],
                        ],
                      );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: index == 0 ? null : onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('前へ'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canGoNext ? onNext : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.choice,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.revealAnswer,
    required this.canChangeAnswer,
    required this.onTap,
  });

  final AnswerChoice choice;
  final AnswerChoice? selectedAnswer;
  final AnswerChoice correctAnswer;
  final bool revealAnswer;
  final bool canChangeAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = selectedAnswer != null;
    final selected = selectedAnswer == choice;
    final isCorrectChoice = correctAnswer == choice;
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final borderColor = !answered
        ? colorScheme.onSurface
        : !revealAnswer
        ? selected
              ? const Color(0xFF2F6F73)
              : const Color(0xFFE3E1DC)
        : isCorrectChoice
        ? const Color(0xFF1D7F48)
        : selected
        ? const Color(0xFFB73A36)
        : const Color(0xFFE3E1DC);
    final background = !answered
        ? surface
        : !revealAnswer
        ? selected
              ? const Color(0xFFE8F3F3)
              : surface
        : isCorrectChoice
        ? const Color(0xFFEAF6EE)
        : selected
        ? const Color(0xFFFBEDEC)
        : surface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: !answered || canChangeAnswer ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor, width: 1.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          choice.label,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.language,
    required this.text,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final TranslationLanguage language;
  final String? text;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: colorScheme.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.displayLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (text != null)
            Text(text!, style: Theme.of(context).textTheme.bodyLarge)
          else if (isLoading)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(language.loadingMessage)),
              ],
            )
          else ...[
            Text(translationFailureMessage(language, error)),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(language.retryLabel),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.question,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.examSummary,
    required this.index,
    required this.total,
    required this.detailMode,
    required this.commentCount,
    required this.onDetailModeChanged,
  });

  final DriverQuestion question;
  final AnswerChoice? selectedAnswer;
  final bool revealAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final String? examSummary;
  final int index;
  final int total;
  final _PracticeDetailMode detailMode;
  final int commentCount;
  final ValueChanged<_PracticeDetailMode> onDetailModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('進捗', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: (index + 1) / total),
                const SizedBox(height: 10),
                Text('${index + 1} / $total'),
                if (question.workbookDisplayNo != null ||
                    question.sequence != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (question.workbookDisplayNo != null)
                        '第${question.workbookDisplayNo}回',
                      if (question.sequence != null) '問${question.sequence}',
                    ].join(' / '),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (examSummary != null) ...[
          _ExamSummaryCard(text: examSummary!),
          const SizedBox(height: 12),
        ],
        _QuestionDetailPanel(
          question: question,
          selectedAnswer: selectedAnswer,
          revealAnswer: revealAnswer,
          showRuby: showRuby,
          translations: translations,
          retryTranslations: retryTranslations,
          mode: detailMode,
          commentCount: commentCount,
          onModeChanged: onDetailModeChanged,
        ),
      ],
    );
  }
}

class _QuestionDetailPanel extends StatelessWidget {
  const _QuestionDetailPanel({
    required this.question,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.mode,
    required this.commentCount,
    required this.onModeChanged,
  });

  final DriverQuestion question;
  final AnswerChoice? selectedAnswer;
  final bool revealAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final _PracticeDetailMode mode;
  final int commentCount;
  final ValueChanged<_PracticeDetailMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_PracticeDetailMode>(
          segments: [
            const ButtonSegment(
              value: _PracticeDetailMode.explanation,
              icon: Icon(Icons.menu_book_outlined),
              label: Text('解説'),
            ),
            ButtonSegment(
              value: _PracticeDetailMode.comments,
              icon: const Icon(Icons.mode_comment_outlined),
              label: Text('コメント $commentCount'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            onModeChanged(selection.single);
          },
        ),
        const SizedBox(height: 12),
        if (mode == _PracticeDetailMode.explanation)
          _ResultPanel(
            question: question,
            selectedAnswer: selectedAnswer,
            revealAnswer: revealAnswer,
            showRuby: showRuby,
            translations: translations,
            retryTranslations: retryTranslations,
          )
        else
          _CommentPanel(questionId: question.canonicalId),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.question,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
  });

  final DriverQuestion question;
  final AnswerChoice? selectedAnswer;
  final bool revealAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAnswer;
    if (selected == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('未回答', style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }

    if (!revealAnswer) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('回答済み', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('あなたの答え：${selected.label}'),
              const SizedBox(height: 8),
              const Text('採点は提出後に表示されます'),
            ],
          ),
        ),
      );
    }

    final isCorrect = question.isCorrect(selected);
    final color = isCorrect ? const Color(0xFF1D7F48) : const Color(0xFFB73A36);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? '正解' : '不正解',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('答え：${question.answer.label}'),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 14),
              RubyText(
                text: question.explanation,
                rubyHtml: question.explanationRubyHtml,
                showRuby: showRuby,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (question.explanation.isNotEmpty)
              for (final entry in translations.entries) ...[
                const SizedBox(height: 12),
                _TranslationCard(
                  language: entry.key,
                  text: entry.value.value.explanation,
                  isLoading: entry.value.isLoading,
                  error: entry.value.error,
                  onRetry: retryTranslations[entry.key],
                ),
              ],
            if (question.explanationImageAssetPaths.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ImageList(paths: question.explanationImageAssetPaths),
            ],
            if (question.textbookRef != null) ...[
              const SizedBox(height: 14),
              Text(question.textbookRef!),
            ],
            if (question.schoolAccuracyRate != null ||
                question.nationwideAccuracyRate != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (question.schoolAccuracyRate != null)
                    _SmallPill(label: '教習所内 ${question.schoolAccuracyRate}%'),
                  if (question.nationwideAccuracyRate != null)
                    _SmallPill(label: '全国 ${question.nationwideAccuracyRate}%'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentPanel extends ConsumerStatefulWidget {
  const _CommentPanel({required this.questionId});

  final String questionId;

  @override
  ConsumerState<_CommentPanel> createState() => _CommentPanelState();
}

class _CommentPanelState extends ConsumerState<_CommentPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _CommentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) {
      return;
    }
    final user = ref.read(accountUserProvider).value;
    setState(() => _saving = true);
    await ref
        .read(progressControllerProvider.notifier)
        .addComment(
          questionId: widget.questionId,
          text: text,
          authorLabel: user?.label ?? 'ゲスト',
          authorId: user?.id,
        );
    if (!mounted) {
      return;
    }
    _controller.clear();
    setState(() => _saving = false);
  }

  Future<void> _removeComment(QuestionComment comment) async {
    await ref
        .read(progressControllerProvider.notifier)
        .removeComment(questionId: widget.questionId, commentId: comment.id);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final comments =
        ref
            .watch(progressControllerProvider)
            .value
            ?.commentsByQuestion[widget.questionId] ??
        const <QuestionComment>[];

    if (userAsync.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (user == null) {
      return const AccountRequiredCard(
        title: 'コメントにはアカウント連携が必要です',
        message: '問題ごとのコメントは連携したアカウントに保存されます。',
        icon: Icons.mode_comment_outlined,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (comments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'コメントはまだありません',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              for (var i = 0; i < comments.length; i += 1) ...[
                _CommentItem(
                  comment: comments[i],
                  onDelete: () => _removeComment(comments[i]),
                ),
                if (i != comments.length - 1)
                  const Divider(height: 24, color: Color(0xFFE3E1DC)),
              ],
            if (comments.isNotEmpty) const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'コメント',
                hintText: 'コメントを入力',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _controller.text.trim().isEmpty || _saving
                    ? null
                    : _addComment,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('投稿'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.comment, required this.onDelete});

  final QuestionComment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: const Icon(Icons.person_outline_rounded, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.authorLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatCommentTime(comment.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(comment.text),
            ],
          ),
        ),
        IconButton(
          tooltip: '削除',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

String _formatCommentTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

class _ExamSummaryCard extends StatelessWidget {
  const _ExamSummaryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.fact_check_outlined),
            const SizedBox(width: 10),
            Text(text, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3F3),
        border: Border.all(color: const Color(0xFF2F6F73)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 18),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeSettingsButton extends ConsumerWidget {
  const _PracticeSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '設定',
      onPressed: () {
        showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.18),
          builder: (context) {
            return Consumer(
              builder: (context, ref, child) {
                final settings =
                    ref.watch(settingsControllerProvider).value ??
                    AppSettings.defaults();
                final controller = ref.read(
                  settingsControllerProvider.notifier,
                );

                return Dialog(
                  alignment: Alignment.topRight,
                  insetPadding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '設定',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: '閉じる',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text('明るい'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text('暗い'),
                              ),
                            ],
                            selected: {settings.darkMode},
                            onSelectionChanged: (values) {
                              controller.setDarkMode(values.single);
                            },
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('自動で次の問題へ'),
                            value: settings.autoAdvance,
                            onChanged: controller.setAutoAdvance,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('ふりがなを表示'),
                            value: settings.showRuby,
                            onChanged: controller.setShowRuby,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('显示中文翻译'),
                            value: settings.showChinese,
                            onChanged: controller.setShowChinese,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show English translation'),
                            value: settings.showEnglish,
                            onChanged: controller.setShowEnglish,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hiển thị bản dịch tiếng Việt'),
                            value: settings.showVietnamese,
                            onChanged: controller.setShowVietnamese,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      icon: const Icon(Icons.settings_outlined),
    );
  }
}

class _AnswerSheetCard extends StatelessWidget {
  const _AnswerSheetCard({
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.revealAnswer,
    required this.onJumpToQuestion,
  });

  final List<DriverQuestion> questions;
  final Map<int, AnswerChoice> answers;
  final int currentIndex;
  final bool revealAnswer;
  final ValueChanged<int> onJumpToQuestion;

  @override
  Widget build(BuildContext context) {
    final answered = answers.length;
    final correct = revealAnswer
        ? answers.entries.where((entry) {
            final question = questions[entry.key];
            return question.isCorrect(entry.value);
          }).length
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '解答カード',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  correct == null
                      ? '$answered / ${questions.length}'
                      : '$correct / ${questions.length}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < questions.length; i += 1)
                  _AnswerSheetCell(
                    number: i + 1,
                    isCurrent: i == currentIndex,
                    answer: answers[i],
                    question: questions[i],
                    revealAnswer: revealAnswer,
                    onTap: () => onJumpToQuestion(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerSheetCell extends StatelessWidget {
  const _AnswerSheetCell({
    required this.number,
    required this.isCurrent,
    required this.answer,
    required this.question,
    required this.revealAnswer,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final AnswerChoice? answer;
  final DriverQuestion question;
  final bool revealAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = answer != null;
    final isCorrect = answered && question.isCorrect(answer!);
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final background = !answered
        ? surface
        : !revealAnswer
        ? const Color(0xFFE8F3F3)
        : isCorrect
        ? const Color(0xFFEAF6EE)
        : const Color(0xFFFBEDEC);
    final borderColor = isCurrent
        ? colorScheme.onSurface
        : !answered
        ? const Color(0xFFE3E1DC)
        : !revealAnswer
        ? const Color(0xFF2F6F73)
        : isCorrect
        ? const Color(0xFF1D7F48)
        : const Color(0xFFB73A36);
    final textColor = !answered
        ? colorScheme.onSurface
        : !revealAnswer
        ? const Color(0xFF2F6F73)
        : isCorrect
        ? const Color(0xFF1D7F48)
        : const Color(0xFFB73A36);

    return Tooltip(
      message: answered ? '問$number ${answer!.label}' : '問$number 未回答',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor, width: isCurrent ? 2 : 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final path in paths) ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE3E1DC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(path),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E1DC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }
}

class _EmptyPractice extends StatelessWidget {
  const _EmptyPractice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.popOrGoBack('/'),
            child: const Text('問題集へ'),
          ),
        ],
      ),
    );
  }
}

class _MissingScreen extends StatelessWidget {
  const _MissingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Japan Driver')),
      body: Center(child: Text(message)),
    );
  }
}
