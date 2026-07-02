class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.autoAdvance,
    required this.showRuby,
    required this.showChinese,
  });

  final bool darkMode;
  final bool autoAdvance;
  final bool showRuby;
  final bool showChinese;

  factory AppSettings.defaults() {
    return const AppSettings(
      darkMode: false,
      autoAdvance: false,
      showRuby: true,
      showChinese: false,
    );
  }

  AppSettings copyWith({
    bool? darkMode,
    bool? autoAdvance,
    bool? showRuby,
    bool? showChinese,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      showRuby: showRuby ?? this.showRuby,
      showChinese: showChinese ?? this.showChinese,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'darkMode': darkMode,
      'autoAdvance': autoAdvance,
      'showRuby': showRuby,
      'showChinese': showChinese,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      autoAdvance: json['autoAdvance'] as bool? ?? false,
      showRuby: json['showRuby'] as bool? ?? true,
      showChinese: json['showChinese'] as bool? ?? false,
    );
  }
}
