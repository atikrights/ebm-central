import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

enum UpdateState { idle, checking, available, downloading, validating, readyToInstall, installing, relaunching, error }

final ValueNotifier<UpdateState> updateStateNotifier = ValueNotifier(UpdateState.idle);
final ValueNotifier<double> updateProgressNotifier = ValueNotifier(0.0);
final ValueNotifier<String> updateStatusNotifier = ValueNotifier('');
final ValueNotifier<bool> isUpdatingNotifier = ValueNotifier(false);

class UpdateService {
  static const String _updateUrl = 'https://api.github.com/repos/atikrights/ebm-central/releases';

  // ✅ SECURE: Token is injected at compile-time via --dart-define=GITHUB_TOKEN=xxx
  static const String _privateRepoToken = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');

  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  
  final Dio _dio = Dio();
  
  UpdateService._internal();

  // Initialize and check in background
  Future<void> initializeBackgroundUpdate() async {
    try {
      final updateInfo = await checkForUpdateFlow();
      final current = await _currentVersion;
      if (updateInfo != null && _isVersionNewer(current, updateInfo['version'])) {
        await startDirectUpdate(updateInfo);
      } else {
        await _cleanOldUpdates();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> checkForUpdateFlow() async {
    updateStateNotifier.value = UpdateState.checking;
    final releases = await getReleases();
    
    if (releases == null || releases.isEmpty) {
      updateStateNotifier.value = UpdateState.idle;
      return null;
    }

    final latest = releases.first;
    final String version = (latest['tag_name'] as String).replaceAll('v', '');
    final List assets = latest['assets'];
    
    Map<String, dynamic>? platformAsset;
    
    // Improved asset detection for all platforms
    if (Platform.isWindows) {
      // Priority: .msix -> .exe
      platformAsset = assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.msix'), orElse: () => null) ??
                      assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.exe'), orElse: () => null);
    } else if (Platform.isAndroid) {
      platformAsset = assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.apk'), orElse: () => null);
    } else if (Platform.isMacOS) {
      // Priority: .dmg -> .zip (containing macos)
      platformAsset = assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.dmg'), orElse: () => null) ??
                      assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.zip') && a['name'].toString().toLowerCase().contains('macos'), orElse: () => null);
    } else if (Platform.isIOS) {
      platformAsset = assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.ipa'), orElse: () => null);
    }

    if (platformAsset == null) {
      // If no platform specific asset, look for a 'universal' zip or similar
      platformAsset = assets.firstWhere((a) => a['name'].toString().toLowerCase().endsWith('.zip'), orElse: () => null);
    }

    if (platformAsset == null) {
      updateStateNotifier.value = UpdateState.idle;
      return null;
    }

    final info = {
      'version': version,
      'url': platformAsset['url'],
      'browser_download_url': platformAsset['browser_download_url'],
      'name': platformAsset['name'],
      'size': platformAsset['size'],
      'sizeMb': (platformAsset['size'] / (1024 * 1024)).toStringAsFixed(1),
      'notes': latest['body'],
      'published_at': latest['published_at'],
      'tag_name': latest['tag_name'],
      'author': latest['author']['login'],
      'author_avatar': latest['author']['avatar_url'],
    };

    final current = await _currentVersion;
    
    // Check if the file already exists locally to skip download
    bool alreadyDownloaded = false;
    try {
      final updateDirPath = await getUpdateFolderPath();
      final filePath = '$updateDirPath/${platformAsset['name']}';
      if (await File(filePath).exists()) {
        alreadyDownloaded = true;
      }
    } catch (_) {}

    updateStateNotifier.value = _isVersionNewer(current, version) 
      ? (alreadyDownloaded ? UpdateState.readyToInstall : UpdateState.available) 
      : UpdateState.idle;
    
    // Debug logging for developers
    debugPrint('Checking for updates: $current -> $version');
    debugPrint('Already downloaded: $alreadyDownloaded');
    debugPrint('Found Platform Asset: ${platformAsset['name']}');

    return info;
  }

  Future<List<Map<String, dynamic>>?> getReleases() async {
    try {
      final headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'ebm-central-Production-App-Client',
      };
      
      if (_privateRepoToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_privateRepoToken';
      }
        
      final response = await _dio.get(
        _updateUrl, 
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500, // Handle 403 gracefully
        )
      );

      if (response.statusCode == 403) {
        debugPrint('GitHub rate limit reached (403). Waiting for cool-down...');
        return null;
      }

      if (response.statusCode != 200) return null;
      
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Update Check Failed (Network Issue): $e');
      return null;
    }
  }

  // Get the dedicated Update Folder path
  Future<String> getUpdateFolderPath() async {
    final baseDir = Platform.isAndroid 
        ? await getTemporaryDirectory() 
        : await getApplicationDocumentsDirectory();
    final updateDirPath = '${baseDir.path}/ebmCentral/Update - New Release';
    final directory = Directory(updateDirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return updateDirPath;
  }

  Future<void> startDirectUpdate(Map<String, dynamic> info) async {
    if (isUpdatingNotifier.value) return;
    isUpdatingNotifier.value = true;

    try {
      final updateDirPath = await getUpdateFolderPath();
      debugPrint('Target Download Folder: $updateDirPath');
      
      // 1. Resilient Cleanup: Delete files individually
      final directory = Directory(updateDirPath);
      if (await directory.exists()) {
        try {
          final entities = await directory.list().toList();
          for (var entity in entities) {
             if (entity is File) {
               await entity.delete();
               debugPrint('Deleted old file: ${entity.path}');
             }
          }
        } catch (e) {
          debugPrint('Non-critical cleanup error: $e');
        }
      } else {
        await directory.create(recursive: true);
      }

      final fileName = info['name'];
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 2. Download start
      updateStateNotifier.value = UpdateState.downloading;
      updateStatusNotifier.value = 'Preparing download...';
      
      final headers = _privateRepoToken.isNotEmpty 
        ? {'Authorization': 'Bearer $_privateRepoToken', 'Accept': 'application/octet-stream'}
        : {'Accept': 'application/octet-stream'};

      String downloadUrl = _privateRepoToken.isNotEmpty ? info['url'] : info['browser_download_url'];
      debugPrint('Downloading from: $downloadUrl');

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 20),
        followRedirects: true,
      ));

      int retryCount = 0;
      bool success = false;
      while (retryCount < 3 && !success) {
        try {
          await dio.download(
            downloadUrl,
            filePath,
            options: Options(headers: headers),
            onReceiveProgress: (count, total) {
              if (total != -1) {
                updateProgressNotifier.value = count / total;
                updateStatusNotifier.value = 'Downloading: ${(count / (1024 * 1024)).toStringAsFixed(1)}MB / ${(total / (1024 * 1024)).toStringAsFixed(1)}MB';
              }
            },
          );
          success = true;
        } catch (e) {
          retryCount++;
          if (retryCount >= 3) rethrow;
          updateStatusNotifier.value = 'Retry $retryCount/3...';
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Verify integrity
      updateStateNotifier.value = UpdateState.validating;
      updateStatusNotifier.value = 'Verifying secure package...';
      await Future.delayed(const Duration(seconds: 1));

      if (await file.length() == info['size']) {
        updateStateNotifier.value = UpdateState.readyToInstall;
        updateStatusNotifier.value = 'Download Complete in "Update - New Release"';
      } else {
        throw Exception('File integrity check failed');
      }
    } catch (e) {
      updateStateNotifier.value = UpdateState.error;
      updateStatusNotifier.value = 'Download Failed: $e';
      isUpdatingNotifier.value = false;
    }
  }

  // Open the local update directory or launch/highlight the file
  Future<void> openUpdateFolder() async {
    final path = await getUpdateFolderPath();
    final directory = Directory(path);

    if (!await directory.exists()) return;

    // Check for files inside the folder
    final files = await directory.list().toList();
    if (files.isEmpty) {
      if (Platform.isWindows) {
        final winPath = path.replaceAll('/', '\\');
        await Process.run('explorer.exe', [winPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      }
      return;
    }

    final latestFile = files.first.path;

    if (Platform.isWindows) {
      // Open folder and HIGHLIGHT the setup file for manual install
      final winPath = latestFile.replaceAll('/', '\\');
      await Process.run('explorer.exe', ['/select,', winPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [latestFile]);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Trigger installer for Mobile
      if (latestFile.endsWith('.apk')) {
        await OpenFilex.open(latestFile, type: "application/vnd.android.package-archive");
      } else {
        await OpenFilex.open(latestFile);
      }
    }
  }

  Future<void> installUpdate(Map<String, dynamic> info) async {
    final updateDirPath = await getUpdateFolderPath();
    final filePath = '$updateDirPath/${info['name']}';
    await _installExecutingFile(filePath);
  }

  Future<void> _installExecutingFile(String path) async {
    updateStateNotifier.value = UpdateState.installing;
    updateStatusNotifier.value = 'Preparing installation...';
    await Future.delayed(const Duration(seconds: 1));

    if (Platform.isWindows) {
      if (path.toLowerCase().endsWith('.exe')) {
        updateStatusNotifier.value = 'Starting EXE installer...';
        await Process.start('cmd', ['/c', 'start', '""', '"$path"', '/VERYSILENT', '/SUPPRESSMSGBOXES'], 
          runInShell: true, mode: ProcessStartMode.detached);
      } else if (path.toLowerCase().endsWith('.msix')) {
        updateStatusNotifier.value = 'Starting MSIX installer...';
        await Process.start('cmd', ['/c', 'start', '""', '"$path"'], 
          runInShell: true, mode: ProcessStartMode.detached);
      } else {
        await Process.start(path, [], runInShell: true, mode: ProcessStartMode.detached);
      }
      
      updateStateNotifier.value = UpdateState.relaunching;
      updateStatusNotifier.value = 'Success! App closing to apply update...';
      await Future.delayed(const Duration(seconds: 3));
      exit(0);
    }

    if (Platform.isAndroid) {
      updateStatusNotifier.value = 'Opening APK file...';
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done) {
        updateStateNotifier.value = UpdateState.relaunching;
        updateStatusNotifier.value = 'Installer active.';
      } else {
        updateStateNotifier.value = UpdateState.error;
        updateStatusNotifier.value = 'Installer failed: ${result.message}';
        isUpdatingNotifier.value = false;
      }
    }

    if (Platform.isMacOS) {
      updateStatusNotifier.value = 'Opening update file...';
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done) {
        updateStateNotifier.value = UpdateState.relaunching;
        updateStatusNotifier.value = 'Update package opened.';
      } else {
        updateStateNotifier.value = UpdateState.error;
        updateStatusNotifier.value = 'Failed to open update file.';
        isUpdatingNotifier.value = false;
      }
    }
  }

  Future<void> _cleanOldUpdates() async {
    try {
      final path = await getUpdateFolderPath();
      final directory = Directory(path);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<String> get _currentVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  bool _isVersionNewer(String current, String online) {
    try {
      List<int> curr = current.split('.').map(int.parse).toList();
      List<int> next = online.split('.').map(int.parse).toList();
      for (int i = 0; i < curr.length && i < next.length; i++) {
        if (next[i] > curr[i]) return true;
        if (next[i] < curr[i]) return false;
      }
      return next.length > curr.length;
    } catch (_) {
      return online != current;
    }
  }
}
