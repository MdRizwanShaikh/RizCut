/// Colour filters + adjustments as one 3x4 RGB matrix.
///
/// The same matrix drives the live preview (Flutter `ColorFilter.matrix`,
/// or an SVG `feColorMatrix` on web) and the export (FFmpeg
/// `colorchannelmixer` + `lutrgb`), so what you see is what you export.
library;

/// Row-major 3x4: for each output channel `[r, g, b, offset]`, offset in 0..1.
typedef RgbMatrix = List<double>;

const RgbMatrix kIdentity = [
  1, 0, 0, 0, //
  0, 1, 0, 0,
  0, 0, 1, 0,
];

/// `a ∘ b`: apply [b] first, then [a].
RgbMatrix compose(RgbMatrix a, RgbMatrix b) {
  final out = List<double>.filled(12, 0);
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 4; c++) {
      var v = c == 3 ? a[r * 4 + 3] : 0.0;
      for (var k = 0; k < 3; k++) {
        v += a[r * 4 + k] * b[k * 4 + c];
      }
      out[r * 4 + c] = v;
    }
  }
  return out;
}

RgbMatrix saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  return [
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, //
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0,
  ];
}

RgbMatrix contrastMatrix(double c) {
  final o = 0.5 * (1 - c);
  return [c, 0, 0, o, 0, c, 0, o, 0, 0, c, o];
}

RgbMatrix brightnessMatrix(double b) => [1, 0, 0, b, 0, 1, 0, b, 0, 0, 1, b];

RgbMatrix _scale(double r, double g, double b, [double o = 0]) =>
    [r, 0, 0, o, 0, g, 0, o, 0, 0, b, o];

RgbMatrix _mix(RgbMatrix a, RgbMatrix b, double t) =>
    [for (var i = 0; i < 12; i++) a[i] * (1 - t) + b[i] * t];

enum FilterPreset {
  none('Original'),
  vivid('Vivid'),
  neon('Neon'),
  warm('Warm'),
  cool('Cool'),
  vintage('Vintage'),
  fade('Fade'),
  mono('B&W');

  const FilterPreset(this.label);
  final String label;

  RgbMatrix get matrix => switch (this) {
        FilterPreset.none => kIdentity,
        FilterPreset.vivid =>
          compose(contrastMatrix(1.1), saturationMatrix(1.4)),
        FilterPreset.neon => compose(
            contrastMatrix(1.15),
            compose(_scale(1.05, 0.95, 1.15), saturationMatrix(1.6)),
          ),
        FilterPreset.warm => _scale(1.08, 1.0, 0.86, 0.015),
        FilterPreset.cool => _scale(0.9, 1.0, 1.1, 0.015),
        FilterPreset.vintage => compose(
            contrastMatrix(0.9),
            _mix(kIdentity, const [
              0.393, 0.769, 0.189, 0, //
              0.349, 0.686, 0.168, 0,
              0.272, 0.534, 0.131, 0,
            ], 0.6),
          ),
        FilterPreset.fade => compose(
            brightnessMatrix(0.03),
            compose(contrastMatrix(0.8), saturationMatrix(0.8)),
          ),
        FilterPreset.mono => saturationMatrix(0),
      };
}

/// Project-wide look: a preset plus fine adjustments.
class ColorGrade {
  const ColorGrade({
    this.preset = FilterPreset.none,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
  });

  final FilterPreset preset;

  /// -0.3..0.3 (added to every channel).
  final double brightness;

  /// 0.5..1.5
  final double contrast;

  /// 0..2
  final double saturation;

  bool get isIdentity =>
      preset == FilterPreset.none &&
      brightness == 0 &&
      contrast == 1 &&
      saturation == 1;

  RgbMatrix get matrix => compose(
        brightnessMatrix(brightness),
        compose(
          contrastMatrix(contrast),
          compose(saturationMatrix(saturation), preset.matrix),
        ),
      );

  /// 4x5 matrix for Flutter's `ColorFilter.matrix` (offsets in 0..255).
  List<double> get flutterMatrix {
    final m = matrix;
    return [
      m[0], m[1], m[2], 0, m[3] * 255, //
      m[4], m[5], m[6], 0, m[7] * 255,
      m[8], m[9], m[10], 0, m[11] * 255,
      0, 0, 0, 1, 0,
    ];
  }

  /// `values` for an SVG `feColorMatrix` (offsets in 0..1).
  String get svgMatrix {
    final m = matrix;
    return [
      m[0], m[1], m[2], 0, m[3], //
      m[4], m[5], m[6], 0, m[7],
      m[8], m[9], m[10], 0, m[11],
      0, 0, 0, 1, 0,
    ].map((v) => v.toStringAsFixed(4)).join(' ');
  }

  ColorGrade copyWith({
    FilterPreset? preset,
    double? brightness,
    double? contrast,
    double? saturation,
  }) =>
      ColorGrade(
        preset: preset ?? this.preset,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
      );

  Map<String, Object?> toJson() => {
        'preset': preset.name,
        'b': brightness,
        'c': contrast,
        's': saturation,
      };

  factory ColorGrade.fromJson(Map<String, Object?> j) => ColorGrade(
        preset: FilterPreset.values.asNameMap()[j['preset']] ??
            FilterPreset.none,
        brightness: (j['b'] as num?)?.toDouble() ?? 0,
        contrast: (j['c'] as num?)?.toDouble() ?? 1,
        saturation: (j['s'] as num?)?.toDouble() ?? 1,
      );
}
