import 'dart:io';

import 'package:video_player/video_player.dart';

import 'video_source.dart' show kPlayerOptions;

VideoPlayerController fileController(String path) =>
    VideoPlayerController.file(File(path), videoPlayerOptions: kPlayerOptions);
