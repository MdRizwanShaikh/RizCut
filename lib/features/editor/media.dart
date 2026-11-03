import 'video_source.dart';

enum MediaKind { video, image }

const kImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'};

/// Guesses the kind from a file name (pickers don't always give a MIME type).
MediaKind mediaKindFor(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return kImageExtensions.contains(ext) ? MediaKind.image : MediaKind.video;
}

/// Default length of a photo when added to the timeline.
const kDefaultPhotoLength = Duration(seconds: 3);

/// Longest a single photo clip can be stretched to.
const kMaxPhotoLength = Duration(seconds: 60);

/// One imported file (video or photo) that clips point to.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.source,
    required this.kind,
    this.duration = Duration.zero,
    this.width,
    this.height,
  });

  final String id;
  final VideoSource source;
  final MediaKind kind;

  /// Video length (zero for photos / unknown).
  final Duration duration;

  /// Display size if known.
  final int? width, height;

  bool get isImage => kind == MediaKind.image;

  MediaItem copyWith({Duration? duration, int? width, int? height}) => MediaItem(
        id: id,
        source: source,
        kind: kind,
        duration: duration ?? this.duration,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'source': source.toJson(),
        'kind': kind.name,
        'dur': duration.inMicroseconds,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
      };

  factory MediaItem.fromJson(Map<String, Object?> j) => MediaItem(
        id: j['id'] as String,
        source: VideoSource.fromJson((j['source'] as Map).cast()),
        kind: MediaKind.values.asNameMap()[j['kind']] ?? MediaKind.video,
        duration: Duration(microseconds: (j['dur'] as num?)?.toInt() ?? 0),
        width: (j['w'] as num?)?.toInt(),
        height: (j['h'] as num?)?.toInt(),
      );
}

/// Output frame shape.
enum CanvasRatio {
  original('Original', 0, 0),
  portrait('9:16', 9, 16),
  square('1:1', 1, 1),
  landscape('16:9', 16, 9),
  feed('4:5', 4, 5);

  const CanvasRatio(this.label, this.w, this.h);
  final String label;
  final int w, h;

  /// Width / height, or null for [original].
  double? get aspect => w == 0 ? null : w / h;
}

/// What fills the canvas around media that doesn't match its shape.
enum BackgroundMode {
  blur('Blur', null),
  black('Black', 0xFF000000),
  white('White', 0xFFFFFFFF),
  violet('Violet', 0xFF2A0F5C);

  const BackgroundMode(this.label, this.argb);
  final String label;

  /// Solid colour, or null for a blurred copy of the media.
  final int? argb;

  /// `0xRRGGBB` for FFmpeg's `pad` filter.
  String get ffmpegColor =>
      '0x${((argb ?? 0xFF000000) & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
