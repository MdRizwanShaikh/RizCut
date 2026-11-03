import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'project.dart';

/// Horizontal timeline with a fixed centre playhead. Dragging scrubs.
class Timeline extends StatefulWidget {
  const Timeline({
    super.key,
    required this.project,
    required this.position,
    required this.activeClip,
    required this.selectedText,
    required this.playing,
    required this.onScrub,
    required this.onTapText,
  });

  final Project project;
  final Duration position;
  final int activeClip;
  final int? selectedText;
  final bool playing;
  final ValueChanged<Duration> onScrub;
  final ValueChanged<int> onTapText;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  static const double pxPerSecond = 64;
  final _scroll = ScrollController();
  bool _userDragging = false;

  double _px(Duration d) => d.inMicroseconds / 1e6 * pxPerSecond;

  @override
  void didUpdateWidget(Timeline old) {
    super.didUpdateWidget(old);
    if (!_userDragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && !_userDragging) {
          final target = _px(widget.position)
              .clamp(0.0, _scroll.position.maxScrollExtent);
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
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
    } else if (n is ScrollUpdateNotification && _userDragging) {
      widget.onScrub(Duration(
          microseconds: (_scroll.offset / pxPerSecond * 1e6).round()));
    } else if (n is ScrollEndNotification) {
      _userDragging = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return SizedBox(
      height: 132,
      child: LayoutBuilder(builder: (context, box) {
        final half = box.maxWidth / 2;
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
                    _Ruler(duration: p.duration, pxPerSecond: pxPerSecond),
                    const SizedBox(height: 6),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < p.clips.length; i++)
                              _ClipTile(
                                clip: p.clips[i],
                                width: _px(p.clips[i].timelineLength),
                                color: RizColors.clipColors[
                                    i % RizColors.clipColors.length],
                                active: i == widget.activeClip,
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
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: _px(p.duration),
                      height: 26,
                      child: Stack(
                        children: [
                          for (var i = 0; i < p.texts.length; i++)
                            Positioned(
                              left: _px(p.texts[i].start),
                              width: _px(p.texts[i].end - p.texts[i].start)
                                  .clamp(24.0, double.infinity),
                              top: 0,
                              bottom: 0,
                              child: _TextBar(
                                text: p.texts[i].text,
                                selected: i == widget.selectedText,
                                onTap: () => widget.onTapText(i),
                              ),
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

class _Ruler extends StatelessWidget {
  const _Ruler({required this.duration, required this.pxPerSecond});
  final Duration duration;
  final double pxPerSecond;

  @override
  Widget build(BuildContext context) {
    final secs = (duration.inMilliseconds / 1000).ceil();
    return SizedBox(
      height: 14,
      width: duration.inMicroseconds / 1e6 * pxPerSecond,
      child: Stack(
        children: [
          for (var s = 0; s <= secs; s += 1)
            Positioned(
              left: s * pxPerSecond,
              child: Text(
                s % 2 == 0 ? '${s}s' : '·',
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
    required this.clip,
    required this.width,
    required this.color,
    required this.active,
  });

  final VideoClip clip;
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
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: active ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRect(
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
    );
  }
}

class _TextBar extends StatelessWidget {
  const _TextBar({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: RizColors.pink.withValues(alpha: selected ? 0.9 : 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: RizColors.pink),
        ),
        child: Row(
          children: [
            const Icon(Icons.text_fields, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
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
