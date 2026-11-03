import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../editor/editor_screen.dart';

/// Guest-mode home: no sign-in wall, straight into editing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newProject(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    final path = files.isEmpty ? null : files.first.path;
    if (path == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(videoPath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'RizCut',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('new-project'),
              borderRadius: BorderRadius.circular(20),
              onTap: () => _newProject(context),
              child: Ink(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline,
                        size: 48, color: theme.colorScheme.onPrimary),
                    const SizedBox(height: 8),
                    Text(
                      'New Project',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Drafts', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  'No drafts yet',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
