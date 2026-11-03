import 'package:flutter/widgets.dart';

import 'thumbnailer_stub.dart'
    if (dart.library.io) 'thumbnailer_io.dart'
    if (dart.library.js_interop) 'thumbnailer_web.dart' as impl;

/// A small frame from a video at [at]: extracted with FFmpeg on Android,
/// drawn from a <video> element on web. Null if it can't be produced.
Future<ImageProvider?> videoThumbnail(String location, Duration at) =>
    impl.videoThumbnail(location, at);
