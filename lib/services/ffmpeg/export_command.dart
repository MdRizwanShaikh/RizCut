/// Pure (platform-free) builders for FFmpeg export commands.
///
/// Kept separate from the FFmpeg runner so it can be unit tested on any host
/// (and against a desktop ffmpeg binary).
library;

import '../../features/editor/project.dart';

enum ExportResolution {
  p480(480, 2500),
  p720(720, 5000),
  p1080(1080, 10000);

  const ExportResolution(this.shortSide, this.videoBitrateKbps);

  /// Target length of the shorter video side (works for portrait & landscape).
  final int shortSide;
  final int videoBitrateKbps;

  String get label => '${shortSide}p';
}

enum VideoEncoder {
  /// Android MediaCodec hardware H.264 encoder (fast, battery friendly).
  hardware('h264_mediacodec'),

  /// Software fallback included in the LGPL minimal FFmpeg build.
  software('mpeg4');

  const VideoEncoder(this.codec);
  final String codec;
}

class ExportSettings {
  const ExportSettings({
    this.resolution = ExportResolution.p720,
    this.fps = 30,
  }) : assert(fps == 30 || fps == 60);

  final ExportResolution resolution;
  final int fps;
}

/// Output frame size: short side = [shortSide], aspect kept, even numbers.
/// Never upscales beyond the source.
({int width, int height}) outputSize(int srcW, int srcH, int shortSide) {
  final srcShort = srcW < srcH ? srcW : srcH;
  final target = shortSide > srcShort ? srcShort : shortSide;
  int even(double v) => (v / 2).round() * 2;
  if (srcW >= srcH) {
    return (width: even(srcW * target / srcH), height: even(target.toDouble()));
  }
  return (width: even(target.toDouble()), height: even(srcH * target / srcW));
}

/// Display size of a video stream, applying rotation metadata (90/270 swap).
({int width, int height}) displaySize(int w, int h, num? rotation) {
  final r = ((rotation ?? 0).round() % 360 + 360) % 360;
  return (r == 90 || r == 270) ? (width: h, height: w) : (width: w, height: h);
}

/// Formats seconds with millisecond precision, e.g. `12.345`.
String ffmpegSeconds(Duration d) =>
    (d.inMicroseconds / 1e6).toStringAsFixed(3);

/// `atempo` only accepts 0.5–2.0 (per filter), so chain filters for 0.25/4x.
String atempoChain(double speed) {
  final parts = <String>[];
  var s = speed;
  while (s > 2.0) {
    parts.add('atempo=2');
    s /= 2.0;
  }
  while (s < 0.5) {
    parts.add('atempo=0.5');
    s /= 0.5;
  }
  if ((s - 1.0).abs() > 1e-6 || parts.isEmpty) {
    parts.add('atempo=${_num(s)}');
  }
  return parts.join(',');
}

String _num(double v) {
  final s = v.toStringAsFixed(4);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// A pre-rendered PNG (e.g. a text overlay) shown during [start, end).
class OverlayImage {
  const OverlayImage({
    required this.path,
    required this.start,
    required this.end,
    required this.centerX,
    required this.centerY,
  });

  final String path;
  final Duration start, end;

  /// Center position relative to the output frame (0..1).
  final double centerX, centerY;
}

/// Builds the full export command for a multi-clip [project].
List<String> buildProjectExportArgs({
  required String input,
  required String output,
  required List<VideoClip> clips,
  required int width,
  required int height,
  required bool hasAudio,
  required ExportSettings settings,
  List<OverlayImage> overlays = const [],
  VideoEncoder encoder = VideoEncoder.hardware,
}) {
  if (clips.isEmpty) throw ArgumentError('project has no clips');
  final graph = <String>[];
  final concatInputs = StringBuffer();

  for (var i = 0; i < clips.length; i++) {
    final c = clips[i];
    if (c.sourceOut <= c.sourceIn) {
      throw ArgumentError('clip $i has an empty range');
    }
    final a = ffmpegSeconds(c.sourceIn), b = ffmpegSeconds(c.sourceOut);
    final speed = _num(c.speed);
    graph.add('[0:v]trim=start=$a:end=$b,'
        'setpts=(PTS-STARTPTS)/$speed,'
        'scale=$width:$height,setsar=1,fps=${settings.fps},format=yuv420p'
        '[v$i]');
    concatInputs.write('[v$i]');
    if (hasAudio) {
      graph.add('[0:a]atrim=start=$a:end=$b,asetpts=PTS-STARTPTS,'
          '${atempoChain(c.speed)},aresample=44100[a$i]');
      concatInputs.write('[a$i]');
    }
  }
  graph.add('${concatInputs}concat=n=${clips.length}:v=1:a=${hasAudio ? 1 : 0}'
      '[vc]${hasAudio ? '[ac]' : ''}');

  var last = 'vc';
  for (var i = 0; i < overlays.length; i++) {
    final o = overlays[i];
    final next = 'o$i';
    graph.add('[$last][${i + 1}:v]overlay='
        'x=main_w*${_num(o.centerX)}-overlay_w/2:'
        'y=main_h*${_num(o.centerY)}-overlay_h/2:'
        "enable='between(t,${ffmpegSeconds(o.start)},${ffmpegSeconds(o.end)})'"
        '[$next]');
    last = next;
  }

  final videoCodecArgs = switch (encoder) {
    VideoEncoder.hardware => [
        '-c:v', encoder.codec,
        '-b:v', '${settings.resolution.videoBitrateKbps}k',
      ],
    VideoEncoder.software => [
        '-c:v', encoder.codec,
        '-q:v', '3',
      ],
  };

  return [
    '-y',
    '-i', input,
    for (final o in overlays) ...['-i', o.path],
    '-filter_complex', graph.join(';'),
    '-map', '[$last]',
    if (hasAudio) ...['-map', '[ac]', '-c:a', 'aac', '-b:a', '128k'],
    ...videoCodecArgs,
    '-movflags', '+faststart',
    output,
  ];
}
