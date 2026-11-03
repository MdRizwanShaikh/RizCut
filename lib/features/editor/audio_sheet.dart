import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'project.dart';

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

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return;
    final f = files.first;
    setState(() {
      _music = MusicTrack(
        location: f.path ?? f.uri.toString(),
        isUrl: f.path == null,
        name: f.name,
        volume: _music?.volume ?? 0.8,
        fade: _music?.fade ?? true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _music;
    return SafeArea(
      child: Padding(
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
            if (m == null && kIsWeb) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('demo-music'),
                onPressed: () => setState(() => _music = const MusicTrack(
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
                      onPressed: () => setState(() => _music = null),
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
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 12),
                title: const Text('Fade in & out'),
                value: m.fade,
                activeThumbColor: RizColors.magenta,
                onChanged: (v) => setState(() => _music = m.copyWith(fade: v)),
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
