class QuestionComment {
  const QuestionComment({
    required this.id,
    required this.questionId,
    required this.text,
    required this.authorLabel,
    required this.createdAt,
    this.authorId,
  });

  final String id;
  final String questionId;
  final String text;
  final String authorLabel;
  final DateTime createdAt;
  final String? authorId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'questionId': questionId,
      'text': text,
      'authorLabel': authorLabel,
      'createdAt': createdAt.toIso8601String(),
      if (authorId != null) 'authorId': authorId,
    };
  }

  factory QuestionComment.fromJson(Map<String, Object?> json) {
    return QuestionComment(
      id: json['id'] as String,
      questionId: json['questionId'] as String,
      text: json['text'] as String? ?? '',
      authorLabel: json['authorLabel'] as String? ?? 'ゲスト',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      authorId: json['authorId'] as String?,
    );
  }
}
