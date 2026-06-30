import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase_bootstrap.dart';
import '../models/account_user.dart';

class AccountAuthException implements Exception {
  const AccountAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountRepository {
  const AccountRepository();

  bool get isConfigured => FirebaseBootstrap.isConfigured;

  Stream<AccountUser?> authStateChanges() {
    if (!isConfigured) {
      return Stream<AccountUser?>.value(null);
    }
    return FirebaseAuth.instance.authStateChanges().map((user) {
      return user == null ? null : AccountUser.fromFirebase(user);
    });
  }

  Future<void> signInWithGoogle() async {
    if (!isConfigured) {
      throw const AccountAuthException('Googleログインはまだ設定されていません。');
    }

    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(provider);
      return;
    }

    await FirebaseAuth.instance.signInWithProvider(provider);
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      return;
    }
    await FirebaseAuth.instance.signOut();
  }
}
