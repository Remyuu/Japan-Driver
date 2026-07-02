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
}
