import 'answer_choice.dart';

class PracticeDraft {
  const PracticeDraft({
    required this.sessionId,
    required this.currentIndex,
    required this.answers,
    required this.savedAt,
    this.remainingSeconds,
  });

  final String sessionId;
  final int currentIndex;
  final Map<int, Map<int, AnswerChoice>> answers;
  final DateTime savedAt;
  final int? remainingSeconds;

  Map<String, Object?> toJson() {
    return {
      'sessionId': sessionId,
      'currentIndex': currentIndex,
      'answers': {
        for (final entry in answers.entries)
          '${entry.key}': {
            for (final answer in entry.value.entries)
              '${answer.key}': answer.value.label,
          },
      },
      'savedAt': savedAt.toIso8601String(),
      if (remainingSeconds != null) 'remainingSeconds': remainingSeconds,
    };
  }

  factory PracticeDraft.fromJson(Map<String, Object?> json) {
    final rawAnswers = json['answers'];
    return PracticeDraft(
      sessionId: json['sessionId'] as String,
      currentIndex: json['currentIndex'] as int? ?? 0,
      answers: _parseAnswers(rawAnswers),
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      remainingSeconds: json['remainingSeconds'] as int?,
    );
  }

  static Map<int, Map<int, AnswerChoice>> _parseAnswers(Object? rawAnswers) {
    final parsed = <int, Map<int, AnswerChoice>>{};
    if (rawAnswers is! Map) {
      return parsed;
    }

    for (final entry in rawAnswers.entries) {
      final questionIndex = int.tryParse('${entry.key}');
      if (questionIndex == null) {
        continue;
      }
      final answers = switch (entry.value) {
        final String value => {0: AnswerChoice.fromRaw(value)},
        final Map value => {
          for (final answer in value.entries)
            if (int.tryParse('${answer.key}') != null && answer.value is String)
              int.parse('${answer.key}'): AnswerChoice.fromRaw(
                answer.value as String,
              ),
        },
        _ => <int, AnswerChoice>{},
      };
      if (answers.isNotEmpty) {
        parsed[questionIndex] = answers;
      }
    }

    return parsed;
  }
}

String practiceSessionId({
  required String bankId,
  required String mode,
  int? workbookNumber,
  int? chapterNumber,
  int? rangeStep,
}) {
  return [
    bankId,
    mode,
    if (workbookNumber != null) 'workbook:$workbookNumber',
    if (chapterNumber != null) 'chapter:$chapterNumber',
    if (rangeStep != null) 'rangeStep:$rangeStep',
  ].join('|');
}
