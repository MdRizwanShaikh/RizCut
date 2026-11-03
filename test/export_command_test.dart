import 'package:flutter_test/flutter_test.dart';
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
      clips: clips,
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
      clips: clips,
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
}
