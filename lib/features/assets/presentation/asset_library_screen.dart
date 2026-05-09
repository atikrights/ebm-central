import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/ebm_image.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import '../models/asset_model.dart';
import '../providers/asset_provider.dart';
import '../../../core/config/app_config.dart';
import 'asset_editor_screen.dart';
import 'dart:math';

class AssetLibraryScreen extends ConsumerStatefulWidget {
  final Function(AssetModel)? onAssetSelected;
  final bool isPickerMode;

  const AssetLibraryScreen({
    super.key, 
    this.onAssetSelected,
    this.isPickerMode = false,
  });

  @override
  ConsumerState<AssetLibraryScreen> createState() => _AssetLibraryScreenState();
}

class _AssetLibraryScreenState extends ConsumerState<AssetLibraryScreen> {
  String _searchQuery = '';
  String _selectedFolderId = 'all'; // 'all', 'trash', or Folder ID

  final ScrollController _scrollController = ScrollController();
  bool _showDrafts = false; // Toggle between active and draft assets

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetProvider).fetchFromServer();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = ref.read(assetProvider);
      final filtered = _getFiltered(_showDrafts ? provider.draftAssets : provider.activeAssets);
      if (provider.hasMore(filtered)) {
        provider.loadMore();
      }
    }
  }

  List<AssetModel> _getFiltered(List<AssetModel> all) {
    final query = _searchQuery.toLowerCase().trim();
    return all.where((a) {
      // 1. Filter by Custom Folder (if a folder is selected)
      if (_selectedFolderId != 'all' && _selectedFolderId != 'trash') {
        final provider = ref.read(assetProvider);
        final folder = provider.folders.firstWhere(
          (f) => f.id == _selectedFolderId,
          orElse: () => AssetFolderModel(id: '', name: '', assetIds: []),
        );
        if (!folder.assetIds.contains(a.id)) return false;
      }

      // 2. Multi-Field Search (Name, ID, Link/Path)
      if (query.isNotEmpty) {
        final matchesName = a.name.toLowerCase().contains(query);
        final matchesId = a.id.toLowerCase().contains(query);
        final matchesPath = a.path.toLowerCase().contains(query);
        
        if (!matchesName && !matchesId && !matchesPath) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(assetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bp = ResponsiveBreakpoints.of(context);

    final filtered = _getFiltered(_showDrafts ? provider.draftAssets : provider.activeAssets);
    final paged = provider.pagedAssets(filtered);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: bp.isMobile ? 16.0 : 24.0, 
            vertical: bp.isMobile ? 12.0 : 20.0
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Actionable Area (Scrollable if height is restricted)
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header bar (Storage + Stats integrated)
                    _buildHeaderBar(isDark, provider),

                    const SizedBox(height: 12),

                    // ── Filter tabs (Only in Active View)
                    if (!_showDrafts) ...[
                      _buildFilterTabs(isDark),
                      const SizedBox(height: 12),
                    ],

                    // ── Upload Progress
                    if (provider.isUploading) ...[
                      _buildUploadProgress(provider, isDark),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),

              // ── Main grid (Fixed height, self-scrollable)
              Expanded(
                child: provider.isLoading
                    ? _buildLoadingSkeleton()
                    : filtered.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildAssetGrid(paged, filtered, isDark, provider),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeaderBar(bool isDark, AssetProvider provider) {
    final bp = ResponsiveBreakpoints.of(context);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      if (_showDrafts) ...[
                        IconButton(
                          onPressed: () => setState(() => _showDrafts = false),
                          icon: Icon(IconsaxPlusLinear.arrow_left_2, 
                            color: isDark ? Colors.white : Colors.black, size: 20),
                          tooltip: 'Back to Library',
                        ),
                        const SizedBox(width: 8),
                        Text('Recycle Bin', 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.white : Colors.black87
                          ),
                        ),
                      ] else ...[
                        _buildStorageBadge(isDark, provider),
                        const SizedBox(width: 12),
                        _buildCombinedStatsRow(provider, isDark),
                      ],
                    ],
                  ),
                ),
              ),
              if (bp.largerThan(TABLET)) ...[
                const SizedBox(width: 16),
                _buildDraftsToggle(isDark, provider),
                if (!_showDrafts) ...[
                  const SizedBox(width: 12),
                  _buildUploadButton(provider),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSearchBox(isDark)),
            if (!bp.largerThan(TABLET)) ...[
              const SizedBox(width: 10),
              _buildDraftsToggle(isDark, provider),
              if (!_showDrafts) ...[
                const SizedBox(width: 10),
                _buildIconUploadButton(provider),
              ],
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCombinedStatsRow(AssetProvider provider, bool isDark) {
    final assets = provider.activeAssets;
    final Map<String, int> extCounts = {};
    for (var a in assets) {
      final ext = a.path.split('.').last.toUpperCase();
      if (ext.length < 5) {
        extCounts[ext] = (extCounts[ext] ?? 0) + 1;
      }
    }
    final sortedExts = extCounts.keys.toList()..sort();

    return Row(
      children: [
        _buildStatPill(
          '${assets.length} Total',
          IconsaxPlusLinear.category_2,
          AppColors.primary,
          isDark,
          onTap: () => _showExtensionItemsPopup(context, 'All', assets, isDark),
        ),
        const SizedBox(width: 8),
        ...sortedExts.map((ext) {
          final count = extCounts[ext];
          final filtered = assets.where((a) => a.path.toUpperCase().endsWith('.$ext')).toList();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildStatPill(
              '$count $ext',
              _getIconForExt(ext),
              _getColorForExt(ext),
              isDark,
              onTap: () => _showExtensionItemsPopup(context, ext, filtered, isDark),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIconUploadButton(AssetProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: provider.isUploading
            ? null
            : () => provider.pickAndImportAssets(folderId: _selectedFolderId),
        icon: const Icon(IconsaxPlusLinear.document_upload,
            color: Colors.white, size: 20),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildUploadButton(AssetProvider provider) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      onPressed: provider.isUploading
          ? null
          : () => provider.pickAndImportAssets(folderId: _selectedFolderId),
      icon: const Icon(IconsaxPlusLinear.document_upload, size: 18),
      label: const Text('Upload Media',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }


  void _showExtensionItemsPopup(BuildContext context, String title, List<AssetModel> assets, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final itemBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$title Assets (${assets.length})', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(IconsaxPlusLinear.close_square, color: subColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: assets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final asset = assets[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: itemBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(_getIconForExt(asset.path.split('.').last.toUpperCase()), 
                            size: 18, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 4),
                                _buildCopyRow(asset.id, isDark, IconsaxPlusLinear.copy, small: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForExt(String ext) {
    if (['PNG', 'JPG', 'JPEG', 'WEBP', 'SVG'].contains(ext)) return IconsaxPlusLinear.gallery;
    if (['PDF', 'DOC', 'DOCX', 'TXT'].contains(ext)) return IconsaxPlusLinear.document_text;
    if (['MP4', 'MOV', 'AVI'].contains(ext)) return IconsaxPlusLinear.video_square;
    if (['ZIP', 'RAR', '7Z'].contains(ext)) return IconsaxPlusLinear.archive_1;
    return IconsaxPlusLinear.document;
  }

  Color _getColorForExt(String ext) {
    if (ext == 'PNG' || ext == 'JPG' || ext == 'JPEG') return Colors.blue;
    if (ext == 'SVG') return Colors.orange;
    if (ext == 'PDF') return Colors.redAccent;
    if (ext == 'MP4') return Colors.purple;
    if (ext == 'ZIP') return Colors.teal;
    return Colors.grey;
  }

  Widget _buildStatPill(
      String label, IconData icon, Color color, bool isDark, {VoidCallback? onTap}) {
    final bp = ResponsiveBreakpoints.of(context);
    final isMobile = bp.isMobile;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 10, 
          vertical: 5
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            if (!isMobile) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Upload Progress ───────────────────────────────────────────────────────

  Widget _buildUploadProgress(AssetProvider provider, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 12,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              provider.uploadStatus ?? 'Processing…',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.3, duration: 300.ms);
  }

  Widget _buildFilterTabs(bool isDark) {
    final provider = ref.watch(assetProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // ── All Assets Tab
          _buildTabItem('All Assets', 'all', IconsaxPlusLinear.grid_1, isDark),
          
          // ── Divider
          Container(
            height: 14,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? Colors.white12 : Colors.black12,
          ),

          // ── Custom Folders
          ...provider.folders.map((folder) => _buildTabItem(
            folder.name, 
            folder.id, 
            IconsaxPlusLinear.folder_2, 
            isDark,
            onLongPress: () => _showFolderOptionsDialog(folder),
          )),

          // ── Add Folder Small Button
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showCreateFolderDialog(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(IconsaxPlusLinear.add, 
                size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, String id, IconData icon, bool isDark, {VoidCallback? onLongPress}) {
    final isSelected = _selectedFolderId == id;
    final bp = ResponsiveBreakpoints.of(context);
    final isMobile = bp.isMobile;
    final activeColor = AppColors.primary;
    final inactiveBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final inactiveText = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedFolderId = id),
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: (isMobile && !isSelected) ? 8 : 10, 
              vertical: 6
            ),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : inactiveBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? activeColor : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, 
                  size: 12, 
                  color: isSelected ? Colors.white : inactiveText),
                if (!isMobile || isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : inactiveText,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(assetProvider).createFolder(controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptionsDialog(AssetFolderModel folder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Manage "${folder.name}"', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.edit, color: Colors.blue),
              title: Text('Rename Folder', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameFolderDialog(folder);
              },
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.trash, color: Colors.red),
              title: const Text('Delete Folder', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFolder(folder);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(AssetFolderModel folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(assetProvider).renameFolder(folder.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(AssetFolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text('This will only remove the folder category, not the actual assets inside.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(assetProvider).deleteFolder(folder.id);
              if (_selectedFolderId == folder.id) {
                setState(() => _selectedFolderId = 'all');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    final bp = ResponsiveBreakpoints.of(context);
    int crossAxisCount = 3;
    if (bp.largerThan(MOBILE)) crossAxisCount = 6;
    if (bp.largerThan(TABLET)) crossAxisCount = 8;
    if (bp.largerThan(DESKTOP)) crossAxisCount = 10;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.1)),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconsaxPlusLinear.folder_cross,
              size: 80,
              color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 16),
          Text('No Assets Found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text('Upload media or documents to populate the library.',
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  // ── Storage Badge ─────────────────────────────────────────────────────────

  Widget _buildStorageBadge(bool isDark, AssetProvider provider) {
    final usedStr = _formatBytes(provider.totalStorageBytes, 2);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.03),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(IconsaxPlusLinear.cloud_change,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile)
                Text('Storage Capacity',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w500)),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '$usedStr ',
                    style: TextStyle(
                        color:
                            isDark ? Colors.white : Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  if (!isMobile)
                    TextSpan(
                      text: '/ 10 GB',
                      style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : Colors.black54,
                          fontSize: 11),
                    ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search box ────────────────────────────────────────────────────────────

  Widget _buildSearchBox(bool isDark) {
    return Container(
      width: ResponsiveBreakpoints.of(context).isMobile ? double.infinity : 300,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: TextField(
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search by Title, ID, or Link…',
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 12),
          prefixIcon: Icon(IconsaxPlusLinear.search_normal_1,
              color: isDark ? Colors.white54 : Colors.black54,
              size: 16),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(IconsaxPlusLinear.close_circle, size: 14),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDraftsToggle(bool isDark, AssetProvider provider) {
    final draftCount = provider.draftAssets.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _showDrafts = !_showDrafts;
                  // If switching to trash, clear folder filter
                  if (_showDrafts) _selectedFolderId = 'all';
                });
              },
              icon: Icon(
                _showDrafts
                    ? IconsaxPlusLinear.document_favorite
                    : IconsaxPlusLinear.trash,
                color: _showDrafts
                    ? AppColors.secondary
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              tooltip: _showDrafts ? 'View Active Assets' : 'View Drafts/Trash',
            ),
            if (draftCount > 0 && !_showDrafts)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$draftCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ).animate().scale(delay: 200.ms),
          ],
        ),
        if (_showDrafts && draftCount > 0)
          TextButton.icon(
            onPressed: () => provider.emptyTrash(),
            icon: const Icon(IconsaxPlusLinear.trash, size: 16),
            label: const Text('Empty Trash'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
      ],
    );
  }

  // ── Asset Grid ────────────────────────────────────────────────────────────

  Widget _buildAssetGrid(
    List<AssetModel> paged,
    List<AssetModel> filtered,
    bool isDark,
    AssetProvider provider,
  ) {
    final bp = ResponsiveBreakpoints.of(context);
    int crossAxisCount = 3;
    if (bp.largerThan(MOBILE)) crossAxisCount = 6;
    if (bp.largerThan(TABLET)) crossAxisCount = 8;
    if (bp.largerThan(DESKTOP)) crossAxisCount = 10;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            cacheExtent: 1200,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: paged.length,
            itemBuilder: (context, index) {
              final asset = paged[index];
              return _AssetCard(
                asset: asset,
                isDark: isDark,
                provider: provider,
                isDraftMode: _showDrafts,
                isPickerMode: widget.isPickerMode,
                onAssetSelected: widget.onAssetSelected,
                onShowDetails: () =>
                    _showAssetDetails(context, asset, provider),
              )
                  .animate()
                  .fade(delay: (30 * index).ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutQuart);
            },
          ),
        ),

        // ── Load More button
        if (provider.hasMore(filtered))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton.icon(
              onPressed: () => provider.loadMore(),
              icon: const Icon(IconsaxPlusLinear.arrow_down_2, size: 16),
              label: Text(
                'Load More (${filtered.length - paged.length} remaining)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ── Asset Details popup (AppConfig domain-aware) ─────────────────────────

  void _showAssetDetails(
      BuildContext context, AssetModel asset, AssetProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: asset.name);

    // ✅ Unified Universal Link
    final String liveLink = 'asset://${asset.id}';
    final String sharedLink = AppConfig.sharedLink(asset.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          borderRadius: 24,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asset Details',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black)),
                      if (asset.isCompressed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(IconsaxPlusLinear.flash_1,
                                  size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '${asset.compressionSavingPercent}% smaller',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(IconsaxPlusLinear.close_square,
                        color: isDark
                            ? Colors.white54
                            : Colors.black54),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Rename (Locked if deleted)
              IgnorePointer(
                ignoring: asset.isDeleted,
                child: Opacity(
                  opacity: asset.isDeleted ? 0.5 : 1.0,
                  child: _buildDetailField(
                    'Rename Asset ${asset.isDeleted ? "(Locked in Trash)" : ""}',
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: _inputDecoration(isDark, 'Enter asset name'),
                      onChanged: (val) =>
                          provider.updateAssetName(asset.id, val),
                    ),
                    isDark,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Asset ID
              _buildDetailField(
                'Asset ID',
                _buildCopyRow(asset.id, isDark,
                    IconsaxPlusLinear.finger_scan),
                isDark,
              ),

              const SizedBox(height: 16),

              // 📂 Folder Assignment (Locked if deleted)
              if (provider.folders.isNotEmpty) ...[
                IgnorePointer(
                  ignoring: asset.isDeleted,
                  child: Opacity(
                    opacity: asset.isDeleted ? 0.5 : 1.0,
                    child: _buildDetailField(
                      'Assign to Folders ${asset.isDeleted ? "(Locked)" : ""}',
                      StatefulBuilder(
                        builder: (ctx, setPopupState) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: provider.folders.map((folder) {
                              final isInFolder =
                                  folder.assetIds.contains(asset.id);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(folder.name),
                                  selected: isInFolder,
                                  onSelected: (_) {
                                    provider.toggleAssetInFolder(
                                        asset.id, folder.id);
                                    setPopupState(() {}); // Refresh local UI
                                  },
                                  selectedColor:
                                      AppColors.primary.withOpacity(0.2),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: isInFolder
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                    fontWeight: isInFolder
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Live Link (AppConfig auto-domain)
              _buildDetailField(
                'Live Link  •  ${AppConfig.isLocalhost ? "🟡 Localhost (dev)" : "🟢 Production"}',
                _buildCopyRow(liveLink, isDark, IconsaxPlusLinear.link),
                isDark,
              ),

              const SizedBox(height: 16),

              // Shared Link
              _buildDetailField(
                'Shared Public Link',
                _buildCopyRow(sharedLink, isDark,
                    IconsaxPlusLinear.share),
                isDark,
              ),

              const SizedBox(height: 24),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, Widget child, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCopyRow(String text, bool isDark, IconData icon, {bool small = false}) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(IconsaxPlusLinear.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Text('Copied: $text', style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 8 : 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, size: small ? 13 : 15, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: small ? 11 : 12,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(IconsaxPlusLinear.copy, size: small ? 12 : 14, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Asset Card ───────────────────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final AssetModel asset;
  final bool isDark;
  final AssetProvider provider;
  final VoidCallback onShowDetails;
  final bool isDraftMode;
  final bool isPickerMode;
  final Function(AssetModel)? onAssetSelected;

  const _AssetCard({
    required this.asset,
    required this.isDark,
    required this.provider,
    required this.onShowDetails,
    this.isDraftMode = false,
    this.isPickerMode = false,
    this.onAssetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return GestureDetector(
      onTap: () {
        if (isPickerMode) {
          onAssetSelected?.call(asset);
          return;
        }
        if (asset.type == AssetType.image) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssetEditorScreen(asset: asset),
            ),
          );
        }
      },
      onLongPress: (isDesktop || isPickerMode) ? null : onShowDetails,
      child: GlassContainer(
        padding: const EdgeInsets.all(0),
        borderRadius: 16,
        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.black.withOpacity(0.05),
        ),
        child: Stack(
          children: [
            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildPreview(),
                  ),
                ),

                // Footer info
                Container(
                  height: 42,
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Row(
                    children: [
                      Icon(_getIconForType(asset.type),
                          size: 11, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              asset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              _formatBytes(asset.sizeBytes, 1),
                              style: TextStyle(
                                fontSize: 8,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Desktop action buttons
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDraftMode) ...[
                    _buildActionBtn(
                      onTap: () => provider.restoreAsset(asset.id),
                      icon: IconsaxPlusLinear.refresh,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 5),
                    _buildActionBtn(
                      onTap: () => provider.permanentDeleteAsset(asset.id),
                      icon: IconsaxPlusLinear.trash,
                      color: Colors.redAccent,
                    ),
                  ] else ...[
                    if (isDesktop) ...[
                      _buildActionBtn(
                        onTap: onShowDetails,
                        icon: IconsaxPlusLinear.setting_4,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    _buildActionBtn(
                      onTap: () => provider.removeAsset(asset.id),
                      icon: IconsaxPlusLinear.trash,
                      color: Colors.redAccent,
                    ),
                  ],
                ],
              ),
            ),

            // Compressed badge
            if (asset.isCompressed && asset.compressionSavingPercent > 0)
              Positioned(
                bottom: 50,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${asset.compressionSavingPercent}%',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.88),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 6),
          ],
        ),
        child: Icon(icon, size: 10, color: Colors.white),
      ),
    );
  }

  Widget _buildPreview() {
    return EbmImage(
      source: 'asset://${asset.id}',
      fit: BoxFit.cover,
      isThumbnail: true, // Lightweight memory footprint
      errorWidget: _fallback(),
      placeholder: _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.02),
      child: Center(
        child: Icon(
          _getIconForType(asset.type),
          size: 24,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }

  IconData _getIconForType(AssetType type) {
    switch (type) {
      case AssetType.image:
        return IconsaxPlusLinear.gallery;
      case AssetType.document:
        return IconsaxPlusLinear.document_text;
      case AssetType.video:
        return IconsaxPlusLinear.video_square;
      default:
        return IconsaxPlusLinear.document;
    }
  }
}

// ── Global helpers ─────────────────────────────────────────────────────────────

String _formatBytes(int bytes, int decimals) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}
