import '../data/bank_catalog.dart';
import 'answer_choice.dart';

class ChapterOption implements Comparable<ChapterOption> {
  const ChapterOption({required this.number, required this.name});

  final int number;
  final String name;

  @override
  int compareTo(ChapterOption other) => number.compareTo(other.number);
}

class QuestionIdGroupSummary {
  const QuestionIdGroupSummary({required this.questionIds});

  final List<String> questionIds;

  int get questionCount => questionIds.length;
}

class WorkbookSummary extends QuestionIdGroupSummary {
  const WorkbookSummary({required this.number, required super.questionIds});

  final int number;
}

class ChapterSummary extends QuestionIdGroupSummary
    implements Comparable<ChapterSummary> {
  const ChapterSummary({
    required this.number,
    required this.name,
    required super.questionIds,
  });

  final int number;
  final String name;

  @override
  int compareTo(ChapterSummary other) => number.compareTo(other.number);
}

class RangeStepSummary extends QuestionIdGroupSummary {
  const RangeStepSummary({required this.step, required super.questionIds});

  final int step;
}

class QuestionBankSummary extends QuestionIdGroupSummary {
  const QuestionBankSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.hasChapters,
    required super.questionIds,
    required this.workbooks,
    required this.chapters,
    required this.rangeSteps,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool hasChapters;
  final List<WorkbookSummary> workbooks;
  final List<ChapterSummary> chapters;
  final List<RangeStepSummary> rangeSteps;

  factory QuestionBankSummary.fromJson(
    BankDefinition definition,
    Map<String, Object?> json,
  ) {
    return QuestionBankSummary(
      id: definition.id,
      title: definition.title,
      subtitle: definition.subtitle,
      hasChapters: definition.hasChapters,
      questionIds: _strings(json, 'question_ids'),
      workbooks: [
        for (final item in (json['workbooks'] as List? ?? const []))
          if (item is Map)
            WorkbookSummary(
              number: _int(item.cast<String, Object?>(), 'number') ?? 0,
              questionIds: _strings(
                item.cast<String, Object?>(),
                'question_ids',
              ),
            ),
      ],
      chapters: [
        for (final item in (json['chapters'] as List? ?? const []))
          if (item is Map)
            ChapterSummary(
              number: _int(item.cast<String, Object?>(), 'number') ?? 0,
              name:
                  _string(item.cast<String, Object?>(), 'name') ??
                  '第${_int(item.cast<String, Object?>(), 'number') ?? 0}章',
              questionIds: _strings(
                item.cast<String, Object?>(),
                'question_ids',
              ),
            ),
      ],
      rangeSteps: [
        for (final item in (json['range_steps'] as List? ?? const []))
          if (item is Map)
            RangeStepSummary(
              step: _int(item.cast<String, Object?>(), 'step') ?? 0,
              questionIds: _strings(
                item.cast<String, Object?>(),
                'question_ids',
              ),
            ),
      ],
    );
  }
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
    required this.subquestions,
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
  final List<DriverSubquestion> subquestions;

  List<AnswerChoice> get correctAnswers => subquestions.isEmpty
      ? [answer]
      : [for (final subquestion in subquestions) subquestion.answer];

  int get pointValue =>
      bankId == 'karimen_test' || subquestions.isNotEmpty ? 2 : 1;

  bool isCorrect(AnswerChoice choice) => choice == answer;

  bool isResponseComplete(Map<int, AnswerChoice> response) {
    return response.length == correctAnswers.length &&
        List.generate(
          correctAnswers.length,
          response.containsKey,
        ).every((answered) => answered);
  }

  bool isResponseCorrect(Map<int, AnswerChoice> response) {
    if (!isResponseComplete(response)) {
      return false;
    }
    for (var i = 0; i < correctAnswers.length; i += 1) {
      if (response[i] != correctAnswers[i]) {
        return false;
      }
    }
    return true;
  }

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
    final subquestionTranslations = switch (translation['subquestions']) {
      final List value => value,
      _ => const [],
    };
    final subquestionsJson = json['subquestions'] as List? ?? const [];

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
      subquestions: [
        for (var i = 0; i < subquestionsJson.length; i += 1)
          if (subquestionsJson[i] is Map)
            DriverSubquestion.fromJson(
              (subquestionsJson[i] as Map).cast<String, Object?>(),
              translation: i < subquestionTranslations.length
                  ? subquestionTranslations[i]
                  : null,
            ),
      ],
    );
  }
}

class DriverSubquestion {
  const DriverSubquestion({
    required this.text,
    required this.rubyHtml,
    required this.textChinese,
    required this.answer,
  });

  final String text;
  final String? rubyHtml;
  final String? textChinese;
  final AnswerChoice answer;

  factory DriverSubquestion.fromJson(
    Map<String, Object?> json, {
    Object? translation,
  }) {
    final translationMap = switch (translation) {
      final Map value => value.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    return DriverSubquestion(
      text: _requiredString(json, 'text'),
      rubyHtml: _nonEmptyString(json, 'ruby_html'),
      textChinese:
          _nonEmptyString(json, 'text_zh') ??
          _nonEmptyString(translationMap, 'text') ??
          _nonEmptyValueString(translation),
      answer: AnswerChoice.fromRaw(_requiredString(json, 'answer')),
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

String? _nonEmptyValueString(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.trim();
  return text.isEmpty ? null : text;
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
