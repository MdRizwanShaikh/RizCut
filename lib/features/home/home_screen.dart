import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../editor/editor_screen.dart';
import '../editor/video_source.dart';

/// Guest-mode home: no sign-in wall, straight into editing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newProject(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty || !context.mounted) return;
    final f = files.first;
    final source = f.path != null
        ? VideoSource.file(f.path!, name: f.name)
        : VideoSource.url(f.uri.toString(), name: f.name);
    _open(context, source);
  }

  void _open(BuildContext context, VideoSource source) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(source: source)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Soft neon glows in the background, like the logo.
          const Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: RizColors.magenta, size: 320),
          ),
          const Positioned(
            bottom: -140,
            right: -100,
            child: _Glow(color: RizColors.blue, size: 360),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/branding/icon.png',
                          width: 44, height: 44),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (r) => RizColors.brand.createShader(r),
                      child: Text(
                        'RizCut',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _NewProjectCard(onTap: () => _newProject(context)),
                const SizedBox(height: 16),
                if (kIsWeb)
                  OutlinedButton.icon(
                    key: const Key('demo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: RizColors.cyan),
                      foregroundColor: RizColors.cyan,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _open(
                      context,
                      const VideoSource.url('demo.mp4', name: 'Demo'),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Try with demo video'),
                  ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    _Feature(icon: Icons.content_cut, label: 'Split', color: RizColors.magenta),
                    _Feature(icon: Icons.speed, label: 'Speed', color: RizColors.cyan),
                    _Feature(icon: Icons.text_fields, label: 'Text', color: RizColors.pink),
                    _Feature(icon: Icons.hd_outlined, label: '1080p', color: RizColors.blue),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Drafts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RizColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RizColors.outline),
                  ),
                  child: const Text('No drafts yet',
                      style: TextStyle(color: RizColors.textDim)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewProjectCard extends StatelessWidget {
  const _NewProjectCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RizColors.brand,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: RizColors.magenta.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('new-project'),
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: const SizedBox(
            height: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.add, size: 36, color: Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  'New Project',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text('No login needed',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
