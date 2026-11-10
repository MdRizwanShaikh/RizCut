import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../services/ffmpeg/media_tools.dart';
import '../../services/waveform/waveform.dart';
import 'project.dart';
import 'video_source.dart';

class AudioSettings {
  const AudioSettings({required this.originalVolume, this.music});
  final double originalVolume;
  final MusicTrack? music;
}

/// Original sound volume + background music. Pops [AudioSettings] on Done.
class AudioSheet extends StatefulWidget {
  const AudioSheet({super.key, required this.initial});
  final AudioSettings initial;

  @override
  State<AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends State<AudioSheet> {
  late double _orig = widget.initial.originalVolume;
  late MusicTrack? _music = widget.initial.music;

  /// Loaded song: for its length, the start-point preview and its waveform.
  VideoPlayerController? _song;
  String? _songLoc;
  List<double>? _songPeaks;
  bool _previewing = false;
  bool _extracting = false;
  Timer? _previewStop;

  @override
  void initState() {
    super.initState();
    _loadSong();
  }

  @override
  void dispose() {
    _previewStop?.cancel();
    _song?.dispose();
    super.dispose();
  }

  Duration get _songLength => _song?.value.duration ?? Duration.zero;

  Future<void> _loadSong() async {
    final m = _music;
    if (m?.location == _songLoc) return;
    _previewStop?.cancel();
    final old = _song;
    _song = null;
    _songLoc = m?.location;
    _songPeaks = null;
    _previewing = false;
    await old?.dispose();
    if (m == null) return;
    audioPeaks(m.location, isUrl: m.isUrl).then((v) {
      if (mounted && _songLoc == m.location) setState(() => _songPeaks = v);
    });
    try {
      final c = await (m.isUrl ? VideoSource.url(m.location) : VideoSource.file(m.location))
          .createController();
      await c.initialize();
      if (!mounted || _songLoc != m.location) {
        await c.dispose();
        return;
      }
      setState(() => _song = c);
    } catch (_) {}
  }

  /// Plays 8 seconds from the chosen start point.
  Future<void> _togglePreview() async {
    final c = _song, m = _music;
    if (c == null || m == null) return;
    _previewStop?.cancel();
    if (_previewing) {
      await c.pause();
      setState(() => _previewing = false);
      return;
    }
    await c.setVolume(m.volume.clamp(0.0, 1.0));
    await c.seekTo(m.offset);
    await c.play();
    setState(() => _previewing = true);
    _previewStop = Timer(const Duration(seconds: 8), () {
      c.pause();
      if (mounted) setState(() => _previewing = false);
    });
  }

  void _setMusic(MusicTrack? m) {
    setState(() => _music = m);
    _loadSong();
  }

  MusicTrack _keepSettings(String location, bool isUrl, String name) => MusicTrack(
        location: location,
        isUrl: isUrl,
        name: name,
        volume: _music?.volume ?? 0.8,
        fadeIn: _music?.fadeIn ?? MusicTrack.kDefaultMusicFade,
        fadeOut: _music?.fadeOut ?? MusicTrack.kDefaultMusicFade,
        duck: _music?.duck ?? true,
      );

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return;
    final f = files.first;
    _setMusic(_keepSettings(f.path ?? f.uri.toString(), f.path == null, f.name));
  }

  /// Uses the sound of a video (e.g. a song from a saved reel) as music.
  Future<void> _fromVideo() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty || files.first.path == null) return;
    final f = files.first;
    setState(() => _extracting = true);
    final out = await MediaTools.extractAudio(f.path!);
    if (!mounted) return;
    setState(() => _extracting = false);
    if (out == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That video has no sound we can use.')));
      return;
    }
    final base = f.name.contains('.') ? f.name.substring(0, f.name.lastIndexOf('.')) : f.name;
    _setMusic(_keepSettings(out, false, 'Sound · $base'));
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Widget _fadeRow(String label, Duration v, ValueChanged<Duration> onChanged) => Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: Slider(
              value: v.inMilliseconds / 1000,
              max: MusicTrack.kMaxFade.inSeconds.toDouble(),
              divisions: MusicTrack.kMaxFade.inSeconds * 2,
              onChanged: (s) => onChanged(Duration(milliseconds: (s * 1000).round())),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(v == Duration.zero ? 'Off' : '${(v.inMilliseconds / 1000).toStringAsFixed(1)}s',
                textAlign: TextAlign.end, style: const TextStyle(color: RizColors.textDim)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final m = _music;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Audio', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: _orig == 0 ? 'Unmute' : 'Mute',
                  onPressed: () => setState(() => _orig = _orig == 0 ? 1 : 0),
                  icon: Icon(
                    _orig == 0 ? Icons.volume_off : Icons.volume_up,
                    color: RizColors.cyan,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Original sound'),
                Expanded(
                  child: Slider(
                    value: _orig,
                    onChanged: (v) => setState(() => _orig = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${(_orig * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: RizColors.textDim)),
                ),
              ],
            ),
            const Divider(height: 28, color: RizColors.outline),
            if (m == null)
              OutlinedButton.icon(
                key: const Key('add-music'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: RizColors.blue),
                  foregroundColor: RizColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pick,
                icon: const Icon(Icons.library_music_outlined),
                label: const Text('Add music from device'),
              ),
            if (m == null && MediaTools.supported) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('music-from-video'),
                onPressed: _extracting ? null : _fromVideo,
                icon: _extracting
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.movie_outlined),
                label: Text(_extracting ? 'Taking the sound…' : 'Use sound from a video'),
              ),
            ],
            if (m == null && kIsWeb) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('demo-music'),
                onPressed: () => _setMusic(const MusicTrack(
                  location: 'demo_music.mp4',
                  isUrl: true,
                  name: 'Demo beat',
                )),
                icon: const Icon(Icons.graphic_eq),
                label: const Text('Use demo beat'),
              ),
            ],
            if (m != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RizColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RizColors.blue.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: RizColors.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.name.isEmpty ? 'Music' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(onPressed: _pick, child: const Text('Replace')),
                    IconButton(
                      tooltip: 'Remove music',
                      onPressed: () => _setMusic(null),
                      icon: const Icon(Icons.close, color: RizColors.textDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 12),
                  const Text('Music volume'),
                  Expanded(
                    child: Slider(
                      value: m.volume,
                      onChanged: (v) =>
                          setState(() => _music = m.copyWith(volume: v)),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${(m.volume * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: RizColors.textDim)),
                  ),
                ],
              ),
              // Start point in the song.
              Row(
                children: [
                  IconButton(
                    key: const Key('music-preview'),
                    tooltip: _previewing ? 'Stop' : 'Listen from here',
                    onPressed: _song == null ? null : _togglePreview,
                    icon: Icon(_previewing ? Icons.stop_circle : Icons.play_circle,
                        color: RizColors.cyan, size: 30),
                  ),
                  const Text('Start at'),
                  Expanded(
                    child: Slider(
                      key: const Key('music-offset'),
                      value: _songLength > const Duration(seconds: 1)
                          ? m.offset.inMilliseconds
                              .clamp(0, _songLength.inMilliseconds - 1000)
                              .toDouble()
                          : 0,
                      max: _songLength > const Duration(seconds: 1)
                          ? (_songLength.inMilliseconds - 1000).toDouble()
                          : 1,
                      onChanged: _songLength > const Duration(seconds: 1)
                          ? (v) => setState(() => _music =
                              m.copyWith(offset: Duration(milliseconds: v.round())))
                          : null,
                      onChangeEnd: (_) {
                        if (_previewing) {
                          _previewing = false;
                          _togglePreview();
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text(
                      _songLength == Duration.zero
                          ? _fmt(m.offset)
                          : '${_fmt(m.offset)} / ${_fmt(_songLength)}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: RizColors.textDim, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_songPeaks != null && _songLength > Duration.zero)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: SizedBox(
                    height: 34,
                    child: CustomPaint(
                      painter: _SongWavePainter(
                        _songPeaks!,
                        m.offset.inMicroseconds / _songLength.inMicroseconds,
                      ),
                    ),
                  ),
                ),
              _fadeRow('Fade in', m.fadeIn,
                  (v) => setState(() => _music = m.copyWith(fadeIn: v))),
              _fadeRow('Fade out', m.fadeOut,
                  (v) => setState(() => _music = m.copyWith(fadeOut: v))),
              SwitchListTile(
                key: const Key('music-duck'),
                contentPadding: const EdgeInsets.only(left: 12),
                title: const Text('Lower music under voiceover'),
                value: m.duck,
                activeThumbColor: RizColors.magenta,
                onChanged: (v) => setState(() => _music = m.copyWith(duck: v)),
              ),
              const Text(
                'Music loops to fit the video length.',
                style: TextStyle(color: RizColors.textDim, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: GradientButton(
                key: const Key('audio-done'),
                onPressed: () => Navigator.of(context).pop(
                  AudioSettings(originalVolume: _orig, music: _music),
                ),
                icon: Icons.check,
                label: 'Done',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole song's waveform; the part before the start point is dimmed.
class _SongWavePainter extends CustomPainter {
  _SongWavePainter(this.peaks, this.start);
  final List<double> peaks;
  final double start;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;
    final bars = (size.width / 3).floor().clamp(1, 2000);
    final mid = size.height / 2;
    final on = Paint()
      ..color = RizColors.cyan
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final off = Paint()
      ..color = RizColors.textDim.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars; i++) {
      final a = (peaks.length * i / bars).floor();
      final b = (peaks.length * (i + 1) / bars).ceil().clamp(a + 1, peaks.length);
      var mx = 0.0;
      for (var j = a; j < b; j++) {
        if (peaks[j] > mx) mx = peaks[j];
      }
      final h = (mx * size.height).clamp(1.0, size.height) / 2;
      final x = i * 3 + 1.5;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), i / bars < start ? off : on);
    }
  }

  @override
  bool shouldRepaint(_SongWavePainter old) => old.peaks != peaks || old.start != start;
}
