import 'package:flutter/foundation.dart';

enum AssetType { image, document, video, other }

class AssetModel {
  final String id;
  final String name;
  final String path;
  final AssetType type;
  final int sizeBytes;
  final int originalSizeBytes; // size before compression
  final DateTime uploadDate;
  final String? url;
  final String? thumbnailPath; // 200×200 local thumbnail for fast grid display
  final bool isCompressed;
  final bool isDeleted; // Soft-delete flag for Drafts system

  AssetModel({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.sizeBytes,
    int? originalSizeBytes,
    DateTime? uploadDate,
    this.url,
    this.thumbnailPath,
    this.isCompressed = false,
    this.isDeleted = false,
  })  : uploadDate = uploadDate ?? DateTime.now(),
        originalSizeBytes = originalSizeBytes ?? sizeBytes;

  /// Saved space percentage (0-100)
  int get compressionSavingPercent {
    if (originalSizeBytes <= 0) return 0;
    return (((originalSizeBytes - sizeBytes) / originalSizeBytes) * 100).clamp(0, 100).toInt();
  }

  AssetModel copyWith({
    String? id,
    String? name,
    String? path,
    AssetType? type,
    int? sizeBytes,
    int? originalSizeBytes,
    DateTime? uploadDate,
    String? url,
    String? thumbnailPath,
    bool? isCompressed,
    bool? isDeleted,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      uploadDate: uploadDate ?? this.uploadDate,
      url: url ?? this.url,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isCompressed: isCompressed ?? this.isCompressed,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type.index,
      'sizeBytes': sizeBytes,
      'originalSizeBytes': originalSizeBytes,
      'uploadDate': uploadDate.toIso8601String(),
      'url': url,
      'thumbnailPath': thumbnailPath,
      'isCompressed': isCompressed,
      'isDeleted': isDeleted,
    };
  }

  factory AssetModel.fromMap(Map<String, dynamic> map) {
    return AssetModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unnamed Asset',
      path: map['path'] ?? '',
      type: AssetType.values[map['type'] ?? 3],
      sizeBytes: map['sizeBytes'] ?? 0,
      originalSizeBytes: map['originalSizeBytes'] ?? map['sizeBytes'] ?? 0,
      uploadDate: DateTime.parse(map['uploadDate'] ?? DateTime.now().toIso8601String()),
      url: map['url'],
      thumbnailPath: map['thumbnailPath'],
      isCompressed: map['isCompressed'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  factory AssetModel.fromBackend(Map<String, dynamic> map) {
    final mime = map['mime_type']?.toString().toLowerCase() ?? '';
    AssetType type = AssetType.other;
    if (mime.startsWith('image')) type = AssetType.image;
    else if (mime.startsWith('video')) type = AssetType.video;
    else if (mime.contains('pdf') || mime.contains('doc') || mime.contains('text')) type = AssetType.document;

    return AssetModel(
      id: map['id']?.toString() ?? '',
      name: map['original_name'] ?? 'File',
      path: map['url'] ?? '',
      type: type,
      sizeBytes: map['size'] ?? 0,
      originalSizeBytes: map['size'] ?? 0,
      uploadDate: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      url: map['url'],
      isDeleted: map['deleted_at'] != null,
    );
  }
}

// ── Folder Model ────────────────────────────────────────────────────────────

class AssetFolderModel {
  final String id;
  final String name;
  final List<String> assetIds; // List of Asset IDs assigned to this folder
  final DateTime createdAt;

  AssetFolderModel({
    required this.id,
    required this.name,
    required this.assetIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AssetFolderModel copyWith({
    String? id,
    String? name,
    List<String>? assetIds,
  }) {
    return AssetFolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      assetIds: assetIds ?? this.assetIds,
      createdAt: this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'assetIds': assetIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AssetFolderModel.fromMap(Map<String, dynamic> map) {
    return AssetFolderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'New Folder',
      assetIds: List<String>.from(map['assetIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
