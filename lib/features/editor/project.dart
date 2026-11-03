import 'dart:ui' show Color, Offset;

import 'color_grade.dart';

/// Allowed playback speeds for a clip.
const kSpeeds = <double>[0.25, 0.5, 1, 1.5, 2, 4];

/// Transition played at the boundary *after* a clip.
enum TransitionType {
  none('None'),
  fadeBlack('Fade black'),
  fadeWhite('Flash white');

  const TransitionType(this.label);
  final String label;
}

/// Each side of a transition lasts this long (total = 2x).
const kTransitionHalf = Duration(milliseconds: 300);

/// A segment of the source video placed on the timeline.
class VideoClip {
  const VideoClip({
    required this.sourceIn,
    required this.sourceOut,
    this.speed = 1,
    this.transitionOut = TransitionType.none,
  }) : assert(speed > 0);

  /// Range inside the source file.
  final Duration sourceIn, sourceOut;
  final double speed;
  final TransitionType transitionOut;

  Duration get sourceLength => sourceOut - sourceIn;

  /// Length of this clip on the output timeline (after speed change).
  Duration get timelineLength =>
      Duration(microseconds: (sourceLength.inMicroseconds / speed).round());

  VideoClip copyWith({
    Duration? sourceIn,
    Duration? sourceOut,
    double? speed,
    TransitionType? transitionOut,
  }) =>
      VideoClip(
        sourceIn: sourceIn ?? this.sourceIn,
        sourceOut: sourceOut ?? this.sourceOut,
        speed: speed ?? this.speed,
        transitionOut: transitionOut ?? this.transitionOut,
      );

  Map<String, Object?> toJson() => {
        'in': sourceIn.inMicroseconds,
        'out': sourceOut.inMicroseconds,
        'speed': speed,
        'tr': transitionOut.name,
      };

  factory VideoClip.fromJson(Map<String, Object?> j) => VideoClip(
        sourceIn: Duration(microseconds: (j['in'] as num).toInt()),
        sourceOut: Duration(microseconds: (j['out'] as num).toInt()),
        speed: (j['speed'] as num?)?.toDouble() ?? 1,
        transitionOut: TransitionType.values.asNameMap()[j['tr']] ??
            TransitionType.none,
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

  Map<String, Object?> toJson() => {
        'text': text,
        'start': start.inMicroseconds,
        'end': end.inMicroseconds,
        'color': color.toARGB32(),
        'x': position.dx,
        'y': position.dy,
        'size': sizeFraction,
        'bg': background,
      };

  factory TextOverlay.fromJson(Map<String, Object?> j) => TextOverlay(
        text: j['text'] as String? ?? '',
        start: Duration(microseconds: (j['start'] as num).toInt()),
        end: Duration(microseconds: (j['end'] as num).toInt()),
        color: Color((j['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
        position: Offset(
          (j['x'] as num?)?.toDouble() ?? 0.5,
          (j['y'] as num?)?.toDouble() ?? 0.8,
        ),
        sizeFraction: (j['size'] as num?)?.toDouble() ?? 0.07,
        background: j['bg'] as bool? ?? false,
      );
}

/// Background music mixed under the video.
class MusicTrack {
  const MusicTrack({
    required this.location,
    required this.isUrl,
    this.name = '',
    this.volume = 0.8,
    this.fade = true,
  });

  final String location;
  final bool isUrl;
  final String name;
  final double volume;

  /// Fade in at the start and out at the end of the video.
  final bool fade;

  MusicTrack copyWith({double? volume, bool? fade}) => MusicTrack(
        location: location,
        isUrl: isUrl,
        name: name,
        volume: volume ?? this.volume,
        fade: fade ?? this.fade,
      );

  Map<String, Object?> toJson() => {
        'loc': location,
        'url': isUrl,
        'name': name,
        'vol': volume,
        'fade': fade,
      };

  factory MusicTrack.fromJson(Map<String, Object?> j) => MusicTrack(
        location: j['loc'] as String,
        isUrl: j['url'] as bool? ?? false,
        name: j['name'] as String? ?? '',
        volume: (j['vol'] as num?)?.toDouble() ?? 0.8,
        fade: j['fade'] as bool? ?? true,
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
  const Project({
    required this.clips,
    this.texts = const [],
    this.grade = const ColorGrade(),
    this.music,
    this.originalVolume = 1,
  });

  factory Project.single(Duration sourceDuration) => Project(
      clips: [VideoClip(sourceIn: Duration.zero, sourceOut: sourceDuration)]);

  /// Shortest clip we allow after splitting/trimming.
  static const minClip = Duration(milliseconds: 100);

  final List<VideoClip> clips;
  final List<TextOverlay> texts;
  final ColorGrade grade;
  final MusicTrack? music;

  /// Volume of the video's own sound (0 = muted).
  final double originalVolume;

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
        final clamped =
            off < Duration.zero ? Duration.zero : (off > len ? len : off);
        final src = c.sourceIn +
            Duration(microseconds: (clamped.inMicroseconds * c.speed).round());
        return TimelineHit(i, src, clamped);
      }
      acc += len;
    }
    return null;
  }

  /// Opacity (0..1) of the transition colour at timeline time [t], and which
  /// transition is active. Mirrors the FFmpeg `fade` filters used on export.
  ({double amount, TransitionType type}) transitionAt(Duration t) {
    final half = kTransitionHalf.inMicroseconds;
    var acc = 0;
    for (var i = 0; i < clips.length - 1; i++) {
      acc += clips[i].timelineLength.inMicroseconds;
      final type = clips[i].transitionOut;
      if (type == TransitionType.none) continue;
      final d = (t.inMicroseconds - acc).abs();
      if (d < half) return (amount: 1 - d / half, type: type);
    }
    return (amount: 0, type: TransitionType.none);
  }

  Project copyWith({
    List<VideoClip>? clips,
    List<TextOverlay>? texts,
    ColorGrade? grade,
    MusicTrack? music,
    bool clearMusic = false,
    double? originalVolume,
  }) =>
      Project(
        clips: clips == null ? this.clips : List.unmodifiable(clips),
        texts: texts == null ? this.texts : List.unmodifiable(texts),
        grade: grade ?? this.grade,
        music: clearMusic ? null : (music ?? this.music),
        originalVolume: originalVolume ?? this.originalVolume,
      );

  /// Splits the clip under timeline time [t]. No-op if too close to an edge.
  Project splitAt(Duration t) {
    final hit = hitTest(t);
    if (hit == null) return this;
    final c = clips[hit.index];
    if (hit.sourcePosition - c.sourceIn < minClip ||
        c.sourceOut - hit.sourcePosition < minClip) {
      return this;
    }
    return copyWith(
      clips: [...clips]..replaceRange(hit.index, hit.index + 1, [
          c.copyWith(
              sourceOut: hit.sourcePosition,
              transitionOut: TransitionType.none),
          c.copyWith(sourceIn: hit.sourcePosition),
        ]),
    );
  }

  Project deleteClip(int index) {
    if (clips.length <= 1 || index < 0 || index >= clips.length) return this;
    return copyWith(clips: [...clips]..removeAt(index));
  }

  Project setSpeed(int index, double speed) =>
      copyWith(clips: [...clips]..[index] = clips[index].copyWith(speed: speed));

  Project setTransition(int index, TransitionType type) => copyWith(
      clips: [...clips]..[index] = clips[index].copyWith(transitionOut: type));

  Project moveClip(int from, int to) {
    if (from == to) return this;
    final next = [...clips];
    final c = next.removeAt(from);
    next.insert(to.clamp(0, next.length), c);
    return copyWith(clips: next);
  }

  /// Trims clip [index] to the given source range.
  Project trimClip(int index, Duration sourceIn, Duration sourceOut) {
    if (sourceOut - sourceIn < minClip) return this;
    return copyWith(
        clips: [...clips]
          ..[index] =
              clips[index].copyWith(sourceIn: sourceIn, sourceOut: sourceOut));
  }

  Project addText(TextOverlay t) => copyWith(texts: [...texts, t]);

  Project updateText(int i, TextOverlay t) =>
      copyWith(texts: [...texts]..[i] = t);

  Project removeText(int i) => copyWith(texts: [...texts]..removeAt(i));

  Map<String, Object?> toJson() => {
        'v': 1,
        'clips': [for (final c in clips) c.toJson()],
        'texts': [for (final t in texts) t.toJson()],
        'grade': grade.toJson(),
        if (music != null) 'music': music!.toJson(),
        'origVol': originalVolume,
      };

  factory Project.fromJson(Map<String, Object?> j) => Project(
        clips: List.unmodifiable([
          for (final c in j['clips'] as List)
            VideoClip.fromJson((c as Map).cast()),
        ]),
        texts: List.unmodifiable([
          for (final t in (j['texts'] as List?) ?? const [])
            TextOverlay.fromJson((t as Map).cast()),
        ]),
        grade: j['grade'] == null
            ? const ColorGrade()
            : ColorGrade.fromJson((j['grade'] as Map).cast()),
        music: j['music'] == null
            ? null
            : MusicTrack.fromJson((j['music'] as Map).cast()),
        originalVolume: (j['origVol'] as num?)?.toDouble() ?? 1,
      );
}
