import 'dart:typed_data';

/// A stub for dart:io to allow Flutter Web compilation.
/// All methods are no-ops — the actual dart:io is used on non-web platforms.
class File {
  final String path;
  File(this.path);

  bool existsSync() => false;
  int lengthSync() => 0;

  Future<File> copy(String newPath) async => File(newPath);
  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async => this;
  Future<String> readAsString() async => '';
  Future<List<int>> readAsBytes() async => [];
  Future<bool> exists() async => false;
  Future<File> create({bool recursive = false}) async => this;
  void deleteSync({bool recursive = false}) {}
  Future<void> delete({bool recursive = false}) async {}
}

class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}

class Directory {
  final String path;
  Directory(this.path);
  Future<Directory> create({bool recursive = false}) async => this;
  bool existsSync() => false;
}
