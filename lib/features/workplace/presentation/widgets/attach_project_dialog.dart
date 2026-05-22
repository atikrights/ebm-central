import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../projects/models/project.dart' as pmod;
import '../../../projects/providers/project_provider.dart';
import '../../models/company.dart';

class AttachProjectDialog extends ConsumerStatefulWidget {
  final Company company;

  const AttachProjectDialog({
    super.key,
    required this.company,
  });

  @override
  ConsumerState<AttachProjectDialog> createState() => _AttachProjectDialogState();
}

class _AttachProjectDialogState extends ConsumerState<AttachProjectDialog> {
  final TextEditingController _dialogSearchController = TextEditingController();
  final TextEditingController _manualPidController = TextEditingController();
  
  List<pmod.Project> _unattachedProjects = [];
  bool _isLoadingList = true;
  String _searchQuery = '';
  
  bool _isAttachingManual = false;
  final Map<String, bool> _attachingMap = {}; // tracks which project ID is currently attaching

  @override
  void initState() {
    super.initState();
    _loadUnattachedProjects();
    _dialogSearchController.addListener(() {
      setState(() {
        _searchQuery = _dialogSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _dialogSearchController.dispose();
    _manualPidController.dispose();
    super.dispose();
  }

  Future<void> _loadUnattachedProjects() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await ref.read(projectProvider.notifier).fetchUnattachedProjects();
      if (mounted) {
        setState(() {
          _unattachedProjects = list;
          _isLoadingList = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  Future<void> _attachProject(pmod.Project project) async {
    setState(() {
      _attachingMap[project.id] = true;
    });
    try {
      await ref.read(projectProvider.notifier).linkCompanyToProject(project.id, widget.company.id);
      if (mounted) {
        setState(() {
          _attachingMap[project.id] = false;
          _unattachedProjects.removeWhere((p) => p.id == project.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${project.name}" attached successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _attachingMap[project.id] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to attach project.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _attachManualPid() async {
    final pid = _manualPidController.text.trim();
    if (pid.isEmpty) return;

    setState(() => _isAttachingManual = true);
    try {
      final project = await ref.read(projectProvider.notifier).searchByPid(pid);
      if (project == null) {
        if (mounted) {
          setState(() => _isAttachingManual = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project PID not found or outside team scope.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (project.companyId == widget.company.id) {
        if (mounted) {
          setState(() => _isAttachingManual = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project is already linked to this company.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      await ref.read(projectProvider.notifier).linkCompanyToProject(project.id, widget.company.id);
      if (mounted) {
        setState(() {
          _isAttachingManual = false;
          _manualPidController.clear();
        });
        // Remove it from the list of unattached projects if it was there
        setState(() {
          _unattachedProjects.removeWhere((p) => p.id == project.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${project.name}" linked successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAttachingManual = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    final filteredList = _unattachedProjects.where((p) {
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.pid.toLowerCase().contains(_searchQuery);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 550,
        height: 600,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attach Project',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Link a project to ${widget.company.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: hintColor,
                  hoverColor: Colors.red.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live List Search Bar
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _dialogSearchController,
                style: TextStyle(color: textColor, fontSize: 14),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search unattached projects...',
                  hintStyle: TextStyle(color: hintColor, fontSize: 13),
                  prefixIcon: Icon(IconsaxPlusLinear.search_normal, size: 18, color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Unattached Projects List
            Expanded(
              child: _isLoadingList
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(IconsaxPlusLinear.folder_open, size: 48, color: hintColor),
                              const SizedBox(height: 12),
                              Text(
                                'No unattached projects found',
                                style: TextStyle(color: hintColor, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final proj = filteredList[index];
                            final isAttaching = _attachingMap[proj.id] ?? false;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                              ),
                              child: Row(
                                children: [
                                  // Left side color bar indicator
                                  Container(
                                    width: 4,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: proj.brandColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          proj.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          proj.pid,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: isAttaching ? null : () => _attachProject(proj),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      icon: isAttaching
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 1.5,
                                              ),
                                            )
                                          : const Icon(IconsaxPlusLinear.link_1, size: 14),
                                      label: const Text(
                                        'Attach',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
                          },
                        ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Manual PID Input Section
            Text(
              'Attach by PID directly',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _manualPidController,
                      style: TextStyle(color: textColor, fontSize: 13),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Enter Project PID (e.g. PRJ-001-ABCD)',
                        hintStyle: TextStyle(color: hintColor, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isAttachingManual ? null : _attachManualPid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    child: _isAttachingManual
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Attach PID',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
