import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/storage/draft_store.dart';
import '../editor/editor_screen.dart';
import '../editor/video_source.dart';
import '../settings/settings_screen.dart';

/// Guest-mode home: no sign-in wall, straight into editing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Draft> _drafts = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final d = await DraftStore.instance.list();
    if (mounted) setState(() => _drafts = d);
  }

  Future<void> _deleteDraft(Draft d) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delete this draft?',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Your original video stays on the phone.',
                  style: TextStyle(color: RizColors.textDim)),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Keep'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C7A)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete draft'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await DraftStore.instance.delete(d.id);
      _reload();
    }
  }

  Future<void> _newProject(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.media);
    if (files.isEmpty || !context.mounted) return;
    final sources = [
      for (final f in files)
        f.path != null
            ? VideoSource.file(f.path!, name: f.name)
            : VideoSource.url(f.uri.toString(), name: f.name),
    ];
    _open(context, sources.first, extra: sources.skip(1).toList());
  }

  Future<void> _open(BuildContext context, VideoSource source,
      {Draft? draft, List<VideoSource> extra = const []}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              EditorScreen(source: source, draft: draft, extra: extra)),
    );
    // Give the editor's final save a moment, then refresh drafts.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _reload();
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
                      key: const Key('settings'),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
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
                    _Feature(icon: Icons.auto_awesome, label: 'Filters', color: RizColors.violet),
                    _Feature(icon: Icons.music_note, label: 'Music', color: RizColors.blue),
                    _Feature(icon: Icons.text_fields, label: 'Text', color: RizColors.pink),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Drafts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_drafts.isEmpty)
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
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      for (var i = 0; i < _drafts.length; i++)
                        _DraftCard(
                          draft: _drafts[i],
                          color: RizColors.clipColors[
                              i % RizColors.clipColors.length],
                          onTap: () => _open(context, _drafts[i].source,
                              draft: _drafts[i]),
                          onDelete: () => _deleteDraft(_drafts[i]),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });

  final Draft draft;
  final Color color;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final p = draft.project;
    final secs = p.duration.inMilliseconds / 1000;
    final name = draft.source.name.isEmpty ? 'Untitled' : draft.source.name;
    return Material(
      color: RizColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.movie_filter_outlined,
                          color: Colors.white70, size: 34),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 6,
                      child: Text('${secs.toStringAsFixed(1)}s',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: 'Delete draft',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(Icons.more_horiz,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${p.clips.length} clip${p.clips.length == 1 ? '' : 's'} · ${_ago(draft.updatedAt)}',
                    style: const TextStyle(
                        color: RizColors.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
