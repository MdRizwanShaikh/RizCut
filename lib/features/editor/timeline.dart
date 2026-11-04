import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/waveform/waveform.dart';
import 'audio_track.dart';
import 'project.dart';
import 'stickers.dart';

enum TrimEdge { start, end }

/// Horizontal timeline with a fixed centre playhead. Dragging scrubs; the
/// active clip shows trim handles on both edges.
class Timeline extends StatefulWidget {
  const Timeline({
    super.key,
    required this.project,
    required this.position,
    required this.activeClip,
    required this.selectedText,
    required this.playing,
    required this.pxPerSecond,
    required this.onScrub,
    required this.onTapText,
    required this.onTapClip,
    required this.onLongPressClip,
    required this.onTrimStart,
    required this.onTrimUpdate,
    required this.onTrimEnd,
    this.thumbFor,
    this.selectedLayer,
    this.onTapLayer,
    this.onTapAudio,
    this.peaksFor,
  });

  final Project project;
  final Duration position;
  final int activeClip;
  final int? selectedText;
  final bool playing;

  /// Zoom: horizontal pixels per second of output time.
  final double pxPerSecond;
  final ValueChanged<Duration> onScrub;
  final ValueChanged<int> onTapText;
  final ValueChanged<int> onTapClip;
  final ValueChanged<int> onLongPressClip;
  final void Function(int clip, TrimEdge edge) onTrimStart;

  /// [dxSeconds] is the total drag distance since start, in output seconds.
  final void Function(double dxSeconds) onTrimUpdate;
  final VoidCallback onTrimEnd;

  /// Filmstrip image for a clip (video frame or the photo itself).
  final ImageProvider? Function(VideoClip clip)? thumbFor;
  final int? selectedLayer;
  final ValueChanged<int>? onTapLayer;
  final ValueChanged<int>? onTapAudio;

  /// Audio peaks by key (`m:mediaId` or `a:audioId`), for waveforms.
  final List<double>? Function(String key)? peaksFor;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  final _scroll = ScrollController();
  bool _userDragging = false;
  bool _trimming = false;
  double _trimDx = 0;

  double get pps => widget.pxPerSecond;
  double _px(Duration d) => d.inMicroseconds / 1e6 * pps;

  @override
  void didUpdateWidget(Timeline old) {
    super.didUpdateWidget(old);
    if (!_userDragging && !_trimming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && !_userDragging && !_trimming) {
          final target =
              _px(widget.position).clamp(0.0, _scroll.position.maxScrollExtent);
          if ((target - _scroll.offset).abs() > 0.5) _scroll.jumpTo(target);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (_trimming) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
    } else if (n is ScrollUpdateNotification && _userDragging) {
      widget.onScrub(
          Duration(microseconds: (_scroll.offset / pps * 1e6).round()));
    } else if (n is ScrollEndNotification) {
      _userDragging = false;
    }
    return false;
  }

  Widget _handle(int clip, TrimEdge edge) {
    return GestureDetector(
      key: Key('trim-${edge.name}-$clip'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _trimming = true;
        _trimDx = 0;
        widget.onTrimStart(clip, edge);
      },
      onHorizontalDragUpdate: (d) {
        _trimDx += d.delta.dx;
        widget.onTrimUpdate(_trimDx / pps);
      },
      onHorizontalDragEnd: (_) {
        _trimming = false;
        widget.onTrimEnd();
      },
      onHorizontalDragCancel: () {
        _trimming = false;
        widget.onTrimEnd();
      },
      child: Container(
        width: 18,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(edge == TrimEdge.start ? 10 : 0),
            right: Radius.circular(edge == TrimEdge.end ? 10 : 0),
          ),
        ),
        child: Icon(
          edge == TrimEdge.start ? Icons.chevron_left : Icons.chevron_right,
          size: 18,
          color: RizColors.bg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return SizedBox(
      height: 106 + _laneHeight * _lanes(p).count.clamp(1, _maxLanes),
      child: LayoutBuilder(builder: (context, box) {
        final half = box.maxWidth / 2;
        final active = widget.activeClip.clamp(0, p.clips.length - 1);
        final activeLeft = _px(p.clipStart(active));
        final activeWidth = _px(p.clips[active].timelineLength);
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: half),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    _Ruler(duration: p.duration, pxPerSecond: pps),
                    const SizedBox(height: 6),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < p.clips.length; i++)
                              GestureDetector(
                                onTap: () => widget.onTapClip(i),
                                onLongPress: () => widget.onLongPressClip(i),
                                child: _ClipTile(
                                  peaks: widget.peaksFor?.call('m:${p.clips[i].mediaId}'),
                                  clip: p.clips[i],
                                  thumb: widget.thumbFor?.call(p.clips[i]),
                                  width: _px(p.clips[i].timelineLength),
                                  color: RizColors.clipColors[
                                      i % RizColors.clipColors.length],
                                  active: i == active,
                                ),
                              ),
                          ],
                        ),
                        for (var i = 0; i < p.clips.length - 1; i++)
                          if (p.clips[i].transitionOut != TransitionType.none)
                            Positioned(
                              left: _px(p.clipStart(i + 1)) - 12,
                              top: 14,
                              child: _TransitionBadge(
                                  type: p.clips[i].transitionOut),
                            ),
                        if (!widget.playing) ...[
                          // Handles sit inside the clip's bounds so they
                          // receive touches (Stack doesn't hit-test overflow).
                          Positioned(
                            left: activeLeft,
                            top: 0,
                            child: _handle(active, TrimEdge.start),
                          ),
                          Positioned(
                            left: (activeLeft + activeWidth - 20)
                                .clamp(activeLeft + 18, double.infinity),
                            top: 0,
                            child: _handle(active, TrimEdge.end),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: _px(p.duration),
                      height: _laneHeight * _lanes(p).count.clamp(1, _maxLanes),
                      child: Stack(
                        children: [
                          for (var k = 0; k < p.audio.length; k++)
                            Positioned(
                              left: _px(p.audio[k].start),
                              width: _px(p.audio[k].length)
                                  .clamp(24.0, double.infinity),
                              top: _laneHeight *
                                  _lanes(p).of[p.texts.length + p.layers.length + k]
                                      .clamp(0, _maxLanes - 1),
                              height: _laneHeight - 4,
                              child: _AudioBar(
                                peaks: widget.peaksFor?.call('a:${p.audio[k].id}'),
                                clip: p.audio[k],
                                onTap: () => widget.onTapAudio?.call(k),
                              ),
                            ),
                          for (var j = 0; j < p.layers.length; j++)
                            Positioned(
                              left: _px(p.layers[j].start),
                              width: _px(p.layers[j].length)
                                  .clamp(24.0, double.infinity),
                              top: _laneHeight *
                                  _lanes(p).of[p.texts.length + j]
                                      .clamp(0, _maxLanes - 1),
                              height: _laneHeight - 4,
                              child: _LayerBar(
                                index: j,
                                selected: j == widget.selectedLayer,
                                onTap: () => widget.onTapLayer?.call(j),
                              ),
                            ),
                          for (var i = 0; i < p.texts.length; i++)
                            Positioned(
                              left: _px(p.texts[i].start),
                              width: _px(p.texts[i].end - p.texts[i].start)
                                  .clamp(24.0, double.infinity),
                              top: _laneHeight *
                                  _lanes(p).of[i].clamp(0, _maxLanes - 1),
                              height: _laneHeight - 4,
                              child: _TextBar(
                                overlay: p.texts[i],
                                selected: i == widget.selectedText,
                                onTap: () => widget.onTapText(i),
                              ),
                            ),
                          // Keyframe diamonds on text/sticker and layer bars.
                          for (var i = 0; i < p.texts.length; i++)
                            for (final kf in p.texts[i].keyframes)
                              Positioned(
                                left: _px(kf.at) - 5,
                                top: _laneHeight * _lanes(p).of[i].clamp(0, _maxLanes - 1) + 7,
                                child: const IgnorePointer(child: _Diamond()),
                              ),
                          for (var j = 0; j < p.layers.length; j++)
                            for (final kf in p.layers[j].keyframes)
                              Positioned(
                                left: _px(kf.at) - 5,
                                top: _laneHeight *
                                        _lanes(p).of[p.texts.length + j].clamp(0, _maxLanes - 1) +
                                    7,
                                child: const IgnorePointer(child: _Diamond()),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed centre playhead.
            Positioned(
              left: half - 1,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: RizColors.cyan.withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

const double _laneHeight = 28;
const int _maxLanes = 4;

/// Puts overlapping text/sticker bars on separate rows (greedy, by start).
/// Puts overlapping text/sticker/layer bars on separate rows (greedy by
/// start). Indices: texts first, then layers.
({List<int> of, int count}) _lanes(Project p) {
  final spans = [
    for (final t in p.texts) (t.start, t.end),
    for (final l in p.layers) (l.start, l.end),
    for (final a in p.audio) (a.start, a.end),
  ];
  final order = [for (var i = 0; i < spans.length; i++) i]
    ..sort((a, b) => spans[a].$1.compareTo(spans[b].$1));
  final laneEnds = <Duration>[];
  final of = List<int>.filled(spans.length, 0);
  for (final i in order) {
    final (start, end) = spans[i];
    var lane = laneEnds.indexWhere((e) => e <= start);
    if (lane < 0) {
      laneEnds.add(end);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = end;
    }
    of[i] = lane;
  }
  return (of: of, count: laneEnds.length);
}

class _Diamond extends StatelessWidget {
  const _Diamond();

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: RizColors.bg, width: 1.5),
          ),
        ),
      );
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.clip, required this.onTap, this.peaks});
  final AudioClip clip;
  final List<double>? peaks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF3DDC97);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c),
        ),
        foregroundDecoration: null,
        child: Stack(
          children: [
            if (peaks != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _WavePainter(peaks!, clip.sourceIn, clip.sourceOut,
                      const Color(0x66FFFFFF)),
                ),
              ),
            Row(
          children: [
            Icon(clip.kind == AudioKind.voiceover ? Icons.mic : Icons.graphic_eq,
                size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text(clip.name.isEmpty ? 'Audio' : clip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerBar extends StatelessWidget {
  const _LayerBar({required this.index, required this.selected, required this.onTap});
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFFFB36B);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.withValues(alpha: selected ? 0.9 : 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers_outlined, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Layer ${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.duration, required this.pxPerSecond});
  final Duration duration;
  final double pxPerSecond;

  @override
  Widget build(BuildContext context) {
    final secs = (duration.inMilliseconds / 1000).ceil();
    // Keep labels roughly 60px apart whatever the zoom.
    final step = pxPerSecond >= 120
        ? 1
        : pxPerSecond >= 60
            ? 2
            : pxPerSecond >= 30
                ? 5
                : 10;
    final dot = pxPerSecond >= 40 ? 1 : step;
    return SizedBox(
      height: 14,
      width: duration.inMicroseconds / 1e6 * pxPerSecond,
      child: Stack(
        children: [
          for (var s = 0; s <= secs; s += dot)
            Positioned(
              left: s * pxPerSecond,
              child: Text(
                s % step == 0 ? '${s}s' : '·',
                style: const TextStyle(fontSize: 10, color: RizColors.textDim),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    this.peaks,
    required this.clip,
    this.thumb,
    required this.width,
    required this.color,
    required this.active,
  });

  final VideoClip clip;
  final List<double>? peaks;
  final ImageProvider? thumb;
  final double width;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final speed = clip.speed;
    final secs = clip.timelineLength.inMilliseconds / 1000;
    return Container(
      width: width,
      height: 52,
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color,
        image: thumb == null
            ? null
            : DecorationImage(
                image: thumb!,
                fit: BoxFit.fitHeight,
                repeat: ImageRepeat.repeatX,
                alignment: Alignment.centerLeft,
              ),
        gradient: thumb != null
            ? null
            : LinearGradient(
                colors: [color, color.withValues(alpha: 0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: thumb == null
            ? null
            : LinearGradient(
                colors: [color.withValues(alpha: 0.55), Colors.transparent],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
        border: Border.all(
          color: active ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            if (peaks != null && clip.volume > 0)
              Positioned.fill(
                top: 26,
                child: CustomPaint(
                  painter: _WavePainter(peaks!, clip.sourceIn, clip.sourceOut,
                      const Color(0x88FFFFFF)),
                ),
              ),
            Positioned.fill(
              child: Row(
          children: [
            const Icon(Icons.movie, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${secs.toStringAsFixed(1)}s',
                overflow: TextOverflow.clip,
                softWrap: false,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            if (speed != 1) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${speed}x',
                    softWrap: false,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBar extends StatelessWidget {
  const _TextBar({
    required this.overlay,
    required this.selected,
    required this.onTap,
  });

  final TextOverlay overlay;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = stickerIcon(overlay.sticker);
    final color = icon != null ? RizColors.cyan : RizColors.pink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.9 : 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(icon ?? Icons.text_fields, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                icon != null ? 'Sticker' : overlay.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransitionBadge extends StatelessWidget {
  const _TransitionBadge({required this.type});
  final TransitionType type;

  @override
  Widget build(BuildContext context) {
    final white = type == TransitionType.fadeWhite;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: white ? Colors.white : RizColors.bg,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF7DF9C2), width: 2),
      ),
      child: Icon(Icons.blur_on,
          size: 14, color: white ? RizColors.bg : const Color(0xFF7DF9C2)),
    );
  }
}

/// Draws loudness bars for [from]..[to] of a source across the box.
class _WavePainter extends CustomPainter {
  _WavePainter(this.peaks, this.from, this.to, this.color);
  final List<double> peaks;
  final Duration from, to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;
    final a = (from.inMicroseconds / 1e6 * kPeaksPerSecond).floor().clamp(0, peaks.length);
    final b = (to.inMicroseconds / 1e6 * kPeaksPerSecond).ceil().clamp(a, peaks.length);
    if (b <= a) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bars = (size.width / 3).floor().clamp(1, 2000);
    final mid = size.height / 2;
    for (var i = 0; i < bars; i++) {
      final s = a + ((b - a) * i / bars).floor();
      final e = (a + ((b - a) * (i + 1) / bars).ceil()).clamp(s + 1, b);
      var m = 0.0;
      for (var j = s; j < e; j++) {
        if (peaks[j] > m) m = peaks[j];
      }
      final h = (m * size.height).clamp(1.0, size.height) / 2;
      final x = i * 3 + 1.5;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.peaks != peaks || old.from != from || old.to != to;
}
