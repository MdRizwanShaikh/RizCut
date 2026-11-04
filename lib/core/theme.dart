import 'package:flutter/material.dart';

/// RizCut palette: calm charcoal surfaces and one soft-blue accent,
/// matching the flat blue "R" logo. Older names (magenta, cyan, …) are kept
/// so every screen picks up the same simple palette.
abstract final class RizColors {
  static const bg = Color(0xFF111214);
  static const surface = Color(0xFF1A1B1F);
  static const surfaceHigh = Color(0xFF25272D);
  static const outline = Color(0xFF34373F);
  static const accent = Color(0xFF4F8CFF);
  static const accentSoft = Color(0xFF8AB4FF);
  static const magenta = accent;
  static const pink = accentSoft;
  static const violet = accent;
  static const blue = Color(0xFF6E9BFF);
  static const cyan = accentSoft;
  static const text = Color(0xFFF2F3F5);
  static const textDim = Color(0xFF9A9DA6);

  /// Kept for buttons/cards; a gentle single-hue blue.
  static const brand = LinearGradient(
    colors: [Color(0xFF5B95FF), Color(0xFF3F7AEE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Colors cycled for clips on the timeline (calm blues/greys).
  static const clipColors = [
    Color(0xFF3F6FD8),
    Color(0xFF4F8CFF),
    Color(0xFF3A5A9C),
    Color(0xFF5B7FC7),
  ];
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
    fontFamily: 'Inter',
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
