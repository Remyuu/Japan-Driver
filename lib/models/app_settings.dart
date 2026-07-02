import 'translation_language.dart';

class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.autoAdvance,
    required this.showRuby,
    required this.showChinese,
    required this.showEnglish,
    required this.showVietnamese,
  });

  final bool darkMode;
  final bool autoAdvance;
  final bool showRuby;
  final bool showChinese;
  final bool showEnglish;
  final bool showVietnamese;

  factory AppSettings.defaults() {
    return const AppSettings(
      darkMode: false,
      autoAdvance: false,
      showRuby: true,
      showChinese: false,
      showEnglish: false,
      showVietnamese: false,
    );
  }

  AppSettings copyWith({
    bool? darkMode,
    bool? autoAdvance,
    bool? showRuby,
    bool? showChinese,
    bool? showEnglish,
    bool? showVietnamese,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      showRuby: showRuby ?? this.showRuby,
      showChinese: showChinese ?? this.showChinese,
      showEnglish: showEnglish ?? this.showEnglish,
      showVietnamese: showVietnamese ?? this.showVietnamese,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'darkMode': darkMode,
      'autoAdvance': autoAdvance,
      'showRuby': showRuby,
      'showChinese': showChinese,
      'showEnglish': showEnglish,
      'showVietnamese': showVietnamese,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      autoAdvance: json['autoAdvance'] as bool? ?? false,
      showRuby: json['showRuby'] as bool? ?? true,
      showChinese: json['showChinese'] as bool? ?? false,
      showEnglish: json['showEnglish'] as bool? ?? false,
      showVietnamese: json['showVietnamese'] as bool? ?? false,
    );
  }

  bool isTranslationEnabled(TranslationLanguage language) {
    return switch (language) {
      TranslationLanguage.chinese => showChinese,
      TranslationLanguage.english => showEnglish,
      TranslationLanguage.vietnamese => showVietnamese,
    };
  }

  List<TranslationLanguage> get enabledTranslationLanguages => [
    for (final language in TranslationLanguage.values)
      if (isTranslationEnabled(language)) language,
  ];
}
