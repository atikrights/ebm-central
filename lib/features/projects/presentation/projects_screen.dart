import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/project_provider.dart';
import '../../workplace/providers/company_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/project.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Hold', 'Complete'];

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 7), // Exact 7px top space (4+3)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDark),
                projectState.maybeWhen(
                  data: (projects) => _buildFilterBar(projects, isDark),
                  orElse: () => _buildFilterBar([], isDark),
                ),
                const SizedBox(height: 14), // Space after tabs (Reduced by 2px as requested)
              ],
            ),
          ),
          Expanded(
            child: projectState.when(
              data: (projects) {
                final filteredProjects = projects.where((p) {
                  final sq = _searchQuery.toLowerCase();
                  final matchesSearch = p.name.toLowerCase().contains(sq) ||
                      p.pid.toLowerCase().contains(sq) ||
                      (p.companyName ?? '').toLowerCase().contains(sq) ||
                      (p.companyId ?? '').toLowerCase().contains(sq);
                  
                  bool matchesFilter = false;
                  if (_selectedFilter == 'All') {
                    matchesFilter = true;
                  } else if (_selectedFilter == 'Active') {
                    matchesFilter = p.status == ProjectStatus.active;
                  } else if (_selectedFilter == 'Complete') {
                    matchesFilter = p.status == ProjectStatus.completed;
                  } else if (_selectedFilter == 'Hold') {
                    matchesFilter = p.status == ProjectStatus.onHold;
                  }
                  
                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredProjects.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 1200) {
                      return _buildGridView(filteredProjects, 4, isDark);
                    } else if (constraints.maxWidth > 900) {
                      return _buildGridView(filteredProjects, 3, isDark);
                    } else if (constraints.maxWidth > 600) {
                      return _buildGridView(filteredProjects, 2, isDark);
                    } else {
                      return _buildListView(filteredProjects, isDark);
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => _buildErrorState(err.toString(), isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProjectDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(IconsaxPlusLinear.add_circle, color: Colors.white, size: 18),
        label: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildTopBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projects Registry',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor and deploy strategic company assets.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconsaxPlusLinear.warning_2, size: 48, color: Colors.red.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Registry Sync Error', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<Project> allProjects, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          
          int count = 0;
          if (filter == 'All') {
            count = allProjects.length;
          } else if (filter == 'Active') {
            count = allProjects.where((p) => p.status == ProjectStatus.active).length;
          } else if (filter == 'Complete') {
            count = allProjects.where((p) => p.status == ProjectStatus.completed).length;
          } else if (filter == 'Hold') {
            count = allProjects.where((p) => p.status == ProjectStatus.onHold).length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = filter),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? AppColors.primary 
                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      filter,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
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
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search projects, ID...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                  prefixIcon: Icon(IconsaxPlusLinear.search_normal, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(IconsaxPlusLinear.filter, isDark),
          const SizedBox(width: 6),
          _buildActionButton(IconsaxPlusLinear.document_text, isDark),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black87),
    );
  }

  Widget _buildListView(List<Project> projects, bool isDark) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return ListView.separated(
      itemCount: projects.length,
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 0, isDesktop ? 24 : 16, 80),
      separatorBuilder: (context, index) => const SizedBox(height: 2), // 2px list space as requested
      itemBuilder: (context, index) => _ProjectListItem(project: projects[index], isDark: isDark)
          .animate()
          .fadeIn(delay: (index * 50).ms)
          .slideX(begin: 0.1, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildGridView(List<Project> projects, int crossAxisCount, bool isDark) {
    return _buildListView(projects, isDark);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(IconsaxPlusLinear.folder, size: 64, color: isDark ? Colors.white10 : Colors.black12),
          ),
          const SizedBox(height: 24),
          Text(
            'No Projects Registered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    bool isCreating = false;
    Project? createdProject;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (createdProject != null) {
            return _buildSuccessDialog(ctx, createdProject!, isDark);
          }

          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Deploy Project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87)),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx), 
                          icon: Icon(Icons.close, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildFieldLabel('PROJECT NAME', isDark),
                    const SizedBox(height: 8),
                    _buildDialogField(nameCtrl, 'Enter project name...', IconsaxPlusLinear.edit_2, isDark),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isCreating ? null : () async {
                          if (nameCtrl.text.isNotEmpty) {
                            setDialogState(() => isCreating = true);
                            try {
                              final result = await ref.read(projectProvider.notifier).createProject(
                                name: nameCtrl.text.trim(),
                                companyId: null,
                                category: 'General',
                                status: ProjectStatus.draft,
                              );
                              
                              if (result != null) {
                                setDialogState(() {
                                  createdProject = result;
                                  isCreating = false;
                                });
                              } else {
                                setDialogState(() => isCreating = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to create project.'), backgroundColor: Colors.red),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isCreating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: isCreating 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('CREATE PROJECT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessDialog(BuildContext context, Project project, bool isDark) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(IconsaxPlusBold.tick_circle, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Successfully Created', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Project "${project.name}" is now live.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
            const SizedBox(height: 32),
            _buildFieldLabel('PROJECT PID (CLICK TO COPY)', isDark),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: project.pid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PID Copied to Clipboard'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(project.pid, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'monospace', letterSpacing: 1)),
                    const SizedBox(width: 12),
                    const Icon(IconsaxPlusLinear.copy, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms).fadeIn();
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white38 : Colors.black54));
  }

  Widget _buildDialogField(TextEditingController ctrl, String hint, IconData icon, bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: ctrl,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
          prefixIcon: Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  void showAttachCompanyDialog(BuildContext context, Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();
    String query = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final companies = ref.read(companyProvider).value?.companies ?? [];
          final filtered = companies.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();

          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connect Company', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Linking project: ${project.name}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('PID: ', style: TextStyle(fontSize: 12, color: Colors.white38)),
                      Text(project.pid, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (val) => setDialogState(() => query = val),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Search company name...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                        prefixIcon: const Icon(IconsaxPlusLinear.search_normal, size: 16, color: Colors.white38),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Select a company to attach:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1)),
                  const SizedBox(height: 8),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final comp = filtered[i];
                        return ListTile(
                          onTap: () async {
                            await ref.read(projectProvider.notifier).linkCompanyToProject(project.id, comp.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(IconsaxPlusLinear.buildings, size: 16, color: AppColors.primary),
                          ),
                          title: Text(comp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(comp.id, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                          trailing: const Icon(IconsaxPlusLinear.add_circle, size: 20, color: AppColors.primary),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectListItem extends ConsumerStatefulWidget {
  final Project project;
  final bool isDark;

  const _ProjectListItem({required this.project, required this.isDark});

  @override
  ConsumerState<_ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends ConsumerState<_ProjectListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.project.status);
    final progress = widget.project.totalBudget > 0 ? (widget.project.consumedBudget / widget.project.totalBudget) : 0.0;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 768;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 4), // 4px vertical gap
        decoration: BoxDecoration(
          color: widget.isDark 
              ? (_isHovered ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02))
              : (_isHovered ? statusColor.withOpacity(0.04) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered 
                ? statusColor.withOpacity(0.5) 
                : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            width: _isHovered ? 1.0 : 0.8,
          ),
          boxShadow: widget.isDark ? [] : [
            if (_isHovered)
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => GoRouter.of(context).pushNamed('project_manage', pathParameters: {'id': widget.project.id}),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 16,
                vertical: isMobile ? 12 : 14,
              ),
              child: isMobile 
                  ? _buildMobileLayout(statusColor, progress)
                  : _buildDesktopLayout(statusColor, progress),
            ),
          ),
        ),
      ),
    );
  }

  void _showDraftDialog(BuildContext context, Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(IconsaxPlusBold.edit_2, size: 32, color: Colors.orangeAccent),
              ),
              const SizedBox(height: 16),
              const Text('Move to Draft?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'This project will be private and only visible to administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${project.name} moved to drafts'), backgroundColor: Colors.orangeAccent),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Move to Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms).fadeIn(),
    );
  }

  Widget _buildDesktopLayout(Color statusColor, double progress) {
    final tp = ref.watch(taskProvider);
    final linkedTasks = tp.allTasks.where((t) => widget.project.taskIds.contains(t.id)).toList();
    final taskProgress = linkedTasks.isEmpty ? 0.0 : linkedTasks.where((t) => t.status.name == 'done').length / linkedTasks.length;
    final displayTaskProgress = linkedTasks.isEmpty ? (widget.project.id.hashCode % 100) / 100 : taskProgress;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              _buildProjectIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.w800, 
                              color: widget.isDark ? Colors.white.withOpacity(0.95) : AppColors.lightText, 
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (widget.project.status == ProjectStatus.draft)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Icon(IconsaxPlusBold.edit_2, size: 10, color: Colors.orangeAccent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildPidCopy(),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BUDGET & TASKS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: widget.isDark ? Colors.white38 : Colors.black38)),
                    Text('${(displayTaskProgress * 100).toInt()}% | \$${NumberFormat.compact().format(widget.project.consumedBudget)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: displayTaskProgress,
                    minHeight: 4,
                    backgroundColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildCompanyInfo(),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildTeamStack(),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: _statusBadge(widget.project.status, statusColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _showDraftDialog(context, widget.project),
                icon: Icon(IconsaxPlusLinear.document_favorite, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
                tooltip: 'Move to Draft',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => GoRouter.of(context).pushNamed('project_manage', pathParameters: {'id': widget.project.id}),
                icon: Icon(IconsaxPlusLinear.eye, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
                tooltip: 'Visit Project',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(IconsaxPlusLinear.arrow_right_3, size: 18, color: widget.isDark ? Colors.white24 : Colors.black26),
                onPressed: () => GoRouter.of(context).pushNamed('project_manage', pathParameters: {'id': widget.project.id}),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Color statusColor, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildProjectIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.w800, 
                            color: widget.isDark ? Colors.white.withOpacity(0.95) : AppColors.lightText,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildPidCopy(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _statusBadge(widget.project.status, statusColor),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BUDGET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: widget.isDark ? Colors.white38 : AppColors.lightTextMuted)),
                      Text('\$${NumberFormat.compact().format(widget.project.consumedBudget)} / \$${NumberFormat.compact().format(widget.project.totalBudget)}', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : AppColors.lightText)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (widget.project.id.hashCode % 100) / 100,
                      minHeight: 3,
                      backgroundColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCompanyInfo(),
            Row(
              children: [
                _buildTeamStack(),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _showDraftDialog(context, widget.project),
                  icon: Icon(IconsaxPlusLinear.document_favorite, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                 IconButton(
                  onPressed: () => GoRouter.of(context).pushNamed('project_manage', pathParameters: {'id': widget.project.id}),
                  icon: Icon(IconsaxPlusLinear.eye, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => GoRouter.of(context).pushNamed('project_manage', pathParameters: {'id': widget.project.id}),
                  icon: Icon(IconsaxPlusLinear.arrow_right_3, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: widget.project.brandColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.project.brandColor.withOpacity(0.3)),
      ),
      child: Center(
        child: Icon(IconsaxPlusBold.folder_2, color: widget.project.brandColor, size: 22),
      ),
    );
  }

  Widget _buildPidCopy() {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: widget.project.pid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PID Copied: ${widget.project.pid}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.project.pid,
            style: TextStyle(
              fontSize: 11, 
              color: widget.project.brandColor, 
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 4),
          Icon(IconsaxPlusLinear.copy, size: 10, color: widget.project.brandColor.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo() {
    final hasCompany = widget.project.companyId != null && widget.project.companyId != 'null' && widget.project.companyId != '';
    if (!hasCompany) {
      return InkWell(
        onTap: () => (context.findAncestorStateOfType<_ProjectsScreenState>())?.showAttachCompanyDialog(context, widget.project),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IconsaxPlusLinear.link, size: 12, color: Colors.redAccent),
              SizedBox(width: 6),
              Text('Unlinked', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconsaxPlusBold.buildings, size: 12, color: widget.isDark ? Colors.white70 : AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.project.companyName ?? 'Linked',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : AppColors.primary, 
                fontSize: 10, 
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStack() {
    int teamCount = (widget.project.id.hashCode % 5) + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28.0 + ((teamCount > 3 ? 3 : teamCount) - 1) * 16.0,
          height: 28,
          child: Stack(
            children: List.generate((teamCount > 3 ? 3 : teamCount), (index) {
              return Positioned(
                left: index * 16.0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.primaries[(widget.project.id.hashCode + index) % Colors.primaries.length],
                    border: Border.all(color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(IconsaxPlusBold.user, size: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              );
            }),
          ),
        ),
        if (teamCount > 3)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('+${teamCount - 3}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.white54 : Colors.black54)),
          ),
      ],
    );
  }

  Widget _statusBadge(ProjectStatus status, Color color) {
    IconData icon;
    switch (status) {
      case ProjectStatus.active: icon = IconsaxPlusBold.flash; break;
      case ProjectStatus.completed: icon = IconsaxPlusBold.tick_circle; break;
      case ProjectStatus.onHold: icon = IconsaxPlusBold.pause_circle; break;
      case ProjectStatus.planning: icon = IconsaxPlusBold.clock; break;
      case ProjectStatus.draft: icon = IconsaxPlusBold.edit; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Color _getStatusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active: return const Color(0xFF10B981);
      case ProjectStatus.completed: return AppColors.secondary;
      case ProjectStatus.onHold: return const Color(0xFFEF4444);
      case ProjectStatus.planning: return const Color(0xFF3B82F6);
      case ProjectStatus.draft: return const Color(0xFFF59E0B);
    }
  }
}
