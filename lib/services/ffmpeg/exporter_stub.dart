import 'dart:ui' show Size;

import '../../features/editor/project.dart';
import 'export_command.dart';
import 'project_exporter.dart';

ProjectExporter createExporter() => _UnsupportedExporter();

class _UnsupportedExporter implements ProjectExporter {
  @override
  bool get supported => false;

  @override
  Future<String> export({
    required String input,
    required Project project,
    required Size previewSize,
    required ExportSettings settings,
    void Function(double progress)? onProgress,
  }) =>
      throw UnsupportedError('Export runs in the Android app');

  @override
  Future<void> cancel() async {}

  @override
  Future<String> saveToGallery(String path) async => '';

  @override
  Future<void> share(String path) async {}
}
