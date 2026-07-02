class QuestionTranslation {
  const QuestionTranslation({
    required this.question,
    required this.explanation,
  });

  final String? question;
  final String? explanation;

  bool isComplete({required bool hasExplanation}) {
    return question != null && (!hasExplanation || explanation != null);
  }

  QuestionTranslation merge(QuestionTranslation? other) {
    return QuestionTranslation(
      question: question ?? other?.question,
      explanation: explanation ?? other?.explanation,
    );
  }
}
