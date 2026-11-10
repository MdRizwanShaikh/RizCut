import 'dart:ui' show Color, Offset;

import 'audio_track.dart';
import 'clip_look.dart';
import 'keyframes.dart';
import 'color_grade.dart';
import 'layers.dart';
import 'media.dart';

/// Allowed playback speeds for a clip.
const kSpeeds = <double>[0.25, 0.5, 1, 1.5, 2, 4];

/// Transition played at the boundary *after* a clip.
enum TransitionType {
  none('None'),
  fadeBlack('Fade black'),
  fadeWhite('Flash white'),
  flashPink('Flash pink'),
  slideLeft('Slide left'),
  slideUp('Slide up'),
  wipe('Wipe'),
  zoom('Zoom');

  const TransitionType(this.label);
  final String label;

  /// Colour faded to for fade-style transitions (ARGB), else null.
  int? get fadeColor => switch (this) {
        fadeBlack => 0xFF000000,
        fadeWhite => 0xFFFFFFFF,
        flashPink => 0xFFFB40FA,
        _ => null,
      };
}

/// Where a transition is at a moment: [strength] 0..1 (1 at the cut),
/// [leaving] true on the outgoing clip, false on the incoming one.
typedef TransitionState = ({
  TransitionType type,
  double strength,
  bool leaving,
});

/// Each side of a transition lasts this long (total = 2x).
const kTransitionHalf = Duration(milliseconds: 300);

/// A segment of a media item (video or photo) placed on the timeline.
/// For photos, `sourceIn` is zero and `sourceOut` is the shown length.
class VideoClip {
  const VideoClip({
    this.mediaId = 'm0',
    required this.sourceIn,
    required this.sourceOut,
    this.speed = 1,
    this.transitionOut = TransitionType.none,
    this.look = const ClipLook(),
    this.volume = 1,
  }) : assert(speed > 0);

  /// Which [MediaItem] this clip shows.
  final String mediaId;

  /// Range inside the source file.
  final Duration sourceIn, sourceOut;
  final double speed;
  final TransitionType transitionOut;

  /// Rotate / flip / zoom / motion for this clip.
  final ClipLook look;

  /// This clip's own sound level (0 = muted), on top of the project level.
  final double volume;

  Duration get sourceLength => sourceOut - sourceIn;

  /// Length of this clip on the output timeline (after speed change).
  Duration get timelineLength =>
      Duration(microseconds: (sourceLength.inMicroseconds / speed).round());

  VideoClip copyWith({
    Duration? sourceIn,
    Duration? sourceOut,
    double? speed,
    TransitionType? transitionOut,
    ClipLook? look,
    double? volume,
  }) =>
      VideoClip(
        mediaId: mediaId,
        sourceIn: sourceIn ?? this.sourceIn,
        sourceOut: sourceOut ?? this.sourceOut,
        speed: speed ?? this.speed,
        transitionOut: transitionOut ?? this.transitionOut,
        look: look ?? this.look,
        volume: volume ?? this.volume,
      );

  Map<String, Object?> toJson() => {
        if (!look.isIdentity) 'look': look.toJson(),
        if (volume != 1) 'vol': volume,
        'media': mediaId,
        'in': sourceIn.inMicroseconds,
        'out': sourceOut.inMicroseconds,
        'speed': speed,
        'tr': transitionOut.name,
      };

  factory VideoClip.fromJson(Map<String, Object?> j) => VideoClip(
        mediaId: j['media'] as String? ?? 'm0',
        sourceIn: Duration(microseconds: (j['in'] as num).toInt()),
        sourceOut: Duration(microseconds: (j['out'] as num).toInt()),
        speed: (j['speed'] as num?)?.toDouble() ?? 1,
        transitionOut: TransitionType.values.asNameMap()[j['tr']] ??
            TransitionType.none,
        look: j['look'] == null
            ? const ClipLook()
            : ClipLook.fromJson((j['look'] as Map).cast()),
        volume: (j['vol'] as num?)?.toDouble() ?? 1,
      );
}

/// Text placed over the video for a time range on the output timeline.
class TextOverlay {
  const TextOverlay({
    required this.text,
    required this.start,
    required this.end,
    this.color = const Color(0xFFFFFFFF),
    this.position = const Offset(0.5, 0.8),
    this.sizeFraction = 0.07,
    this.background = false,
    this.sticker,
    this.band,
    this.animIn = TextAnim.none,
    this.animOut = TextAnim.none,
    this.opacity = 1,
    this.keyframes = const [],
  });

  final String text;
  final Duration start, end;
  final Color color;

  /// Center position relative to the frame (0..1, 0..1).
  final Offset position;

  /// Font size as a fraction of the frame height.
  final double sizeFraction;
  final bool background;

  /// Index into `kStickers` when this overlay is a sticker instead of text.
  final int? sticker;

  /// Full-width caption band colour (ARGB), like news/meme captions.
  final int? band;

  bool get isBand => band != null && sticker == null;

  final TextAnim animIn, animOut;

  /// 0..1; keyframes (if any) override it over time.
  final double opacity;

  /// Position/opacity over time (absolute timeline times).
  final List<Keyframe> keyframes;

  /// Needs a per-frame overlay in export (otherwise a still PNG is enough).
  bool get isAnimated =>
      animIn != TextAnim.none ||
      animOut != TextAnim.none ||
      opacity != 1 ||
      keyframes.isNotEmpty;

  bool get isSticker => sticker != null;

  bool visibleAt(Duration t) => t >= start && t < end;

  TextOverlay copyWith({
    String? text,
    Duration? start,
    Duration? end,
    Color? color,
    Offset? position,
    double? sizeFraction,
    bool? background,
    int? sticker,
    int? band,
    bool clearBand = false,
    TextAnim? animIn,
    TextAnim? animOut,
    double? opacity,
    List<Keyframe>? keyframes,
  }) =>
      TextOverlay(
        text: text ?? this.text,
        start: start ?? this.start,
        end: end ?? this.end,
        color: color ?? this.color,
        position: position ?? this.position,
        sizeFraction: sizeFraction ?? this.sizeFraction,
        background: background ?? this.background,
        sticker: sticker ?? this.sticker,
        band: clearBand ? null : (band ?? this.band),
        animIn: animIn ?? this.animIn,
        animOut: animOut ?? this.animOut,
        opacity: opacity ?? this.opacity,
        keyframes: keyframes ?? this.keyframes,
      );

  Map<String, Object?> toJson() => {
        'text': text,
        if (sticker != null) 'sticker': sticker,
        if (band != null) 'band': band,
        if (animIn != TextAnim.none) 'ain': animIn.name,
        if (animOut != TextAnim.none) 'aout': animOut.name,
        if (opacity != 1) 'op': opacity,
        if (keyframes.isNotEmpty) 'kf': [for (final k in keyframes) k.toJson()],
        'start': start.inMicroseconds,
        'end': end.inMicroseconds,
        'color': color.toARGB32(),
        'x': position.dx,
        'y': position.dy,
        'size': sizeFraction,
        'bg': background,
      };

  factory TextOverlay.fromJson(Map<String, Object?> j) => TextOverlay(
        text: j['text'] as String? ?? '',
        start: Duration(microseconds: (j['start'] as num).toInt()),
        end: Duration(microseconds: (j['end'] as num).toInt()),
        color: Color((j['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
        position: Offset(
          (j['x'] as num?)?.toDouble() ?? 0.5,
          (j['y'] as num?)?.toDouble() ?? 0.8,
        ),
        sizeFraction: (j['size'] as num?)?.toDouble() ?? 0.07,
        background: j['bg'] as bool? ?? false,
        sticker: (j['sticker'] as num?)?.toInt(),
        band: (j['band'] as num?)?.toInt(),
        animIn: TextAnim.values.asNameMap()[j['ain']] ?? TextAnim.none,
        animOut: TextAnim.values.asNameMap()[j['aout']] ?? TextAnim.none,
        opacity: (j['op'] as num?)?.toDouble() ?? 1,
        keyframes: [
          for (final k in (j['kf'] as List?) ?? const [])
            Keyframe.fromJson((k as Map).cast()),
        ],
      );
}

/// Background music mixed under the video.
class MusicTrack {
  const MusicTrack({
    required this.location,
    required this.isUrl,
    this.name = '',
    this.volume = 0.8,
    this.offset = Duration.zero,
    this.fadeIn = MusicTrack.kDefaultMusicFade,
    this.fadeOut = MusicTrack.kDefaultMusicFade,
    this.duck = true,
  });

  static const kDefaultMusicFade = Duration(milliseconds: 1500);
  static const kMaxFade = Duration(seconds: 5);

  final String location;
  final bool isUrl;
  final String name;
  final double volume;

  /// Where in the song the music starts (the first pass); later loops start
  /// from the beginning of the file, like FFmpeg's `-ss` + `-stream_loop`.
  final Duration offset;

  /// Fade in at the start and out at the end of the video. Zero = no fade.
  final Duration fadeIn, fadeOut;

  /// Lower the music while a voiceover plays.
  final bool duck;

  /// Volume multiplier while a voiceover plays.
  static const duckLevel = 0.3;

  /// Position in the song file at timeline time [t], given the song length.
  Duration positionAt(Duration t, Duration length) {
    if (length <= Duration.zero) return Duration.zero;
    final first = length - offset;
    if (first > Duration.zero && t < first) return offset + t;
    final rest = first > Duration.zero ? t - first : t;
    return Duration(microseconds: rest.inMicroseconds % length.inMicroseconds);
  }

  MusicTrack copyWith({
    double? volume,
    Duration? offset,
    Duration? fadeIn,
    Duration? fadeOut,
    bool? duck,
  }) =>
      MusicTrack(
        location: location,
        isUrl: isUrl,
        name: name,
        volume: volume ?? this.volume,
        offset: offset ?? this.offset,
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        duck: duck ?? this.duck,
      );

  Map<String, Object?> toJson() => {
        'loc': location,
        'url': isUrl,
        'name': name,
        'vol': volume,
        'off': offset.inMilliseconds,
        'fin': fadeIn.inMilliseconds,
        'fout': fadeOut.inMilliseconds,
        'duck': duck,
      };

  factory MusicTrack.fromJson(Map<String, Object?> j) {
    // Old drafts stored one on/off `fade` flag.
    final legacy = (j['fade'] as bool? ?? true) ? kDefaultMusicFade : Duration.zero;
    Duration ms(String k, Duration d) {
      final v = j[k] as num?;
      return v == null ? d : Duration(milliseconds: v.round());
    }

    return MusicTrack(
      location: j['loc'] as String,
      isUrl: j['url'] as bool? ?? false,
      name: j['name'] as String? ?? '',
      volume: (j['vol'] as num?)?.toDouble() ?? 0.8,
      offset: ms('off', Duration.zero),
      fadeIn: ms('fin', legacy),
      fadeOut: ms('fout', legacy),
      duck: j['duck'] as bool? ?? true,
    );
  }
}

/// Where a timeline time lands: which clip and which source position.
class TimelineHit {
  const TimelineHit(this.index, this.sourcePosition, this.offsetInClip);
  final int index;
  final Duration sourcePosition;
  final Duration offsetInClip;
}

/// Immutable editing state. Every edit returns a new [Project] (easy undo).
class Project {
  const Project({
    required this.clips,
    this.media = const [],
    this.layers = const [],
    this.audio = const [],
    this.mainFrame = FrameRect.full,
    this.mainCover = false,
    this.canvas = CanvasRatio.original,
    this.background = BackgroundMode.blur,
    this.texts = const [],
    this.grade = const ColorGrade(),
    this.music,
    this.originalVolume = 1,
  });

  factory Project.single(Duration sourceDuration) => Project(
      clips: [VideoClip(sourceIn: Duration.zero, sourceOut: sourceDuration)]);

  /// A new project showing [item] in full.
  factory Project.fromMedia(MediaItem item) => Project(
        media: List.unmodifiable([item]),
        clips: List.unmodifiable([clipFor(item)]),
      );

  /// A clip covering all of [item] (photos get the default length).
  static VideoClip clipFor(MediaItem item) => VideoClip(
        mediaId: item.id,
        sourceIn: Duration.zero,
        sourceOut: item.isImage ? kDefaultPhotoLength : item.duration,
      );

  /// Shortest clip we allow after splitting/trimming.
  static const minClip = Duration(milliseconds: 100);

  final List<VideoClip> clips;

  /// Imported files the clips point to.
  final List<MediaItem> media;

  /// Videos/photos shown over the main track in their own frames.
  final List<Layer> layers;

  /// Voiceovers and sound effects placed on the timeline.
  final List<AudioClip> audio;

  /// Where the main track sits on the canvas (layouts shrink it).
  final FrameRect mainFrame;

  /// Main track fills [mainFrame] by cropping instead of fitting inside it.
  final bool mainCover;
  final CanvasRatio canvas;
  final BackgroundMode background;
  final List<TextOverlay> texts;

  MediaItem? mediaById(String id) {
    for (final m in media) {
      if (m.id == id) return m;
    }
    return null;
  }

  MediaItem? mediaFor(VideoClip c) => mediaById(c.mediaId);

  /// Canvas aspect (width / height); `original` follows the first sized item.
  double canvasAspect({double fallback = 9 / 16}) {
    final a = canvas.aspect;
    if (a != null) return a;
    for (final c in clips) {
      final m = mediaFor(c);
      if (m?.width != null && m?.height != null && m!.height! > 0) {
        return m.width! / m.height!;
      }
    }
    return fallback;
  }
  final ColorGrade grade;
  final MusicTrack? music;

  /// Volume of the video's own sound (0 = muted).
  final double originalVolume;

  Duration get duration =>
      clips.fold(Duration.zero, (sum, c) => sum + c.timelineLength);

  /// Timeline start time of clip [index].
  Duration clipStart(int index) => clips
      .take(index)
      .fold(Duration.zero, (sum, c) => sum + c.timelineLength);

  TimelineHit? hitTest(Duration t) {
    var acc = Duration.zero;
    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final len = c.timelineLength;
      if (t < acc + len || i == clips.length - 1) {
        final off = t - acc;
        final clamped =
            off < Duration.zero ? Duration.zero : (off > len ? len : off);
        final src = c.sourceIn +
            Duration(microseconds: (clamped.inMicroseconds * c.speed).round());
        return TimelineHit(i, src, clamped);
      }
      acc += len;
    }
    return null;
  }

  /// Opacity (0..1) of the transition colour at timeline time [t], and which
  /// transition is active. Mirrors the FFmpeg `fade` filters used on export.
  TransitionState transitionAt(Duration t) {
    final half = kTransitionHalf.inMicroseconds;
    var acc = 0;
    for (var i = 0; i < clips.length - 1; i++) {
      acc += clips[i].timelineLength.inMicroseconds;
      final type = clips[i].transitionOut;
      if (type == TransitionType.none) continue;
      final delta = t.inMicroseconds - acc;
      if (delta.abs() < half) {
        return (type: type, strength: 1 - delta.abs() / half, leaving: delta < 0);
      }
    }
    return (type: TransitionType.none, strength: 0.0, leaving: false);
  }

  Project copyWith({
    List<VideoClip>? clips,
    List<MediaItem>? media,
    List<Layer>? layers,
    List<AudioClip>? audio,
    FrameRect? mainFrame,
    bool? mainCover,
    CanvasRatio? canvas,
    BackgroundMode? background,
    List<TextOverlay>? texts,
    ColorGrade? grade,
    MusicTrack? music,
    bool clearMusic = false,
    double? originalVolume,
  }) =>
      Project(
        clips: clips == null ? this.clips : List.unmodifiable(clips),
        media: media == null ? this.media : List.unmodifiable(media),
        layers: layers == null ? this.layers : List.unmodifiable(layers),
        audio: audio == null ? this.audio : List.unmodifiable(audio),
        mainFrame: mainFrame ?? this.mainFrame,
        mainCover: mainCover ?? this.mainCover,
        canvas: canvas ?? this.canvas,
        background: background ?? this.background,
        texts: texts == null ? this.texts : List.unmodifiable(texts),
        grade: grade ?? this.grade,
        music: clearMusic ? null : (music ?? this.music),
        originalVolume: originalVolume ?? this.originalVolume,
      );

  /// Splits the clip under timeline time [t]. No-op if too close to an edge.
  Project splitAt(Duration t) {
    final hit = hitTest(t);
    if (hit == null) return this;
    final c = clips[hit.index];
    if (hit.sourcePosition - c.sourceIn < minClip ||
        c.sourceOut - hit.sourcePosition < minClip) {
      return this;
    }
    return copyWith(
      clips: [...clips]..replaceRange(hit.index, hit.index + 1, [
          c.copyWith(
              sourceOut: hit.sourcePosition,
              transitionOut: TransitionType.none),
          c.copyWith(sourceIn: hit.sourcePosition),
        ]),
    );
  }

  Project deleteClip(int index) {
    if (clips.length <= 1 || index < 0 || index >= clips.length) return this;
    return copyWith(clips: [...clips]..removeAt(index));
  }

  Project setSpeed(int index, double speed) =>
      copyWith(clips: [...clips]..[index] = clips[index].copyWith(speed: speed));

  Project setLook(int index, ClipLook look) =>
      copyWith(clips: [...clips]..[index] = clips[index].copyWith(look: look));

  Project setTransition(int index, TransitionType type) => copyWith(
      clips: [...clips]..[index] = clips[index].copyWith(transitionOut: type));

  Project moveClip(int from, int to) {
    if (from == to) return this;
    final next = [...clips];
    final c = next.removeAt(from);
    next.insert(to.clamp(0, next.length), c);
    return copyWith(clips: next);
  }

  /// Trims clip [index] to the given source range.
  Project trimClip(int index, Duration sourceIn, Duration sourceOut) {
    if (sourceOut - sourceIn < minClip) return this;
    return copyWith(
        clips: [...clips]
          ..[index] =
              clips[index].copyWith(sourceIn: sourceIn, sourceOut: sourceOut));
  }

  /// Appends [items] to the media list and adds a clip for each at the end.
  Project addMedia(List<MediaItem> items) => copyWith(
        media: [...media, ...items],
        clips: [...clips, for (final m in items) clipFor(m)],
      );

  /// Updates stored info (duration/size) for a media item.
  Project updateMedia(MediaItem item) => copyWith(
      media: [for (final m in media) m.id == item.id ? item : m]);

  Project setClipVolume(int index, double v) =>
      copyWith(clips: [...clips]..[index] = clips[index].copyWith(volume: v));

  Project addAudio(AudioClip a) => copyWith(audio: [...audio, a]);

  Project updateAudio(int i, AudioClip a) => copyWith(audio: [...audio]..[i] = a);

  Project removeAudio(int i) => copyWith(audio: [...audio]..removeAt(i));

  Project addLayer(Layer l) => copyWith(layers: [...layers, l]);

  Project updateLayer(int i, Layer l) => copyWith(layers: [...layers]..[i] = l);

  Project removeLayer(int i) => copyWith(layers: [...layers]..removeAt(i));

  /// A new split-screen project: [items][0] fills the main slot, the rest
  /// become layers; every slot runs for the shortest video's length.
  static Project fromLayout(LayoutTemplate tpl, List<MediaItem> items,
      {String captionText = 'Write your caption'}) {
    assert(items.isNotEmpty);
    final len = layoutLength(items.take(tpl.slotCount).toList());
    final main = items.first;
    final mainClip = VideoClip(
      mediaId: main.id,
      sourceIn: Duration.zero,
      sourceOut: main.isImage || main.duration < len ? (main.isImage ? len : main.duration) : len,
    );
    final layers = <Layer>[
      for (var i = 1; i < tpl.slotCount && i < items.length; i++)
        Layer(
          id: 'L$i-${items[i].id}',
          mediaId: items[i].id,
          start: Duration.zero,
          sourceIn: Duration.zero,
          sourceOut: items[i].isImage || items[i].duration > len
              ? len
              : items[i].duration,
          frame: tpl.slots[i],
        ),
    ];
    return Project(
      media: List.unmodifiable(items),
      clips: List.unmodifiable([mainClip]),
      layers: List.unmodifiable(layers),
      mainFrame: tpl.slots.first,
      mainCover: tpl.mainCover,
      canvas: tpl.square ? CanvasRatio.square : CanvasRatio.portrait,
      background: BackgroundMode.black,
      texts: List.unmodifiable([
        if (tpl.captionY != null)
          TextOverlay(
            text: captionText,
            start: Duration.zero,
            end: mainClip.timelineLength,
            band: 0xFFFFE14D,
            color: const Color(0xFF111111),
            position: Offset(0.5, tpl.captionY!),
            sizeFraction: 0.045,
          ),
      ]),
    );
  }

  Project addText(TextOverlay t) => copyWith(texts: [...texts, t]);

  Project updateText(int i, TextOverlay t) =>
      copyWith(texts: [...texts]..[i] = t);

  Project removeText(int i) => copyWith(texts: [...texts]..removeAt(i));

  Map<String, Object?> toJson() => {
        'v': 2,
        'media': [for (final m in media) m.toJson()],
        'canvas': canvas.name,
        if (layers.isNotEmpty) 'layers': [for (final l in layers) l.toJson()],
        if (audio.isNotEmpty) 'audio': [for (final a in audio) a.toJson()],
        if (!mainFrame.isFull) 'mainFrame': mainFrame.toJson(),
        if (mainCover) 'mainCover': true,
        'bg': background.name,
        'clips': [for (final c in clips) c.toJson()],
        'texts': [for (final t in texts) t.toJson()],
        'grade': grade.toJson(),
        if (music != null) 'music': music!.toJson(),
        'origVol': originalVolume,
      };

  /// [fallback] supplies the media list for v1 drafts (single source, 'm0').
  factory Project.fromJson(Map<String, Object?> j, {MediaItem? fallback}) =>
      Project(
        media: List.unmodifiable(j['media'] == null
            ? [?fallback]
            : [
                for (final m in j['media'] as List)
                  MediaItem.fromJson((m as Map).cast()),
              ]),
        layers: List.unmodifiable([
          for (final l in (j['layers'] as List?) ?? const [])
            Layer.fromJson((l as Map).cast()),
        ]),
        audio: List.unmodifiable([
          for (final a in (j['audio'] as List?) ?? const [])
            AudioClip.fromJson((a as Map).cast()),
        ]),
        mainFrame: j['mainFrame'] == null
            ? FrameRect.full
            : FrameRect.fromJson(j['mainFrame'] as List),
        mainCover: j['mainCover'] as bool? ?? false,
        canvas: CanvasRatio.values.asNameMap()[j['canvas']] ??
            CanvasRatio.original,
        background: BackgroundMode.values.asNameMap()[j['bg']] ??
            BackgroundMode.blur,
        clips: List.unmodifiable([
          for (final c in j['clips'] as List)
            VideoClip.fromJson((c as Map).cast()),
        ]),
        texts: List.unmodifiable([
          for (final t in (j['texts'] as List?) ?? const [])
            TextOverlay.fromJson((t as Map).cast()),
        ]),
        grade: j['grade'] == null
            ? const ColorGrade()
            : ColorGrade.fromJson((j['grade'] as Map).cast()),
        music: j['music'] == null
            ? null
            : MusicTrack.fromJson((j['music'] as Map).cast()),
        originalVolume: (j['origVol'] as num?)?.toDouble() ?? 1,
      );
}
