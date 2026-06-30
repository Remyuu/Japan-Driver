import 'answer_choice.dart';

class PracticeRecordAnswer {
  const PracticeRecordAnswer({
    required this.questionId,
    required this.selectedAnswer,
    required this.correctAnswer,
  });

  final String questionId;
  final AnswerChoice selectedAnswer;
  final AnswerChoice correctAnswer;

  bool get isCorrect => selectedAnswer == correctAnswer;

  Map<String, Object?> toJson() {
    return {
      'questionId': questionId,
      'selectedAnswer': selectedAnswer.label,
      'correctAnswer': correctAnswer.label,
    };
  }

  factory PracticeRecordAnswer.fromJson(Map<String, Object?> json) {
    return PracticeRecordAnswer(
      questionId: json['questionId'] as String? ?? '',
      selectedAnswer: AnswerChoice.fromRaw(
        json['selectedAnswer'] as String? ?? '×',
      ),
      correctAnswer: AnswerChoice.fromRaw(
        json['correctAnswer'] as String? ?? '×',
      ),
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
