import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Files other apps shared to RizCut (Android "Share → RizCut").
/// The native side copies them into the app cache and hands over paths.
class ShareIntake {
  ShareIntake._();
  static final instance = ShareIntake._();

  static const _channel = MethodChannel('rizcut/share');
  bool _listening = false;

  /// Calls [onFiles] with shared file paths now (if the app was opened by a
  /// share) and whenever something is shared while it's running.
  Future<void> listen(void Function(List<String> paths) onFiles) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'shared') await _take(onFiles);
      });
    }
    await _take(onFiles);
  }

  Future<void> _take(void Function(List<String> paths) onFiles) async {
    try {
      final paths = await _channel.invokeListMethod<String>('takeShared');
      if (paths != null && paths.isNotEmpty) onFiles(paths);
    } on MissingPluginException {
      // Running without the native side (tests).
    }
  }
}
