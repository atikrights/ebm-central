import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/assets/providers/asset_provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';

/// A universal image widget that handles local paths, web URLs, and Asset IDs.
class EbmImage extends ConsumerWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final bool isThumbnail;

  const EbmImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.isThumbnail = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (source.isEmpty) return _error();

    // 1. Check if it's a direct web URL
    if (source.startsWith('http') && !source.contains(AppConfig.origin)) {
      return _networkImage(source);
    }

    // 2. Local File path (Desktop/Mobile Only)
    if (!kIsWeb && !source.startsWith('http')) {
      final file = File(source);
      if (file.existsSync()) {
        return Image.file(
          file as dynamic,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: isThumbnail ? 300 : cacheWidth,
          errorBuilder: (context, error, stackTrace) => errorWidget ?? _error(),
        );
      }
    }

    // 3. Asset ID or Domain-Relative URL
    String? assetId;
    if (source.startsWith('asset://')) {
      assetId = source.replaceFirst('asset://', '');
    } else if (source.contains('/assets/')) {
      assetId = source.split('/assets/').last;
    } else if (source.startsWith('ASSET-')) {
      assetId = source;
    }

    if (assetId != null) {
      final provider = ref.watch(assetProvider);
      final match = provider.allAssets.where((a) => a.id == assetId).toList();
      
      if (match.isNotEmpty) {
        final asset = match.first;
        
        // On Desktop/Mobile, prefer local path if available
        if (!kIsWeb && asset.path.isNotEmpty) {
          final localFile = File(asset.path);
          if (localFile.existsSync()) {
            return Image.file(
              localFile as dynamic,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: isThumbnail ? 300 : cacheWidth,
              errorBuilder: (context, error, stackTrace) => errorWidget ?? _error(),
            );
          }
        }
        
        // Fallback to URL
        if (asset.url != null && asset.url!.isNotEmpty) {
          return _networkImage(asset.url!);
        }
        return _networkImage(AppConfig.assetLink(asset.id));
      }
    }

    if (source.startsWith('http')) return _networkImage(source);
    return _error();
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: isThumbnail ? 300 : cacheWidth,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _placeholder();
      },
      errorBuilder: (context, error, stackTrace) => errorWidget ?? _error(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withOpacity(0.1),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _error() {
    return Container(
      width: width,
      height: height,
      color: Colors.red.withOpacity(0.05),
      child: const Center(
        child: Icon(IconsaxPlusLinear.image, size: 20, color: Colors.redAccent),
      ),
    );
  }
}
