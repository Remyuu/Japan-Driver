import 'dart:convert';

import 'answer_choice.dart';
import 'practice_draft.dart';
import 'practice_record.dart';
import 'question_comment.dart';

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
  final AnswerChoice? lastAnswer;
  final DateTime lastAnsweredAt;

  bool get isWrong => !lastWasCorrect;

  Map<String, Object?> toJson() {
    return {
      'questionId': questionId,
      'attempts': attempts,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'lastWasCorrect': lastWasCorrect,
      if (lastAnswer != null) 'lastAnswer': lastAnswer?.label,
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
      lastAnswer: json['lastAnswer'] is String
          ? AnswerChoice.fromRaw(json['lastAnswer']! as String)
          : null,
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
    required this.commentsByQuestion,
    required this.favoriteQuestionIdsByStage,
  });

  final Map<String, QuestionProgress> byQuestion;
  final Map<String, PracticeDraft> drafts;
  final List<PracticeRecord> records;
  final Map<String, List<QuestionComment>> commentsByQuestion;
  final Map<String, Set<String>> favoriteQuestionIdsByStage;

  factory ProgressStore.empty() => const ProgressStore(
    byQuestion: {},
    drafts: {},
    records: [],
    commentsByQuestion: {},
    favoriteQuestionIdsByStage: {},
  );

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

  Set<String> favoritesForStage(String stageId) =>
      favoriteQuestionIdsByStage[stageId] ?? const {};

  bool isFavorite({required String stageId, required String questionId}) {
    return favoritesForStage(stageId).contains(questionId);
  }

  ProgressStore toggleFavorite({
    required String stageId,
    required String questionId,
  }) {
    final nextFavorites = {
      for (final entry in favoriteQuestionIdsByStage.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final stageFavorites = nextFavorites.putIfAbsent(stageId, () => {});
    if (!stageFavorites.add(questionId)) {
      stageFavorites.remove(questionId);
    }
    if (stageFavorites.isEmpty) {
      nextFavorites.remove(stageId);
    }
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: drafts,
      records: records,
      commentsByQuestion: commentsByQuestion,
      favoriteQuestionIdsByStage: nextFavorites,
    );
  }

  ProgressStore recordAnswer({
    required String questionId,
    required AnswerChoice? selectedAnswer,
    required AnswerChoice correctAnswer,
    bool? isCorrectOverride,
    DateTime? answeredAt,
  }) {
    final previous = byQuestion[questionId];
    final wasCorrect = isCorrectOverride ?? selectedAnswer == correctAnswer;
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
      commentsByQuestion: commentsByQuestion,
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  ProgressStore saveDraft(PracticeDraft draft) {
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: {...drafts, draft.sessionId: draft},
      records: records,
      commentsByQuestion: commentsByQuestion,
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  ProgressStore removeDraft(String sessionId) {
    final nextDrafts = Map<String, PracticeDraft>.of(drafts)..remove(sessionId);
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: nextDrafts,
      records: records,
      commentsByQuestion: commentsByQuestion,
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  ProgressStore addRecord(PracticeRecord record) {
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: drafts,
      records: [record, ...records].take(200).toList(growable: false),
      commentsByQuestion: commentsByQuestion,
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  ProgressStore addComment(QuestionComment comment) {
    final comments = commentsByQuestion[comment.questionId] ?? const [];
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: drafts,
      records: records,
      commentsByQuestion: {
        ...commentsByQuestion,
        comment.questionId: [...comments, comment],
      },
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  ProgressStore removeComment({
    required String questionId,
    required String commentId,
  }) {
    final nextComments = Map<String, List<QuestionComment>>.of(
      commentsByQuestion,
    );
    final comments = nextComments[questionId];
    if (comments == null) {
      return this;
    }
    final remaining = comments
        .where((comment) => comment.id != commentId)
        .toList(growable: false);
    if (remaining.isEmpty) {
      nextComments.remove(questionId);
    } else {
      nextComments[questionId] = remaining;
    }
    return ProgressStore(
      byQuestion: byQuestion,
      drafts: drafts,
      records: records,
      commentsByQuestion: nextComments,
      favoriteQuestionIdsByStage: favoriteQuestionIdsByStage,
    );
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'version': 3,
      'questions': {
        for (final entry in byQuestion.entries) entry.key: entry.value.toJson(),
      },
      'drafts': {
        for (final entry in drafts.entries) entry.key: entry.value.toJson(),
      },
      'records': [for (final record in records) record.toJson()],
      'comments': {
        for (final entry in commentsByQuestion.entries)
          entry.key: [for (final comment in entry.value) comment.toJson()],
      },
      'favorites': {
        for (final entry in favoriteQuestionIdsByStage.entries)
          entry.key: entry.value.toList(growable: false),
      },
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
    final drafts = decoded['drafts'];
    final records = decoded['records'];
    final comments = decoded['comments'];
    final favorites = decoded['favorites'];
    return ProgressStore(
      byQuestion: {
        if (questions is Map)
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
      commentsByQuestion: {
        if (comments is Map)
          for (final entry in comments.entries)
            if (entry.key is String && entry.value is List)
              entry.key as String: [
                for (final comment in entry.value as List)
                  if (comment is Map)
                    QuestionComment.fromJson(comment.cast<String, Object?>()),
              ],
      },
      favoriteQuestionIdsByStage: {
        if (favorites is Map)
          for (final entry in favorites.entries)
            if (entry.key is String && entry.value is List)
              entry.key as String: (entry.value as List)
                  .whereType<String>()
                  .toSet(),
      },
    );
  }
}
