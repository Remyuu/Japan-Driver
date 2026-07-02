import '../data/bank_catalog.dart';
import 'answer_choice.dart';

class ChapterOption implements Comparable<ChapterOption> {
  const ChapterOption({required this.number, required this.name});

  final int number;
  final String name;

  @override
  int compareTo(ChapterOption other) => number.compareTo(other.number);
}

class QuestionBank {
  const QuestionBank({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.stage,
    required this.questions,
    required this.hasChapters,
  });

  final String id;
  final String title;
  final String subtitle;
  final String mode;
  final String stage;
  final List<DriverQuestion> questions;
  final bool hasChapters;

  List<ChapterOption> get chapters {
    final byNumber = <int, String>{};
    for (final question in questions) {
      for (var i = 0; i < question.chapterNumbers.length; i += 1) {
        final number = question.chapterNumbers[i];
        final name = i < question.chapterNames.length
            ? question.chapterNames[i]
            : '第$number章';
        byNumber.putIfAbsent(number, () => name);
      }
    }
    final options =
        byNumber.entries
            .map((entry) => ChapterOption(number: entry.key, name: entry.value))
            .toList()
          ..sort();
    return options;
  }

  int get uniqueQuestionCount =>
      questions.map((question) => question.canonicalId).toSet().length;

  factory QuestionBank.fromJson(
    BankDefinition definition,
    Map<String, Object?> json, {
    Map<String, Object?> translations = const {},
  }) {
    final source = (json['source'] as Map?)?.cast<String, Object?>();
    final questionsJson = (json['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();

    return QuestionBank(
      id: definition.id,
      title: definition.title,
      subtitle: definition.subtitle,
      mode: _string(source, 'mode') ?? definition.subtitle,
      stage: _string(source, 'stage') ?? definition.title,
      hasChapters: definition.hasChapters,
      questions: [
        for (final question in questionsJson)
          DriverQuestion.fromJson(
            definition,
            question,
            translations: translations,
          ),
      ],
    );
  }
}

class DriverQuestion {
  const DriverQuestion({
    required this.bankId,
    required this.bankTitle,
    required this.questionKey,
    required this.canonicalId,
    required this.questionId,
    required this.sequence,
    required this.workbookDisplayNo,
    required this.workbookId,
    required this.questionText,
    required this.questionRubyHtml,
    required this.questionChinese,
    required this.answer,
    required this.explanation,
    required this.explanationRubyHtml,
    required this.explanationChinese,
    required this.textbookRef,
    required this.questionImageAssetPaths,
    required this.explanationImageAssetPaths,
    required this.chapterNumbers,
    required this.chapterNames,
    required this.rangeStep,
    required this.schoolAccuracyRate,
    required this.nationwideAccuracyRate,
  });

  final String bankId;
  final String bankTitle;
  final String questionKey;
  final String canonicalId;
  final String? questionId;
  final int? sequence;
  final int? workbookDisplayNo;
  final int? workbookId;
  final String questionText;
  final String? questionRubyHtml;
  final String? questionChinese;
  final AnswerChoice answer;
  final String explanation;
  final String? explanationRubyHtml;
  final String? explanationChinese;
  final String? textbookRef;
  final List<String> questionImageAssetPaths;
  final List<String> explanationImageAssetPaths;
  final List<int> chapterNumbers;
  final List<String> chapterNames;
  final int? rangeStep;
  final int? schoolAccuracyRate;
  final int? nationwideAccuracyRate;

  bool isCorrect(AnswerChoice choice) => choice == answer;

  factory DriverQuestion.fromJson(
    BankDefinition definition,
    Map<String, Object?> json, {
    Map<String, Object?> translations = const {},
  }) {
    final questionKey = _requiredString(json, 'question_key');
    final questionId = _nonEmptyString(json, 'question_id');
    final canonicalId = questionId ?? questionKey;
    final translation = switch (translations[canonicalId]) {
      final Map value => value.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };

    return DriverQuestion(
      bankId: definition.id,
      bankTitle: definition.title,
      questionKey: questionKey,
      canonicalId: canonicalId,
      questionId: questionId,
      sequence: _int(json, 'sequence'),
      workbookDisplayNo: _int(json, 'workbook_display_no'),
      workbookId: _int(json, 'workbook_id'),
      questionText: _requiredString(json, 'question'),
      questionRubyHtml: _nonEmptyString(json, 'question_ruby_html'),
      questionChinese:
          _nonEmptyString(json, 'question_zh') ??
          _nonEmptyString(translation, 'question'),
      answer: AnswerChoice.fromRaw(_requiredString(json, 'answer')),
      explanation: _string(json, 'explanation') ?? '',
      explanationRubyHtml: _nonEmptyString(json, 'explanation_ruby_html'),
      explanationChinese:
          _nonEmptyString(json, 'explanation_zh') ??
          _nonEmptyString(translation, 'explanation'),
      textbookRef: _nonEmptyString(json, 'textbook_ref'),
      questionImageAssetPaths: _assetPaths(
        definition,
        _strings(json, 'question_image_paths'),
      ),
      explanationImageAssetPaths: _assetPaths(
        definition,
        _strings(json, 'explanation_image_paths'),
      ),
      chapterNumbers: _intList(json, 'chapter_numbers'),
      chapterNames: _strings(json, 'chapter_names'),
      rangeStep: _int(json, 'range_step'),
      schoolAccuracyRate: _int(json, 'school_accuracy_rate'),
      nationwideAccuracyRate: _int(json, 'nationwide_accuracy_rate'),
    );
  }
}

List<String> _assetPaths(BankDefinition definition, List<String> paths) {
  return paths.map(definition.resolveAsset).toList(growable: false);
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (value == null || value.isEmpty) {
    throw FormatException('Missing string field: $key');
  }
  return value;
}

String? _nonEmptyString(Map<String, Object?> json, String key) {
  final value = _string(json, key)?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? _string(Map<String, Object?>? json, String key) {
  final value = json?[key];
  return value is String ? value : null;
}

int? _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<int> _intList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) {
    final single = _int(json, key.replaceAll('numbers', 'no'));
    return single == null ? const [] : [single];
  }
  return [
    for (final item in value)
      if (item is int) item else if (item is num) item.toInt(),
  ];
}

List<String> _strings(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}
