import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/bank_catalog.dart';
import '../models/question_bank.dart';

class QuestionRepository {
  const QuestionRepository({this.assetBundle});

  final AssetBundle? assetBundle;

  AssetBundle get _bundle => assetBundle ?? rootBundle;

  static const _translationsAssetPath = 'assets/translations_zh.json';

  Future<List<QuestionBank>> loadBanks() async {
    final translationsSource = await _bundle.loadString(_translationsAssetPath);
    final translationsJson = jsonDecode(translationsSource);
    final translations = translationsJson is Map
        ? (translationsJson['translations'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{}
        : const <String, Object?>{};
    final banks = <QuestionBank>[];
    for (final definition in driverBankDefinitions) {
      final source = await _bundle.loadString(definition.assetPath);
      final decoded = jsonDecode(source) as Map<String, Object?>;
      banks.add(
        QuestionBank.fromJson(definition, decoded, translations: translations),
      );
    }
    return banks;
  }
}
