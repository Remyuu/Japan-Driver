import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/app_settings.dart';
import 'package:japan_driver/models/translation_language.dart';

void main() {
  test('Chinese comparison is opt-in and survives serialization', () {
    final defaults = AppSettings.defaults();

    expect(defaults.showChinese, isFalse);
    expect(defaults.showEnglish, isFalse);
    expect(defaults.showVietnamese, isFalse);
    expect(defaults.enabledTranslationLanguages, isEmpty);

    final restored = AppSettings.fromJson(
      defaults
          .copyWith(showChinese: true, showEnglish: true, showVietnamese: true)
          .toJson(),
    );

    expect(restored.showChinese, isTrue);
    expect(restored.showEnglish, isTrue);
    expect(restored.showVietnamese, isTrue);
    expect(restored.enabledTranslationLanguages, TranslationLanguage.values);
  });

  test('older saved settings default Chinese comparison to off', () {
    final restored = AppSettings.fromJson(const {
      'darkMode': true,
      'autoAdvance': true,
      'showRuby': false,
    });

    expect(restored.showChinese, isFalse);
    expect(restored.showEnglish, isFalse);
    expect(restored.showVietnamese, isFalse);
  });
}
