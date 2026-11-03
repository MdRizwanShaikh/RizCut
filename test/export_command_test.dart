import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/color_grade.dart';
import 'package:rizcut/features/editor/media.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

const _media = {
  'v': ExportMedia(path: '/in.mp4', isImage: false, hasAudio: true),
  'p': ExportMedia(path: '/photo.jpg', isImage: true),
  'q': ExportMedia(path: '/silent.mp4', isImage: false),
};

String graphOf(List<String> args) => args[args.indexOf('-filter_complex') + 1];

void main() {
  const clips = [
    VideoClip(mediaId: 'v', sourceIn: Duration(seconds: 1), sourceOut: Duration(seconds: 3)),
    VideoClip(
        mediaId: 'v',
        sourceIn: Duration(seconds: 5),
        sourceOut: Duration(seconds: 7),
        speed: 2),
  ];

  List<String> build(Project p,
          {List<OverlayImage> overlays = const [],
          MusicInput? music,
          VideoEncoder encoder = VideoEncoder.hardware}) =>
      buildProjectExportArgs(
        output: '/out.mp4',
        project: p,
        media: _media,
        width: 720,
        height: 1280,
        settings: const ExportSettings(),
        overlays: overlays,
        music: music,
        encoder: encoder,
      );

  test('each clip is its own seeked input; speed, concat and overlay', () {
    final args = build(const Project(clips: clips), overlays: const [
      OverlayImage(
        path: '/t.png',
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        centerX: 0.5,
        centerY: 0.8,
      ),
    ]);
    expect(args, containsAllInOrder(['-ss', '1.000', '-t', '2.000', '-i', '/in.mp4']));
    expect(args, containsAllInOrder(['-ss', '5.000', '-t', '2.000', '-i', '/in.mp4', '-i', '/t.png']));
    final g = graphOf(args);
    expect(g, contains('[1:v]setpts=(PTS-STARTPTS)/2,fps=30'));
    expect(g, contains('[1:a]asetpts=PTS-STARTPTS,atempo=2'));
    expect(g, contains('[v0][a0][v1][a1]concat=n=2:v=1:a=1[vc][ac]'));
    expect(g, contains("[vc][2:v]overlay=x=main_w*0.5-overlay_w/2:y=main_h*0.8-overlay_h/2:enable='between(t,1.000,2.000)'[o0]"));
    expect(args, containsAllInOrder(['-map', '[o0]', '-map', '[ac]']));
    expect(args[args.indexOf('-c:v') + 1], 'h264_mediacodec');
    expect(args.last, '/out.mp4');
  });

  test('photos loop, silent clips get generated silence', () {
    final args = build(const Project(clips: [
      VideoClip(mediaId: 'p', sourceIn: Duration.zero, sourceOut: Duration(seconds: 3)),
      VideoClip(mediaId: 'q', sourceIn: Duration.zero, sourceOut: Duration(seconds: 2)),
    ]), encoder: VideoEncoder.software);
    expect(args, containsAllInOrder(['-loop', '1', '-framerate', '30', '-t', '3.000', '-i', '/photo.jpg']));
    final g = graphOf(args);
    expect('anullsrc'.allMatches(g).length, 2);
    // No real audio anywhere → concat audio is dropped.
    expect(g, endsWith('[ac]anullsink'));
    expect(args, isNot(contains('-c:a')));
    expect(args[args.indexOf('-c:v') + 1], 'mpeg4');
  });

  test('blur background vs solid colour pad', () {
    final blur = graphOf(build(const Project(clips: clips)));
    expect(blur, contains('boxblur=20:2'));
    expect(blur, contains('overlay=(W-w)/2:(H-h)/2'));
    final solid = graphOf(build(const Project(clips: clips, background: BackgroundMode.violet)));
    expect(solid, contains('pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=0x2a0f5c'));
    expect(solid, isNot(contains('boxblur')));
  });

  test('grade, transitions and music are in the graph', () {
    final args = build(
      const Project(
        clips: [
          VideoClip(
            mediaId: 'v',
            sourceIn: Duration.zero,
            sourceOut: Duration(seconds: 2),
            transitionOut: TransitionType.fadeWhite,
          ),
          VideoClip(mediaId: 'v', sourceIn: Duration(seconds: 2), sourceOut: Duration(seconds: 4)),
        ],
        grade: ColorGrade(preset: FilterPreset.warm),
        originalVolume: 0.5,
      ),
      music: const MusicInput(path: 'm.mp3', volume: 0.6),
    );
    final g = graphOf(args);
    expect(g, contains('colorchannelmixer=rr=1.0800'));
    expect(g, contains("lutrgb=r='clip(val+0.0150*maxval,minval,maxval)'"));
    expect(g, contains('fade=t=out:st=1.700:d=0.300:color=white'));
    expect(g, contains('fade=t=in:st=0:d=0.300:color=white'));
    expect(g, contains('[ac]volume=0.5[ao]'));
    expect(g, contains('[2:a]aresample=44100'));
    expect(g, contains('[ao][m]amix=inputs=2:duration=first:normalize=0[am]'));
    expect(args, containsAllInOrder(['-stream_loop', '-1', '-i', 'm.mp3']));
    expect(args, containsAllInOrder(['-map', '[am]']));
    expect(args, containsAllInOrder(['-t', '4.000']));
  });

  test('muted original with no music has no audio map', () {
    final args = build(const Project(clips: clips, originalVolume: 0));
    expect(args, isNot(contains('-c:a')));
  });

  test('atempo chains outside 0.5–2', () {
    expect(atempoChain(1), 'atempo=1');
    expect(atempoChain(4), 'atempo=2,atempo=2');
    expect(atempoChain(0.25), 'atempo=0.5,atempo=0.5');
    expect(atempoChain(1.5), 'atempo=1.5');
  });

  test('sizes: original keeps aspect, ratios are exact and even', () {
    expect(outputSize(1920, 1080, 720), (width: 1280, height: 720));
    expect(outputSize(1080, 1920, 720), (width: 720, height: 1280));
    expect(outputSize(640, 360, 1080), (width: 640, height: 360));
    expect(displaySize(1920, 1080, -90), (width: 1080, height: 1920));
    expect(canvasSize(CanvasRatio.square, 1920, 1080, 720), (width: 720, height: 720));
    expect(canvasSize(CanvasRatio.portrait, 1920, 1080, 720), (width: 720, height: 1280));
    expect(canvasSize(CanvasRatio.landscape, 1080, 1920, 480), (width: 854, height: 480));
    expect(canvasSize(CanvasRatio.feed, 1080, 1920, 1080), (width: 1080, height: 1350));
  });

  test('strong grades are split to keep mixer coefficients in -2..2', () {
    final g = gradeFilter(const ColorGrade(
        preset: FilterPreset.neon, saturation: 2, contrast: 1.5));
    final coeffs = RegExp(r'(?:rr|rg|rb|gr|gg|gb|br|bg|bb)=(-?[0-9.]+)')
        .allMatches(g)
        .map((m) => double.parse(m.group(1)!));
    expect(coeffs.every((c) => c.abs() <= 2), isTrue);
    expect('colorchannelmixer'.allMatches(g).length, greaterThan(1));
  });
}
