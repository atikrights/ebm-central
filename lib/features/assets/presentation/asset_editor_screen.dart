import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset_model.dart';
import '../providers/asset_provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AssetEditorScreen extends ConsumerStatefulWidget {
  final AssetModel asset;

  const AssetEditorScreen({super.key, required this.asset});

  @override
  ConsumerState<AssetEditorScreen> createState() => _AssetEditorScreenState();
}

class _AssetEditorScreenState extends ConsumerState<AssetEditorScreen> {
  Future<void> _handleImageEdited(Uint8List bytes) async {
    final provider = ref.read(assetProvider);

    try {
      if (kIsWeb) {
        // For web, we might just store the bytes or a blob URL.
      } else {
        // Desktop / Mobile path
        final tempDir = await getTemporaryDirectory();
        final ext = p.extension(widget.asset.path).isNotEmpty ? p.extension(widget.asset.path) : '.png';
        final newFileName = '${p.basenameWithoutExtension(widget.asset.name)}_edited_${DateTime.now().millisecondsSinceEpoch}$ext';
        final newPath = p.join(tempDir.path, newFileName);

        final file = File(newPath);
        await file.writeAsBytes(bytes);

        // Add to provider
        provider.addEditedAsset(widget.asset, newPath, newFileName, bytes.length);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // close editor
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // We pass either File or Network or Memory to pro_image_editor
    Widget editor;

    if (widget.asset.url != null && widget.asset.url!.startsWith('http')) {
      editor = ProImageEditor.network(
        widget.asset.url!,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            await _handleImageEdited(bytes);
          },
        ),
        configs: _getEditorConfigs(isDark),
      );
    } else if (!kIsWeb) {
      editor = ProImageEditor.file(
        File(widget.asset.path),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            await _handleImageEdited(bytes);
          },
        ),
        configs: _getEditorConfigs(isDark),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Unsupported file format or source for Web.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Editors should be black for max contrast
      body: SafeArea(child: editor),
    );
  }

  ProImageEditorConfigs _getEditorConfigs(bool isDark) {
    return ProImageEditorConfigs(
      designMode: ImageEditorDesignMode.material,
      theme: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: Colors.black87,
        ),
      ),
    );
  }
}
