/// A stub for dart:io to allow web compilation.
class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
}

class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}
