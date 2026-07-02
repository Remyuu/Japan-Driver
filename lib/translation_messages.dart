import 'models/translation_language.dart';
import 'repositories/translation_repository.dart';

String translationFailureMessage(TranslationLanguage language, Object? error) {
  if (error is TranslationNotConfiguredException) {
    return language.notConfiguredMessage;
  }
  if (error is TranslationException &&
      (error.code == 'not-found' ||
          error.code == 'unimplemented' ||
          error.code == 'google-v2-400' ||
          error.code == 'google-v2-403' ||
          error.code == 'google-v2-429' ||
          error.code == 'google-v2-500' ||
          error.code == 'google-v2-503')) {
    return language.serviceUnavailableMessage;
  }
  return language.temporaryFailureMessage;
}
