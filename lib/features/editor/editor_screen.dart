import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../export/export_sheet.dart';

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
  return '$m:$s.$ms';
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.videoPath});
  final String videoPath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final VideoPlayerController _controller;
  RangeValues _trim = const RangeValues(0, 1);
  String? _error;

  Duration get _duration => _controller.value.duration;
  Duration _at(double fraction) => _duration * fraction;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object e) {
        if (mounted) setState(() => _error = '$e');
      });
  }

  void _onTick() {
    final v = _controller.value;
    if (v.isPlaying && v.position >= _at(_trim.end)) {
      _controller.pause();
      _controller.seekTo(_at(_trim.start));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      final pos = _controller.value.position;
      if (pos < _at(_trim.start) || pos >= _at(_trim.end)) {
        _controller.seekTo(_at(_trim.start));
      }
      _controller.play();
    }
  }

  void _openExport() {
    _controller.pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => ExportSheet(
        input: widget.videoPath,
        start: _at(_trim.start),
        end: _at(_trim.end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: ready ? _openExport : null,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Could not open video\n$_error'))
          : !ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    ),
                    _Controls(
                      playing: _controller.value.isPlaying,
                      position: _controller.value.position,
                      start: _at(_trim.start),
                      end: _at(_trim.end),
                      trim: _trim,
                      onPlay: _togglePlay,
                      onTrimChanged: (v) {
                        setState(() => _trim = v);
                        _controller.seekTo(_at(v.start));
                      },
                    ),
                  ],
                ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.playing,
    required this.position,
    required this.start,
    required this.end,
    required this.trim,
    required this.onPlay,
    required this.onTrimChanged,
  });

  final bool playing;
  final Duration position, start, end;
  final RangeValues trim;
  final VoidCallback onPlay;
  final ValueChanged<RangeValues> onTrimChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: theme.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onPlay,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                Text(formatDuration(position)),
                const Spacer(),
                Text('Clip: ${formatDuration(end - start)}',
                    style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.content_cut, size: 18),
                const SizedBox(width: 8),
                Text('Trim', style: theme.textTheme.labelLarge),
              ],
            ),
            RangeSlider(
              values: trim,
              onChanged: (v) {
                if (v.end - v.start >= 0.01) onTrimChanged(v);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(formatDuration(start)), Text(formatDuration(end))],
            ),
          ],
        ),
      ),
    );
  }
}
