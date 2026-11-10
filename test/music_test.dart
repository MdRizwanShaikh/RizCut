import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/audio_track.dart';
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
      end: Duration(seconds: 60),
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

  test('song position: only the selected part, repeated', () {
    const len = Duration(seconds: 30);
    const part = MusicTrack(
        location: 'x', isUrl: false, offset: Duration(seconds: 10), end: Duration(seconds: 15));
    expect(part.positionAt(Duration.zero, len), const Duration(seconds: 10));
    expect(part.positionAt(const Duration(seconds: 4), len), const Duration(seconds: 14));
    expect(part.positionAt(const Duration(seconds: 5), len), const Duration(seconds: 10));
    expect(part.positionAt(const Duration(seconds: 12), len), const Duration(seconds: 12));
    // No end: from the start point to the end of the song, then again.
    const tail = MusicTrack(location: 'x', isUrl: false, offset: Duration(seconds: 20));
    expect(tail.positionAt(const Duration(seconds: 9), len), const Duration(seconds: 29));
    expect(tail.positionAt(const Duration(seconds: 10), len), const Duration(seconds: 20));
    const plain = MusicTrack(location: 'x', isUrl: false);
    expect(plain.positionAt(const Duration(seconds: 65), len), const Duration(seconds: 5));
    // Too short a part is widened to a second; an end past the song is cut.
    const tiny = MusicTrack(
        location: 'x', isUrl: false, offset: Duration(seconds: 3), end: Duration(seconds: 3));
    expect(tiny.loopEnd(len), const Duration(seconds: 4));
    const past = MusicTrack(location: 'x', isUrl: false, end: Duration(seconds: 99));
    expect(past.loopEnd(len), len);
  });

  test('selected part survives json; no end stays null', () {
    const m = MusicTrack(
        location: 'x', isUrl: false, offset: Duration(seconds: 2), end: Duration(seconds: 9));
    expect(MusicTrack.fromJson(m.toJson()).end, const Duration(seconds: 9));
    const n = MusicTrack(location: 'x', isUrl: false);
    expect(n.toJson().containsKey('end'), isFalse);
    expect(MusicTrack.fromJson(n.toJson()).end, isNull);
    expect(m.copyWith(clearEnd: true).end, isNull);
  });

  test('export: music file loops whole, fade lengths, no fade at 0', () {
    final args = _build(
      const Project(clips: _clips),
      const MusicInput(
        path: '/part.wav',
        fadeIn: Duration(seconds: 2),
        fadeOut: Duration.zero,
      ),
    );
    final i = args.indexOf('/part.wav');
    expect(args.sublist(i - 3, i + 1), ['-stream_loop', '-1', '-i', '/part.wav']);
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
