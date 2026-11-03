import 'dart:ui' show Color, Offset;

/// Allowed playback speeds for a clip.
const kSpeeds = <double>[0.25, 0.5, 1, 1.5, 2, 4];

/// A segment of the source video placed on the timeline.
class VideoClip {
  const VideoClip({required this.sourceIn, required this.sourceOut, this.speed = 1})
      : assert(speed > 0);

  /// Range inside the source file.
  final Duration sourceIn, sourceOut;
  final double speed;

  Duration get sourceLength => sourceOut - sourceIn;

  /// Length of this clip on the output timeline (after speed change).
  Duration get timelineLength => Duration(
      microseconds: (sourceLength.inMicroseconds / speed).round());

  VideoClip copyWith({Duration? sourceIn, Duration? sourceOut, double? speed}) =>
      VideoClip(
        sourceIn: sourceIn ?? this.sourceIn,
        sourceOut: sourceOut ?? this.sourceOut,
        speed: speed ?? this.speed,
      );
}

/// Text placed over the video for a time range on the output timeline.
class TextOverlay {
  const TextOverlay({
    required this.text,
    required this.start,
    required this.end,
    this.color = const Color(0xFFFFFFFF),
    this.position = const Offset(0.5, 0.8),
    this.sizeFraction = 0.07,
    this.background = false,
  });

  final String text;
  final Duration start, end;
  final Color color;

  /// Center position relative to the frame (0..1, 0..1).
  final Offset position;

  /// Font size as a fraction of the frame height.
  final double sizeFraction;
  final bool background;

  bool visibleAt(Duration t) => t >= start && t < end;

  TextOverlay copyWith({
    String? text,
    Duration? start,
    Duration? end,
    Color? color,
    Offset? position,
    double? sizeFraction,
    bool? background,
  }) =>
      TextOverlay(
        text: text ?? this.text,
        start: start ?? this.start,
        end: end ?? this.end,
        color: color ?? this.color,
        position: position ?? this.position,
        sizeFraction: sizeFraction ?? this.sizeFraction,
        background: background ?? this.background,
      );
}

/// Where a timeline time lands: which clip and which source position.
class TimelineHit {
  const TimelineHit(this.index, this.sourcePosition, this.offsetInClip);
  final int index;
  final Duration sourcePosition;
  final Duration offsetInClip;
}

/// Immutable editing state. Every edit returns a new [Project] (easy undo).
class Project {
  const Project({required this.clips, this.texts = const []});

  factory Project.single(Duration sourceDuration) =>
      Project(clips: [VideoClip(sourceIn: Duration.zero, sourceOut: sourceDuration)]);

  /// Shortest clip we allow after splitting/trimming.
  static const minClip = Duration(milliseconds: 100);

  final List<VideoClip> clips;
  final List<TextOverlay> texts;

  Duration get duration =>
      clips.fold(Duration.zero, (sum, c) => sum + c.timelineLength);

  /// Timeline start time of clip [index].
  Duration clipStart(int index) => clips
      .take(index)
      .fold(Duration.zero, (sum, c) => sum + c.timelineLength);

  TimelineHit? hitTest(Duration t) {
    var acc = Duration.zero;
    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final len = c.timelineLength;
      if (t < acc + len || i == clips.length - 1) {
        final off = t - acc;
        final clamped = off < Duration.zero
            ? Duration.zero
            : (off > len ? len : off);
        final src = c.sourceIn +
            Duration(microseconds: (clamped.inMicroseconds * c.speed).round());
        return TimelineHit(i, src, clamped);
      }
      acc += len;
    }
    return null;
  }

  Project _withClips(List<VideoClip> next) =>
      Project(clips: List.unmodifiable(next), texts: texts);

  /// Splits the clip under timeline time [t]. No-op if too close to an edge.
  Project splitAt(Duration t) {
    final hit = hitTest(t);
    if (hit == null) return this;
    final c = clips[hit.index];
    if (hit.sourcePosition - c.sourceIn < minClip ||
        c.sourceOut - hit.sourcePosition < minClip) {
      return this;
    }
    final next = [...clips]
      ..replaceRange(hit.index, hit.index + 1, [
        c.copyWith(sourceOut: hit.sourcePosition),
        c.copyWith(sourceIn: hit.sourcePosition),
      ]);
    return _withClips(next);
  }

  Project deleteClip(int index) {
    if (clips.length <= 1 || index < 0 || index >= clips.length) return this;
    return _withClips([...clips]..removeAt(index));
  }

  Project setSpeed(int index, double speed) =>
      _withClips([...clips]..[index] = clips[index].copyWith(speed: speed));

  Project moveClip(int from, int to) {
    if (from == to) return this;
    final next = [...clips];
    final c = next.removeAt(from);
    next.insert(to.clamp(0, next.length), c);
    return _withClips(next);
  }

  /// Trims clip [index] to the given source range.
  Project trimClip(int index, Duration sourceIn, Duration sourceOut) {
    if (sourceOut - sourceIn < minClip) return this;
    return _withClips([...clips]
      ..[index] =
          clips[index].copyWith(sourceIn: sourceIn, sourceOut: sourceOut));
  }

  Project addText(TextOverlay t) =>
      Project(clips: clips, texts: List.unmodifiable([...texts, t]));

  Project updateText(int i, TextOverlay t) =>
      Project(clips: clips, texts: List.unmodifiable([...texts]..[i] = t));

  Project removeText(int i) =>
      Project(clips: clips, texts: List.unmodifiable([...texts]..removeAt(i)));
}
