import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/models/system_task.dart';

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

        if (_selectedTabIndex == 3 &&
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
      case 1: return 'Strategic Radar';
      case 2: return _activePlan != null ? 'Plan Console · ${_activePlan!.title}' : 'Strategic Plans';
      case 3: return 'Blueprint Records';
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
                _sidebarItem(1, IconsaxPlusLinear.radar, 'The Radar', isDark),
                _sidebarItem(2, IconsaxPlusLinear.hierarchy, 'Plans', isDark),
                _sidebarItem(3, IconsaxPlusLinear.verify, 'Records', isDark),
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
      case 1: return _buildRadarTab(project, isDark);
      case 2:
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
      case 3: return _buildRecordsTab(project, isDark);
      case 4: return _ConsoleLogCentral(project: project, isDark: isDark);
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(IconsaxPlusLinear.timer_1, color: Colors.orangeAccent, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending Approval', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('This project requires administrative approval before it becomes visible to the rest of the team.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(projectProvider.notifier).approveProject(project.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project Approved successfully!'), backgroundColor: Colors.green));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(IconsaxPlusLinear.tick_circle, size: 18),
                    label: const Text('Approve Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
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
    final color = project.brandColor;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STRATEGIC RADAR MAP', style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  const SizedBox(height: 4),
                  Text('Interactive deployment mapping & connection nodes', style: TextStyle(
                    fontSize: 12, 
                    color: isDark ? Colors.white38 : Colors.black38,
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Radar Map Viewport container
          Container(
            height: 550,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _StrategicRadarMapCentral(project: project),
          ),
          
          const SizedBox(height: 24),
          
          // Metric Cards
          if (isMobile)
            Column(
              children: [
                _buildRadarMetricCard(
                  'Radar Health', 
                  'Operational', 
                  Colors.green, 
                  IconsaxPlusLinear.shield_tick, 
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildRadarMetricCard(
                  'Connected Nodes', 
                  '${project.plans.length} Hubs Registered', 
                  color, 
                  IconsaxPlusLinear.hierarchy, 
                  isDark,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildRadarMetricCard(
                    'Radar Health', 
                    'Operational', 
                    Colors.green, 
                    IconsaxPlusLinear.shield_tick, 
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRadarMetricCard(
                    'Connected Nodes', 
                    '${project.plans.length} Hubs Registered', 
                    color, 
                    IconsaxPlusLinear.hierarchy, 
                    isDark,
                  ),
                ),
              ],
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final color = widget.project.brandColor;
    final plans = widget.project.plans;

    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STRATEGIC PLANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: widget.isDark ? Colors.white38 : Colors.black38)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Plan title...',
                          filled: true,
                          fillColor: widget.isDark ? Colors.white10 : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isCreating ? null : () async {
                        if (_titleCtrl.text.trim().isEmpty) return;
                        setState(() => _isCreating = true);
                        try {
                          await widget.ref.read(projectProvider.notifier).addPlan(
                            widget.project.id, _titleCtrl.text.trim(), _descCtrl.text.trim());
                          _titleCtrl.clear(); _descCtrl.clear();
                        } catch(_) {}
                        setState(() => _isCreating = false);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                      child: _isCreating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(IconsaxPlusLinear.add, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Brief objective...',
                    filled: true,
                    fillColor: widget.isDark ? Colors.white10 : Colors.white70,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          plans.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('No plans yet. Create one above.',
                  style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38))),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plans.length,
                itemBuilder: (ctx, i) => _buildPlanCard(plans[i], color),
              ),
        ],
      ),
    );
  }


  Widget _buildPlanCard(Plan plan, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: Icon(IconsaxPlusLinear.hierarchy, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(plan.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
                            child: Text(plan.icode, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        ],
                      ),
                      Text(plan.status.toUpperCase(), style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => widget.ref.read(projectProvider.notifier).removePlan(widget.project.id, plan.id),
                  icon: const Icon(IconsaxPlusLinear.trash, size: 16, color: Colors.redAccent),
                  label: const Text('PURGE PLAN', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () => widget.onOpenConsole(plan),
                  style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('OPEN CONSOLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan Console (Kanban) ──────────────────────────────────────────────────────
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).syncWithDatabase(
        projectId: widget.project.id,
        planId: widget.plan.id,
        companyId: widget.project.companyId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.project.brandColor;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDesktop = !isMobile && MediaQuery.of(context).size.width > 1024;
    final isDark = widget.isDark;

    // Retrieve real tasks for this plan
    final tasks = ref.watch(taskProvider).allTasks.where((t) => t.planId == widget.plan.id).toList();

    final todoTasks = tasks.where((t) => t.status == TaskStatus.todo).toList();
    final inProgressTasks = tasks.where((t) => t.status == TaskStatus.inProgress).toList();
    final reviewTasks = tasks.where((t) => t.status == TaskStatus.review).toList();
    final doneTasks = tasks.where((t) => t.status == TaskStatus.done).toList();
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(IconsaxPlusLinear.arrow_left_1), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.plan.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    Text('PLAN CONSOLE', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
                child: Text(widget.plan.icode, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kanbanCol('TO DO', Colors.blueGrey, todoTasks, widget.isDark, ref, context),
                    _kanbanCol('IN PROGRESS', Colors.blueAccent, inProgressTasks, widget.isDark, ref, context),
                    _kanbanCol('REVIEW', Colors.amberAccent, reviewTasks, widget.isDark, ref, context),
                    _kanbanCol('DONE', Colors.greenAccent, doneTasks, widget.isDark, ref, context),
                    _kanbanCol('COMPLETED', Colors.tealAccent, completedTasks, widget.isDark, ref, context, isLast: true),
                  ],
                )
              : DefaultTabController(
                  length: 5,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: color,
                        labelColor: color,
                        unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        tabs: const [Tab(text: 'TO DO'), Tab(text: 'ACTION'), Tab(text: 'REVIEW'), Tab(text: 'DONE'), Tab(text: 'COMPLETED')],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(children: [
                          _kanbanCol('TO DO', Colors.blueGrey, todoTasks, isDark, ref, context),
                          _kanbanCol('IN PROGRESS', Colors.blueAccent, inProgressTasks, isDark, ref, context),
                          _kanbanCol('REVIEW', Colors.amberAccent, reviewTasks, isDark, ref, context),
                          _kanbanCol('DONE', Colors.greenAccent, doneTasks, isDark, ref, context),
                          _kanbanCol('COMPLETED', Colors.tealAccent, completedTasks, isDark, ref, context),
                        ]),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _kanbanCol(String label, Color color, List<SystemTask> colTasks, bool isDark, WidgetRef ref, BuildContext context, {bool isLast = false}) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: isLast ? 0 : 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${colTasks.length}',
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: colTasks.isEmpty
                ? Center(
                    child: Text('No tasks', style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: colTasks.length,
                    itemBuilder: (ctx, idx) {
                      final task = colTasks[idx];
                      return _kanbanTaskCard(task, color, isDark, ref, context);
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kanbanTaskCard(SystemTask task, Color color, bool isDark, WidgetRef ref, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _buildTaskDetailsModal(
              context: context,
              task: task,
              color: color,
              isDark: isDark,
              ref: ref,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.taskNumber,
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    task.priority.name.toUpperCase(),
                    style: TextStyle(
                      color: _getPriorityColor(task.priority),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.assignee.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.assignee,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Console Log Analysis ───────────────────────────────────────────────────────
class _ConsoleLogCentral extends StatelessWidget {
  final Project project;
  final bool isDark;
  const _ConsoleLogCentral({required this.project, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = project.brandColor;
    final plans = project.plans;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
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
                child: Center(child: Text('No active plans to analyze.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16,
              ),
              itemCount: plans.length,
              itemBuilder: (ctx, i) {
                final plan = plans[i];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                    boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
                            child: Text(plan.icode, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Text(plan.status.toUpperCase(), style: TextStyle(color: _statusColor(plan.status), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(IconsaxPlusLinear.dollar_square, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text('\$${plan.budget.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Icon(IconsaxPlusLinear.chart_2, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('\$${plan.consumedBudget.toStringAsFixed(0)} used', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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

// ── Strategic Radar Map & Layout ─────────────────────────────────────────────
class _SimulatedRadarTask {
  final String id;
  final String planId;
  final String taskNumber;
  final double grandTotal;
  final String status;

  _SimulatedRadarTask({
    required this.id,
    required this.planId,
    required this.taskNumber,
    required this.grandTotal,
    required this.status,
  });
}

class _StrategicRadarMapCentral extends ConsumerStatefulWidget {
  final Project project;
  const _StrategicRadarMapCentral({required this.project});

  @override
  ConsumerState<_StrategicRadarMapCentral> createState() => _StrategicRadarMapCentralState();
}

class _StrategicRadarMapCentralState extends ConsumerState<_StrategicRadarMapCentral> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Fetch real tasks from the backend in real-time
        ref.read(taskProvider.notifier).syncWithDatabase(
          projectId: widget.project.id, 
          companyId: widget.project.companyId,
        );

        final double viewportWidth = context.size?.width ?? 800;
        final double canvasWidth = (widget.project.plans.length * 400).toDouble().clamp(1800, 10000);
        
        _controller.value = Matrix4.identity()
          ..translate(
            -(canvasWidth / 2 - (viewportWidth / 2)), 
            -0.0 // Start at the top of the hub
          );
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double val) {
    final Matrix4 currentMatrix = _controller.value;
    final double scale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (scale + val).clamp(0.2, 2.0);
    _controller.value = Matrix4.identity()..scale(newScale);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double canvasWidth = (widget.project.plans.length * 400).toDouble().clamp(1800, 10000);
    const double canvasHeight = 1600; // Vertical height for tasks cascading

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

    return Stack(
      children: [
        RepaintBoundary(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1000), 
            minScale: 0.1,
            maxScale: 2.0,
            child: Container(
              width: canvasWidth,
              height: canvasHeight,
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple rings on central Hub
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(canvasWidth, canvasHeight),
                        painter: _RadarRipplePainter(
                          progress: _rippleController.value,
                          color: widget.project.brandColor,
                          canvasWidth: canvasWidth,
                        ),
                      );
                    },
                  ),

                  // Connection links painter
                  CustomPaint(
                    size: Size(canvasWidth, canvasHeight),
                    painter: _RadarLinkPainter(
                      project: widget.project,
                      tasks: tasks,
                      lineColor: widget.project.brandColor,
                      canvasWidth: canvasWidth,
                    ),
                  ),

                  // Node Widgets
                  ..._buildRadarNodes(context, widget.project, tasks, isDark, canvasWidth),
                ],
              ),
            ),
          ),
        ),
        
        // Dynamic Zoom Control HUD
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
                _zoomBtn(Icons.add, () => _zoom(0.15), widget.project.brandColor, isDark),
                const SizedBox(height: 6),
                _zoomBtn(Icons.remove, () => _zoom(-0.15), widget.project.brandColor, isDark),
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

  List<Widget> _buildRadarNodes(BuildContext context, Project project, List<SystemTask> tasks, bool isDark, double canvasWidth) {
    List<Widget> nodes = [];
    final double startY = 120;
    final Offset centerTop = Offset(canvasWidth / 2, startY);
    
    // 1. Root Central Project Hub
    nodes.add(_radarNode(
      context: context,
      offset: centerTop,
      title: project.name,
      icon: IconsaxPlusLinear.box,
      color: project.brandColor,
      isCore: true,
      isDark: isDark,
    ));

    final double planY = startY + 240;
    final double planSpacing = 400;
    final double taskStartY = planY + 180;
    final double taskSpacingY = 120;

    final double totalPlansWidth = (project.plans.length - 1) * planSpacing;
    final double startX = (canvasWidth / 2) - (totalPlansWidth / 2);

    for (int i = 0; i < project.plans.length; i++) {
      final plan = project.plans[i];
      final Offset pNodePos = Offset(startX + (i * planSpacing), planY);
      final planTasks = tasks.where((t) => t.planId == plan.id).toList();

      // 2. Interactive Insight Hub (Branch Nodes)
      nodes.add(_unifiedPlanHubCentral(
        offset: pNodePos,
        plan: plan,
        tasks: planTasks,
        color: project.brandColor,
        isDark: isDark,
        context: context,
      ));

      // 3. Cascading Micro-task Nodes
      for (int j = 0; j < planTasks.length; j++) {
        final task = planTasks[j];
        final Offset tNodePos = Offset(pNodePos.dx, taskStartY + (j * taskSpacingY));

        nodes.add(_taskMicroNodeCentral(
          context: context,
          offset: tNodePos,
          task: task,
          color: _getSimulatedStatusColor(task.status),
          isDark: isDark,
        ));
      }
    }
    return nodes;
  }

  Widget _unifiedPlanHubCentral({
    required Offset offset, 
    required Plan plan, 
    required List<SystemTask> tasks, 
    required Color color, 
    required bool isDark,
    required BuildContext context,
  }) {
    final double totalAmount = tasks.fold(0, (sum, t) => sum + t.grandTotal);
    final todoCount = tasks.where((t) => t.status == TaskStatus.todo).length;
    final doneCount = tasks.where((t) => t.status == TaskStatus.completed || t.status == TaskStatus.done).length;

    return Positioned(
      left: offset.dx - 100,
      top: offset.dy - 40, 
      child: Column(
        children: [
          // Header i-CODE Copy Tab
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: plan.icode));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('i-CODE Copied: ${plan.icode}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: color,
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 200),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(IconsaxPlusLinear.status, color: Colors.white, size: 12),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      plan.title.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Insight Stats Body
          Container(
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _insightItem('CAP', '\$${totalAmount.toInt()}', color),
                    _insightItem('TODO', '$todoCount', Colors.orangeAccent),
                    _insightItem('DONE', '$doneCount', Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${plan.icode} REGISTERED', 
                    style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _insightItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
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

  Widget _taskMicroNodeCentral({
    required BuildContext context,
    required Offset offset,
    required SystemTask task,
    required Color color,
    required bool isDark,
  }) {
    return Positioned(
      left: offset.dx - 30,
      top: offset.dy - 30,
      child: Tooltip(
        message: '${task.taskNumber}: ${task.title}\nStatus: ${task.status.displayName}',
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (context) => _buildTaskDetailsModal(
              context: context,
              task: task,
              color: color,
              isDark: isDark,
              ref: ref,
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)],
                ),
                child: Icon(IconsaxPlusLinear.task_square, color: color, size: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.taskNumber, 
                  style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).scale(),
    );
  }

  Widget _radarNode({
    required BuildContext context,
    required Offset offset,
    required String title,
    required IconData icon,
    required Color color,
    bool isCore = false,
    required bool isDark,
  }) {
    return Positioned(
      left: offset.dx - (isCore ? 50 : 40),
      top: offset.dy - (isCore ? 50 : 40),
      child: Column(
        children: [
          Container(
            width: isCore ? 100 : 80,
            height: isCore ? 100 : 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCore ? 3.5 : 2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, spreadRadius: isCore ? 4 : 1),
              ],
            ),
            child: Icon(icon, color: color, size: isCore ? 36 : 24),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title.toUpperCase(), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

// ── Radar Custom Painters ────────────────────────────────────────────────────
class _RadarRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double canvasWidth;

  _RadarRipplePainter({required this.progress, required this.color, required this.canvasWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(canvasWidth / 2, 120); // Anchored to root Central project hub
    final paint = Paint()
      ..color = color.withOpacity((1 - progress) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 90 + (progress * 150), paint);
    canvas.drawCircle(center, 90 + ((progress + 0.5) % 1.0 * 150), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RadarLinkPainter extends CustomPainter {
  final Project project;
  final List<SystemTask> tasks;
  final Color lineColor;
  final double canvasWidth;

  _RadarLinkPainter({required this.project, required this.tasks, required this.lineColor, required this.canvasWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withOpacity(0.25)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double startY = 120;
    final Offset centerTop = Offset(canvasWidth / 2, startY);
    final double planY = startY + 240;
    final double planSpacing = 400;
    final double taskStartY = planY + 180;
    final double taskSpacingY = 120;

    final double totalPlansWidth = (project.plans.length - 1) * planSpacing;
    final double startX = (canvasWidth / 2) - (totalPlansWidth / 2);

    // Main horizontal network bus line
    if (project.plans.length > 1) {
      canvas.drawLine(
        Offset(startX, planY - 100), 
        Offset(startX + totalPlansWidth, planY - 100), 
        paint
      );
    }

    // Line connecting Hub to Drive Bus Line
    canvas.drawLine(centerTop, Offset(canvasWidth / 2, planY - 100), paint);

    for (int i = 0; i < project.plans.length; i++) {
      final plan = project.plans[i];
      final Offset pNodePos = Offset(startX + (i * planSpacing), planY);

      // Vertical line drops from Bus line down to Plan Hubs
      canvas.drawLine(Offset(pNodePos.dx, planY - 100), Offset(pNodePos.dx, planY - 40), paint);

      final planTasks = tasks.where((t) => t.planId == plan.id).toList();
      final taskPaint = Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Cascading line drop from bottom of Plan Hub down to tasks
      if (planTasks.isNotEmpty) {
        final double lastTaskY = taskStartY + ((planTasks.length - 1) * taskSpacingY);
        canvas.drawLine(
          Offset(pNodePos.dx, planY + 100), 
          Offset(pNodePos.dx, lastTaskY), 
          taskPaint..color = lineColor.withOpacity(0.12)
        );
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
                      labelText: 'CHANGE STATUS',
                      labelStyle: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: TaskStatus.values.map((status) {
                      return DropdownMenuItem<TaskStatus>(
                        value: status,
                        child: Text(status.displayName, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null && newStatus != task.status) {
                        ref.read(taskProvider.notifier).updateTaskStatus(task.id, newStatus);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Task status updated to ${newStatus.displayName}'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: color,
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('CLOSE BRIEF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

