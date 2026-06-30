import 'dart:convert';

import 'answer_choice.dart';
import 'practice_draft.dart';
import 'practice_record.dart';

class QuestionProgress {
  const QuestionProgress({
    required this.questionId,
    required this.attempts,
    required this.correctCount,
    required this.wrongCount,
    required this.lastWasCorrect,
    required this.lastAnswer,
    required this.lastAnsweredAt,
  });

  final String questionId;
  final int attempts;
  final int correctCount;
  final int wrongCount;
  final bool lastWasCorrect;
  final AnswerChoice lastAnswer;
  final DateTime lastAnsweredAt;

  bool get isWrong => !lastWasCorrect;

  Map<String, Object?> toJson() {
    return {
      'questionId': questionId,
      'attempts': attempts,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'lastWasCorrect': lastWasCorrect,
      'lastAnswer': lastAnswer.label,
      'lastAnsweredAt': lastAnsweredAt.toIso8601String(),
    };
  }

  factory QuestionProgress.fromJson(Map<String, Object?> json) {
    return QuestionProgress(
      questionId: json['questionId'] as String,
      attempts: json['attempts'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      lastWasCorrect: json['lastWasCorrect'] as bool? ?? false,
      lastAnswer: AnswerChoice.fromRaw(json['lastAnswer'] as String? ?? '×'),
      lastAnsweredAt:
          DateTime.tryParse(json['lastAnsweredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ProgressStore {
  const ProgressStore({
    required this.byQuestion,
    required this.drafts,
    required this.records,
  });

  final Map<String, QuestionProgress> byQuestion;
  final Map<String, PracticeDraft> drafts;
  final List<PracticeRecord> records;

  factory ProgressStore.empty() =>
      const ProgressStore(byQuestion: {}, drafts: {}, records: []);

  int get answeredQuestionCount => byQuestion.length;

  int get totalAttempts =>
      byQuestion.values.fold(0, (total, progress) => total + progress.attempts);

  int get correctAttempts => byQuestion.values.fold(
    0,
    (total, progress) => total + progress.correctCount,
  );

  int get wrongQuestionCount =>
      byQuestion.values.where((progress) => progress.isWrong).length;

  double get accuracy {
    if (totalAttempts == 0) {
      return 0;
    }
    return correctAttempts / totalAttempts;
  }

  Set<String> get wrongQuestionIds {
    return {
      for (final entry in byQuestion.entries)
        if (entry.value.isWrong) entry.key,
    };
  }

  bool isWrong(String questionId) => byQuestion[questionId]?.isWrong ?? false;

  ProgressStore recordAnswer({
    required String questionId,
    required AnswerChoice selectedAnswer,
    required AnswerChoice correctAnswer,
    DateTime? answeredAt,
  }) {
    final previous = byQuestion[questionId];
    final wasCorrect = selectedAnswer == correctAnswer;
    final next = QuestionProgress(
      questionId: questionId,
      attempts: (previous?.attempts ?? 0) + 1,
      correctCount: (previous?.correctCount ?? 0) + (wasCorrect ? 1 : 0),
      wrongCount: (previous?.wrongCount ?? 0) + (wasCorrect ? 0 : 1),
      lastWasCorrect: wasCorrect,
      lastAnswer: selectedAnswer,
      lastAnsweredAt: answeredAt ?? DateTime.now(),
    );

    return ProgressStore(
      byQuestion: {...byQuestion, questionId: next},
      drafts: drafts,
      records: records,
    );
  }

  ProgressStore saveDraft(PracticeDraft draft) {
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: {...drafts, draft.sessionId: draft},
      records: records,
    );
  }

  ProgressStore removeDraft(String sessionId) {
    final nextDrafts = Map<String, PracticeDraft>.of(drafts)..remove(sessionId);
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: nextDrafts,
      records: records,
    );
  }

  ProgressStore addRecord(PracticeRecord record) {
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: drafts,
      records: [record, ...records].take(200).toList(growable: false),
    );
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'version': 1,
      'questions': {
        for (final entry in byQuestion.entries) entry.key: entry.value.toJson(),
      },
      'drafts': {
        for (final entry in drafts.entries) entry.key: entry.value.toJson(),
      },
      'records': [for (final record in records) record.toJson()],
    };
  }

  factory ProgressStore.decode(String? source) {
    if (source == null || source.trim().isEmpty) {
      return ProgressStore.empty();
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      return ProgressStore.empty();
    }
    final questions = decoded['questions'];
    if (questions is! Map) {
      return ProgressStore.empty();
    }
    final drafts = decoded['drafts'];
    final records = decoded['records'];
    return ProgressStore(
      byQuestion: {
        for (final entry in questions.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: QuestionProgress.fromJson(
              (entry.value as Map).cast<String, Object?>(),
            ),
      },
      drafts: {
        if (drafts is Map)
          for (final entry in drafts.entries)
            if (entry.key is String && entry.value is Map)
              entry.key as String: PracticeDraft.fromJson(
                (entry.value as Map).cast<String, Object?>(),
              ),
      },
      records: [
        if (records is List)
          for (final record in records)
            if (record is Map)
              PracticeRecord.fromJson(record.cast<String, Object?>()),
      ],
    );
  }
}
