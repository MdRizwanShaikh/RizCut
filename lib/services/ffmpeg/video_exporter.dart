import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'export_command.dart';

class ExportCancelled implements Exception {}

class ExportFailed implements Exception {
  ExportFailed(this.logs);
  final String logs;
  @override
  String toString() => 'Export failed';
}

/// Runs FFmpeg on-device. No video ever leaves the phone (zero server cost).
class VideoExporter {
  int? _sessionId;
  bool _cancelled = false;

  /// Trims and re-encodes [input]. [onProgress] receives 0.0–1.0.
  /// Tries the hardware encoder first and falls back to software.
  Future<String> exportTrim({
    required String input,
    required Duration start,
    required Duration end,
    required ExportSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    _cancelled = false;
    final dir = await getTemporaryDirectory();
    final output =
        '${dir.path}/RizCut_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final totalMs = (end - start).inMilliseconds;

    String? lastLogs;
    for (final encoder in VideoEncoder.values) {
      if (_cancelled) throw ExportCancelled();
      final args = buildTrimExportArgs(
        input: input,
        output: output,
        start: start,
        end: end,
        settings: settings,
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
  }

  Future<void> cancel() async {
    _cancelled = true;
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }
}
