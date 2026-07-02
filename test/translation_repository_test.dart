import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/repositories/question_repository.dart';
import 'package:japan_driver/repositories/translation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends the published question and parses a cached translation',
    () async {
      final question =
          (await const QuestionRepository().loadBanks()).first.questions[1];
      Map<String, Object?>? receivedPayload;
      final repository = TranslationRepository(
        call: (payload) async {
          receivedPayload = payload;
          return {
            'translation': {'question': '中文题目', 'explanation': '中文解析'},
            'cached': true,
          };
        },
      );

      final translation = await repository.getQuestionTranslation(
        question,
        generateIfMissing: true,
      );

      expect(receivedPayload?['questionId'], question.canonicalId);
      expect(receivedPayload?['question'], question.questionText);
      expect(receivedPayload?['explanation'], question.explanation);
      expect(receivedPayload?['generateIfMissing'], isTrue);
      expect(translation?.question, '中文题目');
      expect(translation?.explanation, '中文解析');
    },
  );

  test(
    'returns null when cache-only lookup has no server translation',
    () async {
      final question =
          (await const QuestionRepository().loadBanks()).first.questions[1];
      final repository = TranslationRepository(
        call: (payload) async => {'translation': null, 'cached': false},
      );

      final translation = await repository.getQuestionTranslation(
        question,
        generateIfMissing: false,
      );

      expect(translation, isNull);
    },
  );
}
