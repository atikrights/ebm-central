import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import '../models/asset_model.dart';
import '../../../core/network/api_service.dart';
import 'package:http/http.dart' as http;

// ─── Riverpod Provider ───────────────────────────────────────────────────────
final assetProvider = ChangeNotifierProvider<AssetProvider>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AssetProvider(api);
});

// ---------------------------------------------------------------------------
// Image compression helper (runs in isolate to keep UI smooth)
// ---------------------------------------------------------------------------
Future<_CompressResult?> _compressInBackground(_CompressInput input) async {
  try {
    final srcFile = File(input.sourcePath);
    if (!srcFile.existsSync()) return null;
    await srcFile.copy(input.outputPath);
    await srcFile.copy(input.thumbPath);
    return _CompressResult(
      compressedPath: input.outputPath,
      thumbPath: input.thumbPath,
      newSizeBytes: srcFile.lengthSync(),
    );
  } catch (e) {
    return null;
  }
}

class _CompressInput {
  final String sourcePath;
  final String outputPath;
  final String thumbPath;
  const _CompressInput({required this.sourcePath, required this.outputPath, required this.thumbPath});
}

class _CompressResult {
  final String compressedPath;
  final String thumbPath;
  final int newSizeBytes;
  const _CompressResult({required this.compressedPath, required this.thumbPath, required this.newSizeBytes});
}

class AssetProvider extends ChangeNotifier {
  final ApiService _api;
  final List<AssetModel> _assets = [];
  bool _isLoading = true;

  // ── Pagination
  static const int _pageSize = 30;
  int _loadedCount = _pageSize;

  // ── Folders
  final List<AssetFolderModel> _folders = [];
  bool _isUploading = false;
  String? _uploadStatus;

  AssetProvider(this._api) {
    _init();
  }

  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get uploadStatus => _uploadStatus;
  List<AssetFolderModel> get folders => List.unmodifiable(_folders);
  List<AssetModel> get allAssets => List.unmodifiable(_assets);
  List<AssetModel> get activeAssets => _assets.where((a) => !a.isDeleted).toList();
  List<AssetModel> get draftAssets => _assets.where((a) => a.isDeleted).toList();

  List<AssetModel> pagedAssets(List<AssetModel> filtered) {
    if (filtered.length <= _loadedCount) return filtered;
    return filtered.take(_loadedCount).toList();
  }

  bool hasMore(List<AssetModel> filtered) => filtered.length > _loadedCount;

  void loadMore() {
    _loadedCount += _pageSize;
    notifyListeners();
  }

  Future<void> _init() async {
    await _loadFromStorage();
    await fetchFromServer();
  }

  Future<void> fetchFromServer() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _api.get('/assets');
      final serverAssets = data.map((m) => AssetModel.fromBackend(m)).toList();
      
      for (var sa in serverAssets) {
        final idx = _assets.indexWhere((a) => a.id == sa.id);
        if (idx != -1) {
          _assets[idx] = sa;
        } else {
          _assets.insert(0, sa);
        }
      }
      _saveToStorage();
    } catch (e) {
      if (kDebugMode) print('Error fetching server assets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assetData = prefs.getString('ebm_assets');
      if (assetData != null) {
        final List<AssetModel> loaded = await compute(_decodeAssets, assetData);
        _assets.clear();
        _assets.addAll(loaded);
      }
      final folderData = prefs.getString('ebm_asset_folders');
      if (folderData != null) {
        final List<AssetFolderModel> loadedF = await compute(_decodeFolders, folderData);
        _folders.clear();
        _folders.addAll(loadedF);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading storage: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedA = await compute(_encodeAssets, _assets);
      await prefs.setString('ebm_assets', encodedA);
      final String encodedF = await compute(_encodeFolders, _folders);
      await prefs.setString('ebm_asset_folders', encodedF);
    } catch (e) {
      if (kDebugMode) print('Error saving storage: $e');
    }
  }

  Future<void> pickAndImportAssets({String? folderId}) async {
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result == null) return;

      _isUploading = true;
      _uploadStatus = 'Importing ${result.files.length} file(s)…';
      notifyListeners();

      for (final file in result.files) {
        _uploadStatus = 'Uploading ${file.name}…';
        notifyListeners();

        try {
          final multipartFile = kIsWeb 
            ? http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name)
            : await http.MultipartFile.fromPath('file', file.path!);

          final resultData = await _api.postMultipart('/assets', {
            'category': 'general',
            'is_public': '1',
          }, [multipartFile]);

          final newAsset = AssetModel.fromBackend(resultData);
          _assets.insert(0, newAsset);
          
          if (folderId != null && folderId != 'all' && folderId != 'trash') {
            final fIdx = _folders.indexWhere((f) => f.id == folderId);
            if (fIdx != -1) {
              final updatedFolder = _folders[fIdx].copyWith(
                assetIds: [..._folders[fIdx].assetIds, newAsset.id],
              );
              _folders[fIdx] = updatedFolder;
            }
          }
        } catch (e) {
          if (kDebugMode) print('Upload failed: $e');
        }
      }
      await fetchFromServer();
      await _saveToStorage();
    } finally {
      _isUploading = false;
      _uploadStatus = null;
      notifyListeners();
    }
  }

  Future<void> permanentDeleteAsset(String id) async {
    try {
      await _api.delete('/assets/$id');
      _assets.removeWhere((a) => a.id == id);
      _saveToStorage();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Delete failed: $e');
    }
  }

  void updateAssetName(String id, String newName) {
    final index = _assets.indexWhere((a) => a.id == id);
    if (index != -1) {
      _assets[index] = _assets[index].copyWith(name: newName);
      _saveToStorage();
      notifyListeners();
    }
  }

  void removeAsset(String id) {
    final index = _assets.indexWhere((a) => a.id == id);
    if (index != -1) {
      _assets[index] = _assets[index].copyWith(isDeleted: true);
      _saveToStorage();
      notifyListeners();
    }
  }

  void restoreAsset(String id) {
    final index = _assets.indexWhere((a) => a.id == id);
    if (index != -1) {
      _assets[index] = _assets[index].copyWith(isDeleted: false);
      _saveToStorage();
      notifyListeners();
    }
  }

  void emptyTrash() {
    _assets.removeWhere((a) => a.isDeleted);
    _saveToStorage();
    notifyListeners();
  }

  void createFolder(String name) {
    final id = 'FOLDER-${1000 + Random().nextInt(8999)}';
    _folders.insert(0, AssetFolderModel(id: id, name: name, assetIds: []));
    _saveToStorage();
    notifyListeners();
  }

  void deleteFolder(String folderId) {
    _folders.removeWhere((f) => f.id == folderId);
    _saveToStorage();
    notifyListeners();
  }

  void renameFolder(String folderId, String newName) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx != -1) {
      _folders[idx] = _folders[idx].copyWith(name: newName);
      _saveToStorage();
      notifyListeners();
    }
  }

  void toggleAssetInFolder(String assetId, String folderId) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx != -1) {
      final folder = _folders[idx];
      final newIds = List<String>.from(folder.assetIds);
      if (newIds.contains(assetId)) {
        newIds.remove(assetId);
      } else {
        newIds.add(assetId);
      }
      _folders[idx] = folder.copyWith(assetIds: newIds);
      _saveToStorage();
      notifyListeners();
    }
  }

  void addEditedAsset(
    AssetModel originalAsset,
    String newPath,
    String newName,
    int newSizeBytes,
  ) {
    _assets.insert(
      0,
      AssetModel(
        id: 'ASSET-${100000 + Random().nextInt(899999)}_EDITED',
        name: newName,
        path: newPath,
        type: originalAsset.type,
        sizeBytes: newSizeBytes,
      ),
    );
    _saveToStorage();
    notifyListeners();
  }

  int get totalStorageBytes => _assets.fold(0, (s, a) => s + a.sizeBytes);

  AssetType _detectType(String ext) {
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].contains(ext)) return AssetType.image;
    if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) return AssetType.document;
    if (['mp4', 'mov', 'avi'].contains(ext)) return AssetType.video;
    return AssetType.other;
  }
}

String _encodeAssets(List<AssetModel> assets) => jsonEncode(assets.map((a) => a.toMap()).toList());
List<AssetModel> _decodeAssets(String data) {
  try {
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((m) => AssetModel.fromMap(m)).toList();
  } catch (_) { return []; }
}
String _encodeFolders(List<AssetFolderModel> folders) => jsonEncode(folders.map((f) => f.toMap()).toList());
List<AssetFolderModel> _decodeFolders(String data) {
  try {
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((m) => AssetFolderModel.fromMap(m)).toList();
  } catch (_) { return []; }
}
