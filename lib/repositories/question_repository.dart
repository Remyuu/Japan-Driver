import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/bank_catalog.dart';
import '../models/question_bank.dart';

class QuestionRepository {
  const QuestionRepository({this.assetBundle});

  final AssetBundle? assetBundle;

  AssetBundle get _bundle => assetBundle ?? rootBundle;

  static const _manifestAssetPath = 'assets/question_bank_manifest.json';
  static const _translationsAssetPath = 'assets/translations_zh.json';

  Future<QuestionBank> loadBank(String bankId) async {
    final definition = driverBankDefinitionById(bankId);
    if (definition == null) {
      throw ArgumentError.value(bankId, 'bankId', 'Unknown question bank');
    }
    final translations = await _loadTranslations();
    return _loadBank(definition, translations: translations);
  }

  Future<List<QuestionBank>> loadBanks() async {
    final translations = await _loadTranslations();
    final banks = <QuestionBank>[];
    for (final definition in driverBankDefinitions) {
      banks.add(await _loadBank(definition, translations: translations));
    }
    return banks;
  }

  Future<QuestionBankSummary> loadBankSummary(String bankId) async {
    final definition = driverBankDefinitionById(bankId);
    if (definition == null) {
      throw ArgumentError.value(bankId, 'bankId', 'Unknown question bank');
    }
    final manifest = await _loadManifest();
    final banks = (manifest['banks'] as List? ?? const []).whereType<Map>();
    for (final item in banks) {
      final json = item.cast<String, Object?>();
      if (json['id'] == bankId) {
        return QuestionBankSummary.fromJson(definition, json);
      }
    }
    throw StateError('Question bank summary not found: $bankId');
  }

  Future<List<QuestionBankSummary>> loadBankSummaries() async {
    final manifest = await _loadManifest();
    final banks = (manifest['banks'] as List? ?? const []).whereType<Map>();
    final byId = {
      for (final item in banks)
        if (item['id'] is String) item['id'] as String: item,
    };
    return [
      for (final definition in driverBankDefinitions)
        if (byId[definition.id] != null)
          QuestionBankSummary.fromJson(
            definition,
            byId[definition.id]!.cast<String, Object?>(),
          ),
    ];
  }

  Future<Map<String, Object?>> _loadManifest() async {
    final source = await _bundle.loadString(_manifestAssetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Invalid question bank manifest');
    }
    return decoded.cast<String, Object?>();
  }

  Future<Map<String, Object?>> _loadTranslations() async {
    final translationsSource = await _bundle.loadString(_translationsAssetPath);
    final translationsJson = jsonDecode(translationsSource);
    return translationsJson is Map
        ? (translationsJson['translations'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{}
        : const <String, Object?>{};
  }

  Future<QuestionBank> _loadBank(
    BankDefinition definition, {
    required Map<String, Object?> translations,
  }) async {
    final source = await _bundle.loadString(definition.assetPath);
    final decoded = jsonDecode(source) as Map<String, Object?>;
    return QuestionBank.fromJson(
      definition,
      decoded,
      translations: translations,
    );
  }
}
