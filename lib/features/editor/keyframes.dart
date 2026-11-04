/// Keyframes (position + opacity over time) and in/out text animations.
/// The same maths drives the preview and the FFmpeg expressions.
library;

import 'dart:ui' show Offset;

/// Entrance / exit animation for text and stickers.
enum TextAnim {
  none('None'),
  fade('Fade'),
  slideUp('Slide up'),
  slideDown('Slide down'),
  slideLeft('Slide left');

  const TextAnim(this.label);
  final String label;
}

/// Length of an in/out animation.
const kAnimLength = Duration(milliseconds: 400);
const kSlideX = 0.15, kSlideY = 0.08;

/// A value at a moment on the output timeline.
class Keyframe {
  const Keyframe({required this.at, required this.pos, this.opacity = 1});

  /// Absolute time on the output timeline.
  final Duration at;

  /// Position (text: centre; layer: top-left) in canvas fractions.
  final Offset pos;
  final double opacity;

  Keyframe copyWith({Offset? pos, double? opacity}) =>
      Keyframe(at: at, pos: pos ?? this.pos, opacity: opacity ?? this.opacity);

  Map<String, Object?> toJson() =>
      {'t': at.inMicroseconds, 'x': pos.dx, 'y': pos.dy, if (opacity != 1) 'o': opacity};

  factory Keyframe.fromJson(Map<String, Object?> j) => Keyframe(
        at: Duration(microseconds: (j['t'] as num).toInt()),
        pos: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        opacity: (j['o'] as num?)?.toDouble() ?? 1,
      );
}

/// Keyframes within this distance of the playhead count as "at" it.
const kKeyframeSnap = Duration(milliseconds: 60);

List<Keyframe> sortedKeyframes(List<Keyframe> k) =>
    [...k]..sort((a, b) => a.at.compareTo(b.at));

/// Index of a keyframe at [t] (within [kKeyframeSnap]), or -1.
int keyframeAt(List<Keyframe> k, Duration t) =>
    k.indexWhere((f) => (f.at - t).abs() <= kKeyframeSnap);

/// Adds or replaces the keyframe at [t].
List<Keyframe> upsertKeyframe(List<Keyframe> k, Keyframe f) {
  final i = keyframeAt(k, f.at);
  final next = [...k];
  if (i >= 0) {
    next[i] = Keyframe(at: next[i].at, pos: f.pos, opacity: f.opacity);
  } else {
    next.add(f);
  }
  return sortedKeyframes(next);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Position and opacity at [t]: linear between keyframes, held outside.
({Offset pos, double opacity}) sampleKeyframes(
    List<Keyframe> keys, Duration t, Offset pos, double opacity) {
  if (keys.isEmpty) return (pos: pos, opacity: opacity);
  final k = sortedKeyframes(keys);
  if (t <= k.first.at) return (pos: k.first.pos, opacity: k.first.opacity);
  if (t >= k.last.at) return (pos: k.last.pos, opacity: k.last.opacity);
  for (var i = 0; i < k.length - 1; i++) {
    final a = k[i], b = k[i + 1];
    if (t >= a.at && t <= b.at) {
      final span = (b.at - a.at).inMicroseconds;
      final f = span == 0 ? 0.0 : (t - a.at).inMicroseconds / span;
      return (
        pos: Offset(_lerp(a.pos.dx, b.pos.dx, f), _lerp(a.pos.dy, b.pos.dy, f)),
        opacity: _lerp(a.opacity, b.opacity, f),
      );
    }
  }
  return (pos: k.last.pos, opacity: k.last.opacity);
}

/// In/out animation at [t]: alpha multiplier and offset (canvas fractions).
({double alpha, Offset offset}) animAt(
    TextAnim inAnim, TextAnim outAnim, Duration start, Duration end, Duration t) {
  final len = kAnimLength.inMicroseconds;
  final sinceStart = (t - start).inMicroseconds / len; // 0..1 during intro
  final toEnd = (end - t).inMicroseconds / len; // 1..0 during outro
  var alpha = 1.0, dx = 0.0, dy = 0.0;
  if (inAnim != TextAnim.none && sinceStart < 1) {
    final r = 1 - sinceStart.clamp(0.0, 1.0); // 1 → 0
    switch (inAnim) {
      case TextAnim.fade:
        alpha *= 1 - r;
      case TextAnim.slideUp:
        dy += kSlideY * r;
      case TextAnim.slideDown:
        dy -= kSlideY * r;
      case TextAnim.slideLeft:
        dx += kSlideX * r;
      case TextAnim.none:
    }
  }
  if (outAnim != TextAnim.none && toEnd < 1) {
    final r = 1 - toEnd.clamp(0.0, 1.0); // 0 → 1
    switch (outAnim) {
      case TextAnim.fade:
        alpha *= 1 - r;
      case TextAnim.slideUp:
        dy -= kSlideY * r;
      case TextAnim.slideDown:
        dy += kSlideY * r;
      case TextAnim.slideLeft:
        dx -= kSlideX * r;
      case TextAnim.none:
    }
  }
  return (alpha: alpha, offset: Offset(dx, dy));
}

String _n(double v) => v.toStringAsFixed(4);

/// FFmpeg expression for a value that changes linearly between [points]
/// (seconds, value) in variable [tv] and holds outside them.
String piecewiseExpr(List<(double, double)> points, {String tv = 't'}) {
  if (points.isEmpty) return '0';
  if (points.length == 1) return _n(points.first.$2);
  var expr = _n(points.last.$2);
  for (var i = points.length - 2; i >= 0; i--) {
    final (t0, v0) = points[i];
    final (t1, v1) = points[i + 1];
    final slope = t1 == t0 ? 0.0 : (v1 - v0) / (t1 - t0);
    expr = 'if(lt($tv,${_n(t1)}),${_n(v0)}+${_n(slope)}*($tv-${_n(t0)}),$expr)';
  }
  return 'if(lt($tv,${_n(points.first.$1)}),${_n(points.first.$2)},$expr)';
}

/// FFmpeg expression (in main-timeline `t`) for the slide offset on one
/// axis, as a fraction of the frame. [axisX] picks horizontal vs vertical.
String slideOffsetExpr(TextAnim inAnim, TextAnim outAnim, double start,
    double end, {required bool axisX}) {
  final l = kAnimLength.inMicroseconds / 1e6;
  final terms = <String>[];
  double inSign(TextAnim a) => switch (a) {
        TextAnim.slideLeft when axisX => kSlideX,
        TextAnim.slideUp when !axisX => kSlideY,
        TextAnim.slideDown when !axisX => -kSlideY,
        _ => 0,
      };
  double outSign(TextAnim a) => switch (a) {
        TextAnim.slideLeft when axisX => -kSlideX,
        TextAnim.slideUp when !axisX => -kSlideY,
        TextAnim.slideDown when !axisX => kSlideY,
        _ => 0,
      };
  final si = inSign(inAnim), so = outSign(outAnim);
  if (si != 0) terms.add('${_n(si)}*max(0,1-(t-${_n(start)})/${_n(l)})');
  if (so != 0) terms.add('${_n(so)}*max(0,(t-${_n(end - l)})/${_n(l)})');
  return terms.isEmpty ? '0' : terms.join('+');
}
