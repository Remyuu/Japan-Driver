import 'package:firebase_auth/firebase_auth.dart';

class AccountUser {
  const AccountUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }
    return 'Google account';
  }

  factory AccountUser.fromFirebase(User user) {
    return AccountUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
