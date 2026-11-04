import 'waveform_stub.dart'
    if (dart.library.io) 'waveform_io.dart'
    if (dart.library.js_interop) 'waveform_web.dart' as impl;

/// Loudness peaks per second of audio.
const kPeaksPerSecond = 50;

/// Peaks (0..1, [kPeaksPerSecond] per second) for a media/audio file, or null
/// if it has no sound or can't be read. [isAsset] = bundled app asset.
Future<List<double>?> audioPeaks(String location, {bool isUrl = false, bool isAsset = false}) =>
    impl.audioPeaks(location, isUrl: isUrl, isAsset: isAsset);

/// Collapses 16-bit mono PCM samples at [sampleRate] into peaks.
List<double> peaksFromPcm(List<int> samples, int sampleRate) {
  final per = (sampleRate / kPeaksPerSecond).round().clamp(1, 1 << 20);
  final out = <double>[];
  for (var i = 0; i < samples.length; i += per) {
    var m = 0;
    final end = (i + per).clamp(0, samples.length);
    for (var j = i; j < end; j++) {
      final v = samples[j].abs();
      if (v > m) m = v;
    }
    out.add(m / 32768);
  }
  return out;
}
