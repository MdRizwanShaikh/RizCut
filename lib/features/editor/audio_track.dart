/// Extra audio on the timeline: voiceovers, sound effects, other audio.
library;

enum AudioKind { voiceover, sfx, audio }

/// Built-in sound effects (synthesised for RizCut, no licence needed).
class SoundEffect {
  const SoundEffect(this.name, this.label, this.length);
  final String name, label;
  final Duration length;
  String get asset => 'assets/sfx/$name.wav';
}

const kSoundEffects = [
  SoundEffect('whoosh', 'Whoosh', Duration(milliseconds: 700)),
  SoundEffect('pop', 'Pop', Duration(milliseconds: 250)),
  SoundEffect('ding', 'Ding', Duration(milliseconds: 1200)),
  SoundEffect('click', 'Click', Duration(milliseconds: 50)),
  SoundEffect('boom', 'Boom', Duration(milliseconds: 1000)),
  SoundEffect('rise', 'Rise', Duration(milliseconds: 900)),
];

class AudioClip {
  const AudioClip({
    required this.id,
    required this.location,
    required this.kind,
    required this.start,
    required this.sourceIn,
    required this.sourceOut,
    this.isUrl = false,
    this.isAsset = false,
    this.name = '',
    this.volume = 1,
  });

  final String id;

  /// File path, URL, or asset key (when [isAsset]).
  final String location;
  final bool isUrl, isAsset;
  final String name;
  final AudioKind kind;

  /// When it starts on the output timeline.
  final Duration start;
  final Duration sourceIn, sourceOut;
  final double volume;

  Duration get length => sourceOut - sourceIn;
  Duration get end => start + length;
  bool activeAt(Duration t) => t >= start && t < end;

  AudioClip copyWith({Duration? start, double? volume, Duration? sourceOut}) =>
      AudioClip(
        id: id,
        location: location,
        kind: kind,
        start: start ?? this.start,
        sourceIn: sourceIn,
        sourceOut: sourceOut ?? this.sourceOut,
        isUrl: isUrl,
        isAsset: isAsset,
        name: name,
        volume: volume ?? this.volume,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'loc': location,
        'kind': kind.name,
        'start': start.inMicroseconds,
        'in': sourceIn.inMicroseconds,
        'out': sourceOut.inMicroseconds,
        if (isUrl) 'url': true,
        if (isAsset) 'asset': true,
        if (name.isNotEmpty) 'name': name,
        if (volume != 1) 'vol': volume,
      };

  factory AudioClip.fromJson(Map<String, Object?> j) => AudioClip(
        id: j['id'] as String,
        location: j['loc'] as String,
        kind: AudioKind.values.asNameMap()[j['kind']] ?? AudioKind.audio,
        start: Duration(microseconds: (j['start'] as num).toInt()),
        sourceIn: Duration(microseconds: (j['in'] as num).toInt()),
        sourceOut: Duration(microseconds: (j['out'] as num).toInt()),
        isUrl: j['url'] as bool? ?? false,
        isAsset: j['asset'] as bool? ?? false,
        name: j['name'] as String? ?? '',
        volume: (j['vol'] as num?)?.toDouble() ?? 1,
      );
}
