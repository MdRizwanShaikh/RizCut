import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rizcut/main.dart';

void main() {
  testWidgets('opens in guest mode with New Project (no login wall)',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RizCutApp()));
    expect(find.text('RizCut'), findsOneWidget);
    expect(find.byKey(const Key('new-project')), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });
}
