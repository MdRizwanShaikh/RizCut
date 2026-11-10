import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/audio_track.dart';
import 'package:rizcut/features/editor/media.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

const _media = {'v': ExportMedia(path: '/in.mp4', isImage: false, hasAudio: true)};
const _clips = [
  VideoClip(mediaId: 'v', sourceIn: Duration.zero, sourceOut: Duration(seconds: 10)),
];

List<String> _build(Project p, MusicInput music, {Map<String, String> audioPaths = const {}}) =>
    buildProjectExportArgs(
      output: '/out.mp4',
      project: p,
      media: _media,
      width: 720,
      height: 1280,
      settings: const ExportSettings(),
      music: music,
      audioPaths: audioPaths,
    );

String _graph(List<String> args) => args[args.indexOf('-filter_complex') + 1];

void main() {
  test('music settings survive json', () {
    const m = MusicTrack(
      location: '/s.mp3',
      isUrl: false,
      name: 'Song',
      volume: 0.5,
      offset: Duration(seconds: 42),
      fadeIn: Duration(seconds: 3),
      fadeOut: Duration.zero,
      duck: false,
    );
    final back = MusicTrack.fromJson(m.toJson());
    expect(back.toJson(), m.toJson());
    expect(back.offset, const Duration(seconds: 42));
    expect(back.duck, isFalse);
  });

  test('old drafts: fade flag becomes fade lengths, duck on', () {
    final on = MusicTrack.fromJson({'loc': '/a.mp3', 'url': false, 'vol': 0.8, 'fade': true});
    expect(on.fadeIn, MusicTrack.kDefaultMusicFade);
    expect(on.fadeOut, MusicTrack.kDefaultMusicFade);
    expect(on.offset, Duration.zero);
    expect(on.duck, isTrue);
    final off = MusicTrack.fromJson({'loc': '/a.mp3', 'fade': false});
    expect(off.fadeIn, Duration.zero);
    expect(off.fadeOut, Duration.zero);
  });

  test('song position: first pass from the offset, then loops from 0', () {
    const m = MusicTrack(location: 'x', isUrl: false, offset: Duration(seconds: 20));
    const len = Duration(seconds: 30);
    expect(m.positionAt(Duration.zero, len), const Duration(seconds: 20));
    expect(m.positionAt(const Duration(seconds: 9), len), const Duration(seconds: 29));
    expect(m.positionAt(const Duration(seconds: 10), len), Duration.zero);
    expect(m.positionAt(const Duration(seconds: 45), len), const Duration(seconds: 5));
    const plain = MusicTrack(location: 'x', isUrl: false);
    expect(plain.positionAt(const Duration(seconds: 65), len), const Duration(seconds: 5));
  });

  test('export: offset seeks the looping input, fade lengths, no fade at 0', () {
    final args = _build(
      const Project(clips: _clips),
      const MusicInput(
        path: '/s.mp3',
        offset: Duration(seconds: 12),
        fadeIn: Duration(seconds: 2),
        fadeOut: Duration.zero,
      ),
    );
    expect(args, containsAllInOrder(['-ss', '12.000', '-stream_loop', '-1', '-i', '/s.mp3']));
    final g = _graph(args);
    expect(g, contains('afade=t=in:st=0:d=2.000'));
    expect(g, isNot(contains('afade=t=out')));
  });

  test('export: fades are capped at a third of the video', () {
    final g = _graph(_build(
      const Project(clips: _clips),
      const MusicInput(path: '/s.mp3', fadeIn: Duration(seconds: 5), fadeOut: Duration(seconds: 5)),
    ));
    expect(g, contains('afade=t=in:st=0:d=3.333'));
    expect(g, contains('afade=t=out:st=6.667:d=3.333'));
  });

  test('export: music ducks under voiceovers only', () {
    const vo = AudioClip(
      id: 'vo', location: '/vo.m4a', kind: AudioKind.voiceover,
      start: Duration(seconds: 2), sourceIn: Duration.zero, sourceOut: Duration(seconds: 3));
    const fx = AudioClip(
      id: 'fx', location: '/fx.wav', kind: AudioKind.sfx,
      start: Duration(seconds: 6), sourceIn: Duration.zero, sourceOut: Duration(seconds: 1));
    const p = Project(clips: _clips, audio: [vo, fx]);
    final g = _graph(_build(p, const MusicInput(path: '/s.mp3', duck: true),
        audioPaths: {'vo': '/vo.m4a', 'fx': '/fx.wav'}));
    expect(g, contains("volume=0.3:enable='between(t,2.0000,5.0000)'"));
    expect(g, isNot(contains('between(t,6.0000')));
    final noDuck = _graph(_build(p, const MusicInput(path: '/s.mp3')));
    expect(noDuck, isNot(contains('volume=0.3')));
  });
}
