import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../../tasks/presentation/tasks_screen.dart';

class SingleProjectManageScreen extends ConsumerStatefulWidget {
  final String projectId;

  const SingleProjectManageScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<SingleProjectManageScreen> createState() => _SingleProjectManageScreenState();
}

class _SingleProjectManageScreenState extends ConsumerState<SingleProjectManageScreen> {
  int _selectedTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const double kHeaderHeight = 54.0;
  static const double kSidebarWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return projectState.when(
      data: (projects) {
        final project = projects.firstWhere(
          (p) => p.id == widget.projectId,
          orElse: () => Project(
            id: 'N/A',
            pid: 'N/A',
            name: 'Project Not Found',
            brandColor: Colors.grey,
            category: 'N/A',
            status: ProjectStatus.onHold,
            totalBudget: 0,
            consumedBudget: 0,
            taskIds: [],
            description: '',
            startDate: DateTime.now(),
          ),
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          drawer: !isDesktop ? _buildSidebar(project, isDark, true) : null,
          body: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop) _buildSidebar(project, isDark, false),
                    Expanded(
                      child: Stack(
                        children: [
                          // Content Area
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.only(top: kHeaderHeight),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: _buildContent(project, isDark),
                              ),
                            ),
                          ),
                          
                          // Header
                          Positioned(
                            top: 0, 
                            left: 0, 
                            right: 0,
                            child: _buildHeader(project, isDark, !isDesktop),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildHeader(Project project, bool isDark, bool showMenu) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: kHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1117).withOpacity(0.85)
                : const Color(0xFFF8FAFC).withOpacity(0.92),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (showMenu)
                    _headerIcon(Icons.menu_rounded, isDark, () => _scaffoldKey.currentState?.openDrawer()),
                  if (showMenu) const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.80),
                        ),
                      ),
                      Text(
                        _getTabTitle(_selectedTabIndex),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerIcon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    isDark,
                    () => ref.read(themeNotifierProvider.notifier).toggleTheme(),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 19,
            color: isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.60)),
        ),
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0: return 'Project Overview';
      case 1: return 'Operational Tasks';
      case 2: return 'Financial Registry';
      case 3: return 'Resource Allocation';
      case 4: return 'Project Settings';
      default: return '';
    }
  }

  Widget _buildSidebar(Project project, bool isDark, bool isDrawer) {
    final width = isDrawer ? 280.0 : kSidebarWidth;
    final bgColor = isDark
        ? const Color(0xFF0F1117).withOpacity(0.85)
        : const Color(0xFFF8FAFC).withOpacity(0.92);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isDrawer ? MediaQuery.of(context).padding.top + 24 : 12),
          
          // Back Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => context.go('/projects'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      'All Projects',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white10),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _sidebarItem(0, IconsaxPlusLinear.grid_1, 'Overview', isDark),
                _sidebarItem(1, IconsaxPlusLinear.task, 'Tasks', isDark),
                _sidebarItem(2, IconsaxPlusLinear.money_3, 'Budget', isDark),
                _sidebarItem(3, IconsaxPlusLinear.user_tag, 'Team', isDark),
                _sidebarItem(4, IconsaxPlusLinear.setting_2, 'Settings', isDark),
              ],
            ),
          ),

          // Project Identifier Card
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: project.brandColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: project.brandColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: project.brandColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(IconsaxPlusBold.folder_2, color: project.brandColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        project.pid,
                        style: TextStyle(
                          fontSize: 9,
                          color: project.brandColor,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    final primaryColor = AppColors.primary;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedTabIndex = index);
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? primaryColor : unselectedColor,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : Colors.black87) : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Project project, bool isDark) {
    switch (_selectedTabIndex) {
      case 0: return _buildOverviewTab(project, isDark);
      case 1: return const TasksScreen();
      case 2: return _buildPlaceholderTab('Budget Details', IconsaxPlusLinear.money_3, isDark);
      case 3: return _buildPlaceholderTab('Team Management', IconsaxPlusLinear.user_tag, isDark);
      case 4: return _buildPlaceholderTab('Project Settings', IconsaxPlusLinear.setting_2, isDark);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab(Project project, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              children: [
                _buildStatCard('Total Budget', '\$${NumberFormat.compact().format(project.totalBudget)}', IconsaxPlusLinear.wallet, Colors.blue, isDark),
                const SizedBox(height: 16),
                _buildStatCard('Budget Consumed', '\$${NumberFormat.compact().format(project.consumedBudget)}', IconsaxPlusLinear.money_send, Colors.orange, isDark),
                const SizedBox(height: 16),
                _buildStatCard('Tasks Linked', project.taskIds.length.toString(), IconsaxPlusLinear.task_square, Colors.green, isDark),
              ],
            )
          else
            Row(
              children: [
                _buildStatCard('Total Budget', '\$${NumberFormat.compact().format(project.totalBudget)}', IconsaxPlusLinear.wallet, Colors.blue, isDark),
                const SizedBox(width: 20),
                _buildStatCard('Budget Consumed', '\$${NumberFormat.compact().format(project.consumedBudget)}', IconsaxPlusLinear.money_send, Colors.orange, isDark),
                const SizedBox(width: 20),
                _buildStatCard('Tasks Linked', project.taskIds.length.toString(), IconsaxPlusLinear.task_square, Colors.green, isDark),
              ],
            ),
          const SizedBox(height: 32),
          _buildInfoSection(project, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );

    return isMobile ? content : Expanded(child: content);
  }

  Widget _buildInfoSection(Project project, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Metadata',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Identifier (PID)', project.pid, isDark),
          _buildInfoRow('Project Category', project.category, isDark),
          _buildInfoRow('Current Status', project.status.name.toUpperCase(), isDark),
          _buildInfoRow('Associated Company', project.companyName ?? 'Unlinked', isDark),
          const Divider(height: 40, color: Colors.white10),
          Text(
            'Description',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Text(
            'No detailed description available for this project yet. Please update the project settings to add mission statements and operational goals.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black.withOpacity(0.1)),
          ),
          const SizedBox(height: 8),
          Text(
            'This project module is currently being optimized for real-time synchronization.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
        ],
      ),
    ).animate().fade().scale();
  }
}
