import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

final _cache = <String, String?>{};

Future<ImageProvider?> videoThumbnail(String videoPath, Duration at) async {
  final path = await _extract(videoPath, at);
  return path == null ? null : FileImage(File(path));
}

Future<String?> _extract(String videoPath, Duration at) async {
  final key = '$videoPath@${at.inMilliseconds ~/ 100}';
  if (_cache.containsKey(key)) return _cache[key];
  try {
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/rz_thumb_${key.hashCode.toUnsigned(32)}.jpg';
    if (await File(out).exists()) return _cache[key] = out;
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss', (at.inMilliseconds / 1000).toStringAsFixed(3),
      '-i', videoPath,
      '-frames:v', '1',
      '-vf', 'scale=-2:96',
      '-q:v', '5',
      out,
    ]);
    final ok = ReturnCode.isSuccess(await session.getReturnCode());
    return _cache[key] = ok && await File(out).exists() ? out : null;
  } catch (_) {
    return _cache[key] = null;
  }
}
