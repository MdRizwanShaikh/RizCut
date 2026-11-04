import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/layers.dart';
import 'package:rizcut/features/editor/media.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/features/editor/shorts.dart';
import 'package:rizcut/features/editor/video_source.dart';

const _long = MediaItem(
    id: 'v', source: VideoSource.file('/v.mp4'), kind: MediaKind.video,
    duration: Duration(minutes: 5));

void main() {
  test('highlights: evenly spread parts that add up to the length', () {
    final p = buildShort(_long, const ShortOptions(title: 'Hi'));
    expect(p.clips, hasLength(5));
    expect(p.duration, const Duration(seconds: 30));
    expect(p.clips.first.sourceIn, Duration.zero);
    expect(p.clips.last.sourceOut, const Duration(minutes: 5));
    expect(p.canvas, CanvasRatio.portrait);
    expect(p.texts.single.isBand, isTrue);
  });

  test('short video or from-start gives one clip', () {
    const short = MediaItem(
        id: 's', source: VideoSource.file('/s.mp4'), kind: MediaKind.video,
        duration: Duration(seconds: 10));
    expect(buildShort(short, const ShortOptions()).duration, const Duration(seconds: 10));
    final p = buildShort(_long,
        const ShortOptions(style: ShortStyle.fromStart, length: Duration(seconds: 15)));
    expect(p.clips.single.sourceOut, const Duration(seconds: 15));
    expect(p.texts, isEmpty);
  });

  test('layouts fill slots and match the shortest video', () {
    const b = MediaItem(
        id: 'b', source: VideoSource.file('/b.mp4'), kind: MediaKind.video,
        duration: Duration(seconds: 12));
    const c = MediaItem(id: 'c', source: VideoSource.file('/c.jpg'), kind: MediaKind.image);
    final p = Project.fromLayout(LayoutTemplate.stack3, [_long, b, c]);
    expect(p.duration, const Duration(seconds: 12));
    expect(p.layers, hasLength(2));
    expect(p.layers.every((l) => l.length == const Duration(seconds: 12)), isTrue);
    expect(p.mainFrame, LayoutTemplate.stack3.slots.first);
    expect(p.mainCover, isTrue);
    final cap = Project.fromLayout(LayoutTemplate.stack2Caption, [_long, b]);
    expect(cap.texts.single.isBand, isTrue);
    final back = Project.fromJson(cap.toJson());
    expect(back.toJson(), cap.toJson());
  });

  test('frame pixels are even and inside the canvas', () {
    final px = const FrameRect(1 / 3, 1 / 3, 1 / 3, 1 / 3).pixels(720, 1280);
    expect(px.w.isEven && px.h.isEven && px.x.isEven && px.y.isEven, isTrue);
    expect(px.x + px.w <= 720 && px.y + px.h <= 1280, isTrue);
  });
}
