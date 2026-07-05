class BankDefinition {
  const BankDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.assetBasePath,
    this.hasChapters = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final String assetBasePath;
  final bool hasChapters;

  String resolveAsset(String relativePath) => '$assetBasePath/$relativePath';
}

const driverBankDefinitions = <BankDefinition>[
  BankDefinition(
    id: 'karimen_1to1',
    title: '仮免前',
    subtitle: '一問一答形式',
    assetPath: 'scraped/musasi_ja_karimen/karimen_1to1_all.json',
    assetBasePath: 'scraped/musasi_ja_karimen',
  ),
  BankDefinition(
    id: 'sotsuken_1to1',
    title: '卒検前',
    subtitle: '一問一答形式',
    assetPath: 'scraped/musasi_ja_sotsuken/sotsuken_1to1_all.json',
    assetBasePath: 'scraped/musasi_ja_sotsuken',
  ),
  BankDefinition(
    id: 'karimen_test',
    title: '仮免前',
    subtitle: 'テスト形式',
    assetPath: 'scraped/musasi_ja_test_karimen/karimen_test_all.json',
    assetBasePath: 'scraped/musasi_ja_test_karimen',
  ),
  BankDefinition(
    id: 'sotsuken_test',
    title: '卒検前',
    subtitle: 'テスト形式',
    assetPath: 'scraped/musasi_ja_test_sotsuken/sotsuken_test_all.json',
    assetBasePath: 'scraped/musasi_ja_test_sotsuken',
  ),
  BankDefinition(
    id: 'curriculum_stage1',
    title: '第一段階',
    subtitle: '項目別問題',
    assetPath: 'scraped/musasi_ja_curriculum_stage1/curriculum_stage1_all.json',
    assetBasePath: 'scraped/musasi_ja_curriculum_stage1',
    hasChapters: true,
  ),
  BankDefinition(
    id: 'curriculum_stage2',
    title: '第二段階',
    subtitle: '項目別問題',
    assetPath: 'scraped/musasi_ja_curriculum_stage2/curriculum_stage2_all.json',
    assetBasePath: 'scraped/musasi_ja_curriculum_stage2',
    hasChapters: true,
  ),
  BankDefinition(
    id: 'difficult',
    title: 'みんな苦手問題',
    subtitle: '第一段階・第二段階',
    assetPath: 'scraped/musasi_ja_difficult/difficult_all.json',
    assetBasePath: 'scraped/musasi_ja_difficult',
  ),
];

BankDefinition? driverBankDefinitionById(String id) {
  for (final definition in driverBankDefinitions) {
    if (definition.id == id) {
      return definition;
    }
  }
  return null;
}
