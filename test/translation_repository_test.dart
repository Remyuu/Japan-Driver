import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/translation_language.dart';
import 'package:japan_driver/repositories/question_repository.dart';
import 'package:japan_driver/repositories/translation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends a Google Translation v2 request and parses the response',
    () async {
      final question =
          (await const QuestionRepository().loadBanks()).first.questions[1];
      Map<String, Object?>? receivedPayload;
      final repository = TranslationRepository(
        useLocalCache: false,
        googleTranslateV2Call: (payload) async {
          receivedPayload = payload;
          return {
            'data': {
              'translations': [
                {'translatedText': 'Tom &amp; Jerry must drive safely.'},
                {'translatedText': 'This is the explanation.'},
              ],
            },
          };
        },
      );

      final translation = await repository.getQuestionTranslation(
        question,
        language: TranslationLanguage.english,
        generateIfMissing: true,
      );

      expect(receivedPayload?['q'], [
        question.questionText,
        question.explanation,
      ]);
      expect(receivedPayload?['source'], 'ja');
      expect(receivedPayload?['target'], 'en');
      expect(receivedPayload?['format'], 'text');
      expect(translation?.question, 'Tom & Jerry must drive safely.');
      expect(translation?.explanation, 'This is the explanation.');
    },
  );

  test(
    'returns null without calling Google when generation is disabled',
    () async {
      final question =
          (await const QuestionRepository().loadBanks()).first.questions[1];
      var called = false;
      final repository = TranslationRepository(
        useLocalCache: false,
        googleTranslateV2Call: (payload) async {
          called = true;
          return {
            'data': {
              'translations': [
                {'translatedText': 'English question'},
              ],
            },
          };
        },
      );

      final translation = await repository.getQuestionTranslation(
        question,
        language: TranslationLanguage.english,
        generateIfMissing: false,
      );

      expect(translation, isNull);
      expect(called, isFalse);
    },
  );

  test('sends subquestions to Google and parses them in order', () async {
    final banks = await const QuestionRepository().loadBanks();
    final question = banks
        .expand((bank) => bank.questions)
        .firstWhere((question) => question.subquestions.length >= 3);
    final expectedPayload = [
      question.questionText,
      for (final subquestion in question.subquestions) subquestion.text,
      if (question.explanation.isNotEmpty) question.explanation,
    ];
    Map<String, Object?>? receivedPayload;
    final repository = TranslationRepository(
      useLocalCache: false,
      googleTranslateV2Call: (payload) async {
        receivedPayload = payload;
        return {
          'data': {
            'translations': [
              for (var i = 0; i < expectedPayload.length; i += 1)
                {'translatedText': 'translated $i'},
            ],
          },
        };
      },
    );

    final translation = await repository.getQuestionTranslation(
      question,
      language: TranslationLanguage.english,
      generateIfMissing: true,
    );

    expect(receivedPayload?['q'], expectedPayload);
    expect(translation?.question, 'translated 0');
    expect(translation?.subquestions, [
      for (var i = 0; i < question.subquestions.length; i += 1)
        'translated ${i + 1}',
    ]);
    expect(
      translation?.explanation,
      question.explanation.isEmpty
          ? isNull
          : 'translated ${expectedPayload.length - 1}',
    );
  });

  test('caches successful Google v2 translations locally', () async {
    SharedPreferences.setMockInitialValues({});
    final question =
        (await const QuestionRepository().loadBanks()).first.questions[1];
    var calls = 0;
    final repository = TranslationRepository(
      googleTranslateV2Call: (payload) async {
        calls += 1;
        return {
          'data': {
            'translations': [
              {'translatedText': 'Câu hỏi tiếng Việt'},
              {'translatedText': 'Giải thích tiếng Việt'},
            ],
          },
        };
      },
    );

    final first = await repository.getQuestionTranslation(
      question,
      language: TranslationLanguage.vietnamese,
      generateIfMissing: true,
    );
    final second = await repository.getQuestionTranslation(
      question,
      language: TranslationLanguage.vietnamese,
      generateIfMissing: true,
    );

    expect(calls, 1);
    expect(first?.question, 'Câu hỏi tiếng Việt');
    expect(second?.question, 'Câu hỏi tiếng Việt');
    expect(second?.explanation, 'Giải thích tiếng Việt');
  });
}
