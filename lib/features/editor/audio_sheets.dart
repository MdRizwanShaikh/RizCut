import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'audio_io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import 'audio_track.dart';

/// Result of a voiceover take.
class VoiceoverTake {
  const VoiceoverTake(this.path, this.length);
  final String path;
  final Duration length;
}

/// Records a voiceover while the video plays from the playhead.
/// [onStart]/[onStop] let the editor play/pause the preview in sync.
class VoiceoverSheet extends StatefulWidget {
  const VoiceoverSheet({super.key, required this.onStart, required this.onStop});
  final VoidCallback onStart, onStop;

  @override
  State<VoiceoverSheet> createState() => _VoiceoverSheetState();
}

class _VoiceoverSheetState extends State<VoiceoverSheet> {
  final _rec = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _tick;
  bool _recording = false;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    if (_recording) {
      _rec.stop();
      widget.onStop();
    }
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Allow microphone access to record a voiceover.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      await Directory('${dir.path}/voice').create(recursive: true);
      final path = '${dir.path}/voice/vo_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      widget.onStart();
      _watch
        ..reset()
        ..start();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() {}));
      setState(() {
        _recording = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not start recording.');
    }
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _watch.stop();
    final path = await _rec.stop();
    widget.onStop();
    _recording = false;
    if (!mounted) return;
    if (path == null || _watch.elapsed < const Duration(milliseconds: 300)) {
      setState(() => _error = 'Recording was too short.');
      return;
    }
    Navigator.of(context).pop(VoiceoverTake(path, _watch.elapsed));
  }

  @override
  Widget build(BuildContext context) {
    final e = _watch.elapsed;
    final time = '${e.inMinutes}:${e.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voiceover', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              kIsWeb
                  ? 'Voiceover recording works in the Android app.'
                  : 'Records from the playhead while the video plays. Use headphones for the cleanest sound.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: RizColors.textDim),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              key: const Key('vo-record'),
              onTap: kIsWeb ? null : (_recording ? _stop : _start),
              child: Opacity(
                opacity: kIsWeb ? 0.4 : 1,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? const Color(0xFFFF3B5C) : RizColors.surfaceHigh,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(_recording ? Icons.stop : Icons.mic,
                      size: 38, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_recording ? 'Recording $time · tap to stop' : 'Tap to record',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF5C7A))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Built-in sound effects. Tap the speaker to hear one, tap the tile to add.
class SoundEffectsSheet extends StatefulWidget {
  const SoundEffectsSheet({super.key});

  @override
  State<SoundEffectsSheet> createState() => _SoundEffectsSheetState();
}

class _SoundEffectsSheetState extends State<SoundEffectsSheet> {
  VideoPlayerController? _preview;

  static const _icons = {
    'whoosh': Icons.air,
    'pop': Icons.bubble_chart_outlined,
    'ding': Icons.notifications_active_outlined,
    'click': Icons.touch_app_outlined,
    'boom': Icons.flare,
    'rise': Icons.trending_up,
  };

  Future<void> _play(SoundEffect fx) async {
    final old = _preview;
    _preview = null;
    await old?.dispose();
    try {
      final c = VideoPlayerController.asset(fx.asset);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _preview = c;
      await c.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sound effects', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Added at the playhead. Free to use, made for RizCut.',
                style: TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                for (final fx in kSoundEffects)
                  Material(
                    color: RizColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      key: Key('sfx-${fx.name}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(fx),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_icons[fx.name] ?? Icons.music_note,
                                    color: RizColors.cyan, size: 28),
                                const SizedBox(height: 6),
                                Text(fx.label),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: IconButton(
                              tooltip: 'Preview ${fx.label}',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _play(fx),
                              icon: const Icon(Icons.volume_up, size: 18, color: RizColors.textDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit one audio clip. Pops the edited clip, or `null` with [deleted].
class AudioClipEdit {
  const AudioClipEdit.update(this.clip) : delete = false;
  const AudioClipEdit.delete()
      : clip = null,
        delete = true;
  final AudioClip? clip;
  final bool delete;
}

class AudioClipSheet extends StatefulWidget {
  const AudioClipSheet({super.key, required this.initial, required this.playhead});
  final AudioClip initial;
  final Duration playhead;

  @override
  State<AudioClipSheet> createState() => _AudioClipSheetState();
}

class _AudioClipSheetState extends State<AudioClipSheet> {
  late AudioClip _a = widget.initial;

  @override
  Widget build(BuildContext context) {
    final title = switch (_a.kind) {
      AudioKind.voiceover => 'Voiceover',
      AudioKind.sfx => _a.name.isEmpty ? 'Sound effect' : _a.name,
      AudioKind.audio => _a.name.isEmpty ? 'Audio' : _a.name,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => Navigator.of(context).pop(const AudioClipEdit.delete()),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5C7A)),
                ),
                GradientButton(
                  onPressed: () => Navigator.of(context).pop(AudioClipEdit.update(_a)),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_up, size: 18, color: RizColors.textDim),
                const SizedBox(width: 8),
                const SizedBox(width: 64, child: Text('Volume')),
                Expanded(
                  child: Slider(
                    value: _a.volume,
                    max: 2,
                    onChanged: (v) => setState(() => _a = _a.copyWith(volume: v)),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${(_a.volume * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: RizColors.textDim)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => setState(() => _a = _a.copyWith(start: widget.playhead)),
              icon: const Icon(Icons.vertical_align_center),
              label: const Text('Move to playhead'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Volume for one video clip.
class ClipVolumeSheet extends StatefulWidget {
  const ClipVolumeSheet({super.key, required this.initial});
  final double initial;

  @override
  State<ClipVolumeSheet> createState() => _ClipVolumeSheetState();
}

class _ClipVolumeSheetState extends State<ClipVolumeSheet> {
  late double _v = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Clip volume', style: Theme.of(context).textTheme.titleLarge)),
                GradientButton(
                  key: const Key('clip-volume-done'),
                  onPressed: () => Navigator.of(context).pop(_v),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: _v == 0 ? 'Unmute' : 'Mute',
                  onPressed: () => setState(() => _v = _v == 0 ? 1 : 0),
                  icon: Icon(_v == 0 ? Icons.volume_off : Icons.volume_up, color: RizColors.cyan),
                ),
                Expanded(
                  child: Slider(value: _v, max: 2, onChanged: (v) => setState(() => _v = v)),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${(_v * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: RizColors.textDim)),
                ),
              ],
            ),
            const Text('Only this clip. Up to 200% to boost quiet clips.',
                style: TextStyle(color: RizColors.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
