import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/ffmpeg/export_command.dart';
import '../../services/ffmpeg/video_exporter.dart';

enum _Stage { choose, rendering, done, failed }

/// Export flow. Future AdMob hook: show a rewarded/interstitial ad right
/// before `_start()` begins rendering (planned for 2–3 months after launch).
class ExportSheet extends StatefulWidget {
  const ExportSheet({
    super.key,
    required this.input,
    required this.start,
    required this.end,
  });

  final String input;
  final Duration start, end;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final _exporter = VideoExporter();
  ExportResolution _resolution = ExportResolution.p720;
  int _fps = 30;
  _Stage _stage = _Stage.choose;
  double _progress = 0;
  String? _output;
  String _message = '';

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.rendering;
      _progress = 0;
    });
    try {
      final out = await _exporter.exportTrim(
        input: widget.input,
        start: widget.start,
        end: widget.end,
        settings: ExportSettings(resolution: _resolution, fps: _fps),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      var msg = 'Saved to gallery (RizCut album)';
      try {
        await Gal.putVideo(out, album: 'RizCut');
      } on GalException catch (e) {
        msg = 'Rendered, but saving to gallery failed: ${e.type.message}';
      }
      if (!mounted) return;
      setState(() {
        _output = out;
        _message = msg;
        _stage = _Stage.done;
      });
    } on ExportCancelled {
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '$e';
        _stage = _Stage.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: switch (_stage) {
          _Stage.choose => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                const Text('Resolution'),
                const SizedBox(height: 8),
                SegmentedButton<ExportResolution>(
                  segments: [
                    for (final r in ExportResolution.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_resolution},
                  onSelectionChanged: (s) =>
                      setState(() => _resolution = s.first),
                ),
                const SizedBox(height: 16),
                const Text('Frame rate'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30 fps')),
                    ButtonSegment(value: 60, label: Text('60 fps')),
                  ],
                  selected: {_fps},
                  onSelectionChanged: (s) => setState(() => _fps = s.first),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _start,
                      child: const Text('Export video'),
                    ),
                  ],
                ),
              ],
            ),
          _Stage.rendering => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rendering… ${(_progress * 100).round()}%',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                const Text('Keep the app open while exporting.'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _exporter.cancel,
                  child: const Text('Cancel export'),
                ),
              ],
            ),
          _Stage.done => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(_message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(files: [XFile(_output!)]),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          _Stage.failed => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Export failed. $_message', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _stage = _Stage.choose),
                  child: const Text('Try again'),
                ),
              ],
            ),
        },
      ),
    );
  }
}
