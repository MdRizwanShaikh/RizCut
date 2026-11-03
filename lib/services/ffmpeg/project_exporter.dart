import 'dart:ui' show Size;

import '../../features/editor/project.dart';
import 'export_command.dart';
import 'exporter_stub.dart' if (dart.library.io) 'exporter_io.dart' as impl;

class ExportCancelled implements Exception {}

class ExportFailed implements Exception {
  ExportFailed(this.logs);
  final String logs;
  @override
  String toString() =>
      logs.isNotEmpty && logs.length < 160 ? logs : 'Export failed';
}

/// Renders a [Project] to an mp4 on-device. On web (preview build) export is
/// not available and [supported] is false.
abstract class ProjectExporter {
  factory ProjectExporter() => impl.createExporter();

  bool get supported;

  /// [previewSize] is the decoded video size, used if probing fails.
  /// [onProgress] receives 0.0–1.0.
  Future<String> export({
    required Project project,
    required Size previewSize,
    required ExportSettings settings,
    void Function(double progress)? onProgress,
  });

  Future<void> cancel();

  /// Saves to the gallery; returns a user-facing status message.
  Future<String> saveToGallery(String path);

  Future<void> share(String path);
}
