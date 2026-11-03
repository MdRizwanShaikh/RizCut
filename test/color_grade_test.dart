import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/color_grade.dart';

List<double> applyTo(List<double> m, List<double> rgb) => [
      for (var r = 0; r < 3; r++)
        m[r * 4] * rgb[0] + m[r * 4 + 1] * rgb[1] + m[r * 4 + 2] * rgb[2] + m[r * 4 + 3],
    ];

void main() {
  test('identity grade is identity', () {
    expect(const ColorGrade().matrix, kIdentity);
    expect(const ColorGrade().isIdentity, isTrue);
  });

  test('mono makes grey', () {
    final out = applyTo(const ColorGrade(preset: FilterPreset.mono).matrix, [1, 0, 0]);
    expect(out[0], closeTo(out[1], 1e-9));
    expect(out[1], closeTo(out[2], 1e-9));
  });

  test('compose applies right then left', () {
    final m = compose(brightnessMatrix(0.1), contrastMatrix(2));
    // contrast(0.5) = 0.5, then +0.1
    expect(applyTo(m, [0.5, 0.5, 0.5])[0], closeTo(0.6, 1e-9));
  });

  test('flutter matrix scales offsets to 0..255', () {
    final f = const ColorGrade(brightness: 0.2).flutterMatrix;
    expect(f[4], closeTo(51, 1e-9));
    expect(f.length, 20);
  });
}
