import 'dart:io';
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
    super.dispose();
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
      body: Column(
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
      case 2: return 'Performance Analytics';
      case 3: return 'Project Hub';
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
                    _sidebarItem(2, Icons.analytics_outlined, 'Analytics', isDark),
                    _sidebarItem(3, Icons.assignment_outlined, 'Project Hub', isDark),
                    _sidebarItem(4, Icons.task_alt_outlined, 'Tasks', isDark),
                    _sidebarItem(5, Icons.settings_outlined, 'Settings', isDark),
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
      case 2: return _buildPlaceholderTab('Analytics Dashboard', IconsaxPlusLinear.graph, isDark);
      case 3: return _buildProjectHubTab(company, isDark);
      case 4: return const TasksScreen(); // Integrated Tasks Screen
      case 5: return _buildPlaceholderTab('Company Settings', IconsaxPlusLinear.setting_2, isDark);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab(Company company, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatCard('Active Employees', company.activeEmployees.toString(), IconsaxPlusLinear.people, Colors.blue, isDark),
              const SizedBox(width: 20),
              _buildStatCard('Annual Revenue', '\$${(company.annualRevenue / 1000000).toStringAsFixed(1)}M', IconsaxPlusLinear.money_send, Colors.green, isDark),
              const SizedBox(width: 20),
              _buildStatCard('Health Score', '${(company.healthScore * 100).toInt()}%', IconsaxPlusLinear.heart, Colors.red, isDark),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoSection(company, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
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
      ),
    );
  }

  Widget _buildInfoSection(Company company, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
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
          _buildInfoRow('Primary Category', company.categories.join(', '), isDark),
          _buildInfoRow('Official Website', company.website, isDark),
          _buildInfoRow('Corporate Email', company.primaryEmail, isDark),
          _buildInfoRow('Direct Phone', company.phone, isDark),
          _buildInfoRow('Global Location', company.location, isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
        ),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
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
