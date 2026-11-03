import 'package:firebase_core/firebase_core.dart';

/// Firebase settings come from `--dart-define`s at build time, so the repo
/// holds no keys and builds without them simply run without login:
///
///   flutter build appbundle \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=... \
///     --dart-define=FIREBASE_SENDER_ID=... \
///     --dart-define=FIREBASE_STORAGE_BUCKET=... \
///     --dart-define=GOOGLE_SERVER_CLIENT_ID=...
abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// OAuth "Web client" ID from the Firebase/Google Cloud console; Google
  /// Sign-In on Android needs it to issue an ID token for Firebase.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: storageBucket,
      );
}
