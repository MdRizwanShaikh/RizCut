import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Live green-screen preview (Impeller only; elsewhere returns null so the
/// caller can show a note — the export always applies the key).
class ChromaPreview {
  ChromaPreview._();
  static ui.FragmentProgram? _program;
  static bool _loading = false;

  static bool get supported => ui.ImageFilter.isShaderFilterSupported;

  static Future<void> load() async {
    if (_program != null || _loading || !supported) return;
    _loading = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/chroma.frag');
    } catch (_) {
      // Shader unavailable: preview falls back to the export-only note.
    } finally {
      _loading = false;
    }
  }

  /// Wraps [child] so pixels near [rgb] become transparent, or null.
  static Widget? wrap(Widget child, int rgb, double similarity) {
    final program = _program;
    if (program == null || !supported) return null;
    final shader = program.fragmentShader()
      // uSize (0,1) is set by the engine.
      ..setFloat(2, ((rgb >> 16) & 0xFF) / 255)
      ..setFloat(3, ((rgb >> 8) & 0xFF) / 255)
      ..setFloat(4, (rgb & 0xFF) / 255)
      ..setFloat(5, similarity)
      ..setFloat(6, 0.08);
    return ImageFiltered(imageFilter: ui.ImageFilter.shader(shader), child: child);
  }
}
