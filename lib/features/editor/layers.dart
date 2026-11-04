/// Layers (video/photo on top of the main track) and layout templates.
library;

import 'dart:ui' show Offset;

import 'color_grade.dart';
import 'keyframes.dart';
import 'media.dart';

/// A rectangle in canvas fractions (0..1).
class FrameRect {
  const FrameRect(this.x, this.y, this.w, this.h);
  static const full = FrameRect(0, 0, 1, 1);

  final double x, y, w, h;

  bool get isFull => x == 0 && y == 0 && w == 1 && h == 1;

  FrameRect moveTo(Offset topLeft) => FrameRect(
        topLeft.dx.clamp(0.0, 1 - w),
        topLeft.dy.clamp(0.0, 1 - h),
        w,
        h,
      );

  /// Pixel rect on a [cw] x [ch] canvas, snapped to even numbers.
  ({int x, int y, int w, int h}) pixels(int cw, int ch) {
    int even(double v) => (v / 2).round() * 2;
    final w = even(this.w * cw).clamp(2, cw);
    final h = even(this.h * ch).clamp(2, ch);
    return (
      x: even(x * cw).clamp(0, cw - w),
      y: even(y * ch).clamp(0, ch - h),
      w: w,
      h: h,
    );
  }

  List<double> toJson() => [x, y, w, h];
  factory FrameRect.fromJson(List<dynamic> j) => FrameRect(
        (j[0] as num).toDouble(),
        (j[1] as num).toDouble(),
        (j[2] as num).toDouble(),
        (j[3] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is FrameRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// A video or photo shown in its own frame over the main track.
class Layer {
  const Layer({
    required this.id,
    required this.mediaId,
    required this.start,
    required this.sourceIn,
    required this.sourceOut,
    this.frame = const FrameRect(0.58, 0.05, 0.38, 0.24),
    this.volume = 0,
    this.grade,
    this.opacity = 1,
    this.keyframes = const [],
    this.chromaKey,
    this.keySimilarity = 0.3,
  });

  final String id;
  final String mediaId;

  /// When the layer appears on the output timeline.
  final Duration start;

  /// Range of the source file (photos: 0..shown length).
  final Duration sourceIn, sourceOut;
  final FrameRect frame;

  /// Layer sound level; 0 = muted (default, so layouts don't get noisy).
  final double volume;

  /// The layer's own filter; null = use the project's filter.
  final ColorGrade? grade;

  final double opacity;

  /// Top-left position/opacity over time (absolute timeline times).
  final List<Keyframe> keyframes;

  /// Green-screen colour to remove (RGB as 0xRRGGBB), or null.
  final int? chromaKey;

  /// How close a colour must be to [chromaKey] to be removed (0.05..0.6).
  final double keySimilarity;

  Duration get length => sourceOut - sourceIn;
  Duration get end => start + length;
  bool visibleAt(Duration t) => t >= start && t < end;

  Layer copyWith({
    Duration? start,
    Duration? sourceIn,
    Duration? sourceOut,
    FrameRect? frame,
    double? volume,
    String? mediaId,
    ColorGrade? grade,
    bool sameGradeAsProject = false,
    double? opacity,
    List<Keyframe>? keyframes,
    int? chromaKey,
    bool clearChromaKey = false,
    double? keySimilarity,
  }) =>
      Layer(
        id: id,
        mediaId: mediaId ?? this.mediaId,
        start: start ?? this.start,
        sourceIn: sourceIn ?? this.sourceIn,
        sourceOut: sourceOut ?? this.sourceOut,
        frame: frame ?? this.frame,
        volume: volume ?? this.volume,
        grade: sameGradeAsProject ? null : (grade ?? this.grade),
        opacity: opacity ?? this.opacity,
        keyframes: keyframes ?? this.keyframes,
        chromaKey: clearChromaKey ? null : (chromaKey ?? this.chromaKey),
        keySimilarity: keySimilarity ?? this.keySimilarity,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'media': mediaId,
        'start': start.inMicroseconds,
        'in': sourceIn.inMicroseconds,
        'out': sourceOut.inMicroseconds,
        'frame': frame.toJson(),
        if (volume != 0) 'vol': volume,
        if (grade != null) 'grade': grade!.toJson(),
        if (opacity != 1) 'op': opacity,
        if (keyframes.isNotEmpty) 'kf': [for (final k in keyframes) k.toJson()],
        if (chromaKey != null) 'ck': chromaKey,
        if (chromaKey != null) 'cks': keySimilarity,
      };

  factory Layer.fromJson(Map<String, Object?> j) => Layer(
        id: j['id'] as String,
        mediaId: j['media'] as String,
        start: Duration(microseconds: (j['start'] as num).toInt()),
        sourceIn: Duration(microseconds: (j['in'] as num).toInt()),
        sourceOut: Duration(microseconds: (j['out'] as num).toInt()),
        frame: j['frame'] == null
            ? const FrameRect(0.58, 0.05, 0.38, 0.24)
            : FrameRect.fromJson(j['frame'] as List),
        volume: (j['vol'] as num?)?.toDouble() ?? 0,
        grade: j['grade'] == null
            ? null
            : ColorGrade.fromJson((j['grade'] as Map).cast()),
        opacity: (j['op'] as num?)?.toDouble() ?? 1,
        keyframes: [
          for (final k in (j['kf'] as List?) ?? const [])
            Keyframe.fromJson((k as Map).cast()),
        ],
        chromaKey: (j['ck'] as num?)?.toInt(),
        keySimilarity: (j['cks'] as num?)?.toDouble() ?? 0.3,
      );
}

/// Ready-made split-screen layouts. Slot 0 is the main track; the rest are
/// layers. [captionY] adds a caption band at that height.
enum LayoutTemplate {
  stack2('2 stacked', [FrameRect(0, 0, 1, 0.5), FrameRect(0, 0.5, 1, 0.5)]),
  stack2Caption('2 + caption', [
    FrameRect(0, 0, 1, 0.42),
    FrameRect(0, 0.58, 1, 0.42),
  ], captionY: 0.5),
  stack3('3 stacked', [
    FrameRect(0, 0, 1, 1 / 3),
    FrameRect(0, 1 / 3, 1, 1 / 3),
    FrameRect(0, 2 / 3, 1, 1 / 3),
  ]),
  sideBySide('Side by side', [FrameRect(0, 0, 0.5, 1), FrameRect(0.5, 0, 0.5, 1)],
      square: true),
  pip('Picture in picture', [FrameRect.full, FrameRect(0.58, 0.05, 0.38, 0.24)]);

  const LayoutTemplate(this.label, this.slots,
      {this.captionY, this.square = false});
  final String label;
  final List<FrameRect> slots;
  final double? captionY;

  /// Uses a 1:1 canvas instead of 9:16.
  final bool square;

  int get slotCount => slots.length;

  /// Main track fills its slot (cropping) instead of fitting inside it.
  bool get mainCover => !slots.first.isFull;
}

/// Shown length of a photo used in a layout when no video sets the pace.
const kLayoutPhotoLength = Duration(seconds: 5);

/// Length every slot can fill: the shortest video, else the photo default.
Duration layoutLength(List<MediaItem> items) {
  Duration? shortest;
  for (final m in items) {
    if (m.isImage || m.duration <= Duration.zero) continue;
    if (shortest == null || m.duration < shortest) shortest = m.duration;
  }
  return shortest ?? kLayoutPhotoLength;
}
