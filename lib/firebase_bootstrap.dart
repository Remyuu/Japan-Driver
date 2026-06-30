import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        projectId.isNotEmpty &&
        messagingSenderId.isNotEmpty;
  }

  static Future<void> initialize() async {
    if (!isConfigured || Firebase.apps.isNotEmpty) {
      return;
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        measurementId: measurementId.isEmpty ? null : measurementId,
      ),
    );
  }
}
