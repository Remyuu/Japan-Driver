class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.autoAdvance,
    required this.showRuby,
  });

  final bool darkMode;
  final bool autoAdvance;
  final bool showRuby;

  factory AppSettings.defaults() {
    return const AppSettings(
      darkMode: false,
      autoAdvance: false,
      showRuby: true,
    );
  }

  AppSettings copyWith({bool? darkMode, bool? autoAdvance, bool? showRuby}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      showRuby: showRuby ?? this.showRuby,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'darkMode': darkMode,
      'autoAdvance': autoAdvance,
      'showRuby': showRuby,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      autoAdvance: json['autoAdvance'] as bool? ?? false,
      showRuby: json['showRuby'] as bool? ?? true,
    );
  }
}
