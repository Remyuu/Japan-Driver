enum TranslationLanguage {
  chinese(
    apiCode: 'zh-CN',
    cacheKey: 'zh_cn',
    displayLabel: '中文',
    settingLabel: '显示中文翻译',
  ),
  english(
    apiCode: 'en',
    cacheKey: 'en',
    displayLabel: 'English',
    settingLabel: 'Show English translation',
  ),
  vietnamese(
    apiCode: 'vi',
    cacheKey: 'vi',
    displayLabel: 'Tiếng Việt',
    settingLabel: 'Hiển thị bản dịch tiếng Việt',
  );

  const TranslationLanguage({
    required this.apiCode,
    required this.cacheKey,
    required this.displayLabel,
    required this.settingLabel,
  });

  final String apiCode;
  final String cacheKey;
  final String displayLabel;
  final String settingLabel;

  String get loadingMessage {
    return switch (this) {
      TranslationLanguage.chinese => 'Google 翻译生成中…',
      TranslationLanguage.english => 'Generating with Google Translate…',
      TranslationLanguage.vietnamese => 'Đang dịch bằng Google…',
    };
  }

  String get notConfiguredMessage {
    return switch (this) {
      TranslationLanguage.chinese => '现场翻译尚未配置',
      TranslationLanguage.english => 'Live translation is not configured yet.',
      TranslationLanguage.vietnamese => 'Chưa cấu hình dịch trực tiếp.',
    };
  }

  String get serviceUnavailableMessage {
    return switch (this) {
      TranslationLanguage.chinese => '现场翻译服务暂不可用，请稍后重试',
      TranslationLanguage.english =>
        'Live translation is temporarily unavailable. Please try again later.',
      TranslationLanguage.vietnamese =>
        'Dịch trực tiếp tạm thời chưa khả dụng. Vui lòng thử lại sau.',
    };
  }

  String get temporaryFailureMessage {
    return switch (this) {
      TranslationLanguage.chinese => '翻译暂时失败，请稍后重试',
      TranslationLanguage.english =>
        'Translation failed temporarily. Please try again later.',
      TranslationLanguage.vietnamese =>
        'Tạm thời không dịch được. Vui lòng thử lại sau.',
    };
  }

  String get retryLabel {
    return switch (this) {
      TranslationLanguage.chinese => '重试',
      TranslationLanguage.english => 'Retry',
      TranslationLanguage.vietnamese => 'Thử lại',
    };
  }
}
