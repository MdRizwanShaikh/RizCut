import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/editor/media.dart';
import '../../features/editor/project.dart';
import '../../features/editor/video_source.dart';

/// A saved, editable project.
class Draft {
  const Draft({
    required this.id,
    required this.source,
    required this.project,
    required this.updatedAt,
  });

  final String id;
  final VideoSource source;
  final Project project;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'source': source.toJson(),
        'project': project.toJson(),
        'updated': updatedAt.millisecondsSinceEpoch,
      };

  factory Draft.fromJson(Map<String, Object?> j) => Draft(
        id: j['id'] as String,
        source: VideoSource.fromJson((j['source'] as Map).cast()),
        project: Project.fromJson(
          (j['project'] as Map).cast(),
          fallback: _legacyMedia((j['source'] as Map).cast()),
        ),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((j['updated'] as num).toInt()),
      );
}

MediaItem _legacyMedia(Map<String, Object?> source) {
  final s = VideoSource.fromJson(source);
  return MediaItem(id: 'm0', source: s, kind: mediaKindOf(s));
}

/// Drafts live only on this device (no login, no server).
class DraftStore {
  DraftStore._();
  static final instance = DraftStore._();

  static const _key = 'rizcut.drafts.v1';
  static const maxDrafts = 30;

  /// Blob URLs (web file picks) die with the page, so they can't be reopened.
  static bool canPersist(VideoSource s) =>
      !(s.isUrl && s.location.startsWith('blob:'));

  Future<List<Draft>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final drafts = [
        for (final d in jsonDecode(raw) as List)
          Draft.fromJson((d as Map).cast()),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(Draft draft) async {
    if (!canPersist(draft.source)) return;
    final drafts = (await list()).where((d) => d.id != draft.id).toList()
      ..insert(0, draft);
    await _write(drafts.take(maxDrafts).toList());
  }

  Future<void> delete(String id) async =>
      _write((await list()).where((d) => d.id != id).toList());

  Future<void> _write(List<Draft> drafts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final d in drafts) d.toJson()]));
    } catch (_) {
      // Storage unavailable (private mode etc.) — drafts are best effort.
    }
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
