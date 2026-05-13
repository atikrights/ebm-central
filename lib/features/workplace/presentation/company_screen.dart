import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/company.dart';
import '../providers/company_provider.dart';
import '../../../core/auth/auth_provider.dart';

class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 0, isDesktop ? 24 : 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 7), // Exact 7px top space (4+3)
            _buildHeader(context, ref, isDark, textColor, !isDesktop),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(companyProvider.notifier).syncWithDatabase(),
                color: AppColors.primary,
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                child: _buildCompanyGrid(context, ref, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDark, Color textColor, bool isMobile) {
    final state = ref.watch(companyProvider);
    final archivedCount = ref.watch(archivedCompaniesProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LINE 1: Search + Draft Icon + Create Button ──────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextField(
                    onChanged: (val) => ref.read(companyProvider.notifier).setSearchQuery(val),
                    style: TextStyle(color: textColor, fontSize: 13),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Search organizations...',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12),
                      prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildDraftBoxIcon(context, ref, isDark, textColor, archivedCount),
              if (ref.watch(authProvider).isSuperAdmin) ...[
                const SizedBox(width: 8),
                _buildRecycleBinIcon(context, ref, isDark, textColor),
              ],
              const SizedBox(width: 8),
              _buildCreateButton(context, ref, isMobile, isDark, textColor),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: state.maybeWhen(
              data: (data) => Row(
                children: [
                  ...data.categories.map(
                    (cat) => _buildFilterChip(
                      context, ref, cat,
                      data.filterCategory == null ? (cat == 'All') : (data.filterCategory!.toLowerCase() == cat.toLowerCase()),
                      () => ref.read(companyProvider.notifier).setCategoryFilter(cat == 'All' ? null : cat),
                      isDark,
                      onLongPress: cat == 'All' ? null : () => showCategoryManagePopup(context, ref, isDark, textColor, existingCategory: cat),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showCategoryManagePopup(context, ref, isDark, textColor),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(IconsaxPlusLinear.add, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('New Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftBoxIcon(BuildContext context, WidgetRef ref, bool isDark, Color textColor, int count) {
    return Tooltip(
      message: 'Drafts & Recovery',
      child: InkWell(
        onTap: () => showRecoveryPopup(context, ref, isDark, textColor),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(IconsaxPlusBold.box, color: isDark ? Colors.white70 : Colors.black87, size: 16),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ).animate().scale(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecycleBinIcon(BuildContext context, WidgetRef ref, bool isDark, Color textColor) {
    final trashedCount = ref.watch(trashedCompaniesProvider).length;

    return Tooltip(
      message: 'Recycle Bin (Super Admin)',
      child: InkWell(
        onTap: () => showRecycleBinPopup(context, ref, isDark, textColor),
        onHover: (_) {
           if (trashedCount == 0) ref.read(companyProvider.notifier).fetchTrashed();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(IconsaxPlusBold.trash, color: Colors.redAccent, size: 16),
              if (trashedCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '$trashedCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ).animate().shake(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, WidgetRef ref, bool isMobile, bool isDark, Color textColor) {
    final auth = ref.watch(authProvider);
    
    // Only Admin or Super Admin can see the create button
    if (!auth.isAdmin) return const SizedBox.shrink();

    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.primary,
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ElevatedButton.icon(
        onPressed: () => showCreateCompanyPopup(context, ref, isDark, textColor),
        icon: const Icon(IconsaxPlusLinear.add, size: 15),
        label: Text(
          isMobile ? 'Create' : 'Create Company',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label, bool isSelected, VoidCallback onTap, bool isDark, {VoidCallback? onLongPress}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyGrid(BuildContext context, WidgetRef ref, bool isDark) {
    final companies = ref.watch(filteredCompaniesProvider);
    final width = MediaQuery.of(context).size.width;
    final isSuperAdmin = ref.watch(authProvider).isSuperAdmin;

    if (companies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(IconsaxPlusLinear.building_3, size: 56, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 16),
            Text('No companies found.', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // Responsive: mobile=1 col, tablet=2 col, desktop=3 col, ultrawide=4+ cols
    int crossAxisCount;
    if (width < 650) {
      crossAxisCount = 1;
    } else if (width < 1100) {
      crossAxisCount = 2;
    } else if (width < 1500) {
      crossAxisCount = 3;
    } else if (width < 1900) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }
    
    final cardHeight = width < 600 ? 220.0 : 240.0;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: companies.length,
      itemBuilder: (context, index) {
        return _PremiumCompanyCard(company: companies[index], isDark: isDark)
            .animate()
            .fade(delay: Duration(milliseconds: 40 * index))
            .slideY(begin: 0.08, end: 0, delay: Duration(milliseconds: 40 * index));
      },
    );
  }
}

void showRecoveryPopup(BuildContext context, WidgetRef ref, bool isDark, Color textColor) {
  showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final archived = ref.watch(archivedCompaniesProvider);
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(IconsaxPlusBold.box, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Text('Drafts & Logs', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 300,
              child: archived.isEmpty 
                ? Center(child: Text('No archived organizations found.', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)))
                : ListView.builder(
                    itemCount: archived.length,
                    itemBuilder: (context, index) {
                      final comp = archived[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comp.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                                  Text('Archived CID: ${comp.id}', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(IconsaxPlusLinear.refresh, size: 18, color: Colors.greenAccent),
                              onPressed: () => ref.read(companyProvider.notifier).restoreCompany(comp.id),
                            ),
                            IconButton(
                              icon: const Icon(IconsaxPlusLinear.trash, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Move to Recycle Bin?'),
                                    content: Text('"${comp.name}" will be removed from your team records and sent to the Super Admin for final review.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref.read(companyProvider.notifier).deleteCompany(comp.id);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                        child: const Text('Move to Recycle Bin'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        },
      );
    },
  );
}

void showRecycleBinPopup(BuildContext context, WidgetRef ref, bool isDark, Color textColor) {
  // Fetch immediately
  ref.read(companyProvider.notifier).fetchTrashed();

  showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final trashed = ref.watch(trashedCompaniesProvider);
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(IconsaxPlusBold.trash, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text('Recycle Bin', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (trashed.isNotEmpty)
                  Text('${trashed.length} items', style: TextStyle(fontSize: 12, color: Colors.redAccent.withOpacity(0.7))),
              ],
            ),
            content: SizedBox(
              width: 450,
              height: 400,
              child: trashed.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconsaxPlusLinear.trash, size: 48, color: isDark ? Colors.white10 : Colors.black12),
                        const SizedBox(height: 16),
                        Text('Recycle bin is empty', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: trashed.length,
                    itemBuilder: (context, index) {
                      final comp = trashed[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(IconsaxPlusBold.building_3, color: Colors.redAccent, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comp.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                                  Text('CID: ${comp.id}', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(IconsaxPlusLinear.refresh_right_square, size: 20, color: Color(0xFF00C896)),
                              onPressed: () async {
                                await ref.read(companyProvider.notifier).restoreTrashed(comp.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${comp.name} restored successfully'), backgroundColor: const Color(0xFF00C896)),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Permanent Delete',
                              icon: const Icon(IconsaxPlusLinear.trash, size: 20, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Permanent Delete?'),
                                    content: Text('Are you sure you want to PERMANENTLY remove "${comp.name}"? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await ref.read(companyProvider.notifier).permanentDelete(comp.id);
                                          if (context.mounted) Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        child: const Text('Wipe Data'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0);
                    },
                  ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: textColor))),
            ],
          );
        },
      );
    },
  );
}

void showCategoryManagePopup(BuildContext context, WidgetRef ref, bool isDark, Color textColor, {String? existingCategory}) {
  final nameController = TextEditingController(text: existingCategory);
  final asyncState = ref.read(companyProvider);
  if (asyncState.value == null) return;
  final currentState = asyncState.value!;

  String popupSearchQuery = '';
  List<String> assignedIds = currentState.companies
      .where((c) => existingCategory != null && c.categories.contains(existingCategory))
      .map((c) => c.id).toList();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setPopupState) {
          final filteredCompanies = currentState.companies.where((c) => 
            c.name.toLowerCase().contains(popupSearchQuery.toLowerCase()) || 
            c.id.toLowerCase().contains(popupSearchQuery.toLowerCase())
          ).toList();

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(existingCategory == null ? 'Create Category' : 'Modify Category', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  popupTextField(isDark, 'e.g., Artificial Intelligence', IconsaxPlusLinear.folder_add, nameController),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: TextField(
                      onChanged: (val) => setPopupState(() => popupSearchQuery = val),
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by CID or Name...',
                        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12),
                        prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Text('Assign Organizations:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12)
                    ),
                    child: filteredCompanies.isEmpty 
                      ? Center(child: Text('No organizations match your search.', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)))
                      : ListView.builder(
                          itemCount: filteredCompanies.length,
                          itemBuilder: (context, index) {
                            final c = filteredCompanies[index];
                            final isAssigned = assignedIds.contains(c.id);
                            return CheckboxListTile(
                              value: isAssigned,
                              title: Text(c.name, style: TextStyle(color: textColor, fontSize: 13)),
                              subtitle: Text(c.id, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setPopupState(() {
                                  if (val == true) assignedIds.add(c.id);
                                  else assignedIds.remove(c.id);
                                });
                              },
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              if (existingCategory != null)
                TextButton(
                  onPressed: () {
                    ref.read(companyProvider.notifier).deleteCategory(existingCategory);
                    Navigator.pop(context);
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    ref.read(companyProvider.notifier).manageCategory(existingCategory, nameController.text, assignedIds);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(existingCategory == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      );
    },
  );
}

void showCreateCompanyPopup(BuildContext context, WidgetRef ref, bool isDark, Color textColor) {
  final nameController = TextEditingController();
  final websiteController = TextEditingController();
  final currentState = ref.read(companyProvider).value;
  
  // Use a list to support multiple categories
  List<String> selectedCategories = [];
  if (currentState?.filterCategory != null) {
    selectedCategories.add(currentState!.filterCategory!);
  }
  
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setPopupState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Create Company', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                popupTextField(isDark, 'Name', IconsaxPlusLinear.building, nameController),
                const SizedBox(height: 12),
                popupTextField(isDark, 'Website', IconsaxPlusLinear.global, websiteController),
                const SizedBox(height: 16),
                Text('Categories', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: (currentState?.categories ?? []).isEmpty 
                    ? Text('No categories available. Please create one first.', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (currentState!.categories).map((String cat) {
                          final isSelected = selectedCategories.contains(cat);
                          return FilterChip(
                            label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : textColor)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            checkmarkColor: Colors.white,
                            onSelected: (bool selected) {
                              setPopupState(() {
                                if (selected) {
                                  selectedCategories.add(cat);
                                } else {
                                  selectedCategories.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                ),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              ref.read(companyProvider.notifier).addCompany(Company(
                id: 'PENDING', 
                name: nameController.text,
                website: websiteController.text,
                categories: selectedCategories,
                primaryEmail: '',
                phone: '',
                location: '',
              ));
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Create'),
        ),
      ],
          );
        },
      );
    },
  );
}

Widget popupTextField(bool isDark, String hint, IconData icon, TextEditingController controller) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
    ),
    child: TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        border: InputBorder.none,
      ),
    ),
  );
}

class _PremiumCompanyCard extends ConsumerWidget {
  final Company company;
  final bool isDark;

  const _PremiumCompanyCard({required this.company, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final isCritical = company.healthScore < 0.7;
    final isAdmin = ref.watch(authProvider).isAdmin;
    final healthColor = isCritical ? Colors.redAccent : const Color(0xFF00C896);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical
              ? Colors.redAccent.withValues(alpha: 0.25)
              : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.07)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP ROW: Logo + Name + Status Badge ───────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(IconsaxPlusBold.building_3, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                // Name
                Expanded(
                  child: Text(
                    company.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Builder(
                  builder: (context) {
                    Color bColor;
                    String txt;
                    switch (company.status) {
                      case CompanyStatus.active:
                        bColor = const Color(0xFF00C896);
                        txt = 'Active';
                        break;
                      case CompanyStatus.onHold:
                        bColor = Colors.orange;
                        txt = 'Hold';
                        break;
                      case CompanyStatus.archived:
                        bColor = Colors.grey;
                        txt = 'Draft';
                        break;
                      case CompanyStatus.pending:
                        bColor = Colors.amber;
                        txt = 'Approval Required';
                        break;
                      case CompanyStatus.declined:
                        bColor = Colors.redAccent;
                        txt = 'Declined';
                        break;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        txt,
                        style: TextStyle(
                          color: bColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── CID ROW ─────────────────────────────────────────
            Tooltip(
              message: 'Copy CID',
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: company.id));
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconsaxPlusLinear.copy, size: 9, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        company.id,
                        style: TextStyle(
                          color: isDark ? AppColors.primaryContainer : AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── CATEGORY CHIPS + TEAM COUNT ─────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category chips
                Expanded(
                  child: company.categories.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: company.categories.take(2).map((cat) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          )).toList(),
                        ),
                ),
                const SizedBox(width: 6),
                // Manager count badge
                _TeamCountBadge(
                  icon: IconsaxPlusLinear.personalcard,
                  count: company.managerCount,
                  label: 'Mgr',
                  color: const Color(0xFF818CF8), // indigo
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                // Staff count badge
                _TeamCountBadge(
                  icon: IconsaxPlusLinear.profile_2user,
                  count: company.staffCount,
                  label: 'Staff',
                  color: const Color(0xFF34D399), // emerald
                  isDark: isDark,
                ),
              ],
            ),

            const Spacer(),

            // ── HEALTH BAR ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Health', style: TextStyle(color: subTextColor, fontSize: 10, fontWeight: FontWeight.w600)),
                Text(
                  '${(company.healthScore * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: healthColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: company.healthScore,
                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                color: healthColor,
                minHeight: 5,
              ),
            ),

            const SizedBox(height: 12),

            // ── ACTION ROW ──────────────────────────────────────
            Row(
              children: [
                // Manage Button (primary CTA — navigates to single company page)
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => context.pushNamed(
                        'company_manage',
                        pathParameters: {'id': company.id},
                      ),
                      icon: Icon(company.status == CompanyStatus.pending ? IconsaxPlusBold.verify : IconsaxPlusBold.setting_2, size: 13),
                      label: Text(company.status == CompanyStatus.pending ? 'Review Approval' : 'Manage', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: company.status == CompanyStatus.pending ? Colors.amber[700] : AppColors.primary,
                        foregroundColor: Colors.white,
                        shadowColor: (company.status == CompanyStatus.pending ? Colors.amber : AppColors.primary).withValues(alpha: 0.3),
                        elevation: 4,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Manager / Team icon
                _SmallIconButton(
                  icon: IconsaxPlusLinear.profile_2user,
                  isDark: isDark,
                  tooltip: 'View Team',
                  onTap: () => context.pushNamed(
                    'company_manage',
                    pathParameters: {'id': company.id},
                  ),
                ),
                const SizedBox(width: 6),
                // Archive button (admin only)
                if (isAdmin)
                  _SmallIconButton(
                    icon: IconsaxPlusLinear.archive_add,
                    isDark: isDark,
                    tooltip: 'Move to Draft',
                    onTap: () => _quickArchive(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _quickArchive(BuildContext context, WidgetRef ref) {
    ref.read(companyProvider.notifier).archiveCompany(company.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${company.name}" moved to Draft Box.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () => ref.read(companyProvider.notifier).restoreCompany(company.id),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isError;

  const _SmallIconButton({
    required this.icon,
    required this.isDark,
    required this.tooltip,
    this.onTap,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isError
                ? Colors.redAccent.withOpacity(0.1)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withOpacity(0.3)
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isError ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _TeamCountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final bool isDark;

  const _TeamCountBadge({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


