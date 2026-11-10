import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/editor/overlay_style.dart';
import '../../features/editor/project.dart';
import 'export_command.dart';
import 'project_exporter.dart';

ProjectExporter createExporter() => _FfmpegExporter();

/// Runs FFmpeg on the phone — no video ever leaves the device.
class _FfmpegExporter implements ProjectExporter {
  int? _sessionId;
  bool _cancelled = false;

  @override
  bool get supported => true;

  @override
  Future<String> export({
    required Project project,
    required ui.Size previewSize,
    required ExportSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    _cancelled = false;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final output = '${dir.path}/RizCut_$stamp.mp4';

    // Probe every media item once: size (with rotation) and audio.
    final media = <String, ExportMedia>{};
    ({int width, int height})? firstSize;
    final used = [
      for (final c in project.clips) c.mediaId,
      for (final l in project.layers) l.mediaId,
    ];
    for (final id in used) {
      if (media.containsKey(id)) continue;
      final m = project.mediaById(id);
      if (m == null || m.source.isUrl) {
        throw ExportFailed('A clip points to a file that is not on this device.');
      }
      final probe = await _probe(m.source.location);
      media[id] = ExportMedia(
        path: m.source.location,
        isImage: m.isImage,
        hasAudio: !m.isImage && probe.hasAudio,
      );
      firstSize ??= probe.size ??
          (m.width != null && m.height != null
              ? (width: m.width!, height: m.height!)
              : null);
    }
    final src = firstSize ??
        (width: previewSize.width.round(), height: previewSize.height.round());
    final out = canvasSize(
        project.canvas, src.width, src.height, settings.resolution.shortSide);

    final overlays = <OverlayImage>[];
    final temp = <File>[];
    for (var i = 0; i < project.texts.length; i++) {
      final t = project.texts[i];
      if (!t.isSticker && t.text.trim().isEmpty) continue;
      final file = File('${dir.path}/rz_text_${stamp}_$i.png');
      await file.writeAsBytes(await renderTextPng(t, out.height.toDouble(),
          frameWidth: out.width.toDouble()));
      temp.add(file);
      overlays.add(OverlayImage(
        path: file.path,
        start: t.start,
        end: t.end,
        centerX: t.isBand ? 0.5 : t.position.dx,
        centerY: t.position.dy,
        animIn: t.animIn,
        animOut: t.animOut,
        opacity: t.opacity,
        keyframes: t.keyframes,
        lockX: t.isBand,
      ));
    }

    final track = project.music;
    final music = track == null || track.isUrl
        ? null
        : MusicInput(
            path: track.location,
            volume: track.volume,
            offset: track.offset,
            fadeIn: track.fadeIn,
            fadeOut: track.fadeOut,
            duck: track.duck,
          );

    // Voiceovers / sound effects: built-in effects are copied out of the
    // app bundle so FFmpeg can read them.
    final audioPaths = <String, String>{};
    for (final a in project.audio) {
      if (a.isUrl) continue;
      if (a.isAsset) {
        final f = File('${dir.path}/rz_${a.location.split('/').last}');
        if (!await f.exists()) {
          final data = await rootBundle.load(a.location);
          await f.writeAsBytes(data.buffer.asUint8List());
        }
        audioPaths[a.id] = f.path;
      } else {
        audioPaths[a.id] = a.location;
      }
    }

    final totalMs = project.duration.inMilliseconds;
    String? lastLogs;
    try {
      for (final encoder in VideoEncoder.values) {
        if (_cancelled) throw ExportCancelled();
        final args = buildProjectExportArgs(
          output: output,
          project: project,
          media: media,
          width: out.width,
          height: out.height,
          settings: settings,
          overlays: overlays,
          music: music,
          audioPaths: audioPaths,
          encoder: encoder,
        );
        final done = Completer<void>();
        final session = await FFmpegKit.executeWithArgumentsAsync(
          args,
          (_) => done.complete(),
          null,
          (stats) {
            if (totalMs > 0) {
              onProgress?.call((stats.getTime() / totalMs).clamp(0.0, 1.0));
            }
          },
        );
        _sessionId = session.getSessionId();
        await done.future;

        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          onProgress?.call(1);
          return output;
        }
        if (ReturnCode.isCancel(rc) || _cancelled) throw ExportCancelled();
        lastLogs = await session.getAllLogsAsString();
        final f = File(output);
        if (await f.exists()) await f.delete();
      }
      throw ExportFailed(lastLogs ?? '');
    } finally {
      for (final f in temp) {
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<({({int width, int height})? size, bool hasAudio})> _probe(
      String input) async {
    try {
      final session = await FFprobeKit.getMediaInformation(input);
      final streams = session.getMediaInformation()?.getStreams() ?? [];
      ({int width, int height})? size;
      var hasAudio = false;
      for (final s in streams) {
        if (s.getType() == 'audio') hasAudio = true;
        if (s.getType() == 'video' && size == null) {
          final w = s.getWidth(), h = s.getHeight();
          if (w != null && h != null) {
            size = displaySize(w, h, _rotation(s.getAllProperties()));
          }
        }
      }
      return (size: size, hasAudio: hasAudio);
    } catch (_) {
      // Assume audio exists; FFmpeg fallback logs will tell us otherwise.
      return (size: null, hasAudio: true);
    }
  }

  num? _rotation(Map<dynamic, dynamic>? props) {
    final sideData = props?['side_data_list'];
    if (sideData is List) {
      for (final d in sideData) {
        if (d is Map && d['rotation'] is num) return d['rotation'] as num;
      }
    }
    final tags = props?['tags'];
    if (tags is Map) return num.tryParse('${tags['rotate'] ?? ''}');
    return null;
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }

  @override
  Future<String> saveToGallery(String path) async {
    try {
      await Gal.putVideo(path, album: 'RizCut');
      return 'Saved to gallery · RizCut album';
    } on GalException catch (e) {
      return 'Rendered, but saving to gallery failed: ${e.type.message}';
    }
  }

  @override
  Future<void> share(String path) =>
      SharePlus.instance.share(ShareParams(files: [XFile(path)]));
}

/// Draws [t] into a transparent PNG sized for a frame of [frameHeight] px.
/// Caption bands span the whole [frameWidth].
Future<List<int>> renderTextPng(TextOverlay t, double frameHeight,
    {double? frameWidth}) async {
  final fontSize = t.sizeFraction * frameHeight;
  final pad = fontSize * 0.35;
  final bandW = t.isBand ? (frameWidth ?? frameHeight * 9 / 16) : null;
  final painter = TextPainter(
    text: overlaySpan(t, fontSize),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: bandW == null ? double.infinity : bandW - pad * 2);
  final w = bandW?.ceil() ?? (painter.width + pad * 2).ceil();
  final h = (painter.height + pad * 2).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  if (t.isBand) {
    canvas.drawRect(rect, Paint()..color = Color(t.band!));
  } else if (t.background) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(pad)),
        Paint()..color = const Color(0xCC07031C));
  }
  painter.paint(canvas, Offset((w - painter.width) / 2, pad));
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
