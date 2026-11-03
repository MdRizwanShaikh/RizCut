import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/clip_look.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

void main() {
  test('look filters crop, flip, then rotate', () {
    expect(lookFilters(const ClipLook()), isEmpty);
    expect(
      lookFilters(const ClipLook(zoom: 2, panX: 1, flipH: true, turns: 1)),
      ['crop=iw/2.0000:ih/2.0000:(iw-ow)*1.0000:(ih-oh)*0.5000', 'hflip', 'transpose=1'],
    );
    expect(lookFilters(const ClipLook(turns: 2)), ['hflip', 'vflip']);
    expect(lookFilters(const ClipLook(turns: 3)), ['transpose=2']);
  });

  test('turns wrap and json round trip', () {
    final l = const ClipLook().copyWith(turns: 5, motion: Motion.panLeft, zoom: 1.5);
    expect(l.turns, 1);
    expect(ClipLook.fromJson(l.toJson()).toJson(), l.toJson());
    expect(const ClipLook().toJson(), isEmpty);
  });

  test('motion: preview curve and zoompan expressions agree at the ends', () {
    const zin = ClipLook(motion: Motion.zoomIn);
    expect(zin.motionAt(0).scale, 1);
    expect(zin.motionAt(1).scale, closeTo(kMotionZoom, 1e-9));
    expect(motionFilter(Motion.zoomIn, 720, 1280, 30, 91),
        "zoompan=z='1+0.2500*on/90':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=720x1280:fps=30");
    const left = ClipLook(motion: Motion.panLeft);
    expect(left.motionAt(0).alignX, 1);
    expect(left.motionAt(1).alignX, -1);
    expect(motionFilter(Motion.panLeft, 720, 1280, 30, 61),
        contains("x='(iw-iw/zoom)*(1-on/60)'"));
    expect(motionFilter(Motion.none, 720, 1280, 30, 61), isNull);
  });
}
