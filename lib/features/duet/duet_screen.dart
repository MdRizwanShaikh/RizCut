import 'dart:async';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../editor/color_grade.dart';
import '../editor/duet_setup.dart';
import '../editor/editor_screen.dart';
import '../editor/layers.dart';
import '../editor/video_source.dart';

/// Duet / reaction: the chosen reel plays at the bottom while you record
/// yourself on top (or import your own video). Both parts stay separately
/// editable afterwards.
class DuetScreen extends StatefulWidget {
  const DuetScreen({super.key, required this.reel});
  final VideoSource reel;

  @override
  State<DuetScreen> createState() => _DuetScreenState();
}

class _DuetScreenState extends State<DuetScreen> {
  VideoPlayerController? _reel;
  CameraController? _cam;
  List<CameraDescription> _cams = const [];
  int _camIndex = 0;
  String? _camError;
  FilterPreset _filter = FilterPreset.none;
  bool _recording = false;
  bool _reelSound = true;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _openReel();
    _openCamera();
  }

  Future<void> _openReel() async {
    try {
      final c = await widget.reel.createController();
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _reel = c);
    } catch (e) {
      if (mounted) _toast('Could not open that reel');
    }
  }

  Future<void> _openCamera() async {
    if (kIsWeb) {
      setState(() => _camError = 'Camera recording works in the Android app. '
          'Here you can import your own video.');
      return;
    }
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) throw StateError('No camera found');
      final front = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _camIndex = front < 0 ? 0 : front;
      await _startCamera();
    } catch (e) {
      if (mounted) {
        setState(() => _camError =
            'Camera unavailable. Allow camera and microphone access, or import a video.');
      }
    }
  }

  Future<void> _startCamera() async {
    final old = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(_cams[_camIndex], ResolutionPreset.high);
    await c.initialize();
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _cam = c;
      _camError = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_cams.length < 2 || _recording) return;
    _camIndex = (_camIndex + 1) % _cams.length;
    try {
      await _startCamera();
    } catch (_) {
      if (mounted) setState(() => _camError = 'Could not switch camera');
    }
  }

  Future<void> _record() async {
    final cam = _cam, reel = _reel;
    if (cam == null || reel == null) return;
    if (_recording) return _stop();
    try {
      await reel.seekTo(Duration.zero);
      await reel.setVolume(_reelSound ? 1 : 0);
      await cam.startVideoRecording();
      await reel.play();
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _elapsed = reel.value.position);
        final v = reel.value;
        if (v.position >= v.duration - const Duration(milliseconds: 150)) _stop();
      });
    } catch (e) {
      _toast('Could not start recording');
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _recording = false;
    await _reel?.pause();
    try {
      final file = await _cam!.stopVideoRecording();
      if (!mounted) return;
      _openEditor(VideoSource.file(file.path, name: 'My recording.mp4'));
    } catch (_) {
      if (mounted) {
        setState(() {});
        _toast('Recording failed, please try again');
      }
    }
  }

  Future<void> _importTop() async {
    if (kIsWeb) {
      _openEditor(const VideoSource.url('demo_photo.jpg', name: 'Demo photo'));
      return;
    }
    final files = await FilePicker.pickFiles(type: FileType.media);
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    _openEditor(f.path != null
        ? VideoSource.file(f.path!, name: f.name)
        : VideoSource.url(f.uri.toString(), name: f.name));
  }

  void _openEditor(VideoSource top) {
    _reel?.pause();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => EditorScreen(
        source: top,
        extra: [widget.reel],
        layout: LayoutTemplate.stack2,
        duet: DuetSetup(
          grade: ColorGrade(preset: _filter),
          reelVolume: _reelSound ? 1 : 0,
        ),
      ),
    ));
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _ticker?.cancel();
    _cam?.dispose();
    _reel?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final reel = _reel;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Duet'),
        actions: [
          IconButton(
            tooltip: _reelSound ? 'Mute reel' : 'Unmute reel',
            onPressed: _recording ? null : () => setState(() => _reelSound = !_reelSound),
            icon: Icon(_reelSound ? Icons.volume_up : Icons.volume_off),
          ),
          if (_cams.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              onPressed: _recording ? null : _flipCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: you.
          Expanded(child: _topPart()),
          // Bottom: the reel.
          Expanded(
            child: reel == null || !reel.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: reel.value.size.width,
                        height: reel.value.size.height,
                        child: VideoPlayer(reel),
                      ),
                    ),
                  ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _topPart() {
    final cam = _cam;
    if (cam != null && cam.value.isInitialized) {
      Widget preview = ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: cam.value.previewSize?.height ?? 720,
            height: cam.value.previewSize?.width ?? 1280,
            child: CameraPreview(cam),
          ),
        ),
      );
      if (_filter != FilterPreset.none) {
        preview = ColorFiltered(
          colorFilter: ColorFilter.matrix(ColorGrade(preset: _filter).flutterMatrix),
          child: preview,
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          preview,
          if (_recording)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCCFF3B5C),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('● REC ${_fmt(_elapsed)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );
    }
    return Container(
      color: RizColors.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_camError == null ? Icons.videocam_outlined : Icons.videocam_off_outlined,
              size: 40, color: RizColors.textDim),
          const SizedBox(height: 10),
          Text(_camError ?? 'Starting camera…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: RizColors.textDim)),
        ],
      ),
    );
  }

  Widget _controls() {
    final canRecord = _cam != null && _reel != null;
    return SafeArea(
      top: false,
      child: Container(
        color: RizColors.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in FilterPreset.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: f == _filter,
                        selectedColor: RizColors.violet,
                        onSelected: _recording ? null : (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('duet-import'),
                    onPressed: _recording ? null : _importTop,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import mine'),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  key: const Key('duet-record'),
                  onTap: canRecord ? _record : null,
                  child: Opacity(
                    opacity: canRecord ? 1 : 0.35,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B5C),
                          borderRadius: BorderRadius.circular(_recording ? 8 : 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _recording ? 'Tap to stop' : 'Record while the reel plays',
                    style: const TextStyle(color: RizColors.textDim, fontSize: 12),
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
