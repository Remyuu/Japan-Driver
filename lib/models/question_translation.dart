class QuestionTranslation {
  const QuestionTranslation({
    required this.question,
    required this.explanation,
    this.subquestions = const [],
  });

  final String? question;
  final String? explanation;
  final List<String?> subquestions;

  String? subquestionAt(int index) {
    return index >= 0 && index < subquestions.length
        ? subquestions[index]
        : null;
  }

  bool isComplete({
    required bool hasExplanation,
    required int subquestionCount,
  }) {
    return question != null &&
        (!hasExplanation || explanation != null) &&
        subquestions.length >= subquestionCount &&
        subquestions.take(subquestionCount).every((text) => text != null);
  }

  QuestionTranslation merge(QuestionTranslation? other) {
    return QuestionTranslation(
      question: question ?? other?.question,
      explanation: explanation ?? other?.explanation,
      subquestions: [
        for (var i = 0; i < _mergedSubquestionLength(other); i += 1)
          i < subquestions.length && subquestions[i] != null
              ? subquestions[i]
              : i < (other?.subquestions.length ?? 0)
              ? other!.subquestions[i]
              : null,
      ],
    );
  }

  int _mergedSubquestionLength(QuestionTranslation? other) {
    final otherLength = other?.subquestions.length ?? 0;
    return subquestions.length > otherLength
        ? subquestions.length
        : otherLength;
  }
}
