import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../services/storage/draft_store.dart';
import '../export/export_sheet.dart';
import 'audio_sheet.dart';
import 'filter_sheet.dart';
import 'project.dart';
import 'text_editor_sheet.dart';
import 'timeline.dart';
import 'video_source.dart';
import 'web_video_filter.dart';

String formatDuration(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final ds = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
  return '$m:$s.$ds';
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.source, this.draft});
  final VideoSource source;

  /// When reopening a saved draft.
  final Draft? draft;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  VideoPlayerController? _ctrl;
  VideoPlayerController get _c => _ctrl!;
  VideoPlayerController? _music;
  String? _musicLoc;
  Project? _project;
  final _undo = <Project>[];
  final _redo = <Project>[];
  late final String _draftId = widget.draft?.id ?? DraftStore.newId();
  Timer? _saveTimer;
  bool _dirty = false;

  /// Current position on the output timeline.
  Duration _t = Duration.zero;
  int _clip = 0;
  int? _selectedText;
  bool _playing = false;
  String? _error;

  Project get p => _project!;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final c = await widget.source.createController();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _ctrl = c;
      try {
        await c.initialize();
      } catch (_) {
        final direct = widget.source.directController();
        if (direct == null) rethrow;
        await c.dispose();
        _ctrl = direct;
        await direct.initialize();
      }
      if (!mounted) return;
      final c2 = _ctrl!;
      setState(() => _project =
          widget.draft?.project ?? Project.single(c2.value.duration));
      c2.addListener(_onTick);
      _projectChanged(save: widget.draft == null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty) _saveNow();
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    _music?.dispose();
    applyWebVideoFilter(null);
    super.dispose();
  }

  // ---------- persistence & side effects ----------

  void _projectChanged({bool save = true}) {
    _c.setVolume(p.originalVolume);
    if (kIsWeb) {
      // The <video> element is attached asynchronously, so apply a few times.
      for (final ms in const [0, 300, 1000, 2500]) {
        Future<void>.delayed(Duration(milliseconds: ms), () {
          if (mounted && _project != null) {
            applyWebVideoFilter(p.grade.isIdentity ? null : p.grade.svgMatrix);
          }
        });
      }
    }
    _syncMusicSource();
    if (save) {
      _dirty = true;
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
    }
  }

  void _saveNow() {
    if (_project == null) return;
    _dirty = false;
    DraftStore.instance.save(Draft(
      id: _draftId,
      source: widget.source,
      project: p,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _syncMusicSource() async {
    final track = p.music;
    if (track?.location == _musicLoc) {
      await _music?.setVolume(track?.volume ?? 0);
      return;
    }
    final old = _music;
    _music = null;
    _musicLoc = track?.location;
    await old?.dispose();
    if (track == null) return;
    VideoPlayerController? ctrl;
    try {
      ctrl = await (track.isUrl
              ? VideoSource.url(track.location)
              : VideoSource.file(track.location))
          .createController();
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(track.volume);
      if (!mounted || _musicLoc != track.location) {
        await ctrl.dispose();
        return;
      }
      _music = ctrl;
      if (_playing) _syncMusicPosition(play: true);
    } catch (_) {
      await ctrl?.dispose();
      if (mounted) _toast('Could not load that audio file');
    }
  }

  void _syncMusicPosition({required bool play}) {
    final m = _music;
    if (m == null || !m.value.isInitialized) return;
    final len = m.value.duration.inMicroseconds;
    if (len > 0) {
      m.seekTo(Duration(microseconds: _t.inMicroseconds % len));
    }
    play ? m.play() : m.pause();
  }

  // ---------- playback across clips ----------

  void _onTick() {
    if (!_playing || _project == null) return;
    final clip = p.clips[_clip];
    final pos = _c.value.position;
    if (pos >= clip.sourceOut - const Duration(milliseconds: 30) ||
        (!_c.value.isPlaying && _c.value.isCompleted)) {
      if (_clip + 1 < p.clips.length) {
        _enterClip(_clip + 1, p.clips[_clip + 1].sourceIn, play: true);
      } else {
        _pause();
        _seek(Duration.zero);
      }
      return;
    }
    final off = pos - clip.sourceIn;
    setState(() {
      _t = p.clipStart(_clip) +
          Duration(microseconds: (off.inMicroseconds / clip.speed).round());
    });
  }

  Future<void> _enterClip(int index, Duration sourcePos,
      {bool play = false}) async {
    _clip = index;
    await _c.setPlaybackSpeed(p.clips[index].speed);
    await _c.seekTo(sourcePos);
    if (play) await _c.play();
  }

  void _seek(Duration t) {
    if (_project == null) return;
    final clamped =
        t < Duration.zero ? Duration.zero : (t > p.duration ? p.duration : t);
    final hit = p.hitTest(clamped);
    if (hit == null) return;
    setState(() => _t = clamped);
    _enterClip(hit.index, hit.sourcePosition);
  }

  void _play() {
    if (_t >= p.duration - const Duration(milliseconds: 50)) {
      _seek(Duration.zero);
    }
    final hit = p.hitTest(_t)!;
    setState(() => _playing = true);
    _enterClip(hit.index, hit.sourcePosition, play: true);
    _syncMusicPosition(play: true);
  }

  void _pause() {
    _c.pause();
    _music?.pause();
    setState(() => _playing = false);
  }

  // ---------- edits ----------

  void _apply(Project next) {
    if (identical(next, _project)) return;
    setState(() {
      _undo.add(p);
      _redo.clear();
      _project = next;
      if (_t > p.duration) _t = p.duration;
    });
    _seek(_t);
    _projectChanged();
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(p);
      _project = _undo.removeLast();
      _selectedText = null;
    });
    _seek(_t);
    _projectChanged();
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(p);
      _project = _redo.removeLast();
    });
    _seek(_t);
    _projectChanged();
  }

  int get _activeClip => p.hitTest(_t)?.index ?? 0;

  void _split() {
    _pause();
    final next = p.splitAt(_t);
    if (identical(next, p)) {
      _toast('Move the playhead inside a clip to split');
    } else {
      _apply(next);
    }
  }

  void _delete() {
    _pause();
    if (_selectedText != null) {
      final i = _selectedText!;
      setState(() => _selectedText = null);
      _apply(p.removeText(i));
      return;
    }
    if (p.clips.length <= 1) {
      _toast('Keep at least one clip');
      return;
    }
    _apply(p.deleteClip(_activeClip));
  }

  Future<void> _speed() async {
    _pause();
    final index = _activeClip;
    final current = p.clips[index].speed;
    final picked = await showModalBottomSheet<double>(
      context: context,
      builder: (_) => _SpeedSheet(current: current),
    );
    if (picked != null && picked != current) _apply(p.setSpeed(index, picked));
  }

  /// Index of the cut nearest to the playhead (transition after that clip).
  int? get _nearestCut {
    if (p.clips.length < 2) return null;
    var best = 0;
    var bestDist = 1 << 62;
    for (var i = 0; i < p.clips.length - 1; i++) {
      final cut = p.clipStart(i + 1).inMicroseconds;
      final d = (cut - _t.inMicroseconds).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  Future<void> _transition() async {
    _pause();
    final cut = _nearestCut;
    if (cut == null) {
      _toast('Split the video first — transitions go between clips');
      return;
    }
    final current = p.clips[cut].transitionOut;
    final picked = await showModalBottomSheet<TransitionType>(
      context: context,
      builder: (_) => _TransitionSheet(current: current, cutNumber: cut + 1),
    );
    if (picked != null && picked != current) {
      _apply(p.setTransition(cut, picked));
      _seek(p.clipStart(cut + 1) - const Duration(milliseconds: 800));
    }
  }

  Future<void> _filters() async {
    _pause();
    final before = p;
    final result = await showModalBottomSheet<bool>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => FilterSheet(
        initial: p.grade,
        onChanged: (g) {
          // Live preview without filling the undo stack.
          setState(() => _project = p.copyWith(grade: g));
          _projectChanged(save: false);
        },
      ),
    );
    final edited = p;
    setState(() => _project = before);
    if (result == true && !identical(edited.grade, before.grade)) {
      _apply(edited);
    } else {
      _projectChanged(save: false);
    }
  }

  Future<void> _audio() async {
    _pause();
    final result = await showModalBottomSheet<AudioSettings>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AudioSheet(
        initial: AudioSettings(
          originalVolume: p.originalVolume,
          music: p.music,
        ),
      ),
    );
    if (result == null) return;
    _apply(p.copyWith(
      originalVolume: result.originalVolume,
      music: result.music,
      clearMusic: result.music == null,
    ));
  }

  Future<void> _addOrEditText([int? index]) async {
    _pause();
    final existing = index == null ? null : p.texts[index];
    final result = await showModalBottomSheet<TextOverlay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TextEditorSheet(
        initial: existing ??
            TextOverlay(
              text: '',
              start: _t,
              end: _minDur(_t + const Duration(seconds: 3), p.duration),
            ),
      ),
    );
    if (result == null) return;
    if (index == null) {
      if (result.end - result.start < const Duration(milliseconds: 300)) {
        final start =
            _maxDur(Duration.zero, p.duration - const Duration(seconds: 3));
        _apply(p.addText(result.copyWith(start: start, end: p.duration)));
      } else {
        _apply(p.addText(result));
      }
      setState(() => _selectedText = p.texts.length - 1);
    } else {
      _apply(p.updateText(index, result));
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _openExport() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ExportSheet(
        source: widget.source,
        project: p,
        previewSize: _c.value.size,
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final ready = _project != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _undo.isEmpty ? null : _undoEdit,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redo.isEmpty ? null : _redoEdit,
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              key: const Key('export'),
              onPressed: ready ? _openExport : null,
              icon: Icons.file_upload_outlined,
              label: 'Export',
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not open video\n$_error',
                    textAlign: TextAlign.center),
              ),
            )
          : !ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _preview()),
                    _transport(),
                    Timeline(
                      project: p,
                      position: _t,
                      activeClip: _activeClip,
                      selectedText: _selectedText,
                      playing: _playing,
                      onScrub: (t) {
                        if (_playing) _pause();
                        _seek(t);
                      },
                      onTapText: (i) => setState(() => _selectedText = i),
                    ),
                    _toolbar(),
                  ],
                ),
    );
  }

  Widget _preview() {
    final visible = <int>[
      for (var i = 0; i < p.texts.length; i++)
        if (p.texts[i].visibleAt(_t) || i == _selectedText) i,
    ];
    final tr = p.transitionAt(_t);
    Widget video = VideoPlayer(_c);
    if (!kIsWeb && !p.grade.isIdentity) {
      video = ColorFiltered(
        colorFilter: ColorFilter.matrix(p.grade.flutterMatrix),
        child: video,
      );
    }
    return GestureDetector(
      onTap: () {
        if (_selectedText != null) {
          setState(() => _selectedText = null);
        } else {
          _playing ? _pause() : _play();
        }
      },
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: _c.value.aspectRatio,
          child: LayoutBuilder(builder: (context, box) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: video),
                if (tr.amount > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: (tr.type == TransitionType.fadeWhite
                                ? Colors.white
                                : Colors.black)
                            .withValues(alpha: tr.amount.clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                for (final i in visible)
                  _TextOnPreview(
                    overlay: p.texts[i],
                    box: box.biggest,
                    selected: i == _selectedText,
                    dimmed: !p.texts[i].visibleAt(_t),
                    onTap: () => setState(() => _selectedText = i),
                    onDoubleTap: () => _addOrEditText(i),
                    onMoved: (pos) {
                      setState(() {
                        _selectedText = i;
                        _project = p.updateText(
                            i, p.texts[i].copyWith(position: pos));
                      });
                    },
                    onMoveStart: () {
                      _undo.add(p);
                      _redo.clear();
                    },
                    onMoveEnd: () => _projectChanged(),
                  ),
                if (!_playing)
                  const Center(
                    child: IgnorePointer(
                      child: Icon(Icons.play_circle_fill,
                          size: 64, color: Color(0xCCFFFFFF)),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _transport() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(formatDuration(_t),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: RizColors.text)),
          Text(' / ${formatDuration(p.duration)}',
              style: const TextStyle(color: RizColors.textDim)),
          const Spacer(),
          IconButton.filled(
            key: const Key('play'),
            style: IconButton.styleFrom(backgroundColor: RizColors.surfaceHigh),
            onPressed: _playing ? _pause : _play,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
          ),
          const Spacer(),
          if (p.music != null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.music_note, size: 16, color: RizColors.cyan),
            ),
          if (!p.grade.isIdentity)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.auto_awesome, size: 16, color: RizColors.pink),
            ),
          Text('${p.clips.length} clip${p.clips.length == 1 ? '' : 's'}',
              style: const TextStyle(color: RizColors.textDim)),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final textSelected = _selectedText != null;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: RizColors.surface,
          border: Border(top: BorderSide(color: RizColors.outline)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              _Tool(icon: Icons.content_cut, label: 'Split', color: RizColors.magenta, onTap: _split),
              _Tool(icon: Icons.speed, label: 'Speed', color: RizColors.cyan, onTap: _speed),
              _Tool(icon: Icons.auto_awesome, label: 'Filters', color: RizColors.violet, onTap: _filters),
              _Tool(icon: Icons.music_note, label: 'Audio', color: RizColors.blue, onTap: _audio),
              _Tool(
                icon: textSelected ? Icons.edit : Icons.text_fields,
                label: textSelected ? 'Edit text' : 'Text',
                color: RizColors.pink,
                onTap: () => _addOrEditText(_selectedText),
              ),
              _Tool(icon: Icons.blur_on, label: 'Transition', color: const Color(0xFF7DF9C2), onTap: _transition),
              _Tool(icon: Icons.delete_outline, label: 'Delete', color: const Color(0xFFFF5C7A), onTap: _delete),
            ],
          ),
        ),
      ),
    );
  }
}

Duration _minDur(Duration a, Duration b) => a < b ? a : b;
Duration _maxDur(Duration a, Duration b) => a > b ? a : b;

class _TransitionSheet extends StatelessWidget {
  const _TransitionSheet({required this.current, required this.cutNumber});
  final TransitionType current;
  final int cutNumber;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Between clip $cutNumber and ${cutNumber + 1}',
                style: const TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in TransitionType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: t == current,
                    selectedColor: RizColors.violet,
                    onSelected: (_) => Navigator.of(context).pop(t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: RizColors.text)),
          ],
        ),
      ),
    );
  }
}

class _TextOnPreview extends StatelessWidget {
  const _TextOnPreview({
    required this.overlay,
    required this.box,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    required this.onDoubleTap,
    required this.onMoved,
    required this.onMoveStart,
    required this.onMoveEnd,
  });

  final TextOverlay overlay;
  final Size box;
  final bool selected, dimmed;
  final VoidCallback onTap, onDoubleTap, onMoveStart, onMoveEnd;
  final ValueChanged<Offset> onMoved;

  @override
  Widget build(BuildContext context) {
    // Same sizing rule as the exported PNG (font = fraction of frame height).
    final fontSize = overlay.sizeFraction * box.height;
    final pad = fontSize * 0.35;
    return Positioned(
      left: overlay.position.dx * box.width,
      top: overlay.position.dy * box.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onPanStart: (_) => onMoveStart(),
          onPanEnd: (_) => onMoveEnd(),
          onPanUpdate: (d) {
            final next = Offset(
              (overlay.position.dx + d.delta.dx / box.width).clamp(0.05, 0.95),
              (overlay.position.dy + d.delta.dy / box.height).clamp(0.05, 0.95),
            );
            onMoved(next);
          },
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: overlay.background ? const Color(0xCC07031C) : null,
                borderRadius: BorderRadius.circular(pad),
                border: selected
                    ? Border.all(color: RizColors.cyan, width: 1.5)
                    : null,
              ),
              child: Text(
                overlay.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: overlay.color,
                  fontFamily: 'Inter',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  shadows: overlay.background
                      ? null
                      : [
                          Shadow(
                            color: const Color(0xAA000000),
                            blurRadius: fontSize * 0.15,
                            offset: Offset(0, fontSize * 0.05),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.current});
  final double current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clip speed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in kSpeeds)
                  ChoiceChip(
                    label: Text('${s == s.roundToDouble() ? s.toInt() : s}x'),
                    selected: s == current,
                    selectedColor: RizColors.violet,
                    onSelected: (_) => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
