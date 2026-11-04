/// Pure (platform-free) builders for FFmpeg export commands.
///
/// Kept separate from the FFmpeg runner so it can be unit tested on any host
/// (and against a desktop ffmpeg binary).
library;

import '../../features/editor/clip_look.dart';
import '../../features/editor/color_grade.dart';
import '../../features/editor/keyframes.dart';
import '../../features/editor/media.dart';
import '../../features/editor/project.dart';

enum ExportResolution {
  p480(480, 2500),
  p720(720, 5000),
  p1080(1080, 10000),
  p1440(1440, 16000),
  p2160(2160, 35000);

  const ExportResolution(this.shortSide, this.videoBitrateKbps);

  /// Target length of the shorter video side (works for portrait & landscape).
  final int shortSide;
  final int videoBitrateKbps;

  String get label => switch (this) {
        p1440 => '2K',
        p2160 => '4K',
        _ => '${shortSide}p',
      };
}

/// Bitrate level (VN-style granular export control).
enum ExportQuality {
  low('Smaller file', 0.6, 6),
  standard('Recommended', 1.0, 3),
  high('Best quality', 1.6, 2);

  const ExportQuality(this.label, this.bitrateFactor, this.mpeg4Q);
  final String label;
  final double bitrateFactor;

  /// `-q:v` for the software encoder (lower = better).
  final int mpeg4Q;
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
    this.quality = ExportQuality.standard,
  }) : assert(fps == 24 || fps == 30 || fps == 60);

  final ExportResolution resolution;
  final int fps;
  final ExportQuality quality;

  /// Video bitrate in kbps: resolution base x quality, +40% at 60 fps.
  int get videoBitrateKbps =>
      (resolution.videoBitrateKbps *
              quality.bitrateFactor *
              (fps == 60 ? 1.4 : fps == 24 ? 0.85 : 1.0))
          .round();

  /// Rough output size for [duration] (video + 128 kbps audio), in MB.
  double estimatedMegabytes(Duration duration) =>
      (videoBitrateKbps + 128) * duration.inMilliseconds / 1000 / 8 / 1000;
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
    this.animIn = TextAnim.none,
    this.animOut = TextAnim.none,
    this.opacity = 1,
    this.keyframes = const [],
    this.lockX = false,
  });

  final String path;
  final Duration start, end;

  /// Center position relative to the output frame (0..1).
  final double centerX, centerY;
  final TextAnim animIn, animOut;
  final double opacity;

  /// Centre position/opacity over time (absolute timeline times).
  final List<Keyframe> keyframes;

  /// Caption bands stay horizontally centred.
  final bool lockX;

  bool get isAnimated =>
      animIn != TextAnim.none ||
      animOut != TextAnim.none ||
      opacity != 1 ||
      keyframes.isNotEmpty;
}

String _sec(Duration d) => (d.inMicroseconds / 1e6).toStringAsFixed(4);

/// Opacity over time as an expression in [tv] (keyframes or a constant),
/// with times shifted by [shift] seconds (for stream-local clocks).
String _opacityExpr(List<Keyframe> k, double opacity, {String tv = 'T', double shift = 0}) {
  if (k.isEmpty) return opacity.toStringAsFixed(4);
  final s = sortedKeyframes(k);
  return piecewiseExpr(
      [for (final f in s) (f.at.inMicroseconds / 1e6 - shift, f.opacity)], tv: tv);
}

bool _opacityVaries(List<Keyframe> k, double opacity) =>
    k.isEmpty ? opacity != 1 : k.any((f) => f.opacity != 1);

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

/// Static framing for a clip: crop (zoom + pan), flips, then rotation —
/// the same order the preview applies them.
List<String> lookFilters(ClipLook look) {
  String f(double v) => v.toStringAsFixed(4);
  return [
    if (look.stabilize) 'deshake',
    if (look.zoom > 1.0001)
      'crop=iw/${f(look.zoom)}:ih/${f(look.zoom)}:'
          '(iw-ow)*${f((look.panX + 1) / 2)}:(ih-oh)*${f((look.panY + 1) / 2)}',
    if (look.flipH) 'hflip',
    if (look.flipV) 'vflip',
    if (look.turns == 1) 'transpose=1',
    if (look.turns == 2) ...['hflip', 'vflip'],
    if (look.turns == 3) 'transpose=2',
  ];
}

/// Ken Burns motion over the whole canvas frame with `zoompan`.
/// [frames] is the clip length in frames.
String? motionFilter(Motion motion, int w, int h, int fps, int frames) =>
    zoomPanFilter(motion, w, h, fps, frames);

/// `zoompan` for a clip's motion and/or "Zoom" transitions. [inFrames] /
/// [outFrames] are the zoom-transition lengths at the start / end (0 = none).
String? zoomPanFilter(Motion motion, int w, int h, int fps, int frames,
    {int inFrames = 0, int outFrames = 0}) {
  if (motion == Motion.none && inFrames == 0 && outFrames == 0) return null;
  final n = frames <= 1 ? 1 : frames - 1;
  final k = (kMotionZoom - 1).toStringAsFixed(4);
  final kz = kMotionZoom.toStringAsFixed(4);
  const cx = '(iw-iw/zoom)/2', cy = '(ih-ih/zoom)/2';
  var (z, x, y) = switch (motion) {
    Motion.zoomIn => ("1+$k*on/$n", cx, cy),
    Motion.zoomOut => ("$kz-$k*on/$n", cx, cy),
    Motion.panLeft => (kz, '(iw-iw/zoom)*(1-on/$n)', cy),
    Motion.panRight => (kz, '(iw-iw/zoom)*on/$n', cy),
    Motion.none => ('1', cx, cy),
  };
  final punch = <String>[
    if (inFrames > 0) 'if(lt(on,$inFrames),1-on/$inFrames,0)',
    if (outFrames > 0)
      'if(gt(on,${n - outFrames}),(on-${n - outFrames})/$outFrames,0)',
  ];
  if (punch.isNotEmpty) z = '($z)*(1+0.5*(${punch.join('+')}))';
  return "zoompan=z='$z':x='$x':y='$y':d=1:s=${w}x$h:fps=$fps";
}

/// Slide / wipe transitions for one clip as extra graph lines turning
/// [inLabel] into [outLabel]. Empty when the clip has neither.
List<String> slideWipeFilters(String inLabel, String outLabel, int w, int h,
    int fps, double len, double d, TransitionType inType, TransitionType outType) {
  final dS = d.toStringAsFixed(3);
  final tail = (len - d).toStringAsFixed(3);
  final lenS = len.toStringAsFixed(3);
  String slide(TransitionType t, String axis) {
    final terms = <String>[
      if (inType == t) 'if(lt(t,$dS),$axis*(1-t/$dS),0)',
      if (outType == t) 'if(gt(t,$tail),-$axis*(t-$tail)/$dS,0)',
    ];
    return terms.isEmpty ? '0' : terms.join('+');
  }
  final slides = inType == TransitionType.slideLeft ||
      inType == TransitionType.slideUp ||
      outType == TransitionType.slideLeft ||
      outType == TransitionType.slideUp;
  final wipes = inType == TransitionType.wipe || outType == TransitionType.wipe;
  if (!slides && !wipes) return const [];
  final lines = <String>[];
  var cur = inLabel;
  if (slides) {
    final next = wipes ? '${outLabel}s' : outLabel;
    lines.add('color=c=black:s=${w}x$h:r=$fps:d=$lenS[${outLabel}k]');
    lines.add("[${outLabel}k][$cur]overlay="
        "x='${slide(TransitionType.slideLeft, 'main_w')}':"
        "y='${slide(TransitionType.slideUp, 'main_h')}':"
        'eval=frame:shortest=1,format=yuv420p[$next]');
    cur = next;
  }
  if (wipes) {
    final inX = inType == TransitionType.wipe ? 'main_w*t/$dS' : null;
    final outX = outType == TransitionType.wipe
        ? '-main_w+main_w*(t-$tail)/$dS'
        : null;
    final x = switch ((inX, outX)) {
      (final i?, final o?) => 'if(lt(t,$dS),$i,if(gt(t,$tail),$o,main_w))',
      (final i?, null) => 'if(lt(t,$dS),$i,main_w)',
      (null, final o?) => 'if(gt(t,$tail),$o,main_w)',
      _ => 'main_w',
    };
    lines.add('color=c=black:s=${w}x$h:r=$fps:d=$lenS[${outLabel}w]');
    lines.add("[$cur][${outLabel}w]overlay=x='$x':y=0:eval=frame,"
        'format=yuv420p[$outLabel]');
  }
  return lines;
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
  Map<String, String> audioPaths = const {},
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

  // The main track renders at its frame's size (whole canvas by default).
  final mainPx = project.mainFrame.pixels(width, height);
  final rw = mainPx.w, rh = mainPx.h;

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
        '0x${(t.fadeColor! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final frames = (len * fps).round();
    final dFrames = (d * fps).round();

    final look = lookFilters(c.look);
    graph.add('[$i:v]setpts=(PTS-STARTPTS)/$speed,fps=$fps,'
        '${look.isEmpty ? '' : '${look.join(',')},'}format=yuv420p[r$i]');
    if (project.mainCover) {
      graph.add('[r$i]scale=$rw:$rh:force_original_aspect_ratio=increase,'
          'crop=$rw:$rh,setsar=1[c$i]');
    } else {
      graph.addAll(_fitToCanvas('r$i', 'c$i', rw, rh, project.background));
    }
    final motion = zoomPanFilter(
      c.look.motion, rw, rh, fps, frames,
      inFrames: inType == TransitionType.zoom ? dFrames : 0,
      outFrames: outType == TransitionType.zoom ? dFrames : 0,
    );
    final v = <String>[
      ?motion,
      if (grade.isNotEmpty) grade,
      if (inType.fadeColor != null)
        'fade=t=in:st=0:d=${d.toStringAsFixed(3)}:color=${color(inType)}',
      if (outType.fadeColor != null)
        'fade=t=out:st=${(len - d).toStringAsFixed(3)}:'
            'd=${d.toStringAsFixed(3)}:color=${color(outType)}',
      'format=yuv420p',
    ];
    final moves = slideWipeFilters(
        'g$i', 'v$i', rw, rh, fps, len, d, inType, outType);
    graph.add('[c$i]${v.join(',')}[${moves.isEmpty ? 'v$i' : 'g$i'}]');
    graph.addAll(moves);
    concatInputs.write('[v$i]');

    final au = <String>[
      if (m.hasAudio && !m.isImage) ...[
        'asetpts=PTS-STARTPTS',
        atempoChain(c.speed),
        if (c.volume != 1) 'volume=${_num(c.volume)}',
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
  if (!project.mainFrame.isFull) {
    final bg = project.background.ffmpegColor;
    graph.add('[vc]pad=$width:$height:${mainPx.x}:${mainPx.y}:color=$bg[vp]');
    last = 'vp';
  }

  // Layers: own input each, cover-fit into their frame, timed overlay.
  final layerBase = clips.length;
  final layerAudio = <String>[];
  for (var j = 0; j < project.layers.length; j++) {
    final l = project.layers[j];
    final m = media[l.mediaId];
    if (m == null) throw ArgumentError('layer $j has no media');
    final k = layerBase + j;
    final lenS = ffmpegSeconds(l.length);
    if (m.isImage) {
      inputs.addAll(['-loop', '1', '-framerate', '$fps', '-t', lenS, '-i', m.path]);
    } else {
      inputs.addAll(['-ss', ffmpegSeconds(l.sourceIn), '-t', lenS, '-i', m.path]);
    }
    final px = l.frame.pixels(width, height);
    final st = ffmpegSeconds(l.start);
    final lg = l.grade == null ? grade : gradeFilter(l.grade!);
    final alpha = <String>[
      if (l.chromaKey != null)
        'colorkey=0x${(l.chromaKey! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}:'
            '${l.keySimilarity.toStringAsFixed(3)}:0.08',
      if (_opacityVaries(l.keyframes, l.opacity))
        (l.keyframes.isEmpty
            ? 'colorchannelmixer=aa=${l.opacity.toStringAsFixed(4)}'
            : "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':"
                "a='alpha(X,Y)*(${_opacityExpr(l.keyframes, l.opacity, shift: l.start.inMicroseconds / 1e6)})'"),
    ];
    graph.add('[$k:v]setpts=PTS-STARTPTS,fps=$fps,'
        'scale=${px.w}:${px.h}:force_original_aspect_ratio=increase,'
        'crop=${px.w}:${px.h},setsar=1,'
        '${lg.isEmpty ? '' : '$lg,'}'
        '${alpha.isEmpty ? 'format=yuv420p' : 'format=rgba,${alpha.join(',')}'},'
        'setpts=PTS+$st/TB[l$j]');
    final lk = sortedKeyframes(l.keyframes);
    final lx = lk.isEmpty
        ? '${px.x}'
        : "'main_w*(${piecewiseExpr([for (final f in lk) (f.at.inMicroseconds / 1e6, f.pos.dx)])})'";
    final ly = lk.isEmpty
        ? '${px.y}'
        : "'main_h*(${piecewiseExpr([for (final f in lk) (f.at.inMicroseconds / 1e6, f.pos.dy)])})'";
    graph.add("[$last][l$j]overlay=x=$lx:y=$ly:"
        "enable='between(t,$st,${ffmpegSeconds(l.end)})':eof_action=pass[y$j]");
    last = 'y$j';
    if (l.volume > 0 && m.hasAudio && !m.isImage) {
      final ms = l.start.inMilliseconds;
      graph.add('[$k:a]asetpts=PTS-STARTPTS,aresample=44100,'
          'aformat=sample_rates=44100:channel_layouts=stereo,'
          'volume=${_num(l.volume)},adelay=$ms:all=1[la$j]');
      layerAudio.add('la$j');
    }
  }

  final overlayBase = clips.length + project.layers.length;
  final overlayInputs = <String>[];
  for (var i = 0; i < overlays.length; i++) {
    final o = overlays[i];
    final next = 'o$i';
    final k = overlayBase + i;
    if (!o.isAnimated) {
      overlayInputs.addAll(['-i', o.path]);
      graph.add('[$last][$k:v]overlay='
          'x=main_w*${_num(o.centerX)}-overlay_w/2:'
          'y=main_h*${_num(o.centerY)}-overlay_h/2:'
          "enable='between(t,${ffmpegSeconds(o.start)},${ffmpegSeconds(o.end)})'"
          '[$next]');
      last = next;
      continue;
    }
    // Animated: loop the PNG for its time window, animate alpha in the
    // stream, and move it with time expressions in overlay.
    final s0 = o.start.inMicroseconds / 1e6, s1 = o.end.inMicroseconds / 1e6;
    final len = s1 - s0;
    overlayInputs.addAll(
        ['-loop', '1', '-framerate', '$fps', '-t', len.toStringAsFixed(3), '-i', o.path]);
    final al = kAnimLength.inMicroseconds / 1e6;
    final f = <String>[
      'format=rgba',
      if (_opacityVaries(o.keyframes, o.opacity))
        "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':"
            "a='alpha(X,Y)*(${_opacityExpr(o.keyframes, o.opacity, shift: s0)})'",
      if (o.animIn == TextAnim.fade) 'fade=t=in:st=0:d=${al.toStringAsFixed(3)}:alpha=1',
      if (o.animOut == TextAnim.fade)
        'fade=t=out:st=${(len - al).toStringAsFixed(3)}:d=${al.toStringAsFixed(3)}:alpha=1',
      'setpts=PTS-STARTPTS+${_sec(o.start)}/TB',
    ];
    graph.add('[$k:v]${f.join(',')}[tx$i]');
    final keys = sortedKeyframes(o.keyframes);
    final px = keys.isEmpty || o.lockX
        ? _num(o.centerX)
        : piecewiseExpr([for (final kf in keys) (kf.at.inMicroseconds / 1e6, kf.pos.dx)]);
    final py = keys.isEmpty
        ? _num(o.centerY)
        : piecewiseExpr([for (final kf in keys) (kf.at.inMicroseconds / 1e6, kf.pos.dy)]);
    final dx = slideOffsetExpr(o.animIn, o.animOut, s0, s1, axisX: true);
    final dy = slideOffsetExpr(o.animIn, o.animOut, s0, s1, axisX: false);
    graph.add("[$last][tx$i]overlay="
        "x='main_w*($px+$dx)-overlay_w/2':"
        "y='main_h*($py+$dy)-overlay_h/2':"
        "enable='between(t,${_sec(o.start)},${_sec(o.end)})':eof_action=pass[$next]");
    last = next;
  }

  // Audio: main track (with volume) + unmuted layers + looping music.
  final total = project.duration.inMicroseconds / 1e6;
  final anyAudio = clips.any((c) {
    final m = media[c.mediaId];
    return m != null && m.hasAudio && !m.isImage;
  });
  final useOriginal = anyAudio && project.originalVolume > 0;
  final extras = [...layerAudio];
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
    extras.add('m');
  }
  // Voiceovers / sound effects: own input each, delayed to their start.
  final audioInputs = <String>[];
  var audioIdx = overlayBase + overlays.length + (music == null ? 0 : 1);
  for (var j = 0; j < project.audio.length; j++) {
    final a = project.audio[j];
    final path = audioPaths[a.id];
    if (path == null || a.volume <= 0 || a.start >= project.duration) continue;
    audioInputs.addAll([
      '-ss', ffmpegSeconds(a.sourceIn), '-t', ffmpegSeconds(a.length), '-i', path,
    ]);
    graph.add('[$audioIdx:a]asetpts=PTS-STARTPTS,aresample=44100,'
        'aformat=sample_rates=44100:channel_layouts=stereo,'
        'volume=${_num(a.volume)},adelay=${a.start.inMilliseconds}:all=1[au$j]');
    extras.add('au$j');
    audioIdx++;
  }
  String? audioOut;
  if (useOriginal || extras.isNotEmpty) {
    // The main track's audio sets the length (amix duration=first).
    var base = 'ac';
    if (!useOriginal) {
      graph.add('[ac]volume=0[ao]');
      base = 'ao';
    } else if (project.originalVolume != 1) {
      graph.add('[ac]volume=${_num(project.originalVolume)}[ao]');
      base = 'ao';
    }
    if (extras.isEmpty) {
      audioOut = base;
    } else {
      graph.add('[$base]${extras.map((e) => '[$e]').join()}'
          'amix=inputs=${extras.length + 1}:duration=first:normalize=0[am]');
      audioOut = 'am';
    }
  }
  if (audioOut == null) {
    // Silent concat audio is discarded.
    graph.add('[ac]anullsink');
  }

  final videoCodecArgs = switch (encoder) {
    VideoEncoder.hardware => [
        '-c:v', encoder.codec,
        '-b:v', '${settings.videoBitrateKbps}k',
      ],
    VideoEncoder.software => [
        '-c:v', encoder.codec,
        '-q:v', '${settings.quality.mpeg4Q}',
      ],
  };

  return [
    '-y',
    ...inputs,
    ...overlayInputs,
    if (music != null) ...['-stream_loop', '-1', '-i', music.path],
    ...audioInputs,
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
