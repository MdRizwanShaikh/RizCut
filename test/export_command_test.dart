import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/color_grade.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

void main() {
  const clips = [
    VideoClip(sourceIn: Duration(seconds: 1), sourceOut: Duration(seconds: 3)),
    VideoClip(
        sourceIn: Duration(seconds: 5),
        sourceOut: Duration(seconds: 7),
        speed: 2),
  ];

  test('multi-clip graph with speed, audio and text overlay', () {
    final args = buildProjectExportArgs(
      input: '/in.mp4',
      output: '/out.mp4',
      project: const Project(clips: clips),
      width: 720,
      height: 1280,
      hasAudio: true,
      settings: const ExportSettings(),
      overlays: const [
        OverlayImage(
          path: '/t.png',
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          centerX: 0.5,
          centerY: 0.8,
        ),
      ],
    );
    final graph = args[args.indexOf('-filter_complex') + 1];
    expect(graph, contains('[0:v]trim=start=1.000:end=3.000,setpts=(PTS-STARTPTS)/1,'));
    expect(graph, contains('setpts=(PTS-STARTPTS)/2,scale=720:1280'));
    expect(graph, contains('atempo=2'));
    expect(graph, contains('[v0][a0][v1][a1]concat=n=2:v=1:a=1[vc][ac]'));
    expect(graph,
        contains("[vc][1:v]overlay=x=main_w*0.5-overlay_w/2:y=main_h*0.8-overlay_h/2:enable='between(t,1.000,2.000)'[o0]"));
    expect(args, containsAllInOrder(['-i', '/in.mp4', '-i', '/t.png']));
    expect(args, containsAllInOrder(['-map', '[o0]', '-map', '[ac]']));
    expect(args[args.indexOf('-c:v') + 1], 'h264_mediacodec');
    expect(args.last, '/out.mp4');
  });

  test('no audio stream → video-only concat', () {
    final args = buildProjectExportArgs(
      input: 'a',
      output: 'b',
      project: const Project(clips: clips),
      width: 640,
      height: 360,
      hasAudio: false,
      settings: const ExportSettings(),
      encoder: VideoEncoder.software,
    );
    final graph = args[args.indexOf('-filter_complex') + 1];
    expect(graph, isNot(contains('[0:a]')));
    expect(graph, endsWith('concat=n=2:v=1:a=0[vc]'));
    expect(args, isNot(contains('-c:a')));
    expect(args[args.indexOf('-c:v') + 1], 'mpeg4');
  });

  test('atempo chains outside 0.5–2', () {
    expect(atempoChain(1), 'atempo=1');
    expect(atempoChain(4), 'atempo=2,atempo=2');
    expect(atempoChain(0.25), 'atempo=0.5,atempo=0.5');
    expect(atempoChain(1.5), 'atempo=1.5');
  });

  test('output size keeps aspect, even, never upscales', () {
    expect(outputSize(1920, 1080, 720), (width: 1280, height: 720));
    expect(outputSize(1080, 1920, 720), (width: 720, height: 1280));
    expect(outputSize(640, 360, 1080), (width: 640, height: 360));
    expect(displaySize(1920, 1080, -90), (width: 1080, height: 1920));
  });

  test('grade, transitions and music are in the graph', () {
    final project = const Project(
      clips: [
        VideoClip(
          sourceIn: Duration.zero,
          sourceOut: Duration(seconds: 2),
          transitionOut: TransitionType.fadeWhite,
        ),
        VideoClip(sourceIn: Duration(seconds: 2), sourceOut: Duration(seconds: 4)),
      ],
      grade: ColorGrade(preset: FilterPreset.warm),
      originalVolume: 0.5,
    );
    final args = buildProjectExportArgs(
      input: 'in.mp4',
      output: 'out.mp4',
      project: project,
      width: 640,
      height: 360,
      hasAudio: true,
      settings: const ExportSettings(),
      music: const MusicInput(path: 'm.mp3', volume: 0.6),
    );
    final graph = args[args.indexOf('-filter_complex') + 1];
    expect(graph, contains('colorchannelmixer=rr=1.0800'));
    expect(graph, contains("lutrgb=r='clip(val+0.0150*maxval,minval,maxval)'"));
    expect(graph, contains('fade=t=out:st=1.700:d=0.300:color=white'));
    expect(graph, contains('fade=t=in:st=0:d=0.300:color=white'));
    expect(graph, contains('[ac]volume=0.5[ao]'));
    expect(graph, contains('[1:a]aresample=44100,atrim=0:4.000'));
    expect(graph, contains('[ao][m]amix=inputs=2:duration=first:normalize=0[am]'));
    expect(args, containsAllInOrder(['-stream_loop', '-1', '-i', 'm.mp3']));
    expect(args, containsAllInOrder(['-map', '[am]']));
    expect(args, containsAllInOrder(['-t', '4.000']));
  });

  test('muted original with no music has no audio map', () {
    final args = buildProjectExportArgs(
      input: 'a',
      output: 'b',
      project: const Project(clips: clips, originalVolume: 0),
      width: 640,
      height: 360,
      hasAudio: true,
      settings: const ExportSettings(),
    );
    expect(args, isNot(contains('-c:a')));
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

