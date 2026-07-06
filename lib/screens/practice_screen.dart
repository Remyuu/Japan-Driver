import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account_access.dart';
import '../design/liquid_glass.dart';
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
import '../widgets/app_settings_button.dart';
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
        subquestions: [
          for (final subquestion in question?.subquestions ?? const [])
            hasBundledTranslation ? subquestion.textChinese : null,
        ],
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
    final bankAsync = ref.watch(questionBankProvider(bankId));
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );

    return bankAsync.when(
      data: (bank) {
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

class WrongReviewScreen extends ConsumerStatefulWidget {
  const WrongReviewScreen({super.key});

  @override
  ConsumerState<WrongReviewScreen> createState() => _WrongReviewScreenState();
}

class _WrongReviewScreenState extends ConsumerState<WrongReviewScreen> {
  List<String>? _sessionWrongIds;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final banksAsync = ref.watch(questionBanksProvider);
    final progressAsync = ref.watch(progressControllerProvider);

    if (userAsync.isLoading ||
        (user != null && progressAsync.isLoading && !progressAsync.hasValue)) {
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
    final progress = progressAsync.value ?? ProgressStore.empty();

    return banksAsync.when(
      data: (banks) {
        final byId = <String, DriverQuestion>{};
        for (final bank in banks) {
          for (final question in bank.questions) {
            byId.putIfAbsent(question.canonicalId, () => question);
          }
        }
        final sessionWrongIds = _sessionWrongIds ??=
            (progress.wrongQuestionIds.toList()..sort());
        final wrongQuestions = [
          for (final id in sessionWrongIds)
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

class _QuestionPracticeRunnerState extends ConsumerState<QuestionPracticeRunner>
    with SingleTickerProviderStateMixin {
  static const _defaultExamDurationSeconds = 30 * 60;
  static const _sotsukenExamDurationSeconds = 60 * 60;
  static const _examPassingScore = 90;
  static final _sotsukenDurationMigrationCutoff = DateTime.utc(
    2026,
    7,
    5,
    8,
    51,
    16,
  );

  int _index = 0;
  final Map<int, Map<int, AnswerChoice>> _selectedAnswers = {};
  bool _examSubmitted = false;
  bool _examSubmitting = false;
  bool _examResultsSaved = false;
  bool _practiceRecordSaved = false;
  Timer? _timer;
  Timer? _draftAutosaveTimer;
  late final AnimationController _examResultController;
  int? _remainingSeconds;
  _PracticeDetailMode _detailMode = _PracticeDetailMode.explanation;

  @override
  void initState() {
    super.initState();
    _examResultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    final draft = widget.initialDraft;
    if (draft != null) {
      final remainingSeconds = _normalizedDraftRemainingSeconds(draft);
      final isExpiredExamDraft =
          _isExam && remainingSeconds != null && remainingSeconds <= 0;
      if (isExpiredExamDraft) {
        unawaited(
          ref
              .read(progressControllerProvider.notifier)
              .removeDraft(widget.sessionId),
        );
      } else {
        _index = draft.currentIndex
            .clamp(0, math.max(widget.questions.length - 1, 0))
            .toInt();
        _selectedAnswers.addAll({
          for (final entry in draft.answers.entries)
            if (entry.value.isNotEmpty)
              entry.key: Map<int, AnswerChoice>.of(entry.value),
        });
        _remainingSeconds = remainingSeconds;
      }
    }
    if (_isExam) {
      _remainingSeconds ??= _examDurationSeconds;
      if (_remainingSeconds! <= 0) {
        _remainingSeconds = _examDurationSeconds;
      }
      _startTimer();
      unawaited(_saveExamDraft());
    }
  }

  @override
  void dispose() {
    _draftAutosaveTimer?.cancel();
    if (_isExam && !_examSubmitted) {
      unawaited(_saveExamDraft());
    }
    _timer?.cancel();
    _examResultController.dispose();
    super.dispose();
  }

  DriverQuestion? get _currentQuestion {
    if (widget.questions.isEmpty) {
      return null;
    }
    _index = math.min(_index, widget.questions.length - 1);
    return widget.questions[_index];
  }

  Future<void> _choose(
    DriverQuestion question,
    int answerIndex,
    AnswerChoice choice,
  ) async {
    final answeredIndex = _index;
    final alreadyAnswered =
        _selectedAnswers[_index]?.containsKey(answerIndex) ?? false;
    if (widget.feedbackMode == PracticeFeedbackMode.instant &&
        alreadyAnswered) {
      return;
    }
    if (_examSubmitted) {
      return;
    }
    setState(() {
      _selectedAnswers.putIfAbsent(_index, () => {})[answerIndex] = choice;
    });
    _scheduleExamDraftAutosave(immediate: true);
    final response = _selectedAnswers[_index] ?? const {};
    if (widget.feedbackMode == PracticeFeedbackMode.instant &&
        question.isResponseComplete(response)) {
      await ref
          .read(progressControllerProvider.notifier)
          .recordAnswer(
            questionId: question.canonicalId,
            selectedAnswer: response[0]!,
            correctAnswer: question.answer,
            isCorrectOverride: question.isResponseCorrect(response),
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
    if (!widget.questions[answeredIndex].isResponseComplete(
      _selectedAnswers[answeredIndex] ?? const {},
    )) {
      return;
    }
    setState(() => _index = answeredIndex + 1);
  }

  Future<void> _saveExamResults() async {
    if (_examResultsSaved) {
      return;
    }
    final answers =
        <
          ({
            String questionId,
            AnswerChoice? selectedAnswer,
            AnswerChoice correctAnswer,
            bool isCorrect,
          })
        >[];
    for (var i = 0; i < widget.questions.length; i += 1) {
      final question = widget.questions[i];
      final response = _selectedAnswers[i] ?? const <int, AnswerChoice>{};
      answers.add((
        questionId: question.canonicalId,
        selectedAnswer: response[0],
        correctAnswer: question.answer,
        isCorrect: question.isResponseCorrect(response),
      ));
    }
    await ref.read(progressControllerProvider.notifier).recordAnswers(answers);
    await _savePracticeRecord();
    await ref
        .read(progressControllerProvider.notifier)
        .removeDraft(widget.sessionId);
    _examResultsSaved = true;
  }

  void _startTimer() {
    _timer?.cancel();
    final initialRemaining = _remainingSeconds ?? _examDurationSeconds;
    if (initialRemaining <= 0) {
      _remainingSeconds = _examDurationSeconds;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isExam || _examSubmitted) {
        timer.cancel();
        return;
      }
      final remaining = _remainingSeconds ?? _examDurationSeconds;
      if (remaining <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
        unawaited(_submitExam(timeExpired: true));
        return;
      }
      setState(() => _remainingSeconds = remaining - 1);
      _scheduleExamDraftAutosave();
    });
  }

  Future<void> _submitExam({bool timeExpired = false}) async {
    if (_examSubmitted || _examSubmitting) {
      return;
    }
    _timer?.cancel();
    setState(() {
      if (timeExpired) {
        _remainingSeconds = 0;
      }
      _examSubmitted = true;
      _examSubmitting = true;
    });
    unawaited(_examResultController.forward(from: 0));
    try {
      await _saveExamResults();
    } catch (error) {
      if (mounted) {
        _showSyncError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _examSubmitting = false);
      }
    }
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
    _scheduleExamDraftAutosave(immediate: _isExam);
  }

  void _previous() {
    if (_index == 0) {
      return;
    }
    setState(() {
      _index -= 1;
    });
    _scheduleExamDraftAutosave(immediate: _isExam);
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
    if (_practiceRecordSaved || widget.questions.isEmpty) {
      return;
    }
    if (!_isExam) {
      if (_selectedAnswers.length != widget.questions.length) {
        return;
      }
      for (var i = 0; i < widget.questions.length; i += 1) {
        if (!widget.questions[i].isResponseComplete(
          _selectedAnswers[i] ?? const {},
        )) {
          return;
        }
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
          if (_isExam ||
              widget.questions[i].isResponseComplete(
                _selectedAnswers[i] ?? const {},
              ))
            PracticeRecordAnswer(
              questionId: widget.questions[i].canonicalId,
              selectedAnswer: _selectedAnswers[i]?[0],
              correctAnswer: widget.questions[i].answer,
              additionalSelectedAnswers: [
                for (
                  var answerIndex = 1;
                  answerIndex < widget.questions[i].correctAnswers.length;
                  answerIndex += 1
                )
                  _selectedAnswers[i]?[answerIndex],
              ],
              additionalCorrectAnswers: widget.questions[i].correctAnswers
                  .skip(1)
                  .toList(),
              points: widget.questions[i].pointValue,
            ),
      ],
    );
    await ref.read(progressControllerProvider.notifier).saveRecord(record);
    _practiceRecordSaved = true;
  }

  bool get _isExam => widget.feedbackMode == PracticeFeedbackMode.exam;

  int get _examDurationSeconds =>
      widget.sessionId.startsWith('sotsuken_test|exam|')
      ? _sotsukenExamDurationSeconds
      : _defaultExamDurationSeconds;

  int? _normalizedDraftRemainingSeconds(PracticeDraft draft) {
    final remainingSeconds = draft.remainingSeconds;
    if (remainingSeconds == null) {
      return null;
    }
    if (widget.sessionId.startsWith('sotsuken_test|exam|') &&
        draft.savedAt.isBefore(_sotsukenDurationMigrationCutoff) &&
        remainingSeconds <= _defaultExamDurationSeconds) {
      return math.min(
        remainingSeconds + _defaultExamDurationSeconds,
        _sotsukenExamDurationSeconds,
      );
    }
    return remainingSeconds.clamp(0, _examDurationSeconds).toInt();
  }

  bool get _revealAnswer => !_isExam || _examSubmitted;

  bool get _canGoNext {
    if (widget.questions.isEmpty) {
      return false;
    }
    if (_isExam && _examSubmitted) {
      return true;
    }
    if (_isExam && !_examSubmitted) {
      return true;
    }
    return widget.questions[_index].isResponseComplete(
      _selectedAnswers[_index] ?? const {},
    );
  }

  String get _nextLabel {
    if (_isExam && !_examSubmitted && _index == widget.questions.length - 1) {
      return '提出';
    }
    return _index == widget.questions.length - 1 ? '完了' : '次へ';
  }

  int get _scorePoints {
    var score = 0;
    for (var i = 0; i < widget.questions.length; i += 1) {
      if (widget.questions[i].isResponseCorrect(
        _selectedAnswers[i] ?? const {},
      )) {
        score += widget.questions[i].pointValue;
      }
    }
    return score;
  }

  int get _totalPoints => widget.questions.fold(
    0,
    (total, question) => total + question.pointValue,
  );

  _ExamResultSummary? get _examResult {
    if (!_isExam || !_examSubmitted) {
      return null;
    }
    return _ExamResultSummary(
      score: _scorePoints,
      total: _totalPoints,
      passingScore: _examPassingScore,
    );
  }

  String get _timerText {
    final seconds = _remainingSeconds ?? _examDurationSeconds;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  PracticeDraft _currentDraft() {
    return PracticeDraft(
      sessionId: widget.sessionId,
      currentIndex: _index,
      answers: {
        for (final entry in _selectedAnswers.entries)
          if (entry.value.isNotEmpty)
            entry.key: Map<int, AnswerChoice>.of(entry.value),
      },
      savedAt: DateTime.now(),
      remainingSeconds: _isExam ? _remainingSeconds : null,
    );
  }

  void _scheduleExamDraftAutosave({bool immediate = false}) {
    if (!_isExam || _examSubmitted) {
      return;
    }
    _draftAutosaveTimer?.cancel();
    if (immediate) {
      unawaited(_saveExamDraft());
      return;
    }
    final remainingSeconds = _remainingSeconds ?? _examDurationSeconds;
    if (remainingSeconds % 10 != 0) {
      return;
    }
    _draftAutosaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveExamDraft());
    });
  }

  Future<void> _saveExamDraft() async {
    if (!_isExam || _examSubmitted || widget.questions.isEmpty) {
      return;
    }
    try {
      await ref
          .read(progressControllerProvider.notifier)
          .saveDraft(_currentDraft());
    } catch (_) {
      // Autosave should not interrupt the exam flow.
    }
  }

  Future<void> _saveDraftAndLeave() async {
    try {
      await ref
          .read(progressControllerProvider.notifier)
          .saveDraft(_currentDraft());
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
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (context) => LiquidDialogPanel(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.all(24),
        maxWidth: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LiquidIconBadge(
                  icon: Icons.exit_to_app_rounded,
                  color: LiquidColors.vermilion,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '終了しますか',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '途中までの回答を保存できます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LiquidColors.muted(context),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_ExitAction.cancel),
                    child: const Text('キャンセル'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_ExitAction.discard),
                    child: const Text('保存しない'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_ExitAction.save),
                    child: const Text('保存して終了'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final examResult = _examResult;

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
          const AppSettingsButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          LiquidBackground(
            child: question == null
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
                                        revealUnansweredAnswer: _examSubmitted,
                                        showRuby: settings.showRuby,
                                        translations: translations,
                                        retryTranslations: retryTranslations,
                                        canChangeAnswer:
                                            !_examSubmitted &&
                                            widget.feedbackMode ==
                                                PracticeFeedbackMode.exam,
                                        canGoNext: _canGoNext,
                                        nextLabel: _nextLabel,
                                        onChoose: (answerIndex, choice) =>
                                            _choose(
                                              question,
                                              answerIndex,
                                              choice,
                                            ),
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
                                        revealUnansweredAnswer: _examSubmitted,
                                        showRuby: settings.showRuby,
                                        translations: translations,
                                        retryTranslations: retryTranslations,
                                        examResult: examResult,
                                        examResultAnimation:
                                            _examResultController,
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
                                  revealUnansweredAnswer: _examSubmitted,
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
                                  revealUnansweredAnswer: _examSubmitted,
                                  showRuby: settings.showRuby,
                                  translations: translations,
                                  retryTranslations: retryTranslations,
                                  canChangeAnswer:
                                      !_examSubmitted &&
                                      widget.feedbackMode ==
                                          PracticeFeedbackMode.exam,
                                  canGoNext: _canGoNext,
                                  nextLabel: _nextLabel,
                                  onChoose: (answerIndex, choice) =>
                                      _choose(question, answerIndex, choice),
                                  onPrevious: _previous,
                                  onNext: () => _next(),
                                ),
                                const SizedBox(height: 12),
                                if (examResult != null) ...[
                                  _ExamSummaryCard(
                                    result: examResult,
                                    animation: _examResultController,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _QuestionDetailPanel(
                                  question: question,
                                  selectedAnswer: selectedAnswer,
                                  revealAnswer: _revealAnswer,
                                  revealUnansweredAnswer: _examSubmitted,
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
                                  revealUnansweredAnswer: _examSubmitted,
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
          ),
          if (examResult != null)
            _ExamResultOverlay(
              result: examResult,
              animation: _examResultController,
            ),
        ],
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
    required this.revealUnansweredAnswer,
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
  final Map<int, AnswerChoice>? selectedAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final bool canChangeAnswer;
  final bool canGoNext;
  final String nextLabel;
  final void Function(int answerIndex, AnswerChoice choice) onChoose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LiquidGlass(
      padding: const EdgeInsets.all(20),
      strong: true,
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
          if (question.subquestions.isEmpty)
            _AnswerButtonPair(
              selectedAnswer: selectedAnswer?[0],
              correctAnswer: question.answer,
              revealAnswer: revealAnswer,
              revealUnansweredAnswer: revealUnansweredAnswer,
              canChangeAnswer: canChangeAnswer,
              onChoose: (choice) => onChoose(0, choice),
            )
          else
            for (var i = 0; i < question.subquestions.length; i += 1) ...[
              _SubquestionCard(
                number: i + 1,
                subquestion: question.subquestions[i],
                selectedAnswer: selectedAnswer?[i],
                revealAnswer: revealAnswer,
                revealUnansweredAnswer: revealUnansweredAnswer,
                showRuby: showRuby,
                translations: translations,
                retryTranslations: retryTranslations,
                canChangeAnswer: canChangeAnswer,
                onChoose: (choice) => onChoose(i, choice),
              ),
              if (i != question.subquestions.length - 1)
                const SizedBox(height: 12),
            ],
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
    );
  }
}

class _SubquestionCard extends StatelessWidget {
  const _SubquestionCard({
    required this.number,
    required this.subquestion,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.revealUnansweredAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.canChangeAnswer,
    required this.onChoose,
  });

  final int number;
  final DriverSubquestion subquestion;
  final AnswerChoice? selectedAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final bool canChangeAnswer;
  final ValueChanged<AnswerChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LiquidColors.glassFill(context, strong: true),
        border: Border.all(color: LiquidColors.hairline(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RubyText(
              text: '($number) ${subquestion.text}',
              rubyHtml: subquestion.rubyHtml == null
                  ? null
                  : '($number) ${subquestion.rubyHtml}',
              showRuby: showRuby,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            for (final entry in translations.entries) ...[
              const SizedBox(height: 8),
              _TranslationCard(
                language: entry.key,
                text: entry.value.value.subquestionAt(number - 1),
                isLoading: entry.value.isLoading,
                error: entry.value.error,
                onRetry: retryTranslations[entry.key],
              ),
            ],
            const SizedBox(height: 14),
            _AnswerButtonPair(
              selectedAnswer: selectedAnswer,
              correctAnswer: subquestion.answer,
              revealAnswer: revealAnswer,
              revealUnansweredAnswer: revealUnansweredAnswer,
              canChangeAnswer: canChangeAnswer,
              onChoose: onChoose,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButtonPair extends StatelessWidget {
  const _AnswerButtonPair({
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.revealAnswer,
    required this.revealUnansweredAnswer,
    required this.canChangeAnswer,
    required this.onChoose,
    this.compact = false,
  });

  final AnswerChoice? selectedAnswer;
  final AnswerChoice correctAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool canChangeAnswer;
  final ValueChanged<AnswerChoice> onChoose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 420;
        final buttons = [
          for (final choice in AnswerChoice.values)
            _AnswerButton(
              choice: choice,
              selectedAnswer: selectedAnswer,
              correctAnswer: correctAnswer,
              revealAnswer: revealAnswer,
              revealUnansweredAnswer: revealUnansweredAnswer,
              canChangeAnswer: canChangeAnswer,
              onTap: () => onChoose(choice),
              height: compact ? 56 : 72,
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
                children: [buttons[0], const SizedBox(height: 12), buttons[1]],
              );
      },
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.choice,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.revealAnswer,
    required this.revealUnansweredAnswer,
    required this.canChangeAnswer,
    required this.onTap,
    this.height = 72,
  });

  final AnswerChoice choice;
  final AnswerChoice? selectedAnswer;
  final AnswerChoice correctAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool canChangeAnswer;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final answered = selectedAnswer != null;
    final selected = selectedAnswer == choice;
    final isCorrectChoice = correctAnswer == choice;
    final revealCorrectChoice =
        revealAnswer && isCorrectChoice && (answered || revealUnansweredAnswer);
    final surface = LiquidColors.glassFill(context, strong: true);
    final borderColor = revealCorrectChoice
        ? LiquidColors.success
        : !answered
        ? LiquidColors.primary.withValues(
            alpha: LiquidColors.isDark(context) ? 0.34 : 0.26,
          )
        : !revealAnswer
        ? selected
              ? LiquidColors.primary
              : LiquidColors.hairline(context)
        : isCorrectChoice
        ? LiquidColors.success
        : selected
        ? LiquidColors.danger
        : LiquidColors.hairline(context);
    final background = revealCorrectChoice
        ? LiquidColors.success.withValues(alpha: 0.12)
        : !answered
        ? surface
        : !revealAnswer
        ? selected
              ? LiquidColors.primary.withValues(alpha: 0.12)
              : surface
        : isCorrectChoice
        ? LiquidColors.success.withValues(alpha: 0.12)
        : selected
        ? LiquidColors.danger.withValues(alpha: 0.12)
        : surface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: !answered || canChangeAnswer ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
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
    final color = switch (language) {
      TranslationLanguage.chinese => LiquidColors.vermilion,
      TranslationLanguage.english => LiquidColors.sky,
      TranslationLanguage.vietnamese => LiquidColors.amber,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: LiquidColors.isDark(context) ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.displayLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
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
    required this.revealUnansweredAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.examResult,
    required this.examResultAnimation,
    required this.index,
    required this.total,
    required this.detailMode,
    required this.commentCount,
    required this.onDetailModeChanged,
  });

  final DriverQuestion question;
  final Map<int, AnswerChoice>? selectedAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;
  final _ExamResultSummary? examResult;
  final Animation<double> examResultAnimation;
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
        LiquidGlass(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LiquidIconBadge(
                    icon: Icons.timeline_rounded,
                    color: LiquidColors.primary,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '進捗',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text('${index + 1} / $total'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (index + 1) / total),
              const SizedBox(height: 10),
              if (question.workbookDisplayNo != null ||
                  question.sequence != null) ...[
                Text(
                  [
                    if (question.workbookDisplayNo != null)
                      '第${question.workbookDisplayNo}回',
                    if (question.sequence != null) '問${question.sequence}',
                  ].join(' / '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (examResult != null) ...[
          _ExamSummaryCard(result: examResult!, animation: examResultAnimation),
          const SizedBox(height: 12),
        ],
        _QuestionDetailPanel(
          question: question,
          selectedAnswer: selectedAnswer,
          revealAnswer: revealAnswer,
          revealUnansweredAnswer: revealUnansweredAnswer,
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
    required this.revealUnansweredAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
    required this.mode,
    required this.commentCount,
    required this.onModeChanged,
  });

  final DriverQuestion question;
  final Map<int, AnswerChoice>? selectedAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
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
            revealUnansweredAnswer: revealUnansweredAnswer,
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
    required this.revealUnansweredAnswer,
    required this.showRuby,
    required this.translations,
    required this.retryTranslations,
  });

  final DriverQuestion question;
  final Map<int, AnswerChoice>? selectedAnswer;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final bool showRuby;
  final Map<TranslationLanguage, _TranslationState> translations;
  final Map<TranslationLanguage, VoidCallback> retryTranslations;

  @override
  Widget build(BuildContext context) {
    final response = selectedAnswer ?? const <int, AnswerChoice>{};
    if (response.isEmpty && !revealUnansweredAnswer) {
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
              Text('あなたの答え：${_answerLabels(response)}'),
              const SizedBox(height: 8),
              const Text('採点は提出後に表示されます'),
            ],
          ),
        ),
      );
    }

    final isCorrect = question.isResponseCorrect(response);
    final color = isCorrect ? LiquidColors.success : LiquidColors.danger;

    return LiquidGlass(
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
          Text(
            'あなたの答え：${_answerLabels(response)}\n'
            '答え：${_correctAnswerLabels(question)}',
          ),
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
    );
  }

  String _answerLabels(Map<int, AnswerChoice> response) {
    if (question.subquestions.isEmpty) {
      return response[0]?.label ?? '未回答';
    }
    return [
      for (var i = 0; i < question.subquestions.length; i += 1)
        '(${i + 1}) ${response[i]?.label ?? '未回答'}',
    ].join('  ');
  }

  String _correctAnswerLabels(DriverQuestion question) {
    if (question.subquestions.isEmpty) {
      return question.answer.label;
    }
    return [
      for (var i = 0; i < question.correctAnswers.length; i += 1)
        '(${i + 1}) ${question.correctAnswers[i].label}',
    ].join('  ');
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
                  Divider(height: 24, color: LiquidColors.hairline(context)),
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

class _ExamResultSummary {
  const _ExamResultSummary({
    required this.score,
    required this.total,
    required this.passingScore,
  });

  final int score;
  final int total;
  final int passingScore;

  bool get passed => score >= passingScore;

  int get pointsToPass => math.max(0, passingScore - score);

  String get title => passed ? '合格おめでとうございます' : '不合格';

  String get message => passed ? '合格ラインをクリアしました' : '合格まであと$pointsToPass点です';

  String get statusLabel => passed ? '合格' : '不合格';
}

class _ExamSummaryCard extends StatelessWidget {
  const _ExamSummaryCard({required this.result, required this.animation});

  final _ExamResultSummary result;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = result.passed ? LiquidColors.success : LiquidColors.danger;
    final icon = result.passed
        ? Icons.emoji_events_outlined
        : Icons.error_outline_rounded;
    final isDark = LiquidColors.isDark(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value.clamp(0.0, 1.0).toDouble();
        final entrance = Curves.easeOutBack.transform(
          math.min(1.0, progress / 0.55),
        );
        final opacity = math.min(1.0, progress * 4);
        final shakeOffset = result.passed
            ? 0.0
            : math.sin(progress * math.pi * 10) * (1 - progress) * 8;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: Transform.scale(
              scale: 0.96 + entrance * 0.04,
              child: LiquidGlass(
                padding: EdgeInsets.zero,
                strong: true,
                tint: color.withValues(alpha: isDark ? 0.18 : 0.08),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ExamCardEffectPainter(
                            progress: progress,
                            passed: result.passed,
                            color: color,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LiquidIconBadge(
                                icon: icon,
                                color: color,
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: color,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      result.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: LiquidColors.muted(context),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ResultBadge(
                                label: result.statusLabel,
                                color: color,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '得点 ${result.score} / ${result.total}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                              ),
                              _ResultBadge(
                                label: '合格ライン ${result.passingScore}点',
                                color: LiquidColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: LiquidColors.isDark(context) ? 0.18 : 0.11,
        ),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ExamResultOverlay extends StatelessWidget {
  const _ExamResultOverlay({required this.result, required this.animation});

  final _ExamResultSummary result;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value.clamp(0.0, 1.0).toDouble();
          final fadeOut = progress < 0.82
              ? 1.0
              : ((1 - progress) / 0.18).clamp(0.0, 1.0).toDouble();
          if (fadeOut <= 0) {
            return const SizedBox.shrink();
          }
          return Opacity(
            opacity: result.passed ? fadeOut : fadeOut * 0.82,
            child: CustomPaint(
              painter: _ExamResultOverlayPainter(
                progress: progress,
                passed: result.passed,
                isDark: LiquidColors.isDark(context),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _ExamCardEffectPainter extends CustomPainter {
  const _ExamCardEffectPainter({
    required this.progress,
    required this.passed,
    required this.color,
    required this.isDark,
  });

  final double progress;
  final bool passed;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (passed) {
      _paintConfetti(canvas, size, progress, overlay: false);
      return;
    }

    final pulse = Curves.easeOutCubic.transform(math.min(1.0, progress / 0.7));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1 - pulse) * 0.32);
    final center = Offset(size.width - 44, 42);
    canvas.drawCircle(center, 18 + pulse * 28, paint);

    final slashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..color = color.withValues(alpha: isDark ? 0.32 : 0.24);
    final crack = Path()
      ..moveTo(size.width - 84, 12)
      ..lineTo(size.width - 64, 32)
      ..lineTo(size.width - 76, 54)
      ..lineTo(size.width - 50, 80);
    canvas.drawPath(crack, slashPaint);
  }

  @override
  bool shouldRepaint(covariant _ExamCardEffectPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.passed != passed ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

class _ExamResultOverlayPainter extends CustomPainter {
  const _ExamResultOverlayPainter({
    required this.progress,
    required this.passed,
    required this.isDark,
  });

  final double progress;
  final bool passed;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (passed) {
      _paintConfetti(canvas, size, progress, overlay: true);
      return;
    }

    final washPaint = Paint()
      ..color = LiquidColors.danger.withValues(
        alpha: (1 - progress) * (isDark ? 0.20 : 0.12),
      );
    canvas.drawRect(Offset.zero & size, washPaint);

    final center = size.center(Offset.zero);
    final pulse = Curves.easeOutCubic.transform(math.min(1.0, progress / 0.76));
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = LiquidColors.danger.withValues(alpha: (1 - pulse) * 0.42);
    canvas.drawCircle(center, 36 + size.shortestSide * 0.2 * pulse, ringPaint);

    final crossProgress = Curves.easeOutBack.transform(
      math.min(1.0, progress / 0.45),
    );
    final length = size.shortestSide * 0.15 * crossProgress;
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = LiquidColors.danger.withValues(
        alpha: (1 - progress * 0.45).clamp(0.0, 1.0).toDouble(),
      );
    canvas.drawLine(
      center.translate(-length, -length),
      center.translate(length, length),
      crossPaint,
    );
    canvas.drawLine(
      center.translate(length, -length),
      center.translate(-length, length),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ExamResultOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.passed != passed ||
        oldDelegate.isDark != isDark;
  }
}

void _paintConfetti(
  Canvas canvas,
  Size size,
  double progress, {
  required bool overlay,
}) {
  final palette = [
    LiquidColors.success,
    LiquidColors.amber,
    LiquidColors.sky,
    LiquidColors.vermilion,
    LiquidColors.primary,
  ];
  final paint = Paint()..style = PaintingStyle.fill;
  final count = overlay ? 86 : 24;
  for (var i = 0; i < count; i += 1) {
    final delay = _unit(i, 11) * 0.28;
    final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
    if (local <= 0 || local >= 1) {
      continue;
    }
    final drift = math.sin(local * math.pi * 2 + i) * (overlay ? 38 : 14);
    final x = size.width * _unit(i, 3) + drift;
    final y = -24 + (size.height + 58) * local;
    final alpha = math.sin(local * math.pi).clamp(0.0, 1.0).toDouble();
    final width = (overlay ? 7.0 : 5.0) + _unit(i, 17) * 6;
    final height = overlay ? 4.0 : 3.0;

    paint.color = palette[i % palette.length].withValues(alpha: alpha);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(local * math.pi * 3 + i * 0.33);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.restore();
  }
}

double _unit(int index, int salt) {
  return ((index * 37 + salt * 53) % 101) / 100;
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LiquidColors.primary.withValues(
          alpha: LiquidColors.isDark(context) ? 0.24 : 0.12,
        ),
        border: Border.all(color: LiquidColors.primary.withValues(alpha: 0.26)),
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

class _AnswerSheetCard extends StatelessWidget {
  const _AnswerSheetCard({
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.revealAnswer,
    required this.revealUnansweredAnswer,
    required this.onJumpToQuestion,
  });

  final List<DriverQuestion> questions;
  final Map<int, Map<int, AnswerChoice>> answers;
  final int currentIndex;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final ValueChanged<int> onJumpToQuestion;

  @override
  Widget build(BuildContext context) {
    final answered = answers.entries.where((entry) {
      return questions[entry.key].isResponseComplete(entry.value);
    }).length;
    final correct = revealAnswer
        ? answers.entries.where((entry) {
            final question = questions[entry.key];
            return question.isResponseCorrect(entry.value);
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
                    revealUnansweredAnswer: revealUnansweredAnswer,
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
    required this.revealUnansweredAnswer,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final Map<int, AnswerChoice>? answer;
  final DriverQuestion question;
  final bool revealAnswer;
  final bool revealUnansweredAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = answer != null && question.isResponseComplete(answer!);
    final isCorrect = answered && question.isResponseCorrect(answer!);
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final revealMissingAnswer =
        revealAnswer && revealUnansweredAnswer && !answered;
    final background = revealMissingAnswer
        ? LiquidColors.danger.withValues(alpha: 0.12)
        : !answered
        ? surface
        : !revealAnswer
        ? LiquidColors.primary.withValues(alpha: 0.12)
        : isCorrect
        ? LiquidColors.success.withValues(alpha: 0.12)
        : LiquidColors.danger.withValues(alpha: 0.12);
    final borderColor = isCurrent
        ? colorScheme.onSurface
        : revealMissingAnswer
        ? LiquidColors.danger
        : !answered
        ? LiquidColors.hairline(context)
        : !revealAnswer
        ? LiquidColors.primary
        : isCorrect
        ? LiquidColors.success
        : LiquidColors.danger;
    final textColor = revealMissingAnswer
        ? LiquidColors.danger
        : !answered
        ? colorScheme.onSurface
        : !revealAnswer
        ? LiquidColors.primary
        : isCorrect
        ? LiquidColors.success
        : LiquidColors.danger;

    return Tooltip(
      message: answered
          ? '問$number ${[for (var i = 0; i < answer!.length; i += 1) answer![i]?.label ?? '-'].join(' / ')}'
          : '問$number 未回答',
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
                    border: Border.all(color: LiquidColors.hairline(context)),
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
        border: Border.all(color: LiquidColors.hairline(context)),
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
