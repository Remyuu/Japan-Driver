import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/translation_language.dart';
import 'package:japan_driver/repositories/translation_repository.dart';
import 'package:japan_driver/translation_messages.dart';

void main() {
  test('uses the selected language for translation status text', () {
    expect(TranslationLanguage.chinese.loadingMessage, 'Google 翻译生成中…');
    expect(
      TranslationLanguage.english.temporaryFailureMessage,
      'Translation failed temporarily. Please try again later.',
    );
    expect(TranslationLanguage.vietnamese.retryLabel, 'Thử lại');
  });

  test('explains unavailable Google v2 translation per language', () {
    const error = TranslationException(code: 'google-v2-403');

    expect(
      translationFailureMessage(TranslationLanguage.chinese, error),
      '现场翻译服务暂不可用，请稍后重试',
    );
    expect(
      translationFailureMessage(TranslationLanguage.english, error),
      'Live translation is temporarily unavailable. Please try again later.',
    );
    expect(
      translationFailureMessage(TranslationLanguage.vietnamese, error),
      'Dịch trực tiếp tạm thời chưa khả dụng. Vui lòng thử lại sau.',
    );
  });
}
