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
}
