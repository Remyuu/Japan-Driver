import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/question_bank.dart';
import 'package:japan_driver/repositories/question_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads bundled MUSASI question banks', () async {
    final banks = await const QuestionRepository().loadBanks();
    final questions = banks.expand((bank) => bank.questions).toList();
    final fallbackIdQuestions = questions
        .where((question) => question.questionId == null)
        .toList();

    expect(banks, hasLength(7));
    expect(questions, hasLength(4107));
    expect(
      questions.map((question) => question.canonicalId).toSet(),
      hasLength(2318),
    );
    expect(fallbackIdQuestions, hasLength(69));
    expect(
      banks.map((bank) => bank.questions.first.questionChinese),
      everyElement(isNotEmpty),
    );
    expect(
      banks.map((bank) => bank.questions.first.explanationChinese),
      everyElement(isNotEmpty),
    );

    final sotsukenExam = banks.singleWhere(
      (bank) => bank.id == 'sotsuken_test',
    );
    final illustrationQuestions = sotsukenExam.questions
        .where((question) => (question.sequence ?? 0) >= 91)
        .toList();
    expect(illustrationQuestions, hasLength(30));
    expect(
      illustrationQuestions,
      everyElement(
        isA<DriverQuestion>().having(
          (question) => question.subquestions.length,
          'subquestions',
          3,
        ),
      ),
    );

    final multiPartQuestions = questions
        .where((question) => question.subquestions.isNotEmpty)
        .toList();
    final multiPartCounts = {
      for (final bank in banks)
        bank.id: bank.questions
            .where((question) => question.subquestions.isNotEmpty)
            .length,
    };
    expect(multiPartQuestions, hasLength(157));
    expect(multiPartCounts['sotsuken_1to1'], 30);
    expect(multiPartCounts['sotsuken_test'], 30);
    expect(multiPartCounts['curriculum_stage2'], 97);
    expect(
      multiPartQuestions,
      everyElement(
        isA<DriverQuestion>()
            .having(
              (question) => question.subquestions.length,
              'subquestions',
              3,
            )
            .having(
              (question) =>
                  question.subquestions.first.answer == question.answer,
              'first subquestion matches legacy answer',
              isTrue,
            ),
      ),
    );
    expect(
      illustrationQuestions,
      everyElement(
        isA<DriverQuestion>().having(
          (question) => question.pointValue,
          'pointValue',
          2,
        ),
      ),
    );
    expect(
      fallbackIdQuestions.every(
        (question) => question.canonicalId == question.questionKey,
      ),
      isTrue,
    );
  });

  test('loads one full bank by id', () async {
    final bank = await const QuestionRepository().loadBank('karimen_1to1');

    expect(bank.id, 'karimen_1to1');
    expect(bank.questions, hasLength(300));
    expect(bank.questions.first.questionChinese, isNotEmpty);
  });

  test('loads lightweight bank summaries', () async {
    final summaries = await const QuestionRepository().loadBankSummaries();
    final summary = await const QuestionRepository().loadBankSummary(
      'karimen_1to1',
    );

    expect(summaries, hasLength(7));
    expect(
      summaries.expand((bank) => bank.questionIds).toSet(),
      hasLength(2318),
    );
    expect(summary.id, 'karimen_1to1');
    expect(summary.questionIds, hasLength(299));
    expect(summary.workbooks.map((workbook) => workbook.number), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
    expect(summary.workbooks.first.questionIds, hasLength(50));
  });
}
