/// Web stand-in for dart:io's Directory (voiceover recording is Android-only).
class Directory {
  Directory(this.path);
  final String path;
  Future<Directory> create({bool recursive = false}) async => this;
}
