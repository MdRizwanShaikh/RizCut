import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/services/ffmpeg/export_command.dart';

void main() {
  test('builds trim args with hardware encoder', () {
    final args = buildTrimExportArgs(
      input: '/in.mp4',
      output: '/out.mp4',
      start: const Duration(milliseconds: 1500),
      end: const Duration(seconds: 4),
      settings: const ExportSettings(),
    );
    expect(args.sublist(0, 5), ['-y', '-ss', '1.500', '-i', '/in.mp4']);
    expect(args[args.indexOf('-t') + 1], '2.500');
    expect(args[args.indexOf('-c:v') + 1], 'h264_mediacodec');
    expect(args[args.indexOf('-b:v') + 1], '5000k');
    expect(args.last, '/out.mp4');
  });

  test('software fallback uses mpeg4 quality mode', () {
    final args = buildTrimExportArgs(
      input: 'a',
      output: 'b',
      start: Duration.zero,
      end: const Duration(seconds: 1),
      settings: const ExportSettings(resolution: ExportResolution.p1080),
      encoder: VideoEncoder.software,
    );
    expect(args[args.indexOf('-c:v') + 1], 'mpeg4');
    expect(args, isNot(contains('-b:v')));
  });

  test('filter scales short side and sets fps', () {
    expect(
      buildVideoFilter(720, 60),
      r'scale=w=if(gt(iw\,ih)\,-2\,720):h=if(gt(iw\,ih)\,720\,-2),fps=60',
    );
  });

  test('rejects empty range', () {
    expect(
      () => buildTrimExportArgs(
        input: 'a',
        output: 'b',
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 2),
        settings: const ExportSettings(),
      ),
      throwsArgumentError,
    );
  });
}
