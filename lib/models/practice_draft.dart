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
  final Map<int, AnswerChoice> answers;
  final DateTime savedAt;
  final int? remainingSeconds;

  Map<String, Object?> toJson() {
    return {
      'sessionId': sessionId,
      'currentIndex': currentIndex,
      'answers': {
        for (final entry in answers.entries) '${entry.key}': entry.value.label,
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
      answers: {
        if (rawAnswers is Map)
          for (final entry in rawAnswers.entries)
            if (int.tryParse('${entry.key}') != null && entry.value is String)
              int.parse('${entry.key}'): AnswerChoice.fromRaw(
                entry.value as String,
              ),
      },
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      remainingSeconds: json['remainingSeconds'] as int?,
    );
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
