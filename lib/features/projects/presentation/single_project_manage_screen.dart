import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/presentation/task_workspace_screen.dart';
import 'package:uuid/uuid.dart';


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
  Plan? _activePlan;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const double kHeaderHeight = 54.0;
  static const double kSidebarWidth = 240.0;

  bool _isGovernanceExpanded = false;
  bool _isBriefExpanded = false;
  bool _isDetailsExpanded = false;


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

        if (_selectedTabIndex == 1 &&
            project.managerSignature.isNotEmpty &&
            project.founderSignature.isEmpty &&
            !_isAuthDialogOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFounderAuthDialog(context, project);
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          drawer: !isDesktop ? _buildSidebar(project, isDark, true) : null,
          body: SafeArea(
            top: !isDesktop,
            bottom: !isDesktop,
            left: !isDesktop,
            right: !isDesktop,
            child: Column(
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
      case 1: return 'Blueprint Records';
      case 2: return 'Strategic Radar';
      case 3: return _activePlan != null ? 'Plan Console · ${_activePlan!.title}' : 'Strategic Plans';
      case 4: return 'Console Log Analysis';
      case 5: return 'Project Settings';
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
                _sidebarItem(1, IconsaxPlusLinear.verify, 'Records', isDark),
                _sidebarItem(2, IconsaxPlusLinear.radar, 'Radar', isDark),
                _sidebarItem(3, IconsaxPlusLinear.hierarchy, 'Plans', isDark),
                _sidebarItem(4, IconsaxPlusLinear.document_favorite, 'Console Log', isDark),
                _sidebarItem(5, IconsaxPlusLinear.setting_2, 'Settings', isDark),
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
      case 1: return _buildRecordsTab(project, isDark);
      case 2: return _buildRadarTab(project, isDark);
      case 3:
        if (_activePlan != null) {
          return _PlanConsoleCentral(
            project: project,
            plan: _activePlan!,
            isDark: isDark,
            onBack: () => setState(() => _activePlan = null),
          );
        }
        return _PlansTabCentral(
          project: project,
          isDark: isDark,
          ref: ref,
          onOpenConsole: (p) => setState(() => _activePlan = p),
        );
      case 4:
        return _ConsoleLogCentral(
          project: project,
          isDark: isDark,
          onOpenConsole: (p) => setState(() {
            _activePlan = p;
            _selectedTabIndex = 3;
          }),
        );
      case 5: return _buildPlaceholderTab('Project Settings', IconsaxPlusLinear.setting_2, isDark);
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
          
          if (!project.isApproved && ['admin', 'sub_admin', 'super_admin'].contains(ref.watch(authProvider).role)) ...[
            _buildApprovalBar(project, isDark),
            const SizedBox(height: 32),
          ],

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
          _buildInfoRow('Approval State', project.isApproved ? 'LIVE / ACTIVE' : 'PENDING APPROVAL', isDark),
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

  Widget _buildRadarTab(Project project, bool isDark) {
    return _StrategicRadarMapCentral(
      project: project,
      onPlanSelected: (plan) {
        setState(() {
          _activePlan = plan;
          _selectedTabIndex = 3;
        });
      },
    );
  }

  Widget _buildRadarMetricCard(String title, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableText({
    required String text,
    required int wordLimit,
    required TextStyle style,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= wordLimit) {
      return Text(text, style: style);
    }

    final displayText = isExpanded ? text : '${words.take(wordLimit).join(' ')}...';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: style),
        const SizedBox(height: 4),
        InkWell(
          onTap: onToggle,
          child: Text(
            isExpanded ? 'Collapse' : 'See more',
            style: TextStyle(
              color: widget.projectId != 'N/A' ? Colors.blue : AppColors.primary,
              fontSize: (style.fontSize ?? 14) - 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(Project project, bool isDark) {
    final color = project.brandColor;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!project.isApproved && ['admin', 'sub_admin', 'super_admin'].contains(ref.watch(authProvider).role)) ...[
            _buildApprovalBar(project, isDark).animate().fadeIn().slideY(begin: -0.1, end: 0),
            const SizedBox(height: 24),
          ],
          // ── HERO: Project Identity Banner ────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover Photo Gradient ──────────────────────────────────
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [color.withOpacity(0.4), color.withOpacity(0.1)]
                        : [color.withOpacity(0.15), color.withOpacity(0.03)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: project.coverPhotoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(project.coverPhotoUrl),
                          fit: BoxFit.cover,
                          opacity: isDark ? 0.35 : 0.5,
                        )
                      : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(IconsaxPlusLinear.folder_open, size: 200, color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)),
                      ),
                    ],
                  ),
                ),
                
                // ── Profile Identity Row ──────────────────────────────────
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Logo/Avatar
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(IconsaxPlusBold.folder_2, color: color, size: 50),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Identity Details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.name,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // PID Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: color.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(IconsaxPlusLinear.copy, size: 14, color: color),
                                              const SizedBox(width: 8),
                                              Text(
                                                project.pid,
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Category
                                        Text(
                                          project.category.isNotEmpty ? project.category.toUpperCase() : "REGISTRY",
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.black38,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // ── Description / Motto ─────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BRIEF DESCRIPTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: color.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildExpandableText(
                              text: project.description.isNotEmpty == true
                                  ? project.description
                                  : 'Strategic organization identity pending brief deployment.',
                              wordLimit: 40,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontStyle: FontStyle.italic,
                                  height: 1.6,
                              ),
                              isExpanded: _isBriefExpanded,
                              onToggle: () => setState(() => _isBriefExpanded = !_isBriefExpanded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Strategic Inspiration ─────────────────────────────────────────
          _buildRecordCard('Strategic Inspiration', IconsaxPlusLinear.lamp_charge, isDark, color, [
            _buildRecordRow(
              'Inspiration Brief',
              project.inspirationText.isNotEmpty
                  ? project.inspirationText
                  : 'No strategic inspiration brief defined yet.',
              isDark,
            ),
            if (project.website.isNotEmpty)
              _buildRecordRow('Official Website', project.website, isDark),
          ]),

          // ── Project Budget Parameters ────────────────────────────────────
          _buildRecordCard('Project Budget Parameters', IconsaxPlusLinear.dollar_circle, isDark, color, [
            LayoutBuilder(
              builder: (context, constraints) {
                final bool useVertical = constraints.maxWidth < 600;
                final Widget content = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: useVertical ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MINIMUM SUGGESTED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text('\$${(project.minBudget > 0 ? project.minBudget : project.totalBudget * 0.85).toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(project.minBudget > 0 ? 'Manager custom budget limit' : 'System parameter calculation (85%)', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                    ),
                    if (useVertical) const SizedBox(height: 24) else const SizedBox(width: 16),
                    Expanded(
                      flex: useVertical ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MAXIMUM SUGGESTED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text('\$${(project.maxBudget > 0 ? project.maxBudget : project.totalBudget * 1.15).toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(project.maxBudget > 0 ? 'Manager custom budget limit' : 'System parameter calculation (115%)', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                    ),
                    if (useVertical) const SizedBox(height: 24) else const SizedBox(width: 16),
                    Expanded(
                      flex: useVertical ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FOUNDER CONFIRMED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          if (project.confirmedBudget != null && project.confirmedBudget! > 0) ...[
                            Text('\$${project.confirmedBudget!.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: const Text('LOCKED & APPROVED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                          ] else ...[
                            Text('PENDING', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                              ),
                              child: const Text('AWAITING CONFIRMATION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
                
                if (useVertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MINIMUM SUGGESTED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text('\$${(project.minBudget > 0 ? project.minBudget : project.totalBudget * 0.85).toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(project.minBudget > 0 ? 'Manager custom budget limit' : 'System parameter calculation (85%)', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MAXIMUM SUGGESTED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text('\$${(project.maxBudget > 0 ? project.maxBudget : project.totalBudget * 1.15).toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(project.maxBudget > 0 ? 'Manager custom budget limit' : 'System parameter calculation (115%)', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FOUNDER CONFIRMED BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          if (project.confirmedBudget != null && project.confirmedBudget! > 0) ...[
                            Text('\$${project.confirmedBudget!.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: const Text('LOCKED & APPROVED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                          ] else ...[
                            Text('PENDING', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                              ),
                              child: const Text('AWAITING CONFIRMATION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }
                return content;
              },
            ),
          ]),

          // ── Project Budget Authorization ─────────────────────────────────────
          _buildRecordCard('Project Budget Authorization', IconsaxPlusLinear.verify, isDark, color, [
            if (project.founderSignature.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(IconsaxPlusLinear.lock, color: Colors.orangeAccent, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PENDING DEPLOYMENT AUTHORIZATION',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The registered budget of \$${project.totalBudget.toStringAsFixed(0)} requires Founder Signature to unlock active node registry.',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showFounderAuthDialog(context, project),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Sign Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            LayoutBuilder(
              builder: (context, constraints) {
                final bool useVertical = constraints.maxWidth < 600;
                final Widget content = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Executive Signature
                    Expanded(
                      flex: useVertical ? 0 : 1,
                      child: _buildSignatureBlock(
                        'EXECUTIVE SIGNATURE',
                        project.managerSignature.isNotEmpty ? project.managerSignature : 'PENDING EXECUTOR DEPLOYMENT',
                        project.managerSignatureTimestamp,
                        isDark,
                      ),
                    ),
                    
                    if (useVertical) const SizedBox(height: 40) else ...[
                      // Divider
                      Container(
                        width: 1,
                        height: 100,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      ),
                    ],

                    // Right: Founder Signature
                    Expanded(
                      flex: useVertical ? 0 : 1,
                      child: _buildSignatureBlock(
                        'FOUNDER SIGNATURE',
                        project.founderSignature.isNotEmpty ? project.founderSignature : 'PENDING DEPLOYMENT',
                        project.founderSignatureTimestamp,
                        isDark,
                        isFounder: true,
                      ),
                    ),
                  ],
                );
                
                if (useVertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSignatureBlock(
                        'EXECUTIVE SIGNATURE',
                        project.managerSignature.isNotEmpty ? project.managerSignature : 'PENDING EXECUTOR DEPLOYMENT',
                        project.managerSignatureTimestamp,
                        isDark,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      ),
                      const SizedBox(height: 32),
                      _buildSignatureBlock(
                        'FOUNDER SIGNATURE',
                        project.founderSignature.isNotEmpty ? project.founderSignature : 'PENDING DEPLOYMENT',
                        project.founderSignatureTimestamp,
                        isDark,
                        isFounder: true,
                      ),
                    ],
                  );
                }
                return content;
              },
            ),
          ]),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String title, IconData icon, bool isDark, Color color, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows.expand((r) => [r, Divider(height: 40, color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))]).toList()..removeLast(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRecordRow(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureBlock(String label, String signature, DateTime? timestamp, bool isDark, {bool isFounder = false}) {
    final bool hasSignature = signature != 'UNAUTHORIZED' && signature != 'PENDING DEPLOYMENT' && signature.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5),
            ),
            if (hasSignature) ...[
              const SizedBox(width: 8),
              Icon(IconsaxPlusBold.verify, size: 12, color: const Color(0xFF10B981).withOpacity(0.7)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            signature,
            style: GoogleFonts.caveat(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: hasSignature 
                  ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9))
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasSignature && timestamp != null)
          Text(
            'Digitally Verified: ${DateFormat('MMM dd, yyyy | hh:mm a').format(timestamp)}',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w500),
          )
        else
          Text(
            isFounder ? 'Awaiting Founder Authorization' : 'Signature pending deployment',
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? Colors.white12 : Colors.black.withOpacity(0.1)),
          ),
      ],
    );
  }

  bool _isAuthDialogOpen = false;

  void _showFounderAuthDialog(BuildContext context, Project project) {
    if (_isAuthDialogOpen) return;
    _isAuthDialogOpen = true;

    final TextEditingController signatureController = TextEditingController();
    final TextEditingController budgetController = TextEditingController(text: project.totalBudget.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = project.brandColor;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Founder Authorization',
      barrierColor: Colors.black.withOpacity(0.8),
      pageBuilder: (ctx, _, __) {
        int currentStep = 1;
        
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final double minBud = project.minBudget > 0 ? project.minBudget : project.totalBudget * 0.85;
            final double maxBud = project.maxBudget > 0 ? project.maxBudget : project.totalBudget * 1.15;

            return Center(
              child: Material(
                color: Colors.transparent,
                child: GlassContainer(
                  width: 500,
                  padding: const EdgeInsets.all(40),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: currentStep == 1
                        ? Column(
                            key: const ValueKey(1),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(IconsaxPlusBold.dollar_circle, color: color, size: 40),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'STEP 1: CONFIRM BUDGET',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Before signing the project, please verify and set a finalized budget. The suggested range based on manager settings is outlined below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Range display
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(project.minBudget > 0 ? 'MANAGER MIN LIMIT' : 'MIN LIMIT (85%)', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('\$${minBud.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                      ],
                                    ),
                                    Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.black12),
                                    Column(
                                      children: [
                                        Text(project.maxBudget > 0 ? 'MANAGER MAX LIMIT' : 'MAX LIMIT (115%)', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('\$${maxBud.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Budget Input field
                              TextField(
                                controller: budgetController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                decoration: InputDecoration(
                                  hintText: 'Enter Confirmed Budget',
                                  labelText: 'CONFIRMED BUDGET AMOUNT (\$)',
                                  labelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                  prefixIcon: const Icon(IconsaxPlusLinear.money_3, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: color, width: 2),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text('CANCEL', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final double? enteredVal = double.tryParse(budgetController.text);
                                        if (enteredVal == null || enteredVal <= 0) return;
                                        setPopupState(() {
                                          currentStep = 2;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      child: const Text('NEXT STEP', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey(2),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(IconsaxPlusBold.verify, color: color, size: 40),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'STEP 2: FOUNDER SIGNATURE',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Budget Confirmation Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(IconsaxPlusBold.dollar_circle, color: color, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CONFIRMED BUDGET: \$${double.tryParse(budgetController.text)?.toStringAsFixed(0) ?? budgetController.text}',
                                      style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Text(
                                'Enter your official signature to finalize and lock this project parameter registry.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Signature Input
                              TextField(
                                controller: signatureController,
                                style: GoogleFonts.caveat(
                                  fontSize: 32,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter Founder Signature',
                                  hintStyle: GoogleFonts.caveat(fontSize: 24, color: isDark ? Colors.white24 : Colors.black26),
                                  labelText: 'OFFICIAL SIGNATURE',
                                  labelStyle: const TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                                  prefixIcon: const Icon(IconsaxPlusLinear.edit_2, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: color, width: 2),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () {
                                        setPopupState(() {
                                          currentStep = 1;
                                        });
                                      },
                                      child: Text('BACK', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (signatureController.text.trim().isEmpty) return;
                                        final double? parsedBudget = double.tryParse(budgetController.text);
                                        if (parsedBudget == null || parsedBudget <= 0) return;
                                        
                                        ref.read(projectProvider.notifier).updateProject(
                                          project.id,
                                          {
                                            'founder_signature': signatureController.text.trim(),
                                            'founder_signature_timestamp': DateTime.now().toIso8601String(),
                                            'confirmed_budget': parsedBudget,
                                            'is_approved': true,
                                          },
                                        );
                                        Navigator.pop(ctx);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      child: const Text('FINALIZE RECORD', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          }
        );
      },
    ).then((_) {
      _isAuthDialogOpen = false;
    });
  }

  Widget _buildApprovalBar(Project project, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [Colors.amber.withOpacity(0.15), Colors.amber.withOpacity(0.05)]
            : [Colors.amber.withOpacity(0.1), Colors.amber.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(IconsaxPlusBold.verify, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Authorization',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber[100] : Colors.amber[900],
                  ),
                ),
                Text(
                  project.managerSignature.isNotEmpty
                      ? 'This project blueprint has been signed by Manager "${project.managerSignature}" and requires your review to go live.'
                      : 'This project was created by a Manager and requires your review to go live (Manager signature is currently pending).',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.amber[100]?.withOpacity(0.7) : Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _handleApproval(project.id, false),
                child: Text('Decline', style: TextStyle(color: isDark ? Colors.redAccent[100] : Colors.redAccent)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _showFounderAuthDialog(context, project),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Approve & Go Live', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproval(String id, bool approved) async {
    try {
      if (!approved) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Reject Project?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              'This project will be marked as rejected. The creator will see it as not approved.',
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        await ref.read(projectProvider.notifier).rejectProject(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project rejected.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}



// ── Plans Tab ──────────────────────────────────────────────────────────────────
class _PlansTabCentral extends StatefulWidget {
  final Project project;
  final bool isDark;
  final WidgetRef ref;
  final Function(Plan) onOpenConsole;
  const _PlansTabCentral({required this.project, required this.isDark, required this.ref, required this.onOpenConsole});
  @override
  State<_PlansTabCentral> createState() => _PlansTabCentralState();
}

class _PlansTabCentralState extends State<_PlansTabCentral> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.ref.read(taskProvider.notifier).syncWithDatabase(
        projectId: widget.project.id,
        companyId: widget.project.companyId,
      );
    });
  }

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _handleCreatePlan() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await widget.ref.read(projectProvider.notifier).addPlan(
        widget.project.id,
        _titleCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
      _titleCtrl.clear();
      _descCtrl.clear();
    } catch (_) {}
    if (mounted) {
      setState(() => _isCreating = false);
    }
  }

  String _formatPlanCode(Plan plan) {
    String suffix = '';
    if (plan.id.length >= 4 && !RegExp(r'^\d+$').hasMatch(plan.id)) {
      suffix = plan.id.substring(0, 4).toUpperCase();
    } else {
      suffix = plan.icode.length >= 4 
          ? plan.icode.substring(0, 4).toUpperCase() 
          : plan.icode.padLeft(4, '0').toUpperCase();
    }
    final prefix = widget.project.pid.isEmpty ? 'PLN' : widget.project.pid;
    return '$prefix-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.project.brandColor;
    final plans = widget.project.plans;

    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    // Group plans by date
    final Map<String, List<Plan>> groupedPlans = {};
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    
    // Sort plans by createdAt (newest first)
    final sortedPlans = List<Plan>.from(plans);
    sortedPlans.sort((a, b) {
      final aTime = a.createdAt != null ? a.createdAt!.toLocal() : widget.project.startDate.toLocal();
      final bTime = b.createdAt != null ? b.createdAt!.toLocal() : widget.project.startDate.toLocal();
      return bTime.compareTo(aTime);
    });

    for (final plan in sortedPlans) {
      final time = plan.createdAt != null ? plan.createdAt!.toLocal() : widget.project.startDate.toLocal();
      final dateStr = DateFormat('yyyy-MM-dd').format(time);
      
      String groupHeader;
      if (dateStr == todayStr) {
        groupHeader = 'Today';
      } else if (dateStr == yesterdayStr) {
        groupHeader = 'Yesterday';
      } else {
        groupHeader = DateFormat('MMMM dd, yyyy').format(time);
      }
      
      if (!groupedPlans.containsKey(groupHeader)) {
        groupedPlans[groupHeader] = [];
      }
      groupedPlans[groupHeader]!.add(plan);
    }

    Widget buildCreatePlanBar() {
      return Padding(
        padding: EdgeInsets.only(
          left: isMobile ? 12 : 24,
          right: isMobile ? 12 : 24,
          top: isMobile ? 16 : 24,
          bottom: 8,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 12 : 8,
          ),
          decoration: BoxDecoration(
            color: widget.isDark 
                ? const Color(0xFF0F111A).withOpacity(0.8)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: isMobile 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          IconsaxPlusLinear.hierarchy_3,
                          size: 13,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NEW STRATEGIC PLAN',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            color: widget.isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Plan title...',
                        hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: widget.isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descCtrl,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Brief objective...',
                        hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: widget.isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isCreating ? null : _handleCreatePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isCreating 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                          : const Icon(IconsaxPlusLinear.add, size: 14),
                      label: const Text('DEPLOY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      IconsaxPlusLinear.hierarchy_3,
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NEW PLAN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: widget.isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 34,
                        child: TextField(
                          controller: _titleCtrl,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Plan title...',
                            hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.black38),
                            filled: true,
                            fillColor: widget.isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 34,
                        child: TextField(
                          controller: _descCtrl,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Brief objective (optional)...',
                            hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.black38),
                            filled: true,
                            fillColor: widget.isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _isCreating ? null : _handleCreatePlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isCreating 
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                            : const Icon(IconsaxPlusLinear.add, size: 14),
                        label: const Text('DEPLOY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    Widget buildTimelineList() {
      return plans.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(IconsaxPlusLinear.hierarchy, size: 40, color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                    const SizedBox(height: 12),
                    Text(
                      'No plans yet. Deploy your first plan above.',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groupedPlans.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.isDark ? const Color(0xFF1E2230) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                color: widget.isDark ? Colors.white70 : Colors.black.withOpacity(0.75),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                                    widget.isDark ? Colors.white.withOpacity(0.0) : Colors.black.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...entry.value.map((plan) => _buildPlanCard(plan, color, isMobile)),
                  ],
                );
              }).toList(),
            );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useScrollableParent = constraints.maxHeight < 400;
        if (useScrollableParent) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCreatePlanBar(),
                Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 12 : 24,
                    right: isMobile ? 12 : 24,
                    bottom: isMobile ? 16 : 24,
                    top: 8,
                  ),
                  child: buildTimelineList(),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildCreatePlanBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: isMobile ? 12 : 24,
                  right: isMobile ? 12 : 24,
                  bottom: isMobile ? 16 : 24,
                  top: 8,
                ),
                child: buildTimelineList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(Plan plan, Color color, bool isMobile) {
    final planTime = plan.createdAt != null ? plan.createdAt!.toLocal() : widget.project.startDate.toLocal();
    final formattedTime = DateFormat('hh:mm a').format(planTime);
    final planCode = _formatPlanCode(plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF11131A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upper section (Information)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator line (brand color)
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Click to Copy UID Badge
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: plan.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Copied Plan UID to clipboard!'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: color,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color.withOpacity(0.2), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        planCode,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 10,
                                        color: color,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // LIVE status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Time Label
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Divider(
              height: 1,
              color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            ),
            
            // Bottom section: Beautiful Action Row (View Console, Edit, Remove)
            Container(
              color: widget.isDark ? const Color(0xFF0D0F14) : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // View Console Button (Primary Action)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onOpenConsole(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withOpacity(0.15),
                        foregroundColor: color,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: color.withOpacity(0.25), width: 1),
                        ),
                      ),
                      icon: Icon(IconsaxPlusLinear.category, size: 14, color: color),
                      label: const Text(
                        'View Console',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Edit Plan Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showEditPlanDialog(plan),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconsaxPlusLinear.edit_2,
                              color: widget.isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Delete Plan Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDeleteConfirmation(plan),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              IconsaxPlusLinear.trash,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlanDialog(Plan plan) {
    final titleCtrl = TextEditingController(text: plan.title);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Plan',
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.project.brandColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(IconsaxPlusLinear.edit_2, color: widget.project.brandColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'EDIT STRATEGIC PLAN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'PLAN TITLE',
                      labelStyle: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: widget.project.brandColor,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.project.brandColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newTitle = titleCtrl.text.trim();
                            if (newTitle.isEmpty) return;
                            
                            try {
                              await widget.ref.read(projectProvider.notifier).updatePlan(
                                widget.project.id,
                                plan.id,
                                newTitle,
                                '',
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Plan updated successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: widget.project.brandColor,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update plan: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.project.brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Plan plan) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete Plan',
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              width: 380,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(IconsaxPlusLinear.trash, color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DELETE STRATEGIC PLAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to permanently delete plan "${plan.title}"? All associated task connections within this console node will be detached.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await widget.ref.read(projectProvider.notifier).removePlan(widget.project.id, plan.id);
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Plan removed successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to remove plan: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('CONFIRM DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Plan Console (Kanban) ──────────────────────────────────────────────────────
class _PlanConsoleCentral extends ConsumerStatefulWidget {
  final Project project;
  final Plan plan;
  final bool isDark;
  final VoidCallback onBack;
  const _PlanConsoleCentral({
    required this.project,
    required this.plan,
    required this.isDark,
    required this.onBack,
  });

  @override
  ConsumerState<_PlanConsoleCentral> createState() => _PlanConsoleCentralState();
}

class _PlanConsoleCentralState extends ConsumerState<_PlanConsoleCentral> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).syncWithDatabase(
        companyId: widget.project.companyId,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.critical: return Colors.redAccent;
      case TaskPriority.high: return Colors.orangeAccent;
      case TaskPriority.medium: return Colors.indigoAccent;
      default: return Colors.blueAccent;
    }
  }

  Color _getColumnColor(TaskStatus status, Color brandColor, bool isDark) {
    if (isDark) {
      switch (status) {
        case TaskStatus.todo: return brandColor;
        case TaskStatus.inProgress: return Colors.blueAccent;
        case TaskStatus.review: return Colors.amberAccent;
        case TaskStatus.done: return Colors.greenAccent;
        case TaskStatus.completed: return Colors.tealAccent;
      }
    } else {
      switch (status) {
        case TaskStatus.todo: return brandColor;
        case TaskStatus.inProgress: return const Color(0xFF1E40AF); // Deep Indigo/Blue
        case TaskStatus.review: return const Color(0xFFB45309); // Deep Amber/Orange
        case TaskStatus.done: return const Color(0xFF15803D); // Deep Green
        case TaskStatus.completed: return const Color(0xFF0F766E); // Deep Teal
      }
    }
  }

  bool _canApprove(SystemTask task, AuthState auth) {
    return canUserApproveTask(task, auth);
  }

  bool _isValidDragTransition(TaskStatus current, TaskStatus target, AuthState auth) {
    if (current == target) return false;
    
    bool isAdjacent = false;
    if (current == TaskStatus.todo && target == TaskStatus.inProgress) isAdjacent = true;
    else if (current == TaskStatus.inProgress && (target == TaskStatus.todo || target == TaskStatus.review)) isAdjacent = true;
    else if (current == TaskStatus.review && (target == TaskStatus.inProgress || target == TaskStatus.done)) isAdjacent = true;
    else if (current == TaskStatus.done && (target == TaskStatus.review || target == TaskStatus.completed)) isAdjacent = true;
    else if (current == TaskStatus.completed && target == TaskStatus.done) isAdjacent = true;
    
    if (!isAdjacent) return false;
    
    final isAdminOrSub = auth.isAdmin || auth.isSubAdmin;
    
    if (current == TaskStatus.todo && target == TaskStatus.inProgress) {
      return isAdminOrSub || auth.isManager;
    } else if (current == TaskStatus.inProgress && target == TaskStatus.todo) {
      return isAdminOrSub || auth.isManager;
    } else if (current == TaskStatus.inProgress && target == TaskStatus.review) {
      return auth.isManager;
    } else if (current == TaskStatus.review && target == TaskStatus.inProgress) {
      return isAdminOrSub;
    } else if (current == TaskStatus.review && target == TaskStatus.done) {
      return isAdminOrSub;
    } else if (current == TaskStatus.done && target == TaskStatus.review) {
      return auth.isManager;
    } else if (current == TaskStatus.done && target == TaskStatus.completed) {
      return auth.isManager;
    } else if (current == TaskStatus.completed && target == TaskStatus.done) {
      return isAdminOrSub;
    }
    
    return false;
  }

  void _updateNodeStatus(SystemTask task, TaskStatus newStatus) async {
    await ref.read(taskProvider.notifier).updateTaskStatus(task.id, newStatus);
    
    // Log the status update comment
    final newComment = TaskComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      author: 'Admin',
      content: 'Node Integrity Approved: Promoted to ${newStatus.displayName}',
      createdAt: DateTime.now()
    );
    final updatedTask = task.copyWith(status: newStatus, comments: [...task.comments, newComment]);
    await ref.read(taskProvider.notifier).updateTask(updatedTask);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Node ${task.taskNumber} shifted to ${newStatus.displayName}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  void _exportConsoleData(List<SystemTask> tasks) async {
    if (tasks.isEmpty) return;
    final encoded = json.encode(tasks.map((t) => t.toMap()).toList());

    if (kIsWeb) {
      final bytes = utf8.encode(encoded);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Console_Bundle_${widget.plan.title}_${DateTime.now().millisecondsSinceEpoch}.json")
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Console bundle exported successfully.'), behavior: SnackBarBehavior.floating));
    } else {
      try {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Export Console Bundle',
          fileName: "Console_Bundle_${widget.plan.title}_${DateTime.now().millisecondsSinceEpoch}.json",
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (outputFile != null) {
          final File file = File(outputFile);
          await file.writeAsString(encoded);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Console bundle exported successfully.'), behavior: SnackBarBehavior.floating));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting data: $e'), behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  Future<void> _importConsoleData(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.isNotEmpty) {
        final content = result.files.first.bytes != null 
            ? utf8.decode(result.files.first.bytes!)
            : await File(result.files.first.path!).readAsString();
            
        final List decoded = json.decode(content);
        final tp = ref.read(taskProvider.notifier);
        int count = 0;
        for (final m in decoded) {
          final oldId = m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          final task = SystemTask.fromMap(m).copyWith(
            id: 'tsk_${DateTime.now().microsecondsSinceEpoch}_$oldId',
            planId: widget.plan.id,
            projectId: widget.project.id,
          );
          await tp.addTask(task, companyId: widget.project.companyId ?? '1');
          count++;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registry imported successfully ($count nodes).'), behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing data: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showAddNodeDialog(BuildContext context, Color color, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Link Console Node', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the UID of a node to link it to this plan.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'UID e.g. T-102...',
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final tp = ref.read(taskProvider.notifier);
              final query = _searchCtrl.text.trim().toUpperCase();
              if (query.isEmpty) return;

              // 1. Exact match
              var matches = tp.allTasks.where((t) => t.taskNumber.toUpperCase() == query);

              // 2. Contains match on taskNumber
              if (matches.isEmpty) {
                matches = tp.allTasks.where((t) => t.taskNumber.toUpperCase().contains(query));
              }

              // 3. Contains match on title
              if (matches.isEmpty) {
                matches = tp.allTasks.where((t) => t.title.toUpperCase().contains(query));
              }

              if (matches.isNotEmpty) {
                final task = matches.first;
                
                final updatedTask = task.copyWith(
                  planId: widget.plan.id,
                  projectId: widget.project.id,
                );
                await tp.updateTask(updatedTask);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Node ${task.taskNumber} successfully attached to traceability flow.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: color,
                  ));
                  _searchCtrl.clear();
                  Navigator.pop(context);
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('UID not found in console registry.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            child: const Text('Link Node'),
          ),
        ],
      ),
    );
  }

  void _showArchivedTasksDialog(BuildContext context, Color color, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(IconsaxPlusLinear.archive_tick, color: color),
            const SizedBox(width: 12),
            const Text('Archived Tasks History', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Consumer(
            builder: (context, ref, _) {
              final archivedTasks = ref.watch(taskProvider).allTasks.where((t) => t.planId == widget.plan.id && t.isArchived).toList();
              if (archivedTasks.isEmpty) {
                return Center(child: Text('No archived tasks.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)));
              }
              return ListView.builder(
                itemCount: archivedTasks.length,
                itemBuilder: (context, index) {
                  final task = archivedTasks[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.taskNumber, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 10)),
                              const SizedBox(height: 4),
                              Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(IconsaxPlusLinear.rotate_left, color: Colors.green),
                          tooltip: 'Restore to Console',
                          onPressed: () async {
                            await ref.read(taskProvider.notifier).updateTask(task.copyWith(isArchived: false, status: TaskStatus.completed));
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Restored!'), behavior: SnackBarBehavior.floating));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context, Color color, bool isDark) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        title: const Text('Fast Generate Task', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Task objective...',
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onSubmitted: (val) {
            _executeQuickAdd(val, ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _executeQuickAdd(titleCtrl.text, ctx),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            child: const Text('Add to TO DO'),
          ),
        ],
      )
    );
  }

  void _executeQuickAdd(String title, BuildContext ctx) async {
    if (title.trim().isEmpty) return;
    final tp = ref.read(taskProvider.notifier);
    final newTask = SystemTask(
      id: const Uuid().v4(),
      taskNumber: 'TSK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title.trim(),
      status: TaskStatus.todo,
      planId: widget.plan.id,
      projectId: widget.project.id,
    );
    await tp.addTask(newTask, companyId: widget.project.companyId ?? '1');
    if (ctx.mounted) Navigator.pop(ctx);
  }

  void _showManageTaskDialog(BuildContext context, SystemTask task, Color accent, bool isDark) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final tp = ref.watch(taskProvider);
          final currentTask = tp.allTasks.firstWhere((t) => t.id == task.id, orElse: () => task);
          final auth = ref.watch(authProvider);
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(IconsaxPlusLinear.setting_4, color: accent),
                          const SizedBox(width: 8),
                          const Text('Manage Node', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(IconsaxPlusLinear.close_circle), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  Text(currentTask.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (currentTask.status == TaskStatus.done || currentTask.status == TaskStatus.completed)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(IconsaxPlusLinear.tick_circle, color: Colors.green, size: 16),
                              SizedBox(width: 6),
                              Text('Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (currentTask.status != TaskStatus.todo && canUserApproveTask(currentTask, auth))
                        InkWell(
                          onTap: () async {
                            TaskStatus prevStatus = currentTask.status;
                            if (currentTask.status == TaskStatus.completed) prevStatus = TaskStatus.done;
                            else if (currentTask.status == TaskStatus.done) prevStatus = TaskStatus.review;
                            else if (currentTask.status == TaskStatus.review) prevStatus = TaskStatus.inProgress;
                            else if (currentTask.status == TaskStatus.inProgress) prevStatus = TaskStatus.todo;

                            final newComment = TaskComment(
                              id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
                              author: 'Admin',
                              content: 'Node Demoted Action: Moved to ${prevStatus.displayName}',
                              createdAt: DateTime.now()
                            );
                            await ref.read(taskProvider.notifier).updateTask(currentTask.copyWith(status: prevStatus, comments: [...currentTask.comments, newComment]));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Node Demoted to ${prevStatus.displayName}.'), behavior: SnackBarBehavior.floating));
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(IconsaxPlusLinear.arrow_left_2, color: Colors.orangeAccent, size: 16),
                                SizedBox(width: 6),
                                Text('Demote (Prev)', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Status: ${currentTask.status.displayName}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Activity & Comments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                    child: currentTask.comments.isEmpty
                        ? Center(child: Text('No activity yet. Be the first to comment.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: currentTask.comments.length,
                            itemBuilder: (c, i) {
                              final cmt = currentTask.comments[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(cmt.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text(cmt.createdAt.toString().substring(0, 16), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(cmt.content, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add tactical observations or reply...',
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(IconsaxPlusLinear.send_1, color: accent),
                        onPressed: () async {
                          if (commentCtrl.text.trim().isNotEmpty) {
                            final newComment = TaskComment(
                                id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
                                author: 'Admin',
                                content: commentCtrl.text.trim(),
                                createdAt: DateTime.now()
                            );
                            await ref.read(taskProvider.notifier).updateTask(currentTask.copyWith(comments: [...currentTask.comments, newComment]));
                            commentCtrl.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Update Node Integrity', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildActionButtons(bool isDesktop, Color color, bool isDark, List<SystemTask> tasks, int archivedCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionIconButton(
          onPressed: () => _showArchivedTasksDialog(context, color, isDark),
          icon: IconsaxPlusLinear.archive_tick,
          tooltip: 'Registry Archive ($archivedCount)',
          color: color,
          isDark: isDark,
          badge: archivedCount > 0 ? '$archivedCount' : null,
        ),
        _actionIconButton(
          onPressed: () => _exportConsoleData(tasks),
          icon: IconsaxPlusLinear.document_download,
          tooltip: 'Export Console Bundle',
          color: color,
          isDark: isDark,
        ),
        _actionIconButton(
          onPressed: () => _importConsoleData(context),
          icon: IconsaxPlusLinear.document_upload,
          tooltip: 'Import Cloud Registry',
          color: color,
          isDark: isDark,
        ),
        _actionIconButton(
          onPressed: () => _showAddNodeDialog(context, color, isDark),
          icon: IconsaxPlusLinear.search_status,
          tooltip: 'Search & Attach Node',
          color: color,
          isDark: isDark,
          isSpecial: true,
        ),
        const SizedBox(width: 8),
        _actionIconButton(
          onPressed: () => _showQuickAddDialog(context, color, isDark), 
          icon: IconsaxPlusLinear.add,
          tooltip: 'Generate New Node',
          color: color,
          isDark: isDark,
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _actionIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool isDark,
    String? badge,
    bool isPrimary = false,
    bool isSpecial = false,
  }) {
    final bgColor = isPrimary 
        ? color 
        : (isSpecial ? color.withOpacity(0.15) : color.withOpacity(0.08));
    final iconColor = isPrimary ? Colors.white : color;

    Widget button = Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );

    if (badge != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Badge(
          label: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: color,
          offset: const Offset(4, -4),
          child: button,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.project.brandColor;
    final isDesktop = MediaQuery.of(context).size.width > 750;
    final allPlanTasks = ref.watch(taskProvider).allTasks.where((t) => t.planId == widget.plan.id).toList();
    final tasks = allPlanTasks.where((t) => !t.isArchived).toList();
    final archivedCount = allPlanTasks.where((t) => t.isArchived).length;
    
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(IconsaxPlusLinear.arrow_left_1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: isDesktop
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(widget.plan.title.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1, color: isDark ? Colors.white : Colors.black87),
                                  overflow: TextOverflow.ellipsis, maxLines: 1),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: widget.plan.icode));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('i-CODE Copied!'), behavior: SnackBarBehavior.floating));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
                                  child: Row(
                                    children: [
                                      Text(widget.plan.icode, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy, color: color, size: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text('ADVANCED TRACE & TRACK CONSOLE',
                            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildActionButtons(isDesktop, color, isDark, tasks, archivedCount),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Builder(
              builder: (context) {
                if (!isDesktop) {
                  return DefaultTabController(
                    length: 5,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: color,
                          labelColor: color,
                          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          tabs: const [
                            Tab(text: 'TO DO'),
                            Tab(text: 'ACTION'),
                            Tab(text: 'REVIEW'),
                            Tab(text: 'DONE'),
                            Tab(text: 'COMPLETED'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildColumnList(tasks.where((t) => t.status == TaskStatus.todo).toList(), _getColumnColor(TaskStatus.todo, color, isDark), isDark),
                              _buildColumnList(tasks.where((t) => t.status == TaskStatus.inProgress).toList(), _getColumnColor(TaskStatus.inProgress, color, isDark), isDark),
                              _buildColumnList(tasks.where((t) => t.status == TaskStatus.review).toList(), _getColumnColor(TaskStatus.review, color, isDark), isDark),
                              _buildColumnList(tasks.where((t) => t.status == TaskStatus.done).toList(), _getColumnColor(TaskStatus.done, color, isDark), isDark),
                              _buildColumnList(tasks.where((t) => t.status == TaskStatus.completed).toList(), _getColumnColor(TaskStatus.completed, color, isDark), isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final boardWidth = MediaQuery.of(context).size.width;
                final useScrollableBoard = boardWidth < 1200;

                Widget wrapColumn(Widget col) {
                  return useScrollableBoard ? SizedBox(width: 280, child: col) : Expanded(child: col);
                }

                final board = Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    wrapColumn(_buildColumn('TO DO', tasks.where((t) => t.status == TaskStatus.todo).toList(), _getColumnColor(TaskStatus.todo, color, isDark), isDark, status: TaskStatus.todo, onMove: (t) => _updateNodeStatus(t, TaskStatus.todo))),
                    wrapColumn(_buildColumn('ACTION', tasks.where((t) => t.status == TaskStatus.inProgress).toList(), _getColumnColor(TaskStatus.inProgress, color, isDark), isDark, status: TaskStatus.inProgress, onMove: (t) => _updateNodeStatus(t, TaskStatus.inProgress))),
                    wrapColumn(_buildColumn('REVIEW', tasks.where((t) => t.status == TaskStatus.review).toList(), _getColumnColor(TaskStatus.review, color, isDark), isDark, status: TaskStatus.review, onMove: (t) => _updateNodeStatus(t, TaskStatus.review))),
                    wrapColumn(_buildColumn('DONE', tasks.where((t) => t.status == TaskStatus.done).toList(), _getColumnColor(TaskStatus.done, color, isDark), isDark, status: TaskStatus.done, onMove: (t) => _updateNodeStatus(t, TaskStatus.done))),
                    wrapColumn(_buildColumn('COMPLETED', tasks.where((t) => t.status == TaskStatus.completed).toList(), _getColumnColor(TaskStatus.completed, color, isDark), isDark, isLast: true, status: TaskStatus.completed, onMove: (t) => _updateNodeStatus(t, TaskStatus.completed))),
                  ],
                );

                if (useScrollableBoard) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: board,
                        ),
                      );
                    }
                  );
                }
                return board;
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, List<SystemTask> tasks, Color accent, bool isDark, {bool isLast = false, required TaskStatus status, required Function(SystemTask) onMove}) {
    return Container(
      margin: EdgeInsets.only(right: isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827).withOpacity(0.8) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: accent, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('${tasks.length}', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: DragTarget<SystemTask>(
              onWillAcceptWithDetails: (details) {
                final auth = ref.read(authProvider);
                return _isValidDragTransition(details.data.status, status, auth);
              },
              onAcceptWithDetails: (details) {
                onMove(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                return _buildColumnList(tasks, accent, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnList(List<SystemTask> tasks, Color accent, bool isDark) {
    final auth = ref.watch(authProvider);
    if (tasks.isEmpty) {
      return Center(child: Text('No active nodes', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 10)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, idx) {
        final task = tasks[idx];
        final nodeWidget = _buildConsoleNode(context, task, accent, isDark);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Draggable<SystemTask>(
            data: task,
            maxSimultaneousDrags: _canApprove(task, auth) ? 1 : 0,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 220,
                child: Opacity(
                  opacity: 0.8,
                  child: nodeWidget,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: nodeWidget,
            ),
            child: nodeWidget,
          ),
        );
      },
    );
  }

  Widget _buildConsoleNode(BuildContext context, SystemTask task, Color accent, bool isDark) {
    final auth = ref.watch(authProvider);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : accent.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: task.taskNumber));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('UID Copied: ${task.taskNumber}'), behavior: SnackBarBehavior.floating));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(task.taskNumber, style: TextStyle(fontSize: 8, color: accent, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Icon(IconsaxPlusLinear.copy, size: 10, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: _priorityColor(task.priority).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(task.priority.name.toUpperCase(), style: TextStyle(fontSize: 7, color: _priorityColor(task.priority), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.2, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(IconsaxPlusLinear.wallet, size: 10, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('\$${task.grandTotal.toInt()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(IconsaxPlusLinear.user, size: 10, color: Colors.grey),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 70),
                    child: Text(task.assignee, style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              if (task.comments.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(IconsaxPlusLinear.message, size: 10, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${task.comments.length}', style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_canApprove(task, auth))
                InkWell(
                  onTap: () async {
                    if (task.status == TaskStatus.completed) {
                      await ref.read(taskProvider.notifier).updateTask(task.copyWith(isArchived: true));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Archived to History!'), behavior: SnackBarBehavior.floating));
                      }
                      return;
                    }

                    TaskStatus nextStatus = task.status;
                    if (task.status == TaskStatus.todo) nextStatus = TaskStatus.inProgress;
                    else if (task.status == TaskStatus.inProgress) nextStatus = TaskStatus.review;
                    else if (task.status == TaskStatus.review) nextStatus = TaskStatus.done;
                    else if (task.status == TaskStatus.done) nextStatus = TaskStatus.completed;

                    if (nextStatus != task.status) {
                      final newComment = TaskComment(
                        id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
                        author: 'Admin',
                        content: 'Node Integrity Approved: Promoted to ${nextStatus.displayName}',
                        createdAt: DateTime.now()
                      );
                      await ref.read(taskProvider.notifier).updateTask(task.copyWith(status: nextStatus, comments: [...task.comments, newComment]));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task Promoted to ${nextStatus.displayName}!'), behavior: SnackBarBehavior.floating));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: task.status == TaskStatus.completed ? Colors.teal.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(task.status == TaskStatus.completed ? IconsaxPlusLinear.archive_tick : IconsaxPlusLinear.tick_circle, size: 10, color: task.status == TaskStatus.completed ? Colors.teal : Colors.green),
                        const SizedBox(width: 4),
                        Text(task.status == TaskStatus.completed ? 'ARCHIVE' : 'APPROVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: task.status == TaskStatus.completed ? Colors.teal : Colors.green)),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 10, color: isDark ? Colors.white30 : Colors.black26),
                    const SizedBox(width: 4),
                    Text('LOCKED (READ-ONLY)', style: TextStyle(fontSize: 8, color: isDark ? Colors.white30 : Colors.black26, fontWeight: FontWeight.bold)),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(IconsaxPlusLinear.eye, size: 14, color: accent),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(taskId: task.id)));
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(IconsaxPlusLinear.setting_4, size: 14, color: accent),
                    onPressed: () {
                      _showManageTaskDialog(context, task, accent, isDark);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Console Log Analysis ───────────────────────────────────────────────────────
class _ConsoleLogCentral extends ConsumerStatefulWidget {
  final Project project;
  final bool isDark;
  final Function(Plan) onOpenConsole;

  const _ConsoleLogCentral({
    required this.project,
    required this.isDark,
    required this.onOpenConsole,
  });

  @override
  ConsumerState<_ConsoleLogCentral> createState() => _ConsoleLogCentralState();
}

class _ConsoleLogCentralState extends ConsumerState<_ConsoleLogCentral> {
  String _formatPlanCode(Plan plan) {
    String suffix = '';
    if (plan.id.length >= 4 && !RegExp(r'^\d+$').hasMatch(plan.id)) {
      suffix = plan.id.substring(0, 4).toUpperCase();
    } else {
      suffix = plan.icode.length >= 4 
          ? plan.icode.substring(0, 4).toUpperCase() 
          : plan.icode.padLeft(4, '0').toUpperCase();
    }
    final prefix = widget.project.pid.isEmpty ? 'PLN' : widget.project.pid;
    return '$prefix-$suffix';
  }

  void _showEditPlanDialog(Plan plan) {
    final titleCtrl = TextEditingController(text: plan.title);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Plan',
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.project.brandColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(IconsaxPlusLinear.edit_2, color: widget.project.brandColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'EDIT STRATEGIC PLAN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'PLAN TITLE',
                      labelStyle: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: widget.project.brandColor,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.project.brandColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newTitle = titleCtrl.text.trim();
                            if (newTitle.isEmpty) return;
                            
                            try {
                              await ref.read(projectProvider.notifier).updatePlan(
                                widget.project.id,
                                plan.id,
                                newTitle,
                                '',
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Plan updated successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: widget.project.brandColor,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update plan: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.project.brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Plan plan) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete Plan',
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              width: 380,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(IconsaxPlusLinear.trash, color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DELETE STRATEGIC PLAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to permanently delete plan "${plan.title}"? All associated task connections within this console node will be detached.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await ref.read(projectProvider.notifier).removePlan(widget.project.id, plan.id);
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Plan removed successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to remove plan: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('CONFIRM DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.project.brandColor;
    final plans = widget.project.plans;
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusLinear.document_favorite, color: color, size: 28),
              const SizedBox(width: 16),
              Text('CONSOLE LOG ANALYSIS', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Plan-by-plan status overview', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 24),
          plans.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.document_favorite, size: 48, color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      const SizedBox(height: 16),
                      Text('No active plans to analyze.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13)),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisExtent: isMobile ? 220 : 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: plans.length,
                itemBuilder: (ctx, i) {
                  final plan = plans[i];
                  return _ConsoleLogCard(
                    plan: plan,
                    project: widget.project,
                    isDark: widget.isDark,
                    planCode: _formatPlanCode(plan),
                    onOpenConsole: widget.onOpenConsole,
                    onEdit: () => _showEditPlanDialog(plan),
                    onRemove: () => _showDeleteConfirmation(plan),
                  );
                },
              ),
          ],
        ),
      );
  }
}

class _ConsoleLogCard extends StatefulWidget {
  final Plan plan;
  final Project project;
  final bool isDark;
  final String planCode;
  final Function(Plan) onOpenConsole;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ConsoleLogCard({
    required this.plan,
    required this.project,
    required this.isDark,
    required this.planCode,
    required this.onOpenConsole,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  State<_ConsoleLogCard> createState() => _ConsoleLogCardState();
}

class _ConsoleLogCardState extends State<_ConsoleLogCard> {
  bool _isHovered = false;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF10B981);
      case 'active': case 'in_progress': return const Color(0xFF3B82F6);
      case 'delayed': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.project.brandColor;
    final plan = widget.plan;
    final budgetPercent = plan.budget > 0 ? (plan.consumedBudget / plan.budget).clamp(0.0, 1.0) : 0.0;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.isDark
              ? (_isHovered ? const Color(0xFF1E2230).withOpacity(0.9) : const Color(0xFF131622).withOpacity(0.85))
              : (_isHovered ? Colors.white : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? color.withOpacity(0.5)
                : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: _isHovered ? 1.2 : 0.8,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: plan.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied Plan UID to clipboard: ${plan.id}'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: color,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color.withOpacity(0.2), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.planCode,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 10,
                                  color: color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(plan.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _statusColor(plan.status).withOpacity(0.2), width: 0.8),
                        ),
                        child: Text(
                          plan.status.toUpperCase(),
                          style: TextStyle(
                            color: _statusColor(plan.status),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BUDGET TELEMETRY',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: widget.isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      Text(
                        '${(budgetPercent * 100).toInt()}% USED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: budgetPercent > 0.85 ? Colors.redAccent : (widget.isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetPercent,
                      minHeight: 5,
                      backgroundColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        budgetPercent > 0.9 ? Colors.redAccent : (budgetPercent > 0.7 ? Colors.orangeAccent : color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${NumberFormat.compact().format(plan.consumedBudget)} Consumed',
                        style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Limit: \$${NumberFormat.compact().format(plan.budget)}',
                        style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Divider(
              height: 1,
              color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            ),
            Container(
              color: widget.isDark ? const Color(0xFF0D0F14).withOpacity(0.5) : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onOpenConsole(widget.plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withOpacity(0.15),
                        foregroundColor: color,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: color.withOpacity(0.25), width: 1),
                        ),
                      ),
                      icon: Icon(IconsaxPlusLinear.category, size: 13, color: color),
                      label: const Text(
                        'View Console',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconsaxPlusLinear.edit_2,
                              color: widget.isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onRemove,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              IconsaxPlusLinear.trash,
                              color: Colors.redAccent,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Strategic Radar Map & Layout (GitHub-style Pipeline Flow) ─────────────────
class _NodePosition {
  final String id;
  final Offset position;
  final double width;
  final double height;
  _NodePosition({required this.id, required this.position, this.width = 240.0, this.height = 80.0});
}

class _FlowGraphNodeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String dateText;
  final String trackingId;
  final String statusText;
  final Color statusColor;
  final Color brandColor;
  final IconData icon;
  final VoidCallback? onTap;
  
  const _FlowGraphNodeCard({
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.trackingId,
    required this.statusText,
    required this.statusColor,
    required this.brandColor,
    required this.icon,
    this.onTap,
  });
  
  @override
  State<_FlowGraphNodeCard> createState() => _FlowGraphNodeCardState();
}

class _FlowGraphNodeCardState extends State<_FlowGraphNodeCard> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 240,
          height: 80,
          decoration: BoxDecoration(
            color: isDark
                ? (_isHovered ? const Color(0xFF1E2230) : const Color(0xFF11131A))
                : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered 
                  ? widget.brandColor.withOpacity(0.8)
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
              width: _isHovered ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? widget.brandColor.withOpacity(0.25)
                    : Colors.transparent,
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header: Icon, Subtitle/Status, and UID Copy Button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: widget.brandColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(widget.icon, color: widget.brandColor, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status Capsule Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: widget.statusColor.withOpacity(0.3), width: 0.8),
                            ),
                            child: Text(
                              widget.statusText,
                              style: TextStyle(
                                color: widget.statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Middle: Truncated Title & Glowing Hover Preview
                      Tooltip(
                        waitDuration: Duration.zero,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2230) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.brandColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        richMessage: TextSpan(
                          children: [
                            TextSpan(
                              text: '${widget.title}\n',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: 'Status: ${widget.statusText} • ID: ${widget.trackingId}\n',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.brandColor,
                                height: 1.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Updated: ${widget.dateText}',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Footer: Time and Click-to-Copy UID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.dateText,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          // Copy UID Trigger Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: widget.trackingId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied to clipboard: ${widget.trackingId}'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: widget.brandColor,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Text(
                                      widget.trackingId,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: widget.brandColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 8,
                                      color: widget.brandColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrategicRadarMapCentral extends ConsumerStatefulWidget {
  final Project project;
  final Function(Plan)? onPlanSelected;
  const _StrategicRadarMapCentral({required this.project, this.onPlanSelected});

  @override
  ConsumerState<_StrategicRadarMapCentral> createState() => _StrategicRadarMapCentralState();
}

class _StrategicRadarMapCentralState extends ConsumerState<_StrategicRadarMapCentral> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late AnimationController _rippleController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncData();
        _controller.value = Matrix4.identity();
      }
    });

    // Periodic auto-refresh every 10 seconds for real-time sync
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _syncData();
    });
  }

  void _syncData() {
    ref.read(taskProvider.notifier).syncWithDatabase(
      projectId: widget.project.id, 
      companyId: widget.project.companyId,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _rippleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double val) {
    final Matrix4 currentMatrix = _controller.value;
    final double scale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (scale + val).clamp(0.2, 2.0);
    _controller.value = Matrix4.identity()..scale(newScale, newScale, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = widget.project.brandColor;
    
    // Read real tasks for this project
    final realTasks = ref.watch(taskProvider).allTasks.where((t) => t.projectId == widget.project.id).toList();
    final List<SystemTask> tasks = [];
    
    if (realTasks.isNotEmpty) {
      tasks.addAll(realTasks);
    } else {
      // Dynamic simulated tasks based on the plans of the project if no tasks exist
      for (var plan in widget.project.plans) {
        tasks.addAll([
          SystemTask(
            id: '${plan.id}-t1',
            planId: plan.id,
            projectId: widget.project.id,
            taskNumber: 'TSK-01',
            title: 'Initiate Operations',
            allocatedCost: plan.budget * 0.25,
            status: TaskStatus.completed,
          ),
          SystemTask(
            id: '${plan.id}-t2',
            planId: plan.id,
            projectId: widget.project.id,
            taskNumber: 'TSK-02',
            title: 'Design Blueprint',
            allocatedCost: plan.budget * 0.35,
            status: TaskStatus.inProgress,
          ),
          SystemTask(
            id: '${plan.id}-t3',
            planId: plan.id,
            projectId: widget.project.id,
            taskNumber: 'TSK-03',
            title: 'Review System',
            allocatedCost: plan.budget * 0.15,
            status: TaskStatus.todo,
          ),
        ]);
      }
    }

    // Dynamic layout coordinate calculations
    const double verticalSpacing = 95.0;
    const double projectX = 50.0;
    const double planX = 400.0;
    const double taskX = 750.0;
    
    double currentY = 40.0;
    final Map<String, Offset> planPositions = {};
    final Map<String, Offset> taskPositions = {};
    
    for (final plan in widget.project.plans) {
      final planTasks = tasks.where((t) => t.planId == plan.id).toList();
      final int taskCount = planTasks.length;
      
      // Heights occupied by task node clusters
      final double clusterHeight = (taskCount > 0 ? taskCount : 1) * verticalSpacing;
      
      // Position of plan node centered within task cluster height
      final double planY = currentY + (clusterHeight / 2) - 40.0;
      planPositions[plan.id] = Offset(planX, planY);
      
      // Position of task nodes vertically
      for (int j = 0; j < taskCount; j++) {
        final task = planTasks[j];
        final double taskY = currentY + (j * verticalSpacing) + (verticalSpacing / 2) - 40.0;
        taskPositions[task.id] = Offset(taskX, taskY);
      }
      
      currentY += clusterHeight + 40.0; // add vertical plan spacing
    }
    
    // Project Y is in the vertical center of all plans
    double projectY = 100.0;
    if (widget.project.plans.isNotEmpty) {
      final firstPlanY = planPositions[widget.project.plans.first.id]!.dy;
      final lastPlanY = planPositions[widget.project.plans.last.id]!.dy;
      projectY = (firstPlanY + lastPlanY) / 2;
    }
    final Offset projectPos = Offset(projectX, projectY);
    
    final double canvasHeight = currentY.clamp(550.0, 10000.0);
    const double canvasWidth = 1100.0;

    return Stack(
      children: [
        RepaintBoundary(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(500), 
            minScale: 0.1,
            maxScale: 2.0,
            child: Container(
              width: canvasWidth,
              height: canvasHeight,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Beautiful Bezier flow paths with light pulse animations
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(canvasWidth, canvasHeight),
                        painter: _RadarLinkPainter(
                          project: widget.project,
                          tasks: tasks,
                          projectPos: projectPos,
                          planPositions: planPositions,
                          taskPositions: taskPositions,
                          lineColor: brandColor,
                          pulseValue: _rippleController.value,
                        ),
                      );
                    },
                  ),

                  // 1. Root Project Node
                  Positioned(
                    left: projectPos.dx,
                    top: projectPos.dy,
                    child: _FlowGraphNodeCard(
                      title: widget.project.name,
                      subtitle: widget.project.category.toUpperCase(),
                      dateText: DateFormat('MMM dd, yyyy').format(widget.project.startDate),
                      trackingId: widget.project.pid,
                      statusText: widget.project.status.name.toUpperCase(),
                      statusColor: widget.project.isApproved ? Colors.green : Colors.orangeAccent,
                      brandColor: brandColor,
                      icon: IconsaxPlusLinear.box,
                    ),
                  ),

                  // 2. Plan Hub Nodes
                  ...widget.project.plans.map((plan) {
                    final planPos = planPositions[plan.id]!;
                    final planTasks = tasks.where((t) => t.planId == plan.id).toList();
                    final double totalAmount = planTasks.fold(0.0, (sum, t) => sum + t.grandTotal);
                    
                    return Positioned(
                      left: planPos.dx,
                      top: planPos.dy,
                      child: _FlowGraphNodeCard(
                        title: plan.title,
                        subtitle: '\$${totalAmount.toInt()} BUDGETED',
                        dateText: 'i-CODE Hub Node',
                        trackingId: plan.icode,
                        statusText: plan.status.toUpperCase(),
                        statusColor: _statusColor(plan.status),
                        brandColor: brandColor,
                        icon: IconsaxPlusLinear.hierarchy,
                        onTap: () {
                          if (widget.onPlanSelected != null) {
                            widget.onPlanSelected!(plan);
                          }
                        },
                      ),
                    );
                  }),

                  // 3. Task Micro Nodes
                  ...tasks.map((task) {
                    final taskPos = taskPositions[task.id];
                    if (taskPos == null) return const SizedBox.shrink();
                    final formattedDate = task.dueDate != null 
                        ? DateFormat('yyyy-MM-dd').format(task.dueDate!)
                        : 'No Due Date';
                    
                    return Positioned(
                      left: taskPos.dx,
                      top: taskPos.dy,
                      child: _FlowGraphNodeCard(
                        title: task.title,
                        subtitle: 'ASSIGNEE: ${task.assignee.toUpperCase()}',
                        dateText: 'DUE: $formattedDate',
                        trackingId: task.taskNumber,
                        statusText: task.status.displayName,
                        statusColor: _getSimulatedStatusColor(task.status),
                        brandColor: brandColor,
                        icon: IconsaxPlusLinear.task_square,
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => _buildTaskDetailsModal(
                            context: context,
                            task: task,
                            color: brandColor,
                            isDark: isDark,
                            ref: ref,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        
        // Zoom Controls HUD
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withOpacity(0.9) : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                _zoomBtn(Icons.add, () => _zoom(0.15), brandColor, isDark),
                const SizedBox(height: 6),
                _zoomBtn(Icons.remove, () => _zoom(-0.15), brandColor, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap, Color color, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'active': case 'in_progress': return Colors.blue;
      case 'delayed': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

// ── Pipeline Cubic Bezier Link Painter ────────────────────────────────────────
class _RadarLinkPainter extends CustomPainter {
  final Project project;
  final List<SystemTask> tasks;
  final Offset projectPos;
  final Map<String, Offset> planPositions;
  final Map<String, Offset> taskPositions;
  final Color lineColor;
  final double pulseValue;

  _RadarLinkPainter({
    required this.project,
    required this.tasks,
    required this.projectPos,
    required this.planPositions,
    required this.taskPositions,
    required this.lineColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startPort = Offset(projectPos.dx + 240.0, projectPos.dy + 40.0);

    // 1. Draw curves from Project right edge to Plans left edge
    for (final plan in project.plans) {
      final planPos = planPositions[plan.id];
      if (planPos != null) {
        final endPort = Offset(planPos.dx, planPos.dy + 40.0);
        
        final path = Path()
          ..moveTo(startPort.dx, startPort.dy)
          ..cubicTo(
            startPort.dx + 80.0, startPort.dy,
            endPort.dx - 80.0, endPort.dy,
            endPort.dx, endPort.dy,
          );

        // Draw background bezier path
        canvas.drawPath(
          path, 
          Paint()
            ..color = lineColor.withOpacity(0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );

        // Draw active light pulse particle
        drawPulse(canvas, path, Paint()..color = lineColor, pulseValue);
      }
    }

    // 2. Draw curves from Plans right edge to Tasks left edge
    for (final plan in project.plans) {
      final planPos = planPositions[plan.id];
      if (planPos != null) {
        final planTasks = tasks.where((t) => t.planId == plan.id).toList();
        final planStartPort = Offset(planPos.dx + 240.0, planPos.dy + 40.0);
        
        for (final task in planTasks) {
          final taskPos = taskPositions[task.id];
          if (taskPos != null) {
            final endPort = Offset(taskPos.dx, taskPos.dy + 40.0);
            
            final path = Path()
              ..moveTo(planStartPort.dx, planStartPort.dy)
              ..cubicTo(
                planStartPort.dx + 80.0, planStartPort.dy,
                endPort.dx - 80.0, endPort.dy,
                endPort.dx, endPort.dy,
              );

            final taskColor = _getSimulatedStatusColor(task.status);
            
            // Draw background bezier path matching task status color
            canvas.drawPath(
              path, 
              Paint()
                ..color = taskColor.withOpacity(0.15)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..strokeCap = StrokeCap.round,
            );

            // Draw active status-themed light pulse particle
            drawPulse(canvas, path, Paint()..color = taskColor, pulseValue);
          }
        }
      }
    }
  }

  void drawPulse(Canvas canvas, Path path, Paint paint, double t) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final double length = metric.length;
      final double targetLength = length * t;
      final tangent = metric.getTangentForOffset(targetLength);
      if (tangent != null) {
        final position = tangent.position;
        
        // Neon outer glow layer
        final glowPaint = Paint()
          ..color = paint.color.withOpacity(0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(position, 7.0, glowPaint);
        
        // High intensity solid core
        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(position, 2.5, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Color _getPriorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low: return Colors.blueGrey;
    case TaskPriority.medium: return Colors.blueAccent;
    case TaskPriority.high: return Colors.orangeAccent;
    case TaskPriority.critical: return Colors.redAccent;
  }
}

Color _getSimulatedStatusColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo: return Colors.orangeAccent;
    case TaskStatus.inProgress: return Colors.blueAccent;
    case TaskStatus.completed: return Colors.green;
    case TaskStatus.review: return Colors.amberAccent;
    case TaskStatus.done: return Colors.tealAccent;
  }
}

Widget _modalDetailItem(String label, String value, Color valColor, bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: valColor,
        ),
      ),
    ],
  );
}

Widget _buildTaskDetailsModal({
  required BuildContext context,
  required SystemTask task,
  required Color color,
  required bool isDark,
  required WidgetRef ref,
}) {
  final auth = ref.watch(authProvider);
  final canApprove = canUserApproveTask(task, auth);

  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
    child: GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    task.taskNumber,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              task.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (task.description.isNotEmpty) ...[
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _modalDetailItem(
                    'STATUS',
                    task.status.displayName,
                    _getSimulatedStatusColor(task.status),
                    isDark,
                  ),
                ),
                Expanded(
                  child: _modalDetailItem(
                    'PRIORITY',
                    task.priority.name.toUpperCase(),
                    _getPriorityColor(task.priority),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _modalDetailItem(
                    'ALLOCATED BUDGET',
                    '\$${NumberFormat('#,##0.00').format(task.allocatedCost)}',
                    color,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _modalDetailItem(
                    'ASSIGNEE',
                    task.assignee,
                    isDark ? Colors.white70 : Colors.black87,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskStatus>(
                    value: task.status,
                    decoration: InputDecoration(
                      labelText: canApprove ? 'CHANGE STATUS' : 'CHANGE STATUS (LOCKED - READ ONLY)',
                      labelStyle: TextStyle(color: canApprove ? color : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: TaskStatus.values.map((status) {
                      return DropdownMenuItem<TaskStatus>(
                        value: status,
                        child: Text(status.displayName, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: canApprove ? (newStatus) {
                      if (newStatus != null && newStatus != task.status) {
                        ref.read(taskProvider.notifier).updateTaskStatus(task.id, newStatus);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Task status updated to ${newStatus.displayName}'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: color,
                        ));
                      }
                    } : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = task.copyWith(planId: '', projectId: '');
                      await ref.read(taskProvider.notifier).updateTask(updated);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Detached task "${task.title}" from plan'),
                          backgroundColor: Colors.orangeAccent,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    icon: const Icon(Icons.link_off, size: 14),
                    label: const Text('DETACH FROM PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('CLOSE BRIEF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

bool canUserApproveTask(SystemTask task, AuthState auth) {
  switch (task.status) {
    case TaskStatus.todo:
      return auth.isAdmin || auth.isSubAdmin || auth.isManager;
    case TaskStatus.inProgress: // ACTION
      return auth.isManager;
    case TaskStatus.review: // REVIEW
      return auth.isAdmin || auth.isSubAdmin;
    case TaskStatus.done: // DONE
      return auth.isManager;
    case TaskStatus.completed: // COMPLETED
      return auth.isAdmin || auth.isSubAdmin;
    default:
      return false;
  }
}


