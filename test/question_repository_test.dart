import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/repositories/question_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads bundled MUSASI question banks', () async {
    final banks = await const QuestionRepository().loadBanks();
    final questions = banks.expand((bank) => bank.questions).toList();
    final fallbackIdQuestions = questions
        .where((question) => question.questionId == null)
        .toList();

    expect(banks, hasLength(6));
    expect(questions, hasLength(3537));
    expect(
      questions.map((question) => question.canonicalId).toSet(),
      hasLength(2294),
    );
    expect(fallbackIdQuestions, hasLength(58));
    expect(
      fallbackIdQuestions.every(
        (question) => question.canonicalId == question.questionKey,
      ),
      isTrue,
    );
  });
}
