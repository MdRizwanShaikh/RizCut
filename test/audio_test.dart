import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/audio_track.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

void main() {
  const clip = VideoClip(
      mediaId: 'v', sourceIn: Duration.zero, sourceOut: Duration(seconds: 4), volume: 0.3);
  const fx = AudioClip(
      id: 'a1', location: 'assets/sfx/ding.wav', isAsset: true, kind: AudioKind.sfx,
      start: Duration(seconds: 1), sourceIn: Duration.zero,
      sourceOut: Duration(milliseconds: 1200), name: 'Ding');

  test('audio clips and clip volume survive json', () {
    const p = Project(clips: [clip], audio: [fx]);
    final back = Project.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.clips.single.volume, 0.3);
    expect(back.audio.single.isAsset, isTrue);
  });

  test('export delays effects to their start and applies clip volume', () {
    final args = buildProjectExportArgs(
      output: 'o',
      project: const Project(clips: [clip], audio: [fx]),
      media: const {'v': ExportMedia(path: 'v.mp4', isImage: false, hasAudio: true)},
      width: 720,
      height: 1280,
      settings: const ExportSettings(),
      audioPaths: const {'a1': '/tmp/ding.wav'},
    );
    final g = args[args.indexOf('-filter_complex') + 1];
    expect(g, contains('atempo=1,volume=0.3'));
    expect(g, contains('[1:a]asetpts=PTS-STARTPTS'));
    expect(g, contains('adelay=1000:all=1[au0]'));
    expect(g, contains('[ac][au0]amix=inputs=2'));
    expect(args, containsAllInOrder(['-ss', '0.000', '-t', '1.200', '-i', '/tmp/ding.wav']));
  });

  test('every built-in effect has an asset path', () {
    expect(kSoundEffects.map((e) => e.asset), everyElement(startsWith('assets/sfx/')));
  });
}
