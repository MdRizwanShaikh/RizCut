import 'web_video_filter_stub.dart'
    if (dart.library.js_interop) 'web_video_filter_web.dart' as impl;

/// On web the video is an HTML element that Flutter's ColorFiltered can't
/// reach, so the grade is applied as an SVG feColorMatrix CSS filter.
/// [svgMatrix] null clears the filter. No-op on mobile.
void applyWebVideoFilter(String? svgMatrix) => impl.apply(svgMatrix);
