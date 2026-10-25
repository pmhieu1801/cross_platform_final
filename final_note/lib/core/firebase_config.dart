import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client identifiers only; never substitute a demo project for missing config.
abstract final class FirebaseConfig {
  static FirebaseOptions fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      throw const FirebaseConfigurationException(
        'W1 chỉ cấu hình Web và Android.',
      );
    }
    if ([apiKey, appId, senderId, projectId].any((value) => value.isEmpty) ||
        (kIsWeb && authDomain.isEmpty)) {
      throw const FirebaseConfigurationException(
        'Chưa có cấu hình Firebase thật cho nền tảng này. '
        'Xem README: thiết lập Firebase và --dart-define-from-file. Auth chưa hoạt động.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: kIsWeb ? authDomain : null,
      storageBucket: bucket.isEmpty ? null : bucket,
    );
  }
}

class FirebaseConfigurationException implements Exception {
  const FirebaseConfigurationException(this.message);
  final String message;
}
