import 'package:flutter/material.dart';

/// RizCut palette, taken from the neon "R" logo.
abstract final class RizColors {
  static const bg = Color(0xFF07031C); // deep navy-black
  static const surface = Color(0xFF120A33);
  static const surfaceHigh = Color(0xFF1C1247);
  static const outline = Color(0xFF3A2D74);
  static const magenta = Color(0xFFFB40FA);
  static const pink = Color(0xFFFF88FE);
  static const violet = Color(0xFF8B3DFF);
  static const blue = Color(0xFF1AACFC);
  static const cyan = Color(0xFF06F9FF);
  static const text = Color(0xFFF5F3FF);
  static const textDim = Color(0xFFA79BD6);

  /// Signature gradient (magenta → violet → cyan) like the logo frame.
  static const brand = LinearGradient(
    colors: [magenta, violet, blue, cyan],
    stops: [0, 0.4, 0.75, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Colors cycled for clips on the timeline.
  static const clipColors = [violet, blue, magenta, Color(0xFF5B5BFF)];
}

ThemeData buildRizCutTheme() {
  const scheme = ColorScheme.dark(
    primary: RizColors.magenta,
    onPrimary: Colors.white,
    secondary: RizColors.cyan,
    onSecondary: RizColors.bg,
    tertiary: RizColors.violet,
    surface: RizColors.surface,
    onSurface: RizColors.text,
    surfaceContainerHighest: RizColors.surfaceHigh,
    outline: RizColors.textDim,
    outlineVariant: RizColors.outline,
    error: Color(0xFFFF5C7A),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Poppins',
  );
  return base.copyWith(
    scaffoldBackgroundColor: RizColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RizColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: RizColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: RizColors.magenta,
      inactiveTrackColor: RizColors.outline,
      thumbColor: Colors.white,
      overlayColor: RizColors.magenta.withValues(alpha: 0.2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? RizColors.violet
                : Colors.transparent),
        foregroundColor: const WidgetStatePropertyAll(RizColors.text),
        side: const WidgetStatePropertyAll(
            BorderSide(color: RizColors.outline)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RizColors.surfaceHigh,
      contentTextStyle: TextStyle(color: RizColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Pill button filled with the brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RizColors.brand,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: RizColors.magenta.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
