import 'media_tools_stub.dart' if (dart.library.io) 'media_tools_io.dart' as impl;

/// On-device helpers that make new media files (Android only; null on web).
abstract final class MediaTools {
  static bool get supported => impl.supported;

  /// A reversed copy (video + audio) of [path] from [start] for [length].
  static Future<String?> reverse(String path, Duration start, Duration length) =>
      impl.reverse(path, start, length);

  /// A JPEG of the frame at [at].
  static Future<String?> frame(String path, Duration at) => impl.frame(path, at);

  /// The sound of a video as an .m4a file (null if it has no audio).
  static Future<String?> extractAudio(String path) => impl.extractAudio(path);
}

/// Reversing holds the whole clip in memory, so keep it short.
const kMaxReverseLength = Duration(seconds: 30);
