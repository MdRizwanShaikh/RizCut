import 'package:video_player/video_player.dart';

import 'video_source_stub.dart' if (dart.library.io) 'video_source_io.dart'
    as impl;

/// A picked video: a local file path (Android) or a URL (web blob / demo).
class VideoSource {
  const VideoSource.file(this.location, {this.name = ''}) : isUrl = false;
  const VideoSource.url(this.location, {this.name = ''}) : isUrl = true;

  final String location;
  final bool isUrl;
  final String name;

  VideoPlayerController createController() => isUrl
      ? VideoPlayerController.networkUrl(Uri.parse(location))
      : impl.fileController(location);
}
