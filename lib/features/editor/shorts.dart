/// Turns any video into a 9:16 Short.
library;

import 'dart:ui' show Color, Offset;

import 'media.dart';
import 'project.dart';

enum ShortStyle {
  highlights('Highlights', 'Moments from across the video'),
  fromStart('From start', 'The opening part of the video');

  const ShortStyle(this.label, this.hint);
  final String label, hint;
}

class ShortOptions {
  const ShortOptions({
    this.length = const Duration(seconds: 30),
    this.style = ShortStyle.highlights,
    this.title = '',
    this.parts = 5,
  });

  final Duration length;
  final ShortStyle style;

  /// Caption band at the top; empty = none.
  final String title;

  /// Number of moments for [ShortStyle.highlights].
  final int parts;
}

const kShortLengths = [
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(seconds: 60),
];

/// Builds the Short: evenly spread moments (or the start), 9:16 canvas
/// with a blurred background, zoom cuts and an optional title band.
Project buildShort(MediaItem video, ShortOptions o) {
  final dur = video.duration;
  final target = dur < o.length ? dur : o.length;
  final clips = <VideoClip>[];
  if (o.style == ShortStyle.fromStart || dur <= o.length || o.parts <= 1) {
    clips.add(VideoClip(mediaId: video.id, sourceIn: Duration.zero, sourceOut: target));
  } else {
    final n = o.parts;
    final part = Duration(microseconds: target.inMicroseconds ~/ n);
    final room = dur - part;
    for (var k = 0; k < n; k++) {
      final start = Duration(microseconds: room.inMicroseconds * k ~/ (n - 1));
      clips.add(VideoClip(
        mediaId: video.id,
        sourceIn: start,
        sourceOut: start + part,
        transitionOut: k < n - 1 ? TransitionType.zoom : TransitionType.none,
      ));
    }
  }
  final total = clips.fold(Duration.zero, (a, c) => a + c.timelineLength);
  return Project(
    media: List.unmodifiable([video]),
    clips: List.unmodifiable(clips),
    canvas: CanvasRatio.portrait,
    background: BackgroundMode.blur,
    texts: List.unmodifiable([
      if (o.title.trim().isNotEmpty)
        TextOverlay(
          text: o.title.trim(),
          start: Duration.zero,
          end: total,
          band: 0xFFFFE14D,
          color: const Color(0xFF111111),
          position: const Offset(0.5, 0.12),
          sizeFraction: 0.05,
        ),
    ]),
  );
}
