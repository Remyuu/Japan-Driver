import 'answer_choice.dart';

class PracticeRecordAnswer {
  const PracticeRecordAnswer({
    required this.questionId,
    required this.selectedAnswer,
    required this.correctAnswer,
    this.additionalSelectedAnswers = const [],
    this.additionalCorrectAnswers = const [],
    this.points = 1,
  });

  final String questionId;
  final AnswerChoice? selectedAnswer;
  final AnswerChoice correctAnswer;
  final List<AnswerChoice?> additionalSelectedAnswers;
  final List<AnswerChoice> additionalCorrectAnswers;
  final int points;

  List<AnswerChoice?> get selectedAnswers => [
    selectedAnswer,
    ...additionalSelectedAnswers,
  ];

  List<AnswerChoice> get correctAnswers => [
    correctAnswer,
    ...additionalCorrectAnswers,
  ];

  bool get isCorrect {
    if (selectedAnswers.length != correctAnswers.length) {
      return false;
    }
    for (var i = 0; i < selectedAnswers.length; i += 1) {
      if (selectedAnswers[i] != correctAnswers[i]) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> toJson() {
    return {
      'questionId': questionId,
      if (selectedAnswer != null) 'selectedAnswer': selectedAnswer?.label,
      'correctAnswer': correctAnswer.label,
      if (selectedAnswer == null || additionalSelectedAnswers.isNotEmpty)
        'selectedAnswers': [
          for (final answer in selectedAnswers) answer?.label,
        ],
      if (additionalCorrectAnswers.isNotEmpty)
        'correctAnswers': [for (final answer in correctAnswers) answer.label],
      if (points != 1) 'points': points,
    };
  }

  factory PracticeRecordAnswer.fromJson(Map<String, Object?> json) {
    final rawSelectedAnswers = json['selectedAnswers'];
    final rawCorrectAnswers = json['correctAnswers'];
    final selectedAnswers = rawSelectedAnswers is List
        ? <AnswerChoice?>[
            for (final value in rawSelectedAnswers)
              value is String ? AnswerChoice.fromRaw(value) : null,
          ]
        : <AnswerChoice?>[];
    final correctAnswers = rawCorrectAnswers is List
        ? rawCorrectAnswers
              .whereType<String>()
              .map(AnswerChoice.fromRaw)
              .toList()
        : <AnswerChoice>[];
    return PracticeRecordAnswer(
      questionId: json['questionId'] as String? ?? '',
      selectedAnswer:
          selectedAnswers.firstOrNull ??
          (json['selectedAnswer'] is String
              ? AnswerChoice.fromRaw(json['selectedAnswer']! as String)
              : null),
      correctAnswer:
          correctAnswers.firstOrNull ??
          AnswerChoice.fromRaw(json['correctAnswer'] as String? ?? '×'),
      additionalSelectedAnswers: selectedAnswers.skip(1).toList(),
      additionalCorrectAnswers: correctAnswers.skip(1).toList(),
      points: json['points'] as int? ?? 1,
    );
  }
}

class PracticeRecord {
  const PracticeRecord({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.completedAt,
    required this.answers,
  });

  final String id;
  final String sessionId;
  final String title;
  final String subtitle;
  final String mode;
  final DateTime completedAt;
  final List<PracticeRecordAnswer> answers;

  int get totalCount => answers.length;

  int get correctCount => answers.where((answer) => answer.isCorrect).length;

  int get wrongCount => totalCount - correctCount;

  int get totalPoints => answers.fold(0, (sum, answer) => sum + answer.points);

  int get scorePoints => answers.fold(
    0,
    (sum, answer) => sum + (answer.isCorrect ? answer.points : 0),
  );

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'title': title,
      'subtitle': subtitle,
      'mode': mode,
      'completedAt': completedAt.toIso8601String(),
      'answers': [for (final answer in answers) answer.toJson()],
    };
  }

  factory PracticeRecord.fromJson(Map<String, Object?> json) {
    final answers = json['answers'];
    return PracticeRecord(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? '問題集',
      subtitle: json['subtitle'] as String? ?? '',
      mode: json['mode'] as String? ?? 'instant',
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      answers: [
        if (answers is List)
          for (final answer in answers)
            if (answer is Map)
              PracticeRecordAnswer.fromJson(answer.cast<String, Object?>()),
      ],
    );
  }
}
