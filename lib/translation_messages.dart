import 'models/translation_language.dart';
import 'repositories/translation_repository.dart';

String translationFailureMessage(TranslationLanguage language, Object? error) {
  if (error is TranslationNotConfiguredException) {
    return language.notConfiguredMessage;
  }
  if (error is TranslationException &&
      (error.code == 'not-found' || error.code == 'unimplemented')) {
    return language.serviceUnavailableMessage;
  }
  return language.temporaryFailureMessage;
}
