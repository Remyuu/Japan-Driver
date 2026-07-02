import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question_bank.dart';
import '../models/question_translation.dart';
import '../models/translation_language.dart';

typedef GoogleTranslateV2Call =
    Future<Object?> Function(Map<String, Object?> payload);

class TranslationRepository {
  TranslationRepository({
    GoogleTranslateV2Call? googleTranslateV2Call,
    SharedPreferences? preferences,
    bool useLocalCache = true,
  }) : _options = _TranslationRepositoryOptions(
         googleTranslateV2Call,
         preferences,
         useLocalCache,
       );

  static const _googleTranslateApiKey = String.fromEnvironment(
    'GOOGLE_TRANSLATE_API_KEY',
  );
  static const _localCachePrefix = 'question_translation_v2';

  final _TranslationRepositoryOptions _options;
  final Map<String, Future<QuestionTranslation?>> _pendingRequests = {};

  Future<QuestionTranslation?> getQuestionTranslation(
    DriverQuestion question, {
    required TranslationLanguage language,
    required bool generateIfMissing,
  }) {
    final requestKey = [
      question.canonicalId,
      question.questionText,
      question.explanation,
      language.apiCode,
      generateIfMissing,
    ].join('\u0000');
    final pending = _pendingRequests[requestKey];
    if (pending != null) {
      return pending;
    }

    late final Future<QuestionTranslation?> request;
    request =
        _requestTranslation(
          question,
          language: language,
          generateIfMissing: generateIfMissing,
        ).whenComplete(() {
          _pendingRequests.remove(requestKey);
        });
    _pendingRequests[requestKey] = request;
    return request;
  }

  Future<QuestionTranslation?> _requestTranslation(
    DriverQuestion question, {
    required TranslationLanguage language,
    required bool generateIfMissing,
  }) async {
    final localCached = await _readLocalCache(question, language);
    if (localCached != null) {
      return localCached;
    }

    if (!generateIfMissing) {
      return null;
    }
    if (!_isGoogleTranslateV2Configured) {
      throw const TranslationNotConfiguredException();
    }

    final directTranslation = await _requestGoogleTranslateV2(
      question,
      language: language,
    );
    await _writeLocalCache(question, language, directTranslation);
    return directTranslation;
  }

  Future<QuestionTranslation> _requestGoogleTranslateV2(
    DriverQuestion question, {
    required TranslationLanguage language,
  }) async {
    final contents = question.explanation.isEmpty
        ? [question.questionText]
        : [question.questionText, question.explanation];
    final call = _options.googleTranslateV2Call ?? _googleTranslateV2HttpCall;
    final response = await call({
      'q': contents,
      'source': 'ja',
      'target': language.apiCode,
      'format': 'text',
    });
    return _translationFromGoogleV2Response(
      response,
      includeExplanation: question.explanation.isNotEmpty,
    );
  }

  Future<Object?> _googleTranslateV2HttpCall(
    Map<String, Object?> payload,
  ) async {
    if (!_isGoogleTranslateV2Configured) {
      throw const TranslationNotConfiguredException();
    }

    final response = await http.post(
      Uri.https('translation.googleapis.com', '/language/translate/v2', {
        'key': _googleTranslateApiKey,
      }),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranslationException(code: 'google-v2-${response.statusCode}');
    }
    return jsonDecode(response.body) as Object?;
  }

  QuestionTranslation _translationFromGoogleV2Response(
    Object? response, {
    required bool includeExplanation,
  }) {
    final data = response is Map ? response['data'] : null;
    final translations = data is Map ? data['translations'] : null;
    final expectedLength = includeExplanation ? 2 : 1;
    if (translations is! List || translations.length != expectedLength) {
      throw const TranslationException();
    }

    final values = [
      for (final item in translations)
        if (item is Map)
          _decodeTranslatedText(item['translatedText'])
        else
          null,
    ];
    if (values.length != expectedLength ||
        values.first == null ||
        (includeExplanation && values[1] == null)) {
      throw const TranslationException();
    }

    return QuestionTranslation(
      question: values[0],
      explanation: includeExplanation ? values[1] : null,
    );
  }

  bool get _isGoogleTranslateV2Configured {
    return _options.googleTranslateV2Call != null ||
        _googleTranslateApiKey.isNotEmpty;
  }

  Future<QuestionTranslation?> _readLocalCache(
    DriverQuestion question,
    TranslationLanguage language,
  ) async {
    if (!_options.useLocalCache) {
      return null;
    }

    final source = (await _localPreferences).getString(
      _localCacheKey(question, language),
    );
    if (source == null) {
      return null;
    }
    try {
      final json = jsonDecode(source);
      if (json is! Map) {
        return null;
      }
      final translatedQuestion = _nonEmptyString(json['question']);
      if (translatedQuestion == null) {
        return null;
      }
      return QuestionTranslation(
        question: translatedQuestion,
        explanation: _nonEmptyString(json['explanation']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocalCache(
    DriverQuestion question,
    TranslationLanguage language,
    QuestionTranslation translation,
  ) async {
    if (!_options.useLocalCache || translation.question == null) {
      return;
    }

    await (await _localPreferences).setString(
      _localCacheKey(question, language),
      jsonEncode({
        'question': translation.question,
        'explanation': translation.explanation,
      }),
    );
  }

  Future<SharedPreferences> get _localPreferences async {
    return _options.preferences ?? SharedPreferences.getInstance();
  }

  String _localCacheKey(DriverQuestion question, TranslationLanguage language) {
    return [
      _localCachePrefix,
      question.canonicalId,
      language.cacheKey,
      _stableHash(question.questionText),
      _stableHash(question.explanation),
    ].join(':');
  }
}

class _TranslationRepositoryOptions {
  const _TranslationRepositoryOptions(
    this.googleTranslateV2Call,
    this.preferences,
    this.useLocalCache,
  );

  final GoogleTranslateV2Call? googleTranslateV2Call;
  final SharedPreferences? preferences;
  final bool useLocalCache;
}

class TranslationException implements Exception {
  const TranslationException({this.code});

  final String? code;
}

class TranslationNotConfiguredException extends TranslationException {
  const TranslationNotConfiguredException() : super(code: 'not-configured');
}

String? _nonEmptyString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

String? _decodeTranslatedText(Object? value) {
  final source = _nonEmptyString(value);
  if (source == null) {
    return null;
  }
  final decoded = html_parser.parseFragment(source).text?.trim();
  return decoded == null || decoded.isEmpty ? source : decoded;
}

String _stableHash(String source) {
  var hash = 0x811c9dc5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
