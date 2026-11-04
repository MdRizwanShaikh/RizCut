import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/cloud/cloud_service.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the bundled font's licence on the Licenses page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        const ['Poppins'], await rootBundle.loadString('assets/fonts/OFL-Poppins.txt'));
  });
  // Optional login/backup; a no-op when Firebase isn't configured.
  CloudService.instance.init();
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
