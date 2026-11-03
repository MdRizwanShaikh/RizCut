import 'package:flutter/painting.dart';

import 'project.dart';
import 'stickers.dart';

/// One span for both the live preview and the exported PNG, so text and
/// stickers look identical in both.
TextSpan overlaySpan(TextOverlay o, double fontSize) {
  final shadows = o.background
      ? null
      : [
          Shadow(
            color: const Color(0xAA000000),
            blurRadius: fontSize * 0.15,
            offset: Offset(0, fontSize * 0.05),
          ),
        ];
  final icon = stickerIcon(o.sticker);
  if (icon != null) {
    return TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: o.color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: fontSize * kStickerScale,
        height: 1,
        shadows: shadows,
      ),
    );
  }
  return TextSpan(
    text: o.text,
    style: TextStyle(
      color: o.color,
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.15,
      shadows: shadows,
    ),
  );
}
