import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/keyframes.dart';
import 'package:rizcut/features/editor/layers.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

void main() {
  const k = [
    Keyframe(at: Duration(seconds: 1), pos: Offset(0.2, 0.8)),
    Keyframe(at: Duration(seconds: 3), pos: Offset(0.6, 0.4), opacity: 0.5),
  ];

  test('sample holds outside and interpolates between keyframes', () {
    expect(sampleKeyframes(k, Duration.zero, Offset.zero, 1).pos, const Offset(0.2, 0.8));
    final mid = sampleKeyframes(k, const Duration(seconds: 2), Offset.zero, 1);
    expect(mid.pos.dx, closeTo(0.4, 1e-9));
    expect(mid.opacity, closeTo(0.75, 1e-9));
    expect(sampleKeyframes(const [], Duration.zero, const Offset(0.5, 0.5), 0.7).opacity, 0.7);
  });

  test('upsert replaces a keyframe near the same time', () {
    final next = upsertKeyframe(k,
        const Keyframe(at: Duration(milliseconds: 1030), pos: Offset(0.9, 0.9)));
    expect(next, hasLength(2));
    expect(next.first.pos, const Offset(0.9, 0.9));
  });

  test('piecewise expression evaluates like the preview', () {
    final e = piecewiseExpr([(1, 0.2), (3, 0.6)]);
    expect(e, startsWith('if(lt(t,1.0000),0.2000,'));
    expect(e, contains('0.2000+0.2000*(t-1.0000)'));
  });

  test('animations: fade alpha and slide offsets at the edges', () {
    const s = Duration(seconds: 1), e = Duration(seconds: 3);
    expect(animAt(TextAnim.fade, TextAnim.none, s, e, s).alpha, closeTo(0, 1e-9));
    expect(animAt(TextAnim.fade, TextAnim.none, s, e, const Duration(seconds: 2)).alpha, 1);
    expect(animAt(TextAnim.slideUp, TextAnim.none, s, e, s).offset.dy, closeTo(kSlideY, 1e-9));
    expect(animAt(TextAnim.none, TextAnim.slideLeft, s, e, e).offset.dx, closeTo(-kSlideX, 1e-9));
  });

  test('export: animated text loops the PNG and moves with expressions', () {
    final args = buildProjectExportArgs(
      output: 'o',
      project: const Project(clips: [
        VideoClip(mediaId: 'v', sourceIn: Duration.zero, sourceOut: Duration(seconds: 4)),
      ], layers: [
        Layer(
            id: 'g', mediaId: 'v', start: Duration.zero, sourceIn: Duration.zero,
            sourceOut: Duration(seconds: 2), chromaKey: 0x00FF00, opacity: 0.5),
      ]),
      media: const {'v': ExportMedia(path: 'v.mp4', isImage: false, hasAudio: false)},
      width: 720,
      height: 1280,
      settings: const ExportSettings(),
      overlays: const [
        OverlayImage(
            path: 't.png', start: Duration(seconds: 1), end: Duration(seconds: 3),
            centerX: 0.5, centerY: 0.8, animIn: TextAnim.fade, keyframes: k),
      ],
    );
    final g = args[args.indexOf('-filter_complex') + 1];
    expect(args, containsAllInOrder(['-loop', '1', '-framerate', '30', '-t', '2.000', '-i', 't.png']));
    expect(g, contains('fade=t=in:st=0:d=0.400:alpha=1'));
    expect(g, contains('setpts=PTS-STARTPTS+1.0000/TB'));
    expect(g, contains("x='main_w*(if(lt(t,1.0000),0.2000"));
    expect(g, contains("a='alpha(X,Y)*("));
    expect(g, contains('colorkey=0x00ff00:0.300:0.08'));
    expect(g, contains('colorchannelmixer=aa=0.5000'));
  });
}
