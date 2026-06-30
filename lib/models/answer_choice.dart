enum AnswerChoice {
  circle('○'),
  cross('×');

  const AnswerChoice(this.label);

  final String label;

  static AnswerChoice fromRaw(String value) {
    final trimmed = value.trim();
    if (trimmed == '○' || trimmed == 'O' || trimmed == 'true') {
      return AnswerChoice.circle;
    }
    if (trimmed == '×' || trimmed == 'x' || trimmed == 'false') {
      return AnswerChoice.cross;
    }
    throw FormatException('Unknown answer choice: $value');
  }
}
