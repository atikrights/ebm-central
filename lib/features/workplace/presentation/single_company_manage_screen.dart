import 'dart:async';
import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/auth/auth_provider.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/window_title_bar.dart';
import '../../../shared/widgets/ebm_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/company.dart';
import '../providers/company_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart' as pmod;
import '../../tasks/presentation/tasks_screen.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/company_external_quota.dart';
import '../providers/company_external_quota_provider.dart';
import 'widgets/quota_manage_dialog.dart';
import 'widgets/attach_project_dialog.dart';
import 'quota_edit_screen.dart';

class WordLimitFormatter extends TextInputFormatter {
  final int maxWords;
  WordLimitFormatter(this.maxWords);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final words = newValue.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > maxWords) {
      final truncatedText = words.take(maxWords).join(' ');
      return TextEditingValue(
        text: truncatedText,
        selection: TextSelection.collapsed(offset: truncatedText.length),
      );
    }
    return newValue;
  }
}

class SingleCompanyManageScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SingleCompanyManageScreen({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<SingleCompanyManageScreen> createState() => _SingleCompanyManageScreenState();
}

class _SingleCompanyManageScreenState extends ConsumerState<SingleCompanyManageScreen> {
  int _selectedTabIndex = 0;
  int _settingsTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const double kHeaderHeight = 54.0;
  static const double kSidebarWidth = 240.0;

  // Records Tab Expansion States
  bool _isBriefExpanded = false;
  bool _isDetailsExpanded = false;
  bool _isGovernanceExpanded = false;

  // Founder Authorization State
  int _lastTabIndex = -1; // Track tab changes for persistent prompts
  bool _isDialogVisible = false;

  // Controllers for Blueprint - Removed (Central is Records only)

  // Configure Tab State
  final TextEditingController _pidController = TextEditingController();
  final TextEditingController _attachedSearchController = TextEditingController();
  String _attachedSearchQuery = '';
  final Set<pmod.ProjectStatus> _selectedStatuses = {};
  pmod.Project? _searchedProject;
  bool _isSearching = false;
  bool _isActioning = false;

  // External Tab – Quota search & filter
  final TextEditingController _quotaSearchController = TextEditingController();
  String _quotaSearchQuery = '';
  String _quotaTagFilter = '';

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    // Blueprint controllers removed for Central (Records only)
  }

  @override
  void dispose() {
    _pidController.dispose();
    _attachedSearchController.dispose();
    _quotaSearchController.dispose();
    super.dispose();
  }

  void _searchProject() async {
    final pid = _pidController.text.trim();
    if (pid.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchedProject = null;
    });

    try {
      final project = await ref.read(projectProvider.notifier).searchByPid(pid);
      if (mounted) {
        setState(() {
          _searchedProject = project;
          _isSearching = false;
        });
        if (project == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project not found or outside your team scope.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _attachProject(Company company) async {
    if (_searchedProject == null) return;

    setState(() {
      _isActioning = true;
    });

    try {
      await ref.read(projectProvider.notifier).linkCompanyToProject(_searchedProject!.id, company.id);
      if (mounted) {
        setState(() {
          _isActioning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project attached successfully.'), backgroundColor: Colors.green),
        );
        _searchProject(); // Refresh the searched project
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isActioning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to attach project.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _detachProject() async {
    if (_searchedProject == null) return;

    setState(() {
      _isActioning = true;
    });

    try {
      await ref.read(projectProvider.notifier).detachCompanyFromProject(_searchedProject!.id);
      if (mounted) {
        setState(() {
          _isActioning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project detached successfully.'), backgroundColor: Colors.green),
        );
        _searchProject(); // Refresh the searched project
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isActioning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to detach project.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusName(pmod.ProjectStatus status) {
    switch (status) {
      case pmod.ProjectStatus.active: return 'Active';
      case pmod.ProjectStatus.completed: return 'Completed';
      case pmod.ProjectStatus.onHold: return 'On Hold';
      case pmod.ProjectStatus.planning: return 'Planning';
      case pmod.ProjectStatus.draft: return 'Draft';
    }
  }

  Color _getStatusColor(pmod.ProjectStatus status) {
    switch (status) {
      case pmod.ProjectStatus.active: return AppColors.success;
      case pmod.ProjectStatus.completed: return Colors.blue;
      case pmod.ProjectStatus.onHold: return Colors.orange;
      case pmod.ProjectStatus.planning: return Colors.purple;
      case pmod.ProjectStatus.draft: return Colors.grey;
    }
  }

  Map<String, List<pmod.Project>> _groupProjectsByDate(List<pmod.Project> projects) {
    final Map<String, List<pmod.Project>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final project in projects) {
      final dateToUse = project.updatedAt ?? project.createdAt ?? project.startDate;
      final projectDate = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

      String header;
      if (projectDate == today) {
        header = 'Today';
      } else if (projectDate == yesterday) {
        header = 'Yesterday';
      } else {
        header = DateFormat('MMMM dd, yyyy').format(projectDate);
      }

      if (!groups.containsKey(header)) {
        groups[header] = [];
      }
      groups[header]!.add(project);
    }
    return groups;
  }

  Map<String, List<CompanyExternalQuota>> _groupQuotasByDate(List<CompanyExternalQuota> quotas) {
    final Map<String, List<CompanyExternalQuota>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final quota in quotas) {
      final quotaDate = DateTime(quota.date.year, quota.date.month, quota.date.day);

      String header;
      if (quotaDate == today) {
        header = 'Today';
      } else if (quotaDate == yesterday) {
        header = 'Yesterday';
      } else {
        header = DateFormat('MMMM dd, yyyy').format(quotaDate);
      }

      if (!groups.containsKey(header)) {
        groups[header] = [];
      }
      groups[header]!.add(quota);
    }
    return groups;
  }

  void _confirmDetach(pmod.Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detach Project'),
        content: Text('Are you sure you want to detach project "${project.name}" (PID: ${project.pid})? It will return to the creator\'s private scope.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isActioning = true;
              });
              try {
                await ref.read(projectProvider.notifier).detachCompanyFromProject(project.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project detached successfully.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to detach project.'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isActioning = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Detach', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(companyProvider);
    final company = asyncState.maybeWhen(
      data: (state) => state.companies.firstWhere(
        (c) => c.id == widget.companyId,
        orElse: () => Company(
          id: 'N/A',
          name: 'Not Found',
          categories: [],
          website: '',
          primaryEmail: '',
          phone: '',
          location: '',
        ),
      ),
      orElse: () => Company(
        id: 'N/A',
        name: 'Not Found',
        categories: [],
        website: '',
        primaryEmail: '',
        phone: '',
        location: '',
      ),
    );

    // ── FOUNDER AUTHORIZATION LOGIC ──────────────────────────────────────────
    // Automatically trigger authorization dialog if manager has signed but founder hasn't
    if (_selectedTabIndex == 1 && // Now at index 1
        _lastTabIndex != 1 && // Trigger only when entering the tab
        company.managerSignature != null && 
        company.managerSignature!.isNotEmpty && 
        company.managerSignature != 'UNAUTHORIZED' &&
        (company.founderSignature == null || company.founderSignature == 'PENDING DEPLOYMENT' || company.founderSignature!.isEmpty) &&
        !_isDialogVisible) {
      
      _lastTabIndex = 1; // Mark as checked for this visit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFounderAuthDialog(context, company);
      });
    } else if (_selectedTabIndex != 1) {
      _lastTabIndex = _selectedTabIndex; // Reset tracker when leaving the tab
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: !isDesktop ? _buildSidebar(company, isDark, true) : null,
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
                  if (isDesktop) _buildSidebar(company, isDark, false),
                  Expanded(
                    child: Stack(
                      children: [
                        // Content Area
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: kHeaderHeight),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: _buildContent(company, isDark),
                            ),
                          ),
                        ),
                        
                        // Header (Absolute Top Overlay)
                        Positioned(
                          top: 0, 
                          left: 0, 
                          right: 0,
                          child: _buildHeader(company, isDark, !isDesktop),
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
  }

  Widget _buildHeader(Company company, bool isDark, bool showMenu) {
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
              // Left: Mobile Menu or Title
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
                        company.name,
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
              
              // Right: Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerIcon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    isDark,
                    () => ref.read(themeNotifierProvider.notifier).toggleTheme(),
                  ),
                  const SizedBox(width: 4),
                  _headerIcon(Icons.notifications_outlined, isDark, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications system is synchronizing...'), duration: Duration(seconds: 1)),
                    );
                  }),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showProfileDropdown(context, isDark),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                      ),
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

  void _showProfileDropdown(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: kHeaderHeight + 5,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('User Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                                Text('System Admin', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _profileItem(Icons.person_outline, 'Profile', () => Navigator.pop(context), isDark),
                    _profileItem(Icons.settings_outlined, 'Account Settings', () => Navigator.pop(context), isDark),
                    const Divider(height: 1),
                    _profileItem(Icons.logout_rounded, 'Logout', () {
                      Navigator.pop(context);
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    }, isDark, isDangerous: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, VoidCallback onTap, bool isDark, {bool isDangerous = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDangerous ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 13, color: isDangerous ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87))),
          ],
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
      case 0: return 'Operational Overview';
      case 1: return 'Organizational Records';
      case 2: return 'Strategic Radar';
      case 3: return 'External';
      case 4: return 'Company Settings';
      default: return '';
    }
  }

  Widget _buildSidebar(Company company, bool isDark, bool isDrawer) {
    final width = isDrawer ? 280.0 : kSidebarWidth;
    final bgColor = isDark
        ? const Color(0xFF0F1117).withOpacity(0.85)
        : const Color(0xFFF8FAFC).withOpacity(0.92);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
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
              
              // Top Back Button (Now at the Top)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/'),
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
                            'Back to Portal',
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
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white10),
              const SizedBox(height: 16),

              // Nav Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    _sidebarItem(0, Icons.speed_rounded, 'Overview', isDark),
                    _sidebarItem(1, Icons.archive_outlined, 'Records', isDark),
                    _sidebarItem(2, IconsaxPlusLinear.radar, 'Radar', isDark),
                    _sidebarItem(3, IconsaxPlusLinear.wallet_money, 'External', isDark),
                    _sidebarItem(4, Icons.settings_outlined, 'Settings', isDark),
                  ],
                ),
              ),

              // Company Profile Card (Now at the Bottom)
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(IconsaxPlusBold.building_3, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            company.id,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
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
              border: isSelected ? Border.all(color: primaryColor.withOpacity(0.1), width: 0.5) : null,
            ),
            child: Row(
              children: [
                // Selection Pill
                if (isSelected)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 4)],
                    ),
                  ),
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
                    color: isSelected ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9)) : unselectedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Company company, bool isDark) {
    switch (_selectedTabIndex) {
      case 0: return _buildOverviewTab(company, isDark);
      case 1: return _buildRecordsTab(company, isDark);
      case 2: return _buildMapTab(company, isDark);
      case 3: return _buildExternalTab(company, isDark);
      case 4: return _buildSettingsContainer(company, isDark);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildMapTab(Company company, bool isDark) {
    return _StrategicCompanyMapCentral(company: company);
  }

  Widget _buildSettingsContainer(Company company, bool isDark) {
    final primaryColor = AppColors.primary;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // WhatsApp style category tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('Configure', 0, primaryColor, textColor, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('General Settings', 1, primaryColor, textColor, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('Security', 2, primaryColor, textColor, isDark),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: Builder(
            builder: (context) {
              switch (_settingsTabIndex) {
                case 0: return _buildConfigureTab(company, isDark);
                case 1: return _buildPlaceholderTab('General Settings', IconsaxPlusLinear.setting_2, isDark);
                case 2: return _buildPlaceholderTab('Security', IconsaxPlusLinear.security_safe, isDark);
                default: return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String title, int index, Color primary, Color textCol, bool isDark) {
    final isSelected = _settingsTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _settingsTabIndex = index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? primary.withValues(alpha: isDark ? 0.2 : 0.1) 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primary.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? primary : textCol,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalTab(Company company, bool isDark) {
    final quotas = ref.watch(companyExternalQuotaProvider(company.id));
    final notifier = ref.read(companyExternalQuotaProvider(company.id).notifier);
    final textColor = isDark ? Colors.white : AppColors.darkText;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    // Apply search filter (quotaSearchQuery) and tag filter (quotaTagFilter)
    final filteredQuotas = quotas.where((quota) {
      final matchesSearch = quota.title.toLowerCase().contains(_quotaSearchQuery.toLowerCase()) ||
          quota.qid.toLowerCase().contains(_quotaSearchQuery.toLowerCase()) ||
          quota.tag.toLowerCase().contains(_quotaSearchQuery.toLowerCase());
      final matchesTag = _quotaTagFilter.isEmpty || quota.tag.toLowerCase() == _quotaTagFilter.toLowerCase();
      return matchesSearch && matchesTag;
    }).toList();

    final groupedQuotas = _groupQuotasByDate(filteredQuotas);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => QuotaManageDialog(
              onSave: (title, tag) {
                notifier.addQuota(title: title, tag: tag);
              },
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Quota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 32,
          vertical: isMobile ? 16 : 24,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar & Filter Row
            Row(
              children: [
                // Search Input Field
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _quotaSearchController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (val) {
                        setState(() {
                          _quotaSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search quotas (Title, QID, Tag)...',
                        hintStyle: TextStyle(color: hintColor, fontSize: 13),
                        prefixIcon: Icon(IconsaxPlusLinear.search_normal, size: 18, color: hintColor),
                        suffixIcon: _quotaSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                color: hintColor,
                                onPressed: () {
                                  _quotaSearchController.clear();
                                  setState(() {
                                    _quotaSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Tag Filter Popup Button
                PopupMenuButton<String>(
                  tooltip: 'Filter by Tag',
                  onSelected: (tag) {
                    setState(() {
                      if (_quotaTagFilter == tag) {
                        _quotaTagFilter = '';
                      } else {
                        _quotaTagFilter = tag;
                      }
                    });
                  },
                  itemBuilder: (context) {
                    final uniqueTags = quotas.map((q) => q.tag).toSet().toList();
                    if (!uniqueTags.contains('General')) uniqueTags.add('General');
                    if (!uniqueTags.contains('Marketing')) uniqueTags.add('Marketing');
                    if (!uniqueTags.contains('Development')) uniqueTags.add('Development');
                    if (!uniqueTags.contains('Operations')) uniqueTags.add('Operations');
                    
                    return [
                      // Clear Filter option
                      PopupMenuItem<String>(
                        value: '',
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_alt_off_outlined,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            const Text('All Tags', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      ...uniqueTags.map((tag) {
                        final isSelected = _quotaTagFilter.toLowerCase() == tag.toLowerCase();
                        return CheckedPopupMenuItem<String>(
                          value: tag,
                          checked: isSelected,
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        );
                      }),
                    ];
                  },
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _quotaTagFilter.isNotEmpty
                          ? AppColors.primary.withOpacity(0.15)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _quotaTagFilter.isNotEmpty
                            ? AppColors.primary
                            : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          IconsaxPlusLinear.filter,
                          size: 18,
                          color: _quotaTagFilter.isNotEmpty ? AppColors.primary : textColor,
                        ),
                        if (_quotaTagFilter.isNotEmpty)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (quotas.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.wallet_search, size: 64, color: hintColor),
                      const SizedBox(height: 16),
                      Text('No quotas added yet', style: TextStyle(color: hintColor, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Click "Add Quota" to create your first entry', style: TextStyle(color: hintColor.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (filteredQuotas.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.search_status, size: 64, color: hintColor),
                      const SizedBox(height: 16),
                      Text('No matching quotas found', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Try adjusting your search query or tag filter', style: TextStyle(color: hintColor, fontSize: 13)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          _quotaSearchController.clear();
                          setState(() {
                            _quotaSearchQuery = '';
                            _quotaTagFilter = '';
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset Search & Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupedQuotas.keys.length,
                itemBuilder: (context, index) {
                  final dateHeader = groupedQuotas.keys.elementAt(index);
                  final quotasInDate = groupedQuotas[dateHeader]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Group Header
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                dateHeader,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quotas under this Date
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: quotasInDate.length,
                        itemBuilder: (context, idx) {
                          final quota = quotasInDate[idx];
                          final formattedTime = DateFormat('hh:mm a').format(quota.date);
                          final hasEarn = quota.earn > 0;
                          final hasExpense = quota.expense > 0;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF111827) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: hasEarn 
                                          ? AppColors.success 
                                          : (hasExpense ? AppColors.error : AppColors.primary),
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuotaEditScreen(quota: quota),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 20,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        // Main info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      quota.title,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: textColor,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 0.5),
                                                    ),
                                                    child: Text(
                                                      quota.tag,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                    quota.qid,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: isDark ? AppColors.primaryContainer : AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '•  $formattedTime',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: hintColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (hasEarn || hasExpense) ...[
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 6,
                                                  children: [
                                                    if (hasEarn)
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(3),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.success.withValues(alpha: 0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 8),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Earn: \$${quota.earn.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.success,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    if (hasExpense)
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(3),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.error.withValues(alpha: 0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.error, size: 8),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Expense: \$${quota.expense.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.error,
                                                            ),
                                                          ),
                                                          if (quota.expenseTime.isNotEmpty) ...[
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '(${quota.expenseTime})',
                                                              style: TextStyle(fontSize: 9, color: hintColor),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Edit icon at the right
                                        IconButton(
                                          icon: Icon(Icons.edit_note_rounded, size: 18, color: hintColor),
                                          style: IconButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(32, 32),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => QuotaEditScreen(quota: quota),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigureTab(Company company, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.darkText;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    // Get projects of the current company — use .value to preserve cached data
    // during background refreshes so the list never flickers/collapses.
    final allCompanyProjects = ref.watch(projectProvider).value
        ?.where((p) => p.companyId == company.id).toList() ?? <pmod.Project>[];

    // Apply search filter (attachedSearchQuery) and status filter (selectedStatuses)
    final filteredProjects = allCompanyProjects.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_attachedSearchQuery.toLowerCase()) ||
          p.pid.toLowerCase().contains(_attachedSearchQuery.toLowerCase());
      final matchesStatus = _selectedStatuses.isEmpty || _selectedStatuses.contains(p.status);
      return matchesSearch && matchesStatus;
    }).toList();

    // Sort by updated time descending (or created time/start date)
    filteredProjects.sort((a, b) {
      final dateA = a.updatedAt ?? a.createdAt ?? a.startDate;
      final dateB = b.updatedAt ?? b.createdAt ?? b.startDate;
      return dateB.compareTo(dateA);
    });

    // Group by Date (Today, Yesterday, Date format)
    final groupedProjects = _groupProjectsByDate(filteredProjects);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 32,
          vertical: isMobile ? 16 : 24,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar & Filter & Attach Row
            Row(
              children: [
                // Search Input Field
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _attachedSearchController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (val) {
                        setState(() {
                          _attachedSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search attached projects...',
                        hintStyle: TextStyle(color: hintColor, fontSize: 13),
                        prefixIcon: Icon(IconsaxPlusLinear.search_normal, size: 18, color: hintColor),
                        suffixIcon: _attachedSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                color: hintColor,
                                onPressed: () {
                                  _attachedSearchController.clear();
                                  setState(() {
                                    _attachedSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Status Filter Icon Button (PopupMenuButton)
                PopupMenuButton<pmod.ProjectStatus>(
                  tooltip: 'Filter by Status',
                  onSelected: (status) {
                    setState(() {
                      if (_selectedStatuses.contains(status)) {
                        _selectedStatuses.remove(status);
                      } else {
                        _selectedStatuses.add(status);
                      }
                    });
                  },
                  itemBuilder: (context) {
                    return pmod.ProjectStatus.values.map((status) {
                      final isSelected = _selectedStatuses.contains(status);
                      return CheckedPopupMenuItem<pmod.ProjectStatus>(
                        value: status,
                        checked: isSelected,
                        child: Text(
                          _getStatusName(status),
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _selectedStatuses.isNotEmpty
                          ? AppColors.primary.withOpacity(0.15)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedStatuses.isNotEmpty
                            ? AppColors.primary
                            : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      ),
                    ),
                    child: Icon(
                      IconsaxPlusLinear.filter,
                      size: 18,
                      color: _selectedStatuses.isNotEmpty ? AppColors.primary : textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Attach Icon Button (Opens Dialog)
                SizedBox(
                  height: 48,
                  width: isMobile ? 48 : null,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AttachProjectDialog(company: company),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: isMobile
                        ? const Icon(IconsaxPlusLinear.link_1, size: 18)
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(IconsaxPlusLinear.link_1, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Attach Project',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date Grouped Project Cards or Empty State
            if (filteredProjects.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.link_square, size: 64, color: hintColor),
                      const SizedBox(height: 16),
                      Text(
                        allCompanyProjects.isEmpty
                            ? 'No projects attached to this organization'
                            : 'No search results match filters',
                        style: TextStyle(color: hintColor, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        allCompanyProjects.isEmpty
                            ? 'Click "Attach Project" to link a project'
                            : 'Try adjusting your search query or filters',
                        style: TextStyle(color: hintColor.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupedProjects.keys.length,
                itemBuilder: (context, index) {
                  final dateHeader = groupedProjects.keys.elementAt(index);
                  final projectsInDate = groupedProjects[dateHeader]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Group Header (WhatsApp message group style or Gallery style)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                dateHeader,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of projects on this date
                      ...projectsInDate.map((proj) {
                        final formattedTime = DateFormat('hh:mm a').format(
                          proj.updatedAt ?? proj.createdAt ?? proj.startDate,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              context.go('/projects/${proj.id}');
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              child: Row(
                                children: [
                                  // Left side brand color indicator bar
                                  Container(
                                    width: 4,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: proj.brandColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),

                                  // Center Section: Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            // PID Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                proj.pid,
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),

                                            // Status Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(proj.status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getStatusName(proj.status).toUpperCase(),
                                                style: TextStyle(
                                                  color: _getStatusColor(proj.status),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 8,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),

                                            // Live/Pending badge based on approval
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (proj.isApproved ? AppColors.success : AppColors.warning).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                proj.isApproved ? 'LIVE' : 'PENDING',
                                                style: TextStyle(
                                                  color: proj.isApproved ? AppColors.success : AppColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 8,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          proj.name,
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 15,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (proj.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            proj.description,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: subTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),

                                  // Right Section: Action (Detach) and Time
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Detach button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => _confirmDetach(proj),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              IconsaxPlusLinear.link_square,
                                              size: 15,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Time of attachment (WhatsApp message time style)
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
                      }).toList(),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Company company, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final paddingVal = isMobile ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(paddingVal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              children: [
                _buildStatCard('Active Employees', company.activeEmployees.toString(), IconsaxPlusLinear.people, Colors.blue, isDark, isMobile: true),
                const SizedBox(height: 16),
                _buildStatCard('Annual Revenue', '\$${(company.annualRevenue / 1000000).toStringAsFixed(1)}M', IconsaxPlusLinear.money_send, Colors.green, isDark, isMobile: true),
                const SizedBox(height: 16),
                _buildStatCard('Health Score', '${(company.healthScore * 100).toInt()}%', IconsaxPlusLinear.heart, Colors.red, isDark, isMobile: true),
              ],
            )
          else
            Row(
              children: [
                _buildStatCard('Active Employees', company.activeEmployees.toString(), IconsaxPlusLinear.people, Colors.blue, isDark, isMobile: false),
                const SizedBox(width: 20),
                _buildStatCard('Annual Revenue', '\$${(company.annualRevenue / 1000000).toStringAsFixed(1)}M', IconsaxPlusLinear.money_send, Colors.green, isDark, isMobile: false),
                const SizedBox(width: 20),
                _buildStatCard('Health Score', '${(company.healthScore * 100).toInt()}%', IconsaxPlusLinear.heart, Colors.red, isDark, isMobile: false),
              ],
            ),
          const SizedBox(height: 32),
          _buildInfoSection(company, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark, {bool isMobile = false}) {
    final cardContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
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
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return cardContent;
    }
    return Expanded(child: cardContent);
  }

  Widget _buildInfoSection(Company company, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Primary Category', company.categories.join(', '), isDark, isMobile),
          _buildInfoRow('Official Website', company.website, isDark, isMobile),
          _buildInfoRow('Corporate Email', company.primaryEmail, isDark, isMobile),
          _buildInfoRow('Direct Phone', company.phone, isDark, isMobile),
          _buildInfoRow('Global Location', company.location, isDark, isMobile),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white24 : Colors.black.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This module is currently being synchronized with the EBM blueprint system.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
        ],
      ),
    ).animate().fade().scale();
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
              color: AppColors.primary,
              fontSize: (style.fontSize ?? 14) - 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(Company company, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (company.status == CompanyStatus.pending)
                _buildApprovalBar(company, isDark).animate().fadeIn().slideY(begin: -0.1, end: 0),
              
              // ── HERO: Company Identity Banner ────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                            ? [AppColors.primary.withValues(alpha: 0.5), AppColors.secondary.withValues(alpha: 0.2)]
                            : [AppColors.primary.withValues(alpha: 0.15), AppColors.secondary.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(IconsaxPlusLinear.building_3, size: 200, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03)),
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
                                // Logo
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      )
                                    ],
                                  ),
                                  child: _buildCompanyLogo(company, 110),
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
                                          company.name,
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
                                            // CID Chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(IconsaxPlusLinear.copy, size: 14, color: AppColors.primary),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    company.id,
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
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
                                              company.categories.isNotEmpty ? company.categories.first.toUpperCase() : "UNCATEGORIZED",
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
                                  'BRIEF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildExpandableText(
                                  text: company.shortDescription?.isNotEmpty == true
                                      ? company.shortDescription!
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
                                if (company.fullDescription?.isNotEmpty == true) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(IconsaxPlusLinear.document_text, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                                            const SizedBox(width: 10),
                                            Text('DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white38 : Colors.black38)),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildExpandableText(
                                          text: company.fullDescription!,
                                          wordLimit: 120,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white60 : Colors.black87,
                                            height: 1.7,
                                          ),
                                          isExpanded: _isDetailsExpanded,
                                          onToggle: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // ── Online Platform ───────────────────────────────
                            if (company.onlinePlatforms.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _buildOnlinePlatformRecordSection(company, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Strategy & Roadmaps ─────────────────────────────────────────
              _buildRecordCard('Strategy & Roadmaps', IconsaxPlusLinear.routing, isDark, [
                _buildRecordRow('Current Execution', company.roadmapExecution ?? 'Pending execution deployment', isDark, isMultiLine: true),
                _buildRecordRow('Future Target', company.targetRoadmap ?? 'Targets not established', isDark, isMultiLine: true),
              ]),

              // ── Governance & Agreements ─────────────────────────────────────
              _buildRecordCard('Governance & Agreements', IconsaxPlusLinear.judge, isDark, [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: company.agreementLink != null && company.agreementLink!.isNotEmpty 
                        ? () => _launchURL(company.agreementLink!) 
                        : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              company.agreementShortDesc?.isNotEmpty == true 
                                ? company.agreementShortDesc! 
                                : 'Governance Title Pending',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                decoration: company.agreementLink != null && company.agreementLink!.isNotEmpty 
                                    ? TextDecoration.underline 
                                    : null,
                              ),
                            ),
                            if (company.agreementLink != null && company.agreementLink!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(IconsaxPlusLinear.link, size: 16, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildExpandableText(
                      text: company.agreementFullDesc?.isNotEmpty == true 
                          ? company.agreementFullDesc! 
                          : 'Organizational governance and agreement context has not been deployed yet for this blueprint.',
                      wordLimit: 150,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.7,
                      ),
                      isExpanded: _isGovernanceExpanded,
                      onToggle: () => setState(() => _isGovernanceExpanded = !_isGovernanceExpanded),
                    ),
                  ],
                ),
              ]),

              // ── Authority & Validation ──────────────────────────────────────
              _buildRecordCard('Authority & Validation', IconsaxPlusLinear.verify, isDark, [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Executive Signature
                    Expanded(
                      child: _buildSignatureBlock(
                        'EXECUTIVE SIGNATURE',
                        company.managerSignature ?? 'UNAUTHORIZED',
                        company.managerSignatureTimestamp,
                        isDark,
                      ),
                    ),
                    
                    // Divider
                    Container(
                      width: 1,
                      height: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),

                    // Right: Founder Signature
                    Expanded(
                      child: _buildSignatureBlock(
                        'FOUNDER SIGNATURE',
                        company.founderSignature ?? 'PENDING DEPLOYMENT',
                        company.founderSignatureTimestamp,
                        isDark,
                        isFounder: true,
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 60),
            ],
          ),
    );
  }

  Widget _buildCompanyLogo(Company company, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: company.logoUrl != null && company.logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: EbmImage(source: company.logoUrl!, fit: BoxFit.cover),
            )
          : Icon(IconsaxPlusBold.building_3, color: AppColors.primary, size: size * 0.45),
    );
  }

  Widget _buildOnlinePlatformRecordSection(Company company, bool isDark) {
    final platforms = company.onlinePlatforms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(IconsaxPlusLinear.global, color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'ONLINE PLATFORMS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${platforms.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 6 : (MediaQuery.of(context).size.width > 800 ? 4 : 2),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: platforms.length,
          itemBuilder: (context, i) => _buildPlatformRecordCard(company, platforms[i], isDark),
        ),
      ],
    );
  }

  Widget _buildPlatformRecordCard(Company company, Map<String, String> platform, bool isDark) {
    final iconSource = platform['icon'] ?? '';
    final title = platform['title'] ?? 'Untitled';
    final link = platform['link'] ?? '';
    final docId = platform['doc'] ?? '';
    final hasLink = link.isNotEmpty;
    final hasDoc = docId.isNotEmpty;

    Future<void> openLink() async {
      if (!hasLink) return;
      final uri = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return MouseRegion(
      cursor: hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Main Body (Icon + Title) ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
                        shape: BoxShape.circle,
                      ),
                      child: iconSource.startsWith('asset://')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: EbmImage(source: iconSource, width: 28, height: 28, fit: BoxFit.contain),
                            )
                          : Icon(IconsaxPlusLinear.global, size: 24, color: isDark ? Colors.white30 : Colors.black26),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Bar (Visit & Docs Icons) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Visit Button
                  Expanded(
                    child: GestureDetector(
                      onTap: hasLink ? openLink : null,
                      behavior: HitTestBehavior.opaque,
                      child: Tooltip(
                        message: hasLink ? 'Visit Platform' : 'No Link Provided',
                        child: Icon(
                          hasLink ? IconsaxPlusLinear.external_drive : IconsaxPlusLinear.lock_1,
                          size: 16,
                          color: hasLink ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                    ),
                  ),
                  
                  // Docs Button
                  Expanded(
                    child: GestureDetector(
                      onTap: hasDoc ? () {
                        // TODO: Open Doc Viewer
                      } : null,
                      behavior: HitTestBehavior.opaque,
                      child: Tooltip(
                        message: hasDoc ? 'View Document' : 'No Document Attached',
                        child: Icon(
                          IconsaxPlusLinear.document_text,
                          size: 16,
                          color: hasDoc ? const Color(0xFF8B5CF6) : (isDark ? Colors.white10 : Colors.black12),
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

  Widget _buildRecordCard(String title, IconData icon, bool isDark, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
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
            children: rows.expand((r) => [r, Divider(height: 40, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))]).toList()..removeLast(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRecordRow(String label, String value, bool isDark, {bool isMultiLine = false}) {
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
              Icon(IconsaxPlusBold.verify, size: 12, color: const Color(0xFF10B981).withValues(alpha: 0.7)),
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
                  ? (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9))
                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
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
            isFounder ? 'Awaiting Founder Authorization' : 'Signature pending blueprint deployment',
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.1)),
          ),
      ],
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

  void _showFounderAuthDialog(BuildContext context, Company company) {
    setState(() => _isDialogVisible = true);
    final TextEditingController signatureController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Force decision
      barrierLabel: 'Founder Authorization',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              width: 500,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(IconsaxPlusBold.verify, color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FOUNDER AUTHORIZATION',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Manager "${company.managerSignature}" has verified this blueprint. As the Founder/Admin, your authorization is required to finalize the organizational record.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
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
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() => _isDialogVisible = false);
                            Navigator.pop(ctx);
                          },
                          child: Text('AUTHORIZE LATER', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (signatureController.text.trim().isEmpty) return;
                            
                            final updatedCompany = company.copyWith(
                              founderSignature: signatureController.text.trim(),
                              founderSignatureTimestamp: DateTime.now(),
                            );
                            
                            await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
                            
                            setState(() => _isDialogVisible = false);
                            if (context.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
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
        );
      },
    );
  }

  Widget _buildApprovalBar(Company company, bool isDark) {
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
                  'This organization was submitted by a Manager and requires your review to go live.',
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
                onPressed: () => _handleApproval(company.id, false),
                child: Text('Decline', style: TextStyle(color: isDark ? Colors.redAccent[100] : Colors.redAccent)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _handleApproval(company.id, true),
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
      final currentState = ref.read(companyProvider).value;
      if (currentState == null) return;
      
      final company = currentState.companies.firstWhere((c) => c.id == id);
      await ref.read(companyProvider.notifier).updateCompany(
        company.copyWith(status: approved ? CompanyStatus.active : CompanyStatus.declined),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Organization approved successfully!' : 'Organization declined.'),
            backgroundColor: approved ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildProjectHubTab(Company company, bool isDark) {
    final projectsState = ref.watch(projectProvider);

    return projectsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading projects: $e')),
      data: (allProjects) {
        final companyProjects = allProjects.where((p) => p.companyId == company.id).toList();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Hub',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'Strategic deployments for ${company.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateProjectDialog(company, isDark),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deploy Project'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (companyProjects.isEmpty)
                _buildEmptyState(
                  'No Projects Deployed',
                  'Initialize your first strategic registry to start tracking goals and progress.',
                  IconsaxPlusLinear.folder_add,
                  isDark,
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: companyProjects.length,
                    itemBuilder: (context, index) {
                      final project = companyProjects[index];
                      return _buildProjectCard(project, isDark);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectCard(pmod.Project project, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: project.brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(IconsaxPlusLinear.folder, color: project.brandColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PID: ${project.pid}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _statusBadge(project.status),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Load',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${project.consumedBudget.toStringAsFixed(0)} / \$${project.totalBudget.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {}, // Future: Open details
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(pmod.ProjectStatus status) {
    Color color;
    String label;
    switch (status) {
      case pmod.ProjectStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case pmod.ProjectStatus.completed:
        color = Colors.blue;
        label = 'Completed';
        break;
      case pmod.ProjectStatus.onHold:
        color = Colors.orange;
        label = 'On Hold';
        break;
      case pmod.ProjectStatus.planning:
        color = Colors.purple;
        label = 'Planning';
        break;
      case pmod.ProjectStatus.draft:
        color = Colors.amber;
        label = 'Draft';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String sub, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(Company company, bool isDark) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Deploy New Project', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(labelText: 'Project Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await ref.read(projectProvider.notifier).createProject(
                      name: nameCtrl.text.trim(),
                      companyId: company.id,
                      description: descCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Deploy'),
          ),
        ],
      ),
    );
  }
}

// ── Strategic Company Map Custom Subcomponents ───────────────────────────────

class _CompanyFlowGraphNodeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String dateText;
  final String trackingId;
  final String statusText;
  final Color statusColor;
  final Color brandColor;
  final IconData icon;
  final VoidCallback? onTap;
  
  const _CompanyFlowGraphNodeCard({
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
  State<_CompanyFlowGraphNodeCard> createState() => _CompanyFlowGraphNodeCardState();
}

class _CompanyFlowGraphNodeCardState extends State<_CompanyFlowGraphNodeCard> {
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

class _StrategicCompanyMapCentral extends ConsumerStatefulWidget {
  final Company company;
  const _StrategicCompanyMapCentral({required this.company});

  @override
  ConsumerState<_StrategicCompanyMapCentral> createState() => _StrategicCompanyMapCentralState();
}

class _StrategicCompanyMapCentralState extends ConsumerState<_StrategicCompanyMapCentral> with SingleTickerProviderStateMixin {
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

    // Periodic real-time sync every 10 seconds (matches project provider pattern)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _syncData();
    });
  }

  void _syncData() {
    // Sync tasks for all projects belonging to this company
    ref.read(taskProvider.notifier).syncWithDatabase(
      companyId: widget.company.id,
    );
    // Also refresh project data to get latest plans
    ref.read(projectProvider.notifier).fetchProjects();
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
    final companyColor = AppColors.primary;
    
    // Read projects for this company — .value retains the cached list even during
    // background loading, so the canvas never collapses or jumps.
    final companyProjects = ref.watch(projectProvider).value
        ?.where((p) => p.companyId == widget.company.id).toList() ?? <pmod.Project>[];

    // Read real tasks for this company's projects
    final projectIds = companyProjects.map((p) => p.id).toSet();
    final realTasks = ref.watch(taskProvider).allTasks.where((t) => projectIds.contains(t.projectId)).toList();
    final List<SystemTask> tasks = [];
    
    if (realTasks.isNotEmpty) {
      tasks.addAll(realTasks);
    } else {
      // Dynamic simulated tasks based on the plans of all projects if no tasks exist
      for (var project in companyProjects) {
        for (var plan in project.plans) {
          tasks.addAll([
            SystemTask(
              id: '${plan.id}-t1',
              planId: plan.id,
              projectId: project.id,
              taskNumber: 'TSK-${project.pid.substring(0, widget.company.id.length > 3 ? 3 : widget.company.id.length)}-01',
              title: 'Strategic Onboarding',
              allocatedCost: plan.budget * 0.20,
              status: TaskStatus.completed,
              assignee: 'Operations Lead',
              dueDate: DateTime.now().add(const Duration(days: 2)),
              description: 'Conduct foundational alignment session, set up credentials, and initialize project blueprint.',
            ),
            SystemTask(
              id: '${plan.id}-t2',
              planId: plan.id,
              projectId: project.id,
              taskNumber: 'TSK-${project.pid.substring(0, widget.company.id.length > 3 ? 3 : widget.company.id.length)}-02',
              title: 'Integrate Core Services',
              allocatedCost: plan.budget * 0.50,
              status: TaskStatus.inProgress,
              assignee: 'Development Team',
              dueDate: DateTime.now().add(const Duration(days: 7)),
              description: 'Formulate core logic, establish databases, build dynamic UI widgets, and deploy service API layers.',
            ),
            SystemTask(
              id: '${plan.id}-t3',
              planId: plan.id,
              projectId: project.id,
              taskNumber: 'TSK-${project.pid.substring(0, widget.company.id.length > 3 ? 3 : widget.company.id.length)}-03',
              title: 'Governance & Auditing',
              allocatedCost: plan.budget * 0.30,
              status: TaskStatus.todo,
              assignee: 'Quality Analyst',
              dueDate: DateTime.now().add(const Duration(days: 14)),
              description: 'Validate requirements checklist, audit security configuration, perform user acceptance tests, and obtain authorization.',
            ),
          ]);
        }
      }
    }

    // Dynamic layout coordinate calculations
    const double verticalSpacing = 95.0;
    const double companyX = 50.0;
    const double projectX = 400.0;
    const double planX = 750.0;
    const double taskX = 1100.0;
    
    double currentY = 40.0;
    final Map<String, Offset> projectPositions = {};
    final Map<String, Offset> planPositions = {};
    final Map<String, Offset> taskPositions = {};
    
    for (final project in companyProjects) {
      final plans = project.plans;
      
      for (final plan in plans) {
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
      
      // If a project has no plans, it should still occupy space
      if (plans.isEmpty) {
        projectPositions[project.id] = Offset(projectX, currentY);
        currentY += verticalSpacing + 40.0;
      } else {
        // Project Y is in the vertical center of its plans
        final firstPlanY = planPositions[plans.first.id]!.dy;
        final lastPlanY = planPositions[plans.last.id]!.dy;
        final double projectY = (firstPlanY + lastPlanY) / 2;
        projectPositions[project.id] = Offset(projectX, projectY);
      }
      
      currentY += 20.0; // Spacing between projects
    }
    
    // Company Y is in the vertical center of all projects
    double companyY = 100.0;
    if (companyProjects.isNotEmpty) {
      final firstProjectY = projectPositions[companyProjects.first.id]!.dy;
      final lastProjectY = projectPositions[companyProjects.last.id]!.dy;
      companyY = (firstProjectY + lastProjectY) / 2;
    }
    final Offset companyPos = Offset(companyX, companyY);
    
    final double canvasHeight = currentY.clamp(650.0, 10000.0);
    const double canvasWidth = 1450.0;

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
                        painter: _CompanyMapLinkPainter(
                          company: widget.company,
                          projects: companyProjects,
                          tasks: tasks,
                          companyPos: companyPos,
                          projectPositions: projectPositions,
                          planPositions: planPositions,
                          taskPositions: taskPositions,
                          pulseValue: _rippleController.value,
                        ),
                      );
                    },
                  ),

                  // 1. Root Company Node
                  Positioned(
                    left: companyPos.dx,
                    top: companyPos.dy,
                    child: _CompanyFlowGraphNodeCard(
                      title: widget.company.name,
                      subtitle: 'COMPANY ROOT NODE',
                      dateText: 'Portal Node ID',
                      trackingId: widget.company.id.substring(0, widget.company.id.length > 8 ? 8 : widget.company.id.length).toUpperCase(),
                      statusText: 'ACTIVE',
                      statusColor: Colors.green,
                      brandColor: companyColor,
                      icon: IconsaxPlusLinear.building_3,
                    ),
                  ),

                  // 2. Project Nodes
                  ...companyProjects.map((project) {
                    final projectPos = projectPositions[project.id]!;
                    return Positioned(
                      left: projectPos.dx,
                      top: projectPos.dy,
                      child: _CompanyFlowGraphNodeCard(
                        title: project.name,
                        subtitle: project.category.toUpperCase(),
                        dateText: DateFormat('MMM dd, yyyy').format(project.startDate),
                        trackingId: project.pid,
                        statusText: project.status.name.toUpperCase(),
                        statusColor: project.isApproved ? Colors.green : Colors.orangeAccent,
                        brandColor: project.brandColor,
                        icon: IconsaxPlusLinear.box,
                      ),
                    );
                  }),

                  // 3. Plan Hub Nodes
                  ...companyProjects.expand((p) => p.plans.map((plan) {
                    final planPos = planPositions[plan.id]!;
                    final planTasks = tasks.where((t) => t.planId == plan.id).toList();
                    final double totalAmount = planTasks.fold(0.0, (sum, t) => sum + t.grandTotal);
                    
                    return Positioned(
                      left: planPos.dx,
                      top: planPos.dy,
                      child: _CompanyFlowGraphNodeCard(
                        title: plan.title,
                        subtitle: '\$${totalAmount.toInt()} BUDGETED',
                        dateText: 'i-CODE Hub Node',
                        trackingId: plan.icode,
                        statusText: plan.status.toUpperCase(),
                        statusColor: _statusColor(plan.status),
                        brandColor: p.brandColor,
                        icon: IconsaxPlusLinear.hierarchy,
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => _buildCompanyPlanDetailsModal(
                            context: context,
                            plan: plan,
                            color: p.brandColor,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    );
                  })),

                  // 4. Task Micro Nodes
                  ...tasks.map((task) {
                    final taskPos = taskPositions[task.id];
                    if (taskPos == null) return const SizedBox.shrink();
                    final project = companyProjects.firstWhere((p) => p.id == task.projectId);
                    final formattedDate = task.dueDate != null 
                        ? DateFormat('yyyy-MM-dd').format(task.dueDate!)
                        : 'No Due Date';
                    
                    return Positioned(
                      left: taskPos.dx,
                      top: taskPos.dy,
                      child: _CompanyFlowGraphNodeCard(
                        title: task.title,
                        subtitle: 'ASSIGNEE: ${task.assignee.toUpperCase()}',
                        dateText: 'DUE: $formattedDate',
                        trackingId: task.taskNumber,
                        statusText: task.status.displayName,
                        statusColor: _getSimulatedStatusColor(task.status),
                        brandColor: project.brandColor,
                        icon: IconsaxPlusLinear.task_square,
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => _buildCompanyTaskDetailsModal(
                            context: context,
                            task: task,
                            color: project.brandColor,
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
                _zoomBtn(Icons.add, () => _zoom(0.15), companyColor, isDark),
                const SizedBox(height: 6),
                _zoomBtn(Icons.remove, () => _zoom(-0.15), companyColor, isDark),
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

// ── Company Cubic Bezier Link Painter ────────────────────────────────────────

class _CompanyMapLinkPainter extends CustomPainter {
  final Company company;
  final List<pmod.Project> projects;
  final List<SystemTask> tasks;
  final Offset companyPos;
  final Map<String, Offset> projectPositions;
  final Map<String, Offset> planPositions;
  final Map<String, Offset> taskPositions;
  final double pulseValue;

  _CompanyMapLinkPainter({
    required this.company,
    required this.projects,
    required this.tasks,
    required this.companyPos,
    required this.projectPositions,
    required this.planPositions,
    required this.taskPositions,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startPort = Offset(companyPos.dx + 240.0, companyPos.dy + 40.0);

    // 1. Draw curves from Company right edge to Projects left edge
    for (final project in projects) {
      final projectPos = projectPositions[project.id];
      if (projectPos != null) {
        final endPort = Offset(projectPos.dx, projectPos.dy + 40.0);
        
        final path = Path()
          ..moveTo(startPort.dx, startPort.dy)
          ..cubicTo(
            startPort.dx + 80.0, startPort.dy,
            endPort.dx - 80.0, endPort.dy,
            endPort.dx, endPort.dy,
          );

        // Draw background bezier path matching project's brandColor
        canvas.drawPath(
          path, 
          Paint()
            ..color = project.brandColor.withOpacity(0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );

        // Draw active light pulse particle
        drawPulse(canvas, path, Paint()..color = project.brandColor, pulseValue);
      }
    }

    // 2. Draw curves from Projects right edge to Plans left edge
    for (final project in projects) {
      final projectPos = projectPositions[project.id];
      if (projectPos != null) {
        final projectStartPort = Offset(projectPos.dx + 240.0, projectPos.dy + 40.0);
        for (final plan in project.plans) {
          final planPos = planPositions[plan.id];
          if (planPos != null) {
            final endPort = Offset(planPos.dx, planPos.dy + 40.0);
            
            final path = Path()
              ..moveTo(projectStartPort.dx, projectStartPort.dy)
              ..cubicTo(
                projectStartPort.dx + 80.0, projectStartPort.dy,
                endPort.dx - 80.0, endPort.dy,
                endPort.dx, endPort.dy,
              );

            canvas.drawPath(
              path, 
              Paint()
                ..color = project.brandColor.withOpacity(0.15)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round,
            );

            drawPulse(canvas, path, Paint()..color = project.brandColor, pulseValue);
          }
        }
      }
    }

    // 3. Draw curves from Plans right edge to Tasks left edge
    for (final project in projects) {
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
              
              canvas.drawPath(
                path, 
                Paint()
                  ..color = taskColor.withOpacity(0.12)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5
                  ..strokeCap = StrokeCap.round,
              );

              drawPulse(canvas, path, Paint()..color = taskColor, pulseValue);
            }
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

// ── Private Helper Mappings and Modals ───────────────────────────────────────

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

Widget _buildCompanyPlanDetailsModal({
  required BuildContext context,
  required pmod.Plan plan,
  required Color color,
  required bool isDark,
}) {
  final double budgetProgress = plan.budget > 0 ? (plan.consumedBudget / plan.budget) : 0.0;
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
                    plan.icode,
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
              plan.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A critical programmatic node mapping system goals to resource allocation and active development phases.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _modalDetailItem(
                    'STATUS',
                    plan.status.toUpperCase(),
                    plan.status.toLowerCase() == 'completed' ? Colors.green : Colors.blueAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _modalDetailItem(
                    'BUDGET CONSUMPTION',
                    '${(budgetProgress * 100).toStringAsFixed(1)}%',
                    budgetProgress > 0.85 ? Colors.redAccent : Colors.greenAccent,
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
                    'TOTAL BUDGET',
                    '\$${NumberFormat('#,##0.00').format(plan.budget)}',
                    color,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _modalDetailItem(
                    'CONSUMED AMOUNT',
                    '\$${NumberFormat('#,##0.00').format(plan.consumedBudget)}',
                    isDark ? Colors.white70 : Colors.black87,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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

Widget _buildCompanyTaskDetailsModal({
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
