import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

const supported = true;

String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);

/// Kept in app documents so drafts can reopen them.
Future<String> _out(String name) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/made');
  await dir.create(recursive: true);
  return '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name';
}

Future<String?> _run(List<String> args, String out) async {
  final session = await FFmpegKit.executeWithArguments(args);
  if (ReturnCode.isSuccess(await session.getReturnCode()) && await File(out).exists()) {
    return out;
  }
  return null;
}

Future<String?> reverse(String path, Duration start, Duration length) async {
  final out = await _out('reversed.mp4');
  // Try with audio first; a clip without sound fails on areverse, so retry.
  return await _run([
        '-y', '-ss', _s(start), '-t', _s(length), '-i', path,
        '-vf', 'reverse', '-af', 'areverse',
        '-c:v', 'mpeg4', '-q:v', '2', '-c:a', 'aac', out,
      ], out) ??
      await _run([
        '-y', '-ss', _s(start), '-t', _s(length), '-i', path,
        '-vf', 'reverse', '-an', '-c:v', 'mpeg4', '-q:v', '2', out,
      ], out);
}

Future<String?> frame(String path, Duration at) async {
  final out = await _out('frame.jpg');
  return _run(['-y', '-ss', _s(at), '-i', path, '-frames:v', '1', '-q:v', '2', out], out);
}

Future<String?> extractAudio(String path) async {
  final out = await _out('sound.m4a');
  // Copy AAC as is (fast); otherwise re-encode.
  return await _run(['-y', '-i', path, '-vn', '-map', '0:a:0', '-c:a', 'copy', out], out) ??
      await _run(
          ['-y', '-i', path, '-vn', '-map', '0:a:0', '-c:a', 'aac', '-b:a', '192k', out], out);
}
