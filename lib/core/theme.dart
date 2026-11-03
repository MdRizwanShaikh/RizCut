import 'package:flutter/material.dart';

const rizAccent = Color(0xFF00D1B2);

ThemeData buildRizCutTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: rizAccent,
    brightness: Brightness.dark,
    surface: const Color(0xFF111316),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0A0B0D),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
