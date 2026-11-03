/// Pure (platform-free) builders for FFmpeg export commands.
///
/// Kept separate from the FFmpeg runner so it can be unit tested on any host
/// (and against a desktop ffmpeg binary).
library;

import '../../features/editor/color_grade.dart';
import '../../features/editor/media.dart';
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

/// Colour grade as FFmpeg filters (empty when the grade is identity).
///
/// Works in 16-bit RGB. `colorchannelmixer` only accepts coefficients in
/// -2..2, so stronger matrices are split into `M/k` followed by a `k` gain.
String gradeFilter(ColorGrade grade) {
  if (grade.isIdentity) return '';
  final m = grade.matrix;
  String f(double v) => v.toStringAsFixed(4);
  var maxAbs = 0.0;
  for (final i in const [0, 1, 2, 4, 5, 6, 8, 9, 10]) {
    if (m[i].abs() > maxAbs) maxAbs = m[i].abs();
  }
  final gains = <double>[];
  var k = 1.0;
  while (maxAbs / k > 2) {
    final step = (maxAbs / k / 2) > 2 ? 2.0 : maxAbs / k / 2 * 1.0001;
    gains.add(step);
    k *= step;
  }
  final mixer = 'colorchannelmixer='
      'rr=${f(m[0] / k)}:rg=${f(m[1] / k)}:rb=${f(m[2] / k)}:'
      'gr=${f(m[4] / k)}:gg=${f(m[5] / k)}:gb=${f(m[6] / k)}:'
      'br=${f(m[8] / k)}:bg=${f(m[9] / k)}:bb=${f(m[10] / k)}';
  final parts = [
    'format=rgb48le',
    mixer,
    for (final g in gains.reversed)
      'colorchannelmixer=rr=${f(g)}:gg=${f(g)}:bb=${f(g)}',
  ];
  final offs = [m[3], m[7], m[11]];
  if (offs.any((o) => o.abs() > 1e-4)) {
    String lut(double o) =>
        "'clip(val+${o.toStringAsFixed(4)}*maxval,minval,maxval)'";
    parts.add('lutrgb=r=${lut(offs[0])}:g=${lut(offs[1])}:b=${lut(offs[2])}');
  }
  return parts.join(',');
}

/// Background music input for the export.
class MusicInput {
  const MusicInput({required this.path, this.volume = 0.8, this.fade = true});
  final String path;
  final double volume;
  final bool fade;
}

/// What the exporter learned about one media file.
class ExportMedia {
  const ExportMedia({
    required this.path,
    required this.isImage,
    this.hasAudio = false,
  });
  final String path;
  final bool isImage;
  final bool hasAudio;
}

/// Output size for a canvas ratio at [shortSide] (even numbers).
/// `original` uses the source size and never upscales.
({int width, int height}) canvasSize(
    CanvasRatio ratio, int srcW, int srcH, int shortSide) {
  if (ratio.aspect == null) return outputSize(srcW, srcH, shortSide);
  int even(double v) => (v / 2).round() * 2;
  final a = ratio.aspect!;
  return a >= 1
      ? (width: even(shortSide * a), height: even(shortSide.toDouble()))
      : (width: even(shortSide.toDouble()), height: even(shortSide / a));
}

/// Fits a clip into the W x H canvas over a blurred copy or a solid colour.
List<String> _fitToCanvas(
    String inLabel, String outLabel, int w, int h, BackgroundMode bg) {
  final fit = 'scale=$w:$h:force_original_aspect_ratio=decrease:'
      'force_divisible_by=2';
  if (bg.argb != null) {
    return [
      '[$inLabel]$fit,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=${bg.ffmpegColor}'
          ',setsar=1[$outLabel]'
    ];
  }
  return [
    '[$inLabel]split=2[${inLabel}f][${inLabel}b]',
    '[${inLabel}b]scale=$w:$h:force_original_aspect_ratio=increase,'
        'crop=$w:$h,boxblur=20:2[${inLabel}bg]',
    '[${inLabel}f]$fit[${inLabel}fg]',
    '[${inLabel}bg][${inLabel}fg]overlay=(W-w)/2:(H-h)/2,setsar=1[$outLabel]',
  ];
}

/// Builds the full export command for a multi-clip, multi-media [project].
///
/// Every clip is its own input, seeked with `-ss`/`-t` (videos) or looped
/// (photos), so nothing is buffered while earlier clips are encoded.
List<String> buildProjectExportArgs({
  required String output,
  required Project project,
  required Map<String, ExportMedia> media,
  required int width,
  required int height,
  required ExportSettings settings,
  List<OverlayImage> overlays = const [],
  MusicInput? music,
  VideoEncoder encoder = VideoEncoder.hardware,
}) {
  final clips = project.clips;
  if (clips.isEmpty) throw ArgumentError('project has no clips');
  final inputs = <String>[];
  final graph = <String>[];
  final concatInputs = StringBuffer();
  final grade = gradeFilter(project.grade);
  final half = kTransitionHalf.inMicroseconds / 1e6;
  final fps = settings.fps;

  for (var i = 0; i < clips.length; i++) {
    final c = clips[i];
    final m = media[c.mediaId];
    if (m == null) throw ArgumentError('clip $i has no media');
    if (c.sourceOut <= c.sourceIn) {
      throw ArgumentError('clip $i has an empty range');
    }
    final len = c.timelineLength.inMicroseconds / 1e6;
    final lenS = len.toStringAsFixed(3);
    if (m.isImage) {
      inputs.addAll(['-loop', '1', '-framerate', '$fps', '-t', lenS, '-i', m.path]);
    } else {
      inputs.addAll([
        '-ss', ffmpegSeconds(c.sourceIn),
        '-t', ffmpegSeconds(c.sourceLength),
        '-i', m.path,
      ]);
    }
    final speed = m.isImage ? '1' : _num(c.speed);
    final d = half < len / 2 ? half : len / 2;
    final inType = i > 0 ? clips[i - 1].transitionOut : TransitionType.none;
    final outType = i < clips.length - 1 ? c.transitionOut : TransitionType.none;
    String color(TransitionType t) =>
        t == TransitionType.fadeWhite ? 'white' : 'black';

    graph.add('[$i:v]setpts=(PTS-STARTPTS)/$speed,fps=$fps,format=yuv420p[r$i]');
    graph.addAll(_fitToCanvas('r$i', 'c$i', width, height, project.background));
    final v = <String>[
      if (grade.isNotEmpty) grade,
      if (inType != TransitionType.none)
        'fade=t=in:st=0:d=${d.toStringAsFixed(3)}:color=${color(inType)}',
      if (outType != TransitionType.none)
        'fade=t=out:st=${(len - d).toStringAsFixed(3)}:'
            'd=${d.toStringAsFixed(3)}:color=${color(outType)}',
      'format=yuv420p',
    ];
    graph.add('[c$i]${v.join(',')}[v$i]');
    concatInputs.write('[v$i]');

    final au = <String>[
      if (m.hasAudio && !m.isImage) ...[
        'asetpts=PTS-STARTPTS',
        atempoChain(c.speed),
      ],
      'aresample=44100',
      'aformat=sample_rates=44100:channel_layouts=stereo',
      'apad',
      'atrim=0:$lenS',
      if (inType != TransitionType.none)
        'afade=t=in:st=0:d=${d.toStringAsFixed(3)}',
      if (outType != TransitionType.none)
        'afade=t=out:st=${(len - d).toStringAsFixed(3)}:d=${d.toStringAsFixed(3)}',
    ];
    final src = m.hasAudio && !m.isImage
        ? '[$i:a]'
        : 'anullsrc=r=44100:cl=stereo,';
    graph.add('$src${au.join(',')}[a$i]');
    concatInputs.write('[a$i]');
  }
  graph.add('${concatInputs}concat=n=${clips.length}:v=1:a=1[vc][ac]');

  var last = 'vc';
  final overlayBase = clips.length;
  for (var i = 0; i < overlays.length; i++) {
    final o = overlays[i];
    final next = 'o$i';
    graph.add('[$last][${overlayBase + i}:v]overlay='
        'x=main_w*${_num(o.centerX)}-overlay_w/2:'
        'y=main_h*${_num(o.centerY)}-overlay_h/2:'
        "enable='between(t,${ffmpegSeconds(o.start)},${ffmpegSeconds(o.end)})'"
        '[$next]');
    last = next;
  }

  final total = project.duration.inMicroseconds / 1e6;
  final anyAudio = clips.any((c) {
    final m = media[c.mediaId];
    return m != null && m.hasAudio && !m.isImage;
  });
  final useOriginal = anyAudio && project.originalVolume > 0;
  String? audioOut;
  if (useOriginal) {
    if (project.originalVolume == 1) {
      audioOut = 'ac';
    } else {
      graph.add('[ac]volume=${_num(project.originalVolume)}[ao]');
      audioOut = 'ao';
    }
  }
  if (music != null) {
    final idx = overlayBase + overlays.length;
    final fadeOut = total > 3 ? 1.5 : total / 3;
    final mf = <String>[
      'aresample=44100',
      'aformat=sample_rates=44100:channel_layouts=stereo',
      'atrim=0:${total.toStringAsFixed(3)}',
      'asetpts=PTS-STARTPTS',
      'volume=${_num(music.volume)}',
      if (music.fade) ...[
        'afade=t=in:st=0:d=${fadeOut.toStringAsFixed(3)}',
        'afade=t=out:st=${(total - fadeOut).toStringAsFixed(3)}:'
            'd=${fadeOut.toStringAsFixed(3)}',
      ],
    ];
    graph.add('[$idx:a]${mf.join(',')}[m]');
    if (audioOut != null) {
      graph.add('[$audioOut][m]amix=inputs=2:duration=first:normalize=0[am]');
      audioOut = 'am';
    } else {
      audioOut = 'm';
    }
  }
  if (audioOut == null) {
    // Silent concat audio is discarded.
    graph.add('[ac]anullsink');
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
    ...inputs,
    for (final o in overlays) ...['-i', o.path],
    if (music != null) ...['-stream_loop', '-1', '-i', music.path],
    '-filter_complex', graph.join(';'),
    '-map', '[$last]',
    if (audioOut != null) ...['-map', '[$audioOut]', '-c:a', 'aac', '-b:a', '128k'],
    ...videoCodecArgs,
    '-pix_fmt', 'yuv420p',
    '-t', total.toStringAsFixed(3),
    '-movflags', '+faststart',
    output,
  ];
}
