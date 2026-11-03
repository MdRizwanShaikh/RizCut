/// Per-clip framing: rotate, flip, zoom/crop and an animated "Ken Burns"
/// motion. Used by the preview and by the FFmpeg export.
library;

enum Motion {
  none('None'),
  zoomIn('Zoom in'),
  zoomOut('Zoom out'),
  panLeft('Pan left'),
  panRight('Pan right');

  const Motion(this.label);
  final String label;
}

/// How far a motion zooms (1.0 = none).
const kMotionZoom = 1.25;

class ClipLook {
  const ClipLook({
    this.turns = 0,
    this.flipH = false,
    this.flipV = false,
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.motion = Motion.none,
  });

  /// Clockwise quarter turns (0..3).
  final int turns;
  final bool flipH, flipV;

  /// Static crop zoom, 1..3.
  final double zoom;

  /// Which part stays in view when zoomed: -1 (left/top) .. 1 (right/bottom).
  final double panX, panY;
  final Motion motion;

  bool get isIdentity =>
      turns == 0 && !flipH && !flipV && zoom == 1 && motion == Motion.none;

  /// Swaps width/height after rotation.
  bool get swapsSides => turns.isOdd;

  /// Ken Burns scale and alignment at [progress] (0..1) through the clip.
  ({double scale, double alignX, double alignY}) motionAt(double progress) {
    final t = progress.clamp(0.0, 1.0);
    return switch (motion) {
      Motion.none => (scale: 1.0, alignX: 0.0, alignY: 0.0),
      Motion.zoomIn => (scale: 1 + (kMotionZoom - 1) * t, alignX: 0.0, alignY: 0.0),
      Motion.zoomOut => (scale: kMotionZoom - (kMotionZoom - 1) * t, alignX: 0.0, alignY: 0.0),
      Motion.panLeft => (scale: kMotionZoom, alignX: 1 - 2 * t, alignY: 0.0),
      Motion.panRight => (scale: kMotionZoom, alignX: -1 + 2 * t, alignY: 0.0),
    };
  }

  ClipLook copyWith({
    int? turns,
    bool? flipH,
    bool? flipV,
    double? zoom,
    double? panX,
    double? panY,
    Motion? motion,
  }) =>
      ClipLook(
        turns: (turns ?? this.turns) % 4,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        zoom: zoom ?? this.zoom,
        panX: panX ?? this.panX,
        panY: panY ?? this.panY,
        motion: motion ?? this.motion,
      );

  Map<String, Object?> toJson() => {
        if (turns != 0) 'r': turns,
        if (flipH) 'fh': true,
        if (flipV) 'fv': true,
        if (zoom != 1) 'z': zoom,
        if (panX != 0) 'px': panX,
        if (panY != 0) 'py': panY,
        if (motion != Motion.none) 'm': motion.name,
      };

  factory ClipLook.fromJson(Map<String, Object?> j) => ClipLook(
        turns: (j['r'] as num?)?.toInt() ?? 0,
        flipH: j['fh'] as bool? ?? false,
        flipV: j['fv'] as bool? ?? false,
        zoom: (j['z'] as num?)?.toDouble() ?? 1,
        panX: (j['px'] as num?)?.toDouble() ?? 0,
        panY: (j['py'] as num?)?.toDouble() ?? 0,
        motion: Motion.values.asNameMap()[j['m']] ?? Motion.none,
      );
}
