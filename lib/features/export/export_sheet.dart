import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/ffmpeg/export_command.dart';
import '../../services/ffmpeg/project_exporter.dart';
import '../editor/project.dart';
import '../editor/video_source.dart';

enum _Stage { choose, rendering, done, failed }

/// Export flow. Future AdMob hook: show a rewarded/interstitial ad right
/// before `_start()` begins rendering (planned for 2–3 months after launch).
class ExportSheet extends StatefulWidget {
  const ExportSheet({
    super.key,
    required this.source,
    required this.project,
    required this.previewSize,
  });

  final VideoSource source;
  final Project project;
  final Size previewSize;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final _exporter = ProjectExporter();
  ExportResolution _resolution = ExportResolution.p720;
  int _fps = 30;
  ExportQuality _quality = ExportQuality.standard;

  ExportSettings get _settings =>
      ExportSettings(resolution: _resolution, fps: _fps, quality: _quality);
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
      final out = await _exporter.export(
        project: widget.project,
        previewSize: widget.previewSize,
        settings: _settings,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final msg = await _exporter.saveToGallery(out);
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
                const SizedBox(height: 4),
                Text(
                  '${widget.project.clips.length} clips · '
                  '${(widget.project.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: RizColors.textDim),
                ),
                const SizedBox(height: 16),
                const Text('Resolution'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in ExportResolution.values)
                      ChoiceChip(
                        key: Key('res-${r.name}'),
                        label: Text(r.label),
                        selected: r == _resolution,
                        selectedColor: RizColors.violet,
                        onSelected: (_) => setState(() => _resolution = r),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Frame rate'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 24, label: Text('24 fps')),
                    ButtonSegment(value: 30, label: Text('30 fps')),
                    ButtonSegment(value: 60, label: Text('60 fps')),
                  ],
                  selected: {_fps},
                  onSelectionChanged: (s) => setState(() => _fps = s.first),
                ),
                const SizedBox(height: 16),
                const Text('Quality (bitrate)'),
                const SizedBox(height: 8),
                SegmentedButton<ExportQuality>(
                  segments: [
                    for (final q in ExportQuality.values)
                      ButtonSegment(value: q, label: Text(q.label)),
                  ],
                  selected: {_quality},
                  onSelectionChanged: (s) => setState(() => _quality = s.first),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_settings.videoBitrateKbps ~/ 1000}.${(_settings.videoBitrateKbps % 1000) ~/ 100} Mbps · '
                  'about ${_settings.estimatedMegabytes(widget.project.duration).toStringAsFixed(_settings.estimatedMegabytes(widget.project.duration) < 10 ? 1 : 0)} MB'
                  '${_resolution.shortSide > 1080 ? ' · 2K/4K needs a 2K/4K source to look sharper' : ''}',
                  style: const TextStyle(color: RizColors.textDim, fontSize: 12),
                ),
                if (!_exporter.supported) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RizColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: RizColors.blue.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'Web preview: export runs on-device in the Android app.',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    GradientButton(
                      onPressed: _exporter.supported ? _start : null,
                      icon: Icons.rocket_launch_outlined,
                      label: 'Export video',
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: RizColors.outline,
                    color: RizColors.magenta,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Keep the app open while exporting.',
                    style: TextStyle(color: RizColors.textDim)),
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
                const Icon(Icons.check_circle,
                    size: 56, color: RizColors.cyan),
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
                    GradientButton(
                      onPressed: () => _exporter.share(_output!),
                      icon: Icons.share,
                      label: 'Share',
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
