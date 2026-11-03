import 'dart:js_interop';

import 'package:web/web.dart' as web;

final _cache = <String, String>{};

/// Downloads [url] into a blob: URL. Some static hosts ignore HTTP Range
/// requests, which leaves a <video> unseekable; a blob is always seekable.
Future<String> playableUrl(String url) async {
  if (url.startsWith('blob:') || url.startsWith('data:')) return url;
  final cached = _cache[url];
  if (cached != null) return cached;
  try {
    final res = await web.window.fetch(url.toJS).toDart;
    if (!res.ok) return url;
    final blob = await res.blob().toDart;
    return _cache[url] = web.URL.createObjectURL(blob);
  } catch (_) {
    return url;
  }
}
