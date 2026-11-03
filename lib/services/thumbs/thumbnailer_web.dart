import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../features/editor/url_resolver_web.dart';

final _cache = <String, ImageProvider?>{};

Future<ImageProvider?> videoThumbnail(String location, Duration at) async {
  final key = '$location@${at.inMilliseconds ~/ 100}';
  if (_cache.containsKey(key)) return _cache[key];
  try {
    final src = await playableUrl(location);
    final v = web.HTMLVideoElement()
      ..muted = true
      ..preload = 'auto'
      ..src = src;
    await web.EventStreamProviders.loadedMetadataEvent
        .forTarget(v)
        .first
        .timeout(const Duration(seconds: 8));
    final seeked = web.EventStreamProviders.seekedEvent.forTarget(v).first;
    v.currentTime = at.inMilliseconds / 1000;
    await seeked.timeout(const Duration(seconds: 8));
    const h = 96;
    final w = v.videoHeight == 0 ? h : (h * v.videoWidth / v.videoHeight).round();
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0, w, h);
    final url = canvas.toDataURL('image/jpeg', 0.7.toJS);
    v.src = '';
    final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
    return _cache[key] = MemoryImage(bytes);
  } catch (_) {
    return _cache[key] = null;
  }
}
