/// Pure (platform-free) builders for FFmpeg export commands.
///
/// Kept separate from the FFmpeg runner so it can be unit tested on any host.
library;

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

/// Formats a duration as seconds with millisecond precision, e.g. `12.345`.
String ffmpegSeconds(Duration d) =>
    (d.inMilliseconds / 1000).toStringAsFixed(3);

/// Video filter that scales so the *short* side equals [shortSide],
/// keeping aspect ratio and even dimensions, then normalises frame rate.
String buildVideoFilter(int shortSide, int fps) {
  final s = shortSide;
  return 'scale=w=if(gt(iw\\,ih)\\,-2\\,$s):h=if(gt(iw\\,ih)\\,$s\\,-2),'
      'fps=$fps';
}

/// Arguments for trimming [input] to [start, end) and re-encoding it.
List<String> buildTrimExportArgs({
  required String input,
  required String output,
  required Duration start,
  required Duration end,
  required ExportSettings settings,
  VideoEncoder encoder = VideoEncoder.hardware,
}) {
  if (end <= start) {
    throw ArgumentError('end ($end) must be after start ($start)');
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
    '-ss', ffmpegSeconds(start),
    '-i', input,
    '-t', ffmpegSeconds(end - start),
    '-vf', buildVideoFilter(settings.resolution.shortSide, settings.fps),
    ...videoCodecArgs,
    '-c:a', 'aac',
    '-b:a', '128k',
    '-movflags', '+faststart',
    output,
  ];
}
