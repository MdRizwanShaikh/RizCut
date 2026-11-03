import 'package:flutter/material.dart';

/// Built-in stickers. Kept as a const list (indexed by position) so icon
/// fonts can still be tree-shaken; drafts store the index.
const kStickers = <IconData>[
  Icons.favorite,
  Icons.star,
  Icons.local_fire_department,
  Icons.bolt,
  Icons.auto_awesome,
  Icons.celebration,
  Icons.emoji_emotions,
  Icons.sentiment_very_satisfied,
  Icons.mood,
  Icons.thumb_up,
  Icons.workspace_premium,
  Icons.music_note,
  Icons.headphones,
  Icons.camera_alt,
  Icons.flight,
  Icons.wb_sunny,
  Icons.nightlight,
  Icons.cloud,
  Icons.pets,
  Icons.local_pizza,
  Icons.cake,
  Icons.sports_esports,
  Icons.diamond,
  Icons.rocket_launch,
  Icons.arrow_forward,
  Icons.arrow_downward,
  Icons.check_circle,
  Icons.location_on,
];

IconData? stickerIcon(int? index) =>
    index == null || index < 0 || index >= kStickers.length
        ? null
        : kStickers[index];

/// Stickers are drawn this much larger than text of the same size setting.
const kStickerScale = 1.6;
