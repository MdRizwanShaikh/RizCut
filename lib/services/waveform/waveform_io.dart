import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'waveform.dart';

final _cache = <String, List<double>?>{};

Future<List<double>?> audioPeaks(String location, {bool isUrl = false, bool isAsset = false}) async {
  if (isUrl) return null;
  if (_cache.containsKey(location)) return _cache[location];
  try {
    final dir = await getTemporaryDirectory();
    var input = location;
    if (isAsset) {
      final f = File('${dir.path}/rz_wave_${location.split('/').last}');
      if (!await f.exists()) {
        await f.writeAsBytes((await rootBundle.load(location)).buffer.asUint8List());
      }
      input = f.path;
    }
    const rate = 2000;
    final out = '${dir.path}/rz_wave_${location.hashCode.toUnsigned(32)}.raw';
    final session = await FFmpegKit.executeWithArguments(
        ['-y', '-i', input, '-vn', '-ac', '1', '-ar', '$rate', '-f', 's16le', out]);
    final f = File(out);
    if (!ReturnCode.isSuccess(await session.getReturnCode()) || !await f.exists()) {
      return _cache[location] = null;
    }
    final bytes = await f.readAsBytes();
    await f.delete();
    final samples = Int16List.view(bytes.buffer, 0, bytes.lengthInBytes ~/ 2);
    return _cache[location] = peaksFromPcm(samples, rate);
  } catch (_) {
    return _cache[location] = null;
  }
}
