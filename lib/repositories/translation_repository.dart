import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_bootstrap.dart';
import '../models/question_bank.dart';
import '../models/question_translation.dart';
import '../models/translation_language.dart';

typedef TranslationCall =
    Future<Object?> Function(Map<String, Object?> payload);

class TranslationRepository {
  TranslationRepository({TranslationCall? call}) : _injectedCall = call;

  static const _region = 'asia-northeast1';
  static const _functionName = 'getQuestionTranslation';
  static const _emulatorHost = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_HOST',
  );
  static const _emulatorPort = int.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );

  final TranslationCall? _injectedCall;
  final Map<String, Future<QuestionTranslation?>> _pendingRequests = {};
  FirebaseFunctions? _functions;

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
    final call = _injectedCall ?? _firebaseCall;
    final response = await call({
      'questionId': question.canonicalId,
      'question': question.questionText,
      'explanation': question.explanation,
      'targetLanguage': language.apiCode,
      'generateIfMissing': generateIfMissing,
    });
    if (response is! Map) {
      throw const TranslationException();
    }
    final translation = response['translation'];
    if (translation == null) {
      return null;
    }
    if (translation is! Map) {
      throw const TranslationException();
    }

    final translatedQuestion = _nonEmptyString(translation['question']);
    final translatedExplanation = _nonEmptyString(translation['explanation']);
    if (translatedQuestion == null) {
      throw const TranslationException();
    }
    return QuestionTranslation(
      question: translatedQuestion,
      explanation: translatedExplanation,
    );
  }

  Future<Object?> _firebaseCall(Map<String, Object?> payload) async {
    if (!FirebaseBootstrap.isConfigured || Firebase.apps.isEmpty) {
      throw const TranslationNotConfiguredException();
    }

    final functions = _functions ??= _createFunctions();
    try {
      final result = await functions
          .httpsCallable(_functionName)
          .call<Map<String, dynamic>>(payload);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw TranslationException(code: error.code);
    }
  }

  FirebaseFunctions _createFunctions() {
    final functions = FirebaseFunctions.instanceFor(region: _region);
    if (_emulatorHost.isNotEmpty) {
      functions.useFunctionsEmulator(_emulatorHost, _emulatorPort);
    }
    return functions;
  }
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
