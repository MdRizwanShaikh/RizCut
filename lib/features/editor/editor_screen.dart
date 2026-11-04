import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../services/storage/draft_store.dart';
import '../export/export_sheet.dart';
import 'audio_sheet.dart';
import 'audio_sheets.dart';
import 'audio_track.dart';
import 'canvas_sheet.dart';
import 'color_grade.dart';
import 'duet_setup.dart';
import 'clip_look.dart';
import 'look_sheet.dart';
import 'filter_sheet.dart';
import '../../services/thumbs/thumbnailer.dart';
import 'chroma_preview.dart';
import 'image_provider.dart';
import 'keyframes.dart';
import 'layer_sheet.dart';
import 'layers.dart';
import 'media.dart';
import 'arrange_sheet.dart';
import 'overlay_style.dart';
import 'project.dart';
import 'shorts.dart';
import 'sticker_sheet.dart';
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
  const EditorScreen({
    super.key,
    required this.source,
    this.draft,
    this.extra = const [],
    this.layout,
    this.short,
    this.duet,
  });
  final VideoSource source;

  /// Start a split-screen project: [source] + [extra] fill the slots.
  final LayoutTemplate? layout;

  /// Start a 9:16 Short cut from [source].
  final ShortOptions? short;

  /// Finish a duet: top part gets [DuetSetup.grade], the reel keeps its
  /// own look and plays with [DuetSetup.reelVolume].
  final DuetSetup? duet;

  /// More files picked together with [source]; appended as clips.
  final List<VideoSource> extra;

  /// When reopening a saved draft.
  final Draft? draft;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  /// One player per video media item (photos need none).
  final _players = <String, VideoPlayerController>{};

  /// One player per video layer (by layer id), separate from main players.
  final _layerPlayers = <String, VideoPlayerController>{};

  /// One player per voiceover / sound effect (by audio clip id).
  final _audioPlayers = <String, VideoPlayerController>{};
  int? _selectedLayer;

  /// Player of the clip under the playhead (null on a photo clip).
  VideoPlayerController? _active;
  VideoPlayerController? _music;
  String? _musicLoc;
  Project? _project;
  final _undo = <Project>[];
  final _redo = <Project>[];
  late final String _draftId = widget.draft?.id ?? DraftStore.newId();
  Timer? _saveTimer;
  bool _dirty = false;

  /// Video frame thumbnails by "mediaId@ms".
  final _thumbs = <String, ImageProvider>{};
  final _thumbsPending = <String>{};

  /// Drives playback through photo clips.
  Timer? _photoTimer;
  DateTime _photoTick = DateTime.now();

  /// Current position on the output timeline.
  Duration _t = Duration.zero;
  int _clip = 0;
  int? _selectedText;
  bool _playing = false;
  String? _error;

  /// Timeline zoom (pixels per second).
  double _pps = 64;
  static const _minPps = 12.0, _maxPps = 320.0;

  // Trim drag state.
  Project? _trimBase;
  int _trimIndex = 0;
  TrimEdge _trimEdge = TrimEdge.start;

  Project get p => _project!;

  /// Size used to shape the export when the canvas is "Original".
  Size get _previewSize {
    for (final c in p.clips) {
      final pl = _players[c.mediaId];
      if (pl != null && pl.value.isInitialized) return pl.value.size;
    }
    return const Size(1080, 1920);
  }

  @override
  void initState() {
    super.initState();
    ChromaPreview.load().then((_) {
      if (mounted) setState(() {});
    });
    _open();
  }

  Future<void> _open() async {
    try {
      var project = widget.draft?.project;
      if (project == null && widget.short != null) {
        final item = MediaItem(
          id: DraftStore.newId(),
          source: widget.source,
          kind: MediaKind.video,
        );
        final loaded = await _loadPlayers(
            Project(clips: const [], media: List.unmodifiable([item])));
        if (!mounted) return;
        project = buildShort(loaded.media.first, widget.short!);
        setState(() => _project = project);
        _enterClip(0, p.clips.first.sourceIn);
        _projectChanged();
        return;
      }
      if (project == null && widget.layout != null) {
        final items = [
          for (final s in [widget.source, ...widget.extra])
            MediaItem(
              id: DraftStore.newId() + s.location.hashCode.toString(),
              source: s,
              kind: mediaKindOf(s),
            ),
        ];
        final loaded = await _loadPlayers(Project(
          clips: const [],
          media: List.unmodifiable(items),
        ));
        if (!mounted) return;
        project = Project.fromLayout(widget.layout!, loaded.media);
        final duet = widget.duet;
        if (duet != null && project.layers.isNotEmpty) {
          project = project
              .copyWith(grade: duet.grade)
              .updateLayer(
                0,
                project.layers.first.copyWith(
                  volume: duet.reelVolume,
                  grade: const ColorGrade(),
                ),
              );
        }
        setState(() => _project = project);
        await _syncLayerPlayers();
        _enterClip(0, p.clips.first.sourceIn);
        _projectChanged();
        return;
      }
      if (project == null) {
        final kind = mediaKindOf(widget.source);
        project = Project.fromMedia(MediaItem(
          id: DraftStore.newId(),
          source: widget.source,
          kind: kind,
        ));
      }
      project = await _loadPlayers(project);
      if (!mounted) return;
      // A brand-new video project: the single clip spans the whole file.
      if (widget.draft == null && !project.media.first.isImage) {
        project = project.copyWith(
            clips: [Project.clipFor(project.media.first)]);
      }
      setState(() => _project = project);
      await _syncLayerPlayers();
      _enterClip(0, p.clips.first.sourceIn);
      _projectChanged(save: widget.draft == null);
      if (widget.extra.isNotEmpty) {
        await _appendMedia(
          [for (final s in widget.extra) (s, mediaKindOf(s))],
          quiet: true,
        );
        _undo.clear();
        _seek(Duration.zero);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Creates players for any video media that doesn't have one yet and
  /// records their duration/size in the project.
  Future<Project> _loadPlayers(Project project) async {
    var next = project;
    for (final m in project.media) {
      if (m.isImage) {
        if (m.width == null) {
          final size = await _imageSize(m);
          if (size != null) {
            next = next.updateMedia(
                m.copyWith(width: size.width.round(), height: size.height.round()));
          }
        }
        continue;
      }
      if (_players.containsKey(m.id)) continue;
      var c = await m.source.createController();
      try {
        await c.initialize();
      } catch (_) {
        final direct = m.source.directController();
        if (direct == null) rethrow;
        await c.dispose();
        c = direct;
        await c.initialize();
      }
      if (!mounted) {
        await c.dispose();
        return next;
      }
      c.addListener(_onTick);
      await c.setVolume(project.originalVolume);
      _players[m.id] = c;
      final size = c.value.size;
      next = next.updateMedia(m.copyWith(
        duration: c.value.duration,
        width: size.width.round(),
        height: size.height.round(),
      ));
    }
    return next;
  }

  Future<Size?> _imageSize(MediaItem m) async {
    final done = Completer<Size?>();
    final stream = imageFor(m.source).resolve(ImageConfiguration.empty);
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (!done.isCompleted) {
        done.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }
      stream.removeListener(l);
    }, onError: (_, _) {
      if (!done.isCompleted) done.complete(null);
      stream.removeListener(l);
    });
    stream.addListener(l);
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _photoTimer?.cancel();
    if (_dirty) _saveNow();
    for (final c in _players.values) {
      c.removeListener(_onTick);
      c.dispose();
    }
    for (final c in _layerPlayers.values) {
      c.dispose();
    }
    for (final c in _audioPlayers.values) {
      c.dispose();
    }
    _music?.dispose();
    applyWebVideoFilter(null);
    super.dispose();
  }

  // ---------- persistence & side effects ----------

  void _projectChanged({bool save = true}) {
    for (final c in _players.values) {
      c.setVolume(p.originalVolume);
    }
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
    _syncLayerPlayers();
    _syncAudioPlayers();
    _loadThumbs();
    if (save) {
      _dirty = true;
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
    }
  }

  String _thumbKey(VideoClip c) => '${c.mediaId}@${c.sourceIn.inMilliseconds}';

  /// Requests frame thumbnails for video clips that don't have one yet.
  void _loadThumbs() {
    if (_project == null) return;
    for (final c in p.clips) {
      final m = p.mediaFor(c);
      if (m == null || m.isImage || (m.source.isUrl && !kIsWeb)) continue;
      final key = _thumbKey(c);
      if (_thumbs.containsKey(key) || !_thumbsPending.add(key)) continue;
      videoThumbnail(m.source.location, c.sourceIn).then((img) {
        _thumbsPending.remove(key);
        if (img != null && mounted) setState(() => _thumbs[key] = img);
      });
    }
  }

  ImageProvider? _thumbFor(VideoClip c) {
    final m = p.mediaFor(c);
    if (m == null) return null;
    if (m.isImage) return ResizeImage(imageFor(m.source), height: 96);
    return _thumbs[_thumbKey(c)];
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

  // ---------- layers ----------

  /// Creates players for new video layers, drops ones for removed layers,
  /// and applies volumes.
  Future<void> _syncLayerPlayers() async {
    if (_project == null) return;
    final ids = {for (final l in p.layers) l.id};
    for (final id in _layerPlayers.keys.toList()) {
      if (!ids.contains(id)) _layerPlayers.remove(id)?.dispose();
    }
    for (final l in p.layers) {
      final m = p.mediaById(l.mediaId);
      if (m == null || m.isImage) continue;
      final existing = _layerPlayers[l.id];
      if (existing != null) {
        await existing.setVolume(l.volume);
        continue;
      }
      try {
        final c = await m.source.createController();
        await c.initialize();
        if (!mounted || _project == null || !p.layers.any((x) => x.id == l.id)) {
          await c.dispose();
          continue;
        }
        await c.setVolume(l.volume);
        _layerPlayers[l.id] = c;
        if (mounted) setState(() {});
        _syncLayers(seek: true);
      } catch (_) {}
    }
  }

  /// Creates players for new audio clips and drops removed ones.
  Future<void> _syncAudioPlayers() async {
    if (_project == null) return;
    final ids = {for (final a in p.audio) a.id};
    for (final id in _audioPlayers.keys.toList()) {
      if (!ids.contains(id)) _audioPlayers.remove(id)?.dispose();
    }
    for (final a in p.audio) {
      final existing = _audioPlayers[a.id];
      if (existing != null) {
        await existing.setVolume(a.volume.clamp(0.0, 1.0));
        continue;
      }
      try {
        final c = a.isAsset
            ? VideoPlayerController.asset(a.location)
            : await (a.isUrl
                    ? VideoSource.url(a.location)
                    : VideoSource.file(a.location))
                .createController();
        await c.initialize();
        if (!mounted || _project == null || !p.audio.any((x) => x.id == a.id)) {
          await c.dispose();
          continue;
        }
        await c.setVolume(a.volume.clamp(0.0, 1.0));
        _audioPlayers[a.id] = c;
      } catch (_) {}
    }
  }

  /// Keeps layer players in step with the playhead.
  void _syncLayers({bool seek = false}) {
    if (_project == null) return;
    for (final a in p.audio) {
      final c = _audioPlayers[a.id];
      if (c == null || !c.value.isInitialized) continue;
      if (_playing && a.activeAt(_t)) {
        if (!c.value.isPlaying) {
          c.seekTo(a.sourceIn + (_t - a.start));
          c.play();
        }
      } else if (c.value.isPlaying) {
        c.pause();
      }
    }
    for (final l in p.layers) {
      final c = _layerPlayers[l.id];
      if (c == null || !c.value.isInitialized) continue;
      if (l.visibleAt(_t)) {
        final target = l.sourceIn + (_t - l.start);
        if (_playing) {
          if (!c.value.isPlaying) {
            c.seekTo(target);
            c.play();
          }
        } else if (seek) {
          c.pause();
          c.seekTo(target);
        }
      } else if (c.value.isPlaying) {
        c.pause();
      }
    }
  }

  // ---------- playback across clips ----------

  void _advance() {
    if (_clip + 1 < p.clips.length) {
      _enterClip(_clip + 1, p.clips[_clip + 1].sourceIn, play: true);
    } else {
      _pause();
      _seek(Duration.zero);
    }
  }

  void _onTick() {
    final c = _active;
    if (!_playing || _project == null || c == null) return;
    final clip = p.clips[_clip];
    final pos = c.value.position;
    if (pos >= clip.sourceOut - const Duration(milliseconds: 30) ||
        (!c.value.isPlaying && c.value.isCompleted)) {
      _advance();
      return;
    }
    final off = pos - clip.sourceIn;
    setState(() {
      _t = p.clipStart(_clip) +
          Duration(microseconds: (off.inMicroseconds / clip.speed).round());
    });
    _syncLayers();
  }

  void _onPhotoTick(Timer _) {
    if (!_playing || _project == null || _active != null) return;
    final now = DateTime.now();
    final dt = now.difference(_photoTick);
    _photoTick = now;
    final end = p.clipStart(_clip) + p.clips[_clip].timelineLength;
    final next = _t + dt;
    if (next >= end - const Duration(milliseconds: 20)) {
      setState(() => _t = end);
      _advance();
    } else {
      setState(() => _t = next);
    }
    _syncLayers();
  }

  Future<void> _enterClip(int index, Duration sourcePos,
      {bool play = false}) async {
    final clip = p.clips[index];
    final player = _players[clip.mediaId];
    if (!identical(player, _active)) {
      await _active?.pause();
      setState(() => _active = player);
    }
    _clip = index;
    if (player == null) {
      // Photo clip: a timer moves the playhead.
      _photoTimer?.cancel();
      if (play) {
        _photoTick = DateTime.now();
        _photoTimer = Timer.periodic(const Duration(milliseconds: 33), _onPhotoTick);
      }
      return;
    }
    _photoTimer?.cancel();
    await player.setVolume((p.originalVolume * clip.volume).clamp(0.0, 1.0));
    await player.setPlaybackSpeed(clip.speed);
    await player.seekTo(sourcePos);
    if (play && _playing) await player.play();
  }

  void _seek(Duration t) {
    if (_project == null) return;
    final clamped =
        t < Duration.zero ? Duration.zero : (t > p.duration ? p.duration : t);
    final hit = p.hitTest(clamped);
    if (hit == null) return;
    setState(() => _t = clamped);
    _enterClip(hit.index, hit.sourcePosition);
    _syncLayers(seek: true);
  }

  void _play() {
    if (_t >= p.duration - const Duration(milliseconds: 50)) {
      _seek(Duration.zero);
    }
    final hit = p.hitTest(_t)!;
    setState(() => _playing = true);
    _enterClip(hit.index, hit.sourcePosition, play: true);
    _syncMusicPosition(play: true);
    _syncLayers(seek: true);
  }

  void _pause() {
    _active?.pause();
    for (final c in _layerPlayers.values) {
      c.pause();
    }
    for (final c in _audioPlayers.values) {
      c.pause();
    }
    _photoTimer?.cancel();
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
    if (_selectedLayer != null) {
      final i = _selectedLayer!;
      setState(() => _selectedLayer = null);
      _apply(p.removeLayer(i));
      return;
    }
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

  Future<void> _appendMedia(List<(VideoSource, MediaKind)> picked,
      {bool quiet = false}) async {
    final items = [
      for (final (src, kind) in picked)
        MediaItem(id: DraftStore.newId() + src.name.hashCode.toString(),
            source: src, kind: kind),
    ];
    try {
      final loaded = await _loadPlayers(p.copyWith(media: [...p.media, ...items]));
      if (!mounted) return;
      final fresh = [for (final m in items) loaded.mediaById(m.id)!];
      final end = p.duration;
      _apply(loaded.copyWith(
        clips: [...p.clips, for (final m in fresh) Project.clipFor(m)],
      ));
      _seek(end);
      if (!quiet) _toast('Added ${fresh.length} item${fresh.length == 1 ? '' : 's'}');
    } catch (e) {
      if (mounted) _toast('Could not open that file');
    }
  }

  /// Lets the user choose files (and demo media on web). Empty if cancelled.
  Future<List<(VideoSource, MediaKind)>> _pickSources({String? title}) async {
    _pause();
    Future<List<(VideoSource, MediaKind)>> device() async {
      final files = await FilePicker.pickFiles(type: FileType.media);
      return [
        for (final f in files)
          (
            f.path != null
                ? VideoSource.file(f.path!, name: f.name)
                : VideoSource.url(f.uri.toString(), name: f.name),
            mediaKindFor(f.name),
          ),
      ];
    }

    if (!kIsWeb) return device();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ListTile(
              leading: const Icon(Icons.perm_media_outlined, color: RizColors.cyan),
              title: const Text('Videos or photos from device'),
              onTap: () => Navigator.of(ctx).pop('device'),
            ),
            ListTile(
              key: const Key('add-demo-photo'),
              leading: const Icon(Icons.image_outlined, color: RizColors.pink),
              title: const Text('Demo photo'),
              onTap: () => Navigator.of(ctx).pop('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.movie_outlined, color: RizColors.violet),
              title: const Text('Demo video'),
              onTap: () => Navigator.of(ctx).pop('video'),
            ),
          ],
        ),
      ),
    );
    return switch (choice) {
      'device' => await device(),
      'photo' => [(const VideoSource.url('demo_photo.jpg', name: 'Demo photo'), MediaKind.image)],
      'video' => [(const VideoSource.url('demo.mp4', name: 'Demo'), MediaKind.video)],
      _ => const [],
    };
  }

  Future<void> _addMediaSheet() async {
    final picked = await _pickSources();
    if (picked.isNotEmpty && mounted) await _appendMedia(picked);
  }

  /// Turns picked sources into media items with durations/sizes loaded.
  Future<List<MediaItem>> _loadNewMedia(List<(VideoSource, MediaKind)> picked) async {
    final items = [
      for (final (src, kind) in picked)
        MediaItem(
            id: DraftStore.newId() + src.location.hashCode.toString(),
            source: src,
            kind: kind),
    ];
    final loaded = await _loadPlayers(p.copyWith(media: [...p.media, ...items]));
    return [for (final m in items) loaded.mediaById(m.id) ?? m];
  }

  Future<void> _addLayer() async {
    final picked = await _pickSources(title: 'Add a layer on top');
    if (picked.isEmpty || !mounted) return;
    try {
      final m = (await _loadNewMedia([picked.first])).first;
      if (!mounted) return;
      final room = p.duration - _t;
      final want = m.isImage ? const Duration(seconds: 3) : m.duration;
      final len = want < room ? want : room;
      final layer = Layer(
        id: 'L${DraftStore.newId()}',
        mediaId: m.id,
        start: _t,
        sourceIn: Duration.zero,
        sourceOut: len < Project.minClip ? Project.minClip : len,
      );
      _apply(p.copyWith(media: [...p.media, m], layers: [...p.layers, layer]));
      setState(() {
        _selectedLayer = p.layers.length - 1;
        _selectedText = null;
      });
    } catch (_) {
      if (mounted) _toast('Could not open that file');
    }
  }

  Future<void> _editLayer(int i) async {
    _pause();
    final l = p.layers[i];
    final m = p.mediaById(l.mediaId);
    final result = await showModalBottomSheet<LayerEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
          child: LayerSheet(initial: l, hasSound: m != null && !m.isImage)),
    );
    if (result == null) return;
    if (result.delete) {
      setState(() => _selectedLayer = null);
      _apply(p.removeLayer(i));
    } else {
      _apply(p.updateLayer(i, result.layer!));
    }
  }

  Future<void> _applyLayout() async {
    _pause();
    final tpl = await showModalBottomSheet<LayoutTemplate>(
      context: context,
      builder: (_) => const LayoutPickerSheet(
          note: 'Your current video goes in frame 1. You can pick the rest next.'),
    );
    if (tpl == null || !mounted) return;
    // Current media in a sensible order: main clip first, then layers, rest.
    final ids = <String>[
      p.clips.first.mediaId,
      for (final l in p.layers) l.mediaId,
      for (final c in p.clips) c.mediaId,
    ];
    final items = <MediaItem>[];
    for (final id in ids) {
      final m = p.mediaById(id);
      if (m != null && !items.any((x) => x.id == id)) items.add(m);
    }
    if (items.length < tpl.slotCount) {
      final need = tpl.slotCount - items.length;
      final picked = await _pickSources(
          title: 'Pick $need more video${need == 1 ? '' : 's'} or photo${need == 1 ? '' : 's'}');
      if (!mounted) return;
      items.addAll(await _loadNewMedia(picked.take(need).toList()));
    }
    if (!mounted) return;
    final built = Project.fromLayout(tpl, items);
    setState(() {
      _selectedLayer = null;
      _selectedText = null;
    });
    _apply(built.copyWith(
      media: {for (final m in [...p.media, ...items]) m.id: m}.values.toList(),
      texts: [...built.texts, ...p.texts],
      grade: p.grade,
      music: p.music,
      clearMusic: p.music == null,
      originalVolume: p.originalVolume,
    ));
    _seek(Duration.zero);
  }

  Future<void> _editLook() async {
    _pause();
    final index = _activeClip;
    final before = p;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LookSheet(
        initial: p.clips[index].look,
        isPhoto: p.mediaFor(p.clips[index])?.isImage ?? false,
        onChanged: (look) => setState(() => _project = p.setLook(index, look)),
      ),
    );
    final edited = p;
    setState(() => _project = before);
    if (ok == true && !identical(edited.clips[index].look, before.clips[index].look)) {
      _apply(edited);
    }
  }

  // ---------- voiceover / sound effects / clip volume ----------

  Future<void> _voiceover() async {
    _pause();
    final start = _t;
    final take = await showModalBottomSheet<VoiceoverTake>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => VoiceoverSheet(
        onStart: () {
          // Mute the preview so the mic doesn't pick it up twice.
          for (final c in _players.values) {
            c.setVolume(0);
          }
          _play();
        },
        onStop: () {
          _pause();
          _projectChanged(save: false);
        },
      ),
    );
    if (take == null || !mounted) return;
    _apply(p.addAudio(AudioClip(
      id: 'A${DraftStore.newId()}',
      location: take.path,
      kind: AudioKind.voiceover,
      start: start,
      sourceIn: Duration.zero,
      sourceOut: take.length,
      name: 'Voiceover',
    )));
    _seek(start);
  }

  Future<void> _soundEffect() async {
    _pause();
    final fx = await showModalBottomSheet<SoundEffect>(
      context: context,
      builder: (_) => const SoundEffectsSheet(),
    );
    if (fx == null || !mounted) return;
    _apply(p.addAudio(AudioClip(
      id: 'A${DraftStore.newId()}',
      location: fx.asset,
      isAsset: true,
      kind: AudioKind.sfx,
      start: _t,
      sourceIn: Duration.zero,
      sourceOut: fx.length,
      name: fx.label,
    )));
  }

  Future<void> _editAudio(int i) async {
    _pause();
    final r = await showModalBottomSheet<AudioClipEdit>(
      context: context,
      builder: (_) => AudioClipSheet(initial: p.audio[i], playhead: _t),
    );
    if (r == null) return;
    _apply(r.delete ? p.removeAudio(i) : p.updateAudio(i, r.clip!));
  }

  Future<void> _clipVolume() async {
    _pause();
    final i = _activeClip;
    final m = p.mediaFor(p.clips[i]);
    if (m == null || m.isImage) {
      _toast('Photos have no sound. Add music or a voiceover instead');
      return;
    }
    final v = await showModalBottomSheet<double>(
      context: context,
      builder: (_) => ClipVolumeSheet(initial: p.clips[i].volume),
    );
    if (v != null && v != p.clips[i].volume) _apply(p.setClipVolume(i, v));
  }

  Future<void> _canvas() async {
    _pause();
    final before = p;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => CanvasSheet(
        ratio: p.canvas,
        background: p.background,
        onChanged: (r, b) =>
            setState(() => _project = p.copyWith(canvas: r, background: b)),
      ),
    );
    final edited = p;
    setState(() => _project = before);
    if (ok == true &&
        (edited.canvas != before.canvas ||
            edited.background != before.background)) {
      _apply(edited);
    }
  }

  Future<void> _speed() async {
    _pause();
    final index = _activeClip;
    if (p.mediaFor(p.clips[index])?.isImage ?? false) {
      _toast('Drag the clip edge to change how long a photo shows');
      return;
    }
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

  // ---------- trim / zoom / arrange / stickers ----------

  void _zoom(double factor) =>
      setState(() => _pps = (_pps * factor).clamp(_minPps, _maxPps));

  void _tapClip(int i) {
    if (_playing) _pause();
    setState(() => _selectedText = null);
    _seek(p.clipStart(i));
  }

  void _trimStart(int i, TrimEdge edge) {
    _pause();
    _trimBase = p;
    _trimIndex = i;
    _trimEdge = edge;
  }

  void _trimUpdate(double dxSeconds) {
    final base = _trimBase;
    if (base == null) return;
    final c = base.clips[_trimIndex];
    final delta =
        Duration(microseconds: (dxSeconds * 1e6 * c.speed).round());
    final media = base.mediaFor(c);
    final src = media == null || media.isImage
        ? kMaxPhotoLength
        : (_players[c.mediaId]?.value.duration ?? media.duration);
    Duration clampD(Duration v, Duration lo, Duration hi) =>
        v < lo ? lo : (v > hi ? hi : v);
    final next = _trimEdge == TrimEdge.start
        ? base.trimClip(_trimIndex,
            clampD(c.sourceIn + delta, Duration.zero, c.sourceOut - Project.minClip),
            c.sourceOut)
        : base.trimClip(_trimIndex, c.sourceIn,
            clampD(c.sourceOut + delta, c.sourceIn + Project.minClip, src));
    final nc = next.clips[_trimIndex];
    setState(() {
      _project = next;
      _clip = _trimIndex;
      _t = _trimEdge == TrimEdge.start
          ? next.clipStart(_trimIndex)
          : next.clipStart(_trimIndex) + nc.timelineLength -
              const Duration(milliseconds: 1);
    });
    _players[c.mediaId]
        ?.seekTo(_trimEdge == TrimEdge.start ? nc.sourceIn : nc.sourceOut);
  }

  void _trimEnd() {
    final base = _trimBase;
    _trimBase = null;
    if (base == null || identical(base, p)) return;
    final edited = p;
    _project = base;
    _apply(edited);
  }

  Future<void> _arrange() async {
    _pause();
    if (p.clips.length < 2) {
      _toast('Split the video first to get clips to arrange');
      return;
    }
    final order = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ArrangeSheet(project: p),
    );
    if (order == null) return;
    final unchanged = [for (var i = 0; i < order.length; i++) i];
    if (order.join(',') == unchanged.join(',')) return;
    _apply(p.copyWith(clips: [for (final i in order) p.clips[i]]));
  }

  Future<void> _stickers([int? index]) async {
    _pause();
    final existing = index == null ? null : p.texts[index];
    final picked = await showModalBottomSheet<StickerChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StickerSheet(
        initialColor: existing?.color,
      ),
    );
    if (picked == null) return;
    if (existing != null && index != null) {
      _apply(p.updateText(
          index, existing.copyWith(sticker: picked.index, color: picked.color)));
      return;
    }
    _apply(p.addText(TextOverlay(
      text: '',
      sticker: picked.index,
      color: picked.color,
      start: _t,
      end: _minDur(_t + const Duration(seconds: 3), p.duration),
      position: const Offset(0.5, 0.4),
      sizeFraction: 0.08,
    )));
    setState(() => _selectedText = p.texts.length - 1);
  }

  Future<void> _addOrEditText([int? index]) async {
    if (index != null && p.texts[index].isSticker) return _stickers(index);
    _pause();
    final existing = index == null ? null : p.texts[index];
    final result = await showModalBottomSheet<TextOverlay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(child: TextEditorSheet(
        initial: existing ??
            TextOverlay(
              text: '',
              start: _t,
              end: _minDur(_t + const Duration(seconds: 3), p.duration),
            ),
      )),
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
    ..showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      // Float above the toolbar so tools stay tappable.
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
    ));

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
        previewSize: _previewSize,
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
                      pxPerSecond: _pps,
                      onScrub: (t) {
                        if (_playing) _pause();
                        _seek(t);
                      },
                      onTapText: (i) => setState(() {
                        _selectedText = i;
                        _selectedLayer = null;
                      }),
                      selectedLayer: _selectedLayer,
                      onTapAudio: _editAudio,
                      onTapLayer: (i) => setState(() {
                        _selectedLayer = i;
                        _selectedText = null;
                      }),
                      onTapClip: _tapClip,
                      onLongPressClip: (_) => _arrange(),
                      onTrimStart: _trimStart,
                      onTrimUpdate: _trimUpdate,
                      onTrimEnd: _trimEnd,
                      thumbFor: _thumbFor,
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
    final clip = p.clips[_clip.clamp(0, p.clips.length - 1)];
    return GestureDetector(
      onTap: () {
        if (_selectedText != null || _selectedLayer != null) {
          setState(() {
            _selectedText = null;
            _selectedLayer = null;
          });
        } else {
          _playing ? _pause() : _play();
        }
      },
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: p.canvasAspect(
              fallback: _previewSize.width / _previewSize.height),
          child: LayoutBuilder(builder: (context, box) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (!p.mainFrame.isFull)
                  Positioned.fill(
                    child: ColoredBox(
                        color: Color(p.background.argb ?? 0xFF000000)),
                  ),
                Positioned(
                  left: p.mainFrame.x * box.maxWidth,
                  top: p.mainFrame.y * box.maxHeight,
                  width: p.mainFrame.w * box.maxWidth,
                  height: p.mainFrame.h * box.maxHeight,
                  child: ClipRect(
                    child: _withTransition(
                      tr,
                      Size(p.mainFrame.w * box.maxWidth,
                          p.mainFrame.h * box.maxHeight),
                      _withMotion(
                        clip,
                        p.mainCover
                            ? _graded(clip, _media(clip, BoxFit.cover))
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  _background(clip),
                                  _graded(clip, _media(clip, BoxFit.contain)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < p.layers.length; i++)
                  if (p.layers[i].visibleAt(_t) || i == _selectedLayer)
                    _layerView(i, box.biggest),
                for (final i in visible)
                  _TextOnPreview(
                    overlay: _shownText(p.texts[i]).overlay,
                    alpha: _shownText(p.texts[i]).alpha,
                    box: box.biggest,
                    selected: i == _selectedText,
                    dimmed: !p.texts[i].visibleAt(_t),
                    onTap: () => setState(() {
                      _selectedText = i;
                      _selectedLayer = null;
                    }),
                    onDoubleTap: () => _addOrEditText(i),
                    onMoved: (pos) {
                      setState(() {
                        _selectedText = i;
                        final o = p.texts[i];
                        _project = p.updateText(
                          i,
                          o.keyframes.isEmpty
                              ? o.copyWith(position: pos)
                              : o.copyWith(
                                  keyframes: upsertKeyframe(
                                    o.keyframes,
                                    Keyframe(
                                      at: _t,
                                      pos: pos,
                                      opacity: sampleKeyframes(
                                              o.keyframes, _t, o.position, o.opacity)
                                          .opacity,
                                    ),
                                  ),
                                ),
                        );
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

  /// The clip's video or photo, fitted with [fit].
  /// The clip's video or photo with its framing (crop/flip/rotate),
  /// fitted into the parent with [fit].
  Widget _media(VideoClip clip, BoxFit fit) {
    final player = _players[clip.mediaId];
    final m = p.mediaFor(clip);
    Size? size;
    Widget? raw;
    if (player != null && player.value.isInitialized) {
      size = player.value.size;
      raw = VideoPlayer(player);
    } else if (m != null && m.isImage) {
      size = m.width != null && m.height != null
          ? Size(m.width!.toDouble(), m.height!.toDouble())
          : null;
      raw = Image(
        image: imageFor(m.source),
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: RizColors.textDim),
        ),
      );
      if (size == null) {
        // Size not known yet: show the photo without framing.
        return Image(image: imageFor(m.source), fit: fit, gaplessPlayback: true);
      }
    }
    if (raw == null || size == null) return const SizedBox.shrink();
    final look = clip.look;
    Widget child = SizedBox(width: size.width, height: size.height, child: raw);
    if (look.zoom > 1.0001) {
      child = ClipRect(
        child: Transform.scale(
          scale: look.zoom,
          alignment: Alignment(look.panX, look.panY),
          child: child,
        ),
      );
    }
    if (look.flipH || look.flipV) {
      child = Transform.flip(flipX: look.flipH, flipY: look.flipV, child: child);
    }
    if (look.turns != 0) child = RotatedBox(quarterTurns: look.turns, child: child);
    return FittedBox(fit: fit, clipBehavior: Clip.hardEdge, child: child);
  }

  /// Text as shown at the playhead: keyframes + in/out animation.
  ({TextOverlay overlay, double alpha}) _shownText(TextOverlay o) {
    final s = sampleKeyframes(o.keyframes, _t, o.position, o.opacity);
    final a = animAt(o.animIn, o.animOut, o.start, o.end, _t);
    return (overlay: o.copyWith(position: s.pos + a.offset), alpha: s.opacity * a.alpha);
  }

  /// Layer top-left + opacity at the playhead.
  ({Offset pos, double opacity}) _shownLayer(Layer l) => sampleKeyframes(
      l.keyframes, _t, Offset(l.frame.x, l.frame.y), l.opacity);

  bool get _hasKeyframeAtPlayhead {
    if (_selectedText != null && _selectedText! < p.texts.length) {
      return keyframeAt(p.texts[_selectedText!].keyframes, _t) >= 0;
    }
    if (_selectedLayer != null && _selectedLayer! < p.layers.length) {
      return keyframeAt(p.layers[_selectedLayer!].keyframes, _t) >= 0;
    }
    return false;
  }

  /// Adds a keyframe at the playhead for the selected text/layer, or removes
  /// the one already there.
  void _toggleKeyframe() {
    _pause();
    if (_selectedText != null) {
      final i = _selectedText!;
      final o = p.texts[i];
      final at = keyframeAt(o.keyframes, _t);
      if (at >= 0) {
        _apply(p.updateText(i, o.copyWith(keyframes: [...o.keyframes]..removeAt(at))));
        return;
      }
      final cur = sampleKeyframes(o.keyframes, _t, o.position, o.opacity);
      _apply(p.updateText(i, o.copyWith(
          keyframes: upsertKeyframe(o.keyframes,
              Keyframe(at: _t, pos: cur.pos, opacity: cur.opacity)))));
      if (o.keyframes.isEmpty) _toast('Keyframe added. Move the playhead, then drag to animate');
    } else if (_selectedLayer != null) {
      final i = _selectedLayer!;
      final l = p.layers[i];
      final at = keyframeAt(l.keyframes, _t);
      if (at >= 0) {
        _apply(p.updateLayer(i, l.copyWith(keyframes: [...l.keyframes]..removeAt(at))));
        return;
      }
      final cur = _shownLayer(l);
      _apply(p.updateLayer(i, l.copyWith(
          keyframes: upsertKeyframe(l.keyframes,
              Keyframe(at: _t, pos: cur.pos, opacity: cur.opacity)))));
      if (l.keyframes.isEmpty) _toast('Keyframe added. Move the playhead, then drag to animate');
    } else {
      _toast('Select a text, sticker or layer first');
    }
  }

  /// A layer in its frame; tap to select, drag to move.
  Widget _layerView(int i, Size box) {
    final l = p.layers[i];
    final shown = _shownLayer(l);
    final f = FrameRect(shown.pos.dx, shown.pos.dy, l.frame.w, l.frame.h);
    final m = p.mediaById(l.mediaId);
    final player = _layerPlayers[l.id];
    Widget media;
    if (player != null && player.value.isInitialized) {
      final size = player.value.size;
      media = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
            width: size.width, height: size.height, child: VideoPlayer(player)),
      );
    } else if (m != null && m.isImage) {
      media = Image(image: imageFor(m.source), fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      media = const ColoredBox(color: RizColors.surfaceHigh);
    }
    final lg = l.grade ?? p.grade;
    if (!lg.isIdentity && !(kIsWeb && player != null)) {
      media = ColorFiltered(
          colorFilter: ColorFilter.matrix(lg.flutterMatrix), child: media);
    }
    if (l.chromaKey != null) {
      final keyed = ChromaPreview.wrap(media, l.chromaKey!, l.keySimilarity);
      media = keyed ??
          Stack(fit: StackFit.expand, children: [
            media,
            const Positioned(
              left: 4,
              bottom: 4,
              child: _Badge('Green screen shows in export'),
            ),
          ]);
    }
    final selected = i == _selectedLayer;
    return Positioned(
      left: f.x * box.width,
      top: f.y * box.height,
      width: f.w * box.width,
      height: f.h * box.height,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedLayer = i;
          _selectedText = null;
        }),
        onDoubleTap: () => _editLayer(i),
        onPanStart: (_) {
          _undo.add(p);
          _redo.clear();
          setState(() {
            _selectedLayer = i;
            _selectedText = null;
          });
        },
        onPanUpdate: (d) => setState(() {
          final layer = p.layers[i];
          final now = _shownLayer(layer);
          final cur = FrameRect(now.pos.dx, now.pos.dy, layer.frame.w, layer.frame.h)
              .moveTo(Offset(now.pos.dx + d.delta.dx / box.width,
                  now.pos.dy + d.delta.dy / box.height));
          _project = p.updateLayer(
            i,
            layer.keyframes.isEmpty
                ? layer.copyWith(frame: cur)
                : layer.copyWith(
                    keyframes: upsertKeyframe(layer.keyframes,
                        Keyframe(at: _t, pos: Offset(cur.x, cur.y), opacity: now.opacity)),
                  ),
          );
        }),
        onPanEnd: (_) => _projectChanged(),
        child: Opacity(
          opacity: (l.visibleAt(_t) ? 1.0 : 0.45) * shown.opacity.clamp(0.0, 1.0),
          child: Container(
            foregroundDecoration: selected
                ? BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFB36B), width: 2))
                : null,
            child: ClipRect(child: media),
          ),
        ),
      ),
    );
  }

  /// Mirrors the export's transition filters (fade/slide/wipe/zoom).
  Widget _withTransition(TransitionState tr, Size box, Widget layer) {
    final s = tr.strength.clamp(0.0, 1.0);
    if (s <= 0 || tr.type == TransitionType.none) return layer;
    final fade = tr.type.fadeColor;
    if (fade != null) {
      return Stack(fit: StackFit.expand, children: [
        layer,
        IgnorePointer(child: ColoredBox(color: Color(fade).withValues(alpha: s))),
      ]);
    }
    final dir = tr.leaving ? -1.0 : 1.0;
    return switch (tr.type) {
      TransitionType.slideLeft => Transform.translate(
          offset: Offset(dir * s * box.width, 0), child: layer),
      TransitionType.slideUp => Transform.translate(
          offset: Offset(0, dir * s * box.height), child: layer),
      TransitionType.zoom => ClipRect(
          child: Transform.scale(scale: 1 + 0.5 * s, child: layer)),
      TransitionType.wipe => Stack(fit: StackFit.expand, children: [
          layer,
          Positioned(
            left: tr.leaving ? 0 : (1 - s) * box.width,
            width: s * box.width,
            top: 0,
            bottom: 0,
            child: const ColoredBox(color: Colors.black),
          ),
        ]),
      _ => layer,
    };
  }

  /// Wraps the clip layer in its Ken Burns motion at the current time.
  Widget _withMotion(VideoClip clip, Widget child) {
    if (clip.look.motion == Motion.none) return child;
    final start = p.clipStart(_clip.clamp(0, p.clips.length - 1));
    final len = clip.timelineLength.inMicroseconds;
    final progress = len == 0 ? 0.0 : (_t - start).inMicroseconds / len;
    final mo = clip.look.motionAt(progress);
    return ClipRect(
      child: Transform.scale(
        scale: mo.scale,
        alignment: Alignment(mo.alignX, mo.alignY),
        child: child,
      ),
    );
  }

  /// Applies the colour grade where Flutter can (web videos use CSS).
  Widget _graded(VideoClip clip, Widget child) {
    final isVideo = _players.containsKey(clip.mediaId);
    if (p.grade.isIdentity || (kIsWeb && isVideo)) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(p.grade.flutterMatrix),
      child: child,
    );
  }

  Widget _background(VideoClip clip) {
    final argb = p.background.argb;
    if (argb != null) return ColoredBox(color: Color(argb));
    final isVideo = _players.containsKey(clip.mediaId);
    if (kIsWeb && isVideo) {
      // A web <video> can't be drawn twice or blurred; use a soft glow.
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF3A1D6E), Color(0xFF0B0620)],
            radius: 0.9,
          ),
        ),
      );
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: _graded(clip, _media(clip, BoxFit.cover)),
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
          if (_selectedText != null || _selectedLayer != null)
            IconButton(
              key: const Key('keyframe'),
              tooltip: _hasKeyframeAtPlayhead ? 'Remove keyframe' : 'Add keyframe',
              visualDensity: VisualDensity.compact,
              onPressed: _toggleKeyframe,
              icon: Icon(
                _hasKeyframeAtPlayhead ? Icons.diamond : Icons.diamond_outlined,
                size: 20,
                color: _hasKeyframeAtPlayhead ? RizColors.cyan : RizColors.textDim,
              ),
            ),
          _ZoomButton(
            icon: Icons.zoom_out,
            tooltip: 'Zoom out timeline',
            onTap: _pps > _minPps ? () => _zoom(1 / 1.5) : null,
          ),
          _ZoomButton(
            icon: Icons.zoom_in,
            tooltip: 'Zoom in timeline',
            onTap: _pps < _maxPps ? () => _zoom(1.5) : null,
          ),
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
              _Tool(icon: Icons.add_photo_alternate_outlined, label: 'Add', color: RizColors.cyan, onTap: _addMediaSheet),
              _Tool(icon: Icons.dashboard_customize_outlined, label: 'Layout', color: const Color(0xFFFFE14D), onTap: _applyLayout),
              _Tool(
                icon: _selectedLayer != null ? Icons.tune : Icons.layers_outlined,
                label: _selectedLayer != null ? 'Edit layer' : 'Layer',
                color: const Color(0xFFFFB36B),
                onTap: () => _selectedLayer != null ? _editLayer(_selectedLayer!) : _addLayer(),
              ),
              _Tool(icon: Icons.aspect_ratio, label: 'Canvas', color: const Color(0xFFFFB36B), onTap: _canvas),
              _Tool(icon: Icons.crop_rotate, label: 'Edit', color: const Color(0xFF9DFF6B), onTap: _editLook),
              _Tool(icon: Icons.content_cut, label: 'Split', color: RizColors.magenta, onTap: _split),
              _Tool(icon: Icons.speed, label: 'Speed', color: RizColors.cyan, onTap: _speed),
              _Tool(icon: Icons.auto_awesome, label: 'Filters', color: RizColors.violet, onTap: _filters),
              _Tool(icon: Icons.mic_none, label: 'Voiceover', color: RizColors.cyan, onTap: _voiceover),
              _Tool(icon: Icons.graphic_eq, label: 'Sound FX', color: RizColors.blue, onTap: _soundEffect),
              _Tool(icon: Icons.volume_up_outlined, label: 'Volume', color: RizColors.pink, onTap: _clipVolume),
              _Tool(icon: Icons.music_note, label: 'Audio', color: RizColors.blue, onTap: _audio),
              _Tool(
                icon: textSelected ? Icons.edit : Icons.text_fields,
                label: textSelected
                  ? (p.texts[_selectedText!].isSticker ? 'Edit sticker' : 'Edit text')
                  : 'Text',
                color: RizColors.pink,
                onTap: () => _addOrEditText(_selectedText),
              ),
              _Tool(icon: Icons.emoji_emotions_outlined, label: 'Stickers', color: const Color(0xFFFFD54F), onTap: () => _stickers()),
              _Tool(icon: Icons.view_week_outlined, label: 'Arrange', color: RizColors.textDim, onTap: _arrange),
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

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xAA000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
      );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: RizColors.textDim),
    );
  }
}

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
    this.alpha = 1,
  });

  final TextOverlay overlay;
  final double alpha;
  final Size box;
  final bool selected, dimmed;
  final VoidCallback onTap, onDoubleTap, onMoveStart, onMoveEnd;
  final ValueChanged<Offset> onMoved;

  @override
  Widget build(BuildContext context) {
    // Same sizing rule as the exported PNG (font = fraction of frame height).
    final fontSize = overlay.sizeFraction * box.height;
    final pad = fontSize * 0.35;
    if (overlay.isBand) {
      return Positioned(
        left: 0,
        width: box.width,
        top: overlay.position.dy * box.height,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: GestureDetector(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onPanStart: (_) => onMoveStart(),
            onPanEnd: (_) => onMoveEnd(),
            onPanUpdate: (d) => onMoved(Offset(
              0.5,
              (overlay.position.dy + d.delta.dy / box.height).clamp(0.05, 0.95),
            )),
            child: Opacity(
              opacity: (dimmed ? 0.45 : 1.0) * alpha.clamp(0.0, 1.0),
              child: Container(
                width: box.width,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: Color(overlay.band!),
                  border: selected
                      ? Border.all(color: RizColors.cyan, width: 1.5)
                      : null,
                ),
                child: Text.rich(
                  overlaySpan(overlay, fontSize),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }
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
            opacity: (dimmed ? 0.45 : 1.0) * alpha.clamp(0.0, 1.0),
            child: Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: overlay.background ? const Color(0xCC07031C) : null,
                borderRadius: BorderRadius.circular(pad),
                border: selected
                    ? Border.all(color: RizColors.cyan, width: 1.5)
                    : null,
              ),
              child: Text.rich(
                overlaySpan(overlay, fontSize),
                textAlign: TextAlign.center,
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
