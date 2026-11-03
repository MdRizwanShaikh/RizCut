import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/color_grade.dart';
import 'package:rizcut/features/editor/media.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/features/editor/video_source.dart';

void main() {
  final p = Project.single(const Duration(seconds: 10));

  test('split creates two clips covering the same source', () {
    final s = p.splitAt(const Duration(seconds: 4));
    expect(s.clips, hasLength(2));
    expect(s.clips[0].sourceOut, const Duration(seconds: 4));
    expect(s.clips[1].sourceIn, const Duration(seconds: 4));
    expect(s.duration, const Duration(seconds: 10));
  });

  test('split at edge is a no-op', () {
    expect(identical(p.splitAt(Duration.zero), p), isTrue);
  });

  test('speed changes timeline length and hit test maps back to source', () {
    final s = p.splitAt(const Duration(seconds: 4)).setSpeed(1, 2);
    expect(s.duration, const Duration(seconds: 7));
    final hit = s.hitTest(const Duration(seconds: 5))!;
    expect(hit.index, 1);
    expect(hit.sourcePosition, const Duration(seconds: 6));
  });

  test('delete keeps at least one clip', () {
    final s = p.splitAt(const Duration(seconds: 4));
    expect(s.deleteClip(0).clips.single.sourceIn, const Duration(seconds: 4));
    expect(identical(p.deleteClip(0), p), isTrue);
  });

  test('texts add/update/remove', () {
    const t = TextOverlay(text: 'hi', start: Duration.zero, end: Duration(seconds: 2));
    final s = p.addText(t).updateText(0, t.copyWith(text: 'yo'));
    expect(s.texts.single.text, 'yo');
    expect(s.removeText(0).texts, isEmpty);
  });

  test('transition opacity peaks at the cut', () {
    final s = p
        .splitAt(const Duration(seconds: 4))
        .setTransition(0, TransitionType.fadeBlack);
    expect(s.transitionAt(const Duration(seconds: 4)).amount, closeTo(1, 1e-6));
    expect(s.transitionAt(const Duration(seconds: 2)).amount, 0);
    expect(s.transitionAt(const Duration(milliseconds: 4150)).amount,
        closeTo(0.5, 1e-6));
  });

  test('json round trip keeps everything', () {
    final s = p
        .splitAt(const Duration(seconds: 4))
        .setSpeed(1, 2)
        .setTransition(0, TransitionType.fadeWhite)
        .addText(const TextOverlay(
            text: 'hey', start: Duration.zero, end: Duration(seconds: 1)))
        .copyWith(
          grade: const ColorGrade(preset: FilterPreset.neon, brightness: 0.1),
          music: const MusicTrack(location: '/m.mp3', isUrl: false, volume: 0.4),
          originalVolume: 0.3,
        );
    final back = Project.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.toJson(), s.toJson());
    expect(back.duration, s.duration);
  });

  test('trim clamps to a minimum clip length', () {
    final s = p.trimClip(0, const Duration(seconds: 2), const Duration(seconds: 6));
    expect(s.duration, const Duration(seconds: 4));
    expect(identical(p.trimClip(0, Duration.zero, const Duration(milliseconds: 50)), p),
        isTrue);
  });

  test('stickers survive json', () {
    const t = TextOverlay(
        text: '', sticker: 3, start: Duration.zero, end: Duration(seconds: 1));
    final back = Project.fromJson(
        jsonDecode(jsonEncode(p.addText(t).toJson())) as Map<String, Object?>);
    expect(back.texts.single.isSticker, isTrue);
    expect(back.texts.single.sticker, 3);
  });

  test('addMedia appends clips; v1 drafts migrate to media m0', () {
    final photo = MediaItem(
        id: 'ph', source: const VideoSource.url('a.jpg'), kind: MediaKind.image);
    final s = p.addMedia([photo]);
    expect(s.clips.last.mediaId, 'ph');
    expect(s.clips.last.timelineLength, kDefaultPhotoLength);
    final legacy = Project.fromJson(
      {'clips': [{'in': 0, 'out': 1000000}]},
      fallback: const MediaItem(
          id: 'm0', source: VideoSource.file('/v.mp4'), kind: MediaKind.video),
    );
    expect(legacy.mediaFor(legacy.clips.single)?.source.location, '/v.mp4');
  });

  test('canvas aspect follows the ratio or the first sized media', () {
    const m = MediaItem(
        id: 'm0', source: VideoSource.file('/v.mp4'), kind: MediaKind.video,
        width: 1920, height: 1080);
    final s = Project.fromMedia(m);
    expect(s.canvasAspect(), closeTo(16 / 9, 1e-9));
    expect(s.copyWith(canvas: CanvasRatio.portrait).canvasAspect(), closeTo(9 / 16, 1e-9));
  });

  test('media kind from file name', () {
    expect(mediaKindFor('IMG_1.JPG'), MediaKind.image);
    expect(mediaKindFor('clip.mp4'), MediaKind.video);
  });
}

