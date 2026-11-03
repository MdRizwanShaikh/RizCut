import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/features/editor/project.dart';

void main() {
  final p = Project.single(const Duration(seconds: 10));

  test('split creates two clips covering the same source', () {
    final s = p.splitAt(const Duration(seconds: 4));
    expect(s.clips, hasLength(2));
    expect(s.clips[0].sourceOut, const Duration(seconds: 4));
    expect(s.clips[1].sourceIn, const Duration(seconds: 4));
    expect(s.duration, const Duration(seconds: 10));
  });

  test('split at edge is a no-op', () {
    expect(identical(p.splitAt(Duration.zero), p), isTrue);
  });

  test('speed changes timeline length and hit test maps back to source', () {
    final s = p.splitAt(const Duration(seconds: 4)).setSpeed(1, 2);
    expect(s.duration, const Duration(seconds: 7));
    final hit = s.hitTest(const Duration(seconds: 5))!;
    expect(hit.index, 1);
    expect(hit.sourcePosition, const Duration(seconds: 6));
  });

  test('delete keeps at least one clip', () {
    final s = p.splitAt(const Duration(seconds: 4));
    expect(s.deleteClip(0).clips.single.sourceIn, const Duration(seconds: 4));
    expect(identical(p.deleteClip(0), p), isTrue);
  });

  test('texts add/update/remove', () {
    const t = TextOverlay(text: 'hi', start: Duration.zero, end: Duration(seconds: 2));
    final s = p.addText(t).updateText(0, t.copyWith(text: 'yo'));
    expect(s.texts.single.text, 'yo');
    expect(s.removeText(0).texts, isEmpty);
  });
}
