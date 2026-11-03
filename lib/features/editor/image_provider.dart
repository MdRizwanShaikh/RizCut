import 'package:flutter/widgets.dart';

import 'image_provider_stub.dart'
    if (dart.library.io) 'image_provider_io.dart' as impl;
import 'video_source.dart';

/// Image for a photo media item (file on Android, URL/blob on web).
ImageProvider imageFor(VideoSource s) =>
    s.isUrl ? NetworkImage(s.location) : impl.fileImage(s.location);
