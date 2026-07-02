import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/app_settings.dart';

void main() {
  test('Chinese comparison is opt-in and survives serialization', () {
    final defaults = AppSettings.defaults();

    expect(defaults.showChinese, isFalse);

    final restored = AppSettings.fromJson(
      defaults.copyWith(showChinese: true).toJson(),
    );

    expect(restored.showChinese, isTrue);
  });

  test('older saved settings default Chinese comparison to off', () {
    final restored = AppSettings.fromJson(const {
      'darkMode': true,
      'autoAdvance': true,
      'showRuby': false,
    });

    expect(restored.showChinese, isFalse);
  });
}
