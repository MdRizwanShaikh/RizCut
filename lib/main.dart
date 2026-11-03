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
      home: const HomeScreen(),
    );
  }
}
