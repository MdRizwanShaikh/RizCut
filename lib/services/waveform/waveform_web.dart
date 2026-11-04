import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../features/editor/url_resolver_web.dart';
import 'waveform.dart';

final _cache = <String, List<double>?>{};

Future<List<double>?> audioPeaks(String location, {bool isUrl = false, bool isAsset = false}) async {
  if (_cache.containsKey(location)) return _cache[location];
  try {
    final url = isAsset ? 'assets/$location' : await playableUrl(location);
    final res = await web.window.fetch(url.toJS).toDart;
    if (!res.ok) return _cache[location] = null;
    final buf = await res.arrayBuffer().toDart;
    final ctx = web.OfflineAudioContext(1.toJS, 1, 44100);
    final audio = await ctx.decodeAudioData(buf).toDart;
    final data = audio.getChannelData(0).toDart;
    final per = (audio.sampleRate / kPeaksPerSecond).round().clamp(1, 1 << 20);
    final out = <double>[];
    for (var i = 0; i < data.length; i += per) {
      var m = 0.0;
      final end = (i + per).clamp(0, data.length);
      for (var j = i; j < end; j++) {
        final v = data[j].abs();
        if (v > m) m = v;
      }
      out.add(m.clamp(0.0, 1.0));
    }
    return _cache[location] = out;
  } catch (_) {
    return _cache[location] = null;
  }
}
