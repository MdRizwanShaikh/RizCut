import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: RizCutApp()));
}

class RizCutApp extends StatelessWidget {
  const RizCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RizCut',
      debugShowCheckedModeBanner: false,
      theme: buildRizCutTheme(),
      scrollBehavior: const _DragEverywhere(),
      home: const HomeScreen(),
    );
  }
}

/// Lets mouse/trackpad drag scroll the timeline too (web preview, desktop).
class _DragEverywhere extends MaterialScrollBehavior {
  const _DragEverywhere();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
