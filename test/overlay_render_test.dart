import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/project.dart';
import 'package:rizcut/services/ffmpeg/exporter_io.dart';

void main() {
  testWidgets('text and sticker overlays render to PNG', (tester) async {
    await tester.runAsync(() async {
      for (final o in const [
        TextOverlay(text: 'Hi', start: Duration.zero, end: Duration(seconds: 1)),
        TextOverlay(
            text: '', sticker: 0, start: Duration.zero, end: Duration(seconds: 1)),
      ]) {
        final png = await renderTextPng(o, 720);
        expect(png.sublist(1, 4), 'PNG'.codeUnits);
      }
    });
  });

  testWidgets('caption band spans the frame width', (tester) async {
    await tester.runAsync(() async {
      const band = TextOverlay(
          text: 'Hello', start: Duration.zero, end: Duration(seconds: 1), band: 0xFFFFE14D);
      final png = await renderTextPng(band, 1280, frameWidth: 720);
      // PNG IHDR width is bytes 16..19 (big-endian).
      final w = (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19];
      expect(w, 720);
    });
  });
}

