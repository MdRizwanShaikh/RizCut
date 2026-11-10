import 'package:video_player/video_player.dart';

import 'video_source_stub.dart' if (dart.library.io) 'video_source_io.dart'
    as io;
import 'url_resolver_stub.dart'
    if (dart.library.js_interop) 'url_resolver_web.dart' as web;

/// Every preview player mixes its sound with the others. Without this,
/// Android gives each ExoPlayer audio focus in turn, so starting the video
/// pauses the music, voiceover, sound-effect and layer players.
final kPlayerOptions = VideoPlayerOptions(mixWithOthers: true);

/// A picked video: a local file path (Android) or a URL (web blob / demo).
class VideoSource {
  const VideoSource.file(this.location, {this.name = ''}) : isUrl = false;
  const VideoSource.url(this.location, {this.name = ''}) : isUrl = true;

  final String location;
  final bool isUrl;
  final String name;

  Map<String, Object?> toJson() =>
      {'loc': location, 'url': isUrl, 'name': name};

  factory VideoSource.fromJson(Map<String, Object?> j) {
    final loc = j['loc'] as String;
    final name = j['name'] as String? ?? '';
    return (j['url'] as bool? ?? false)
        ? VideoSource.url(loc, name: name)
        : VideoSource.file(loc, name: name);
  }

  /// Creates a (not yet initialised) player for this source. On web, plain
  /// URLs are downloaded into a blob first so seeking works on any host.
  Future<VideoPlayerController> createController() async {
    if (!isUrl) return io.fileController(location);
    final url = await web.playableUrl(location);
    return VideoPlayerController.networkUrl(Uri.parse(url),
        videoPlayerOptions: kPlayerOptions);
  }

  /// Plain URL player, used if the blob copy can't be played (strict hosts).
  VideoPlayerController? directController() => isUrl
      ? VideoPlayerController.networkUrl(Uri.parse(location),
          videoPlayerOptions: kPlayerOptions)
      : null;
}
