import 'dart:ui';
import 'dart:io';
import '../../features/live/presentation/live_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/departments/presentation/department_screen.dart';
import '../theme/theme_provider.dart';
import '../../shared/widgets/splash_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/add/presentation/add_screen.dart';
import '../../features/chat/presentation/chat_detail_screen.dart'; // For CallState
import '../../features/chat/presentation/call_screen.dart';
import '../../features/display_board/presentation/display_board_screen.dart';
import '../../features/black_flag/presentation/black_flag_screen.dart';
import '../../features/empire/presentation/empire_screen.dart';
import '../../features/security/presentation/security_screen.dart';
import '../../features/geo_analysis/presentation/geo_analysis_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/online_geo/presentation/online_geo_screen.dart';
import '../../features/online_geo/presentation/web_zone_screen.dart';
import '../../features/online_geo/presentation/app_zone_screen.dart';
import '../../features/online_geo/presentation/software_zone_screen.dart';
import '../../features/pay_manager/presentation/pay_manager_screen.dart';
import '../../features/analysis/presentation/analysis_screens.dart';
import '../../features/live/presentation/overview_screens.dart';
import 'dart:async';

// Global header height constant
const double kGlobalHeaderHeight = 54.0;

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget tabletBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.tabletBody,
    required this.desktopBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return desktopBody;
        } else if (constraints.maxWidth >= 600) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}

class AppLayout extends ConsumerStatefulWidget {
  const AppLayout({super.key});

  @override
  ConsumerState<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends ConsumerState<AppLayout> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Timer? _globalCallTicker;
  final Set<String> _expandedMenus = {}; // Track expanded sidebar menus
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _startLoading();
    CallController.instance.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (mounted) setState(() {});
  }

  void _startGlobalCallTicker() {
    _globalCallTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (CallState.isCallActive && mounted) {
        setState(() {}); // Refresh global header for timer
      }
    });
  }

  @override
  void dispose() {
    CallController.instance.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _startLoading() async {
    // Show splash for 2.5 seconds for a premium feel
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  final List<Widget> _screens = [
    const LiveScreen(),
    const DashboardScreen(),
    const DisplayBoardScreen(),
    const DepartmentScreen(),
    const AddScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
    const BlackFlagScreen(),
    const EmpireScreen(),
    const SecurityScreen(),
    const GeoAnalysisScreen(),
    const CommunityScreen(),
    const OnlineGeoScreen(),
    const WebZoneScreen(),
    const AppZoneScreen(),
    const SoftwareZoneScreen(),
    const PayManagerScreen(),
    const AnalysisScreen(),
    const AnalysisCompanyScreen(),
    const AnalysisProjectsScreen(),
    const AnalysisPlanScreen(),
    const AnalysisConsoleScreen(),
    const AnalysisTasksScreen(),
    const OverviewScreen(),
    const OverviewAnalyticsScreen(),
    const OverviewOperationsScreen(),
    const OverviewSecurityScreen(),
    const OverviewEfficiencyScreen(),
    const OverviewBandwidthScreen(),
    const OverviewAuditScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isDesktopOS = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: !isDesktop ? _buildDrawer(isDark) : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _isLoading 
          ? const SplashScreen(key: ValueKey('splash'))
          : SafeArea(
              key: const ValueKey('main_content'),
              child: Column(
                children: [
                  if (isDesktopOS) _buildMacTitleBar(isDark),
                  Expanded(
                    child: ResponsiveLayout(
                      mobileBody: _buildMobileLayout(isDark),
                      tabletBody: _buildTabletLayout(isDark),
                      desktopBody: _buildDesktopLayout(isDark),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _macDot(Color color, String tooltip, VoidCallback onTap) {
    return _MacDotButton(color: color, tooltip: tooltip, onTap: onTap);
  }

  Widget _buildContentArea() {
    return _screens[_currentIndex];
  }
  Widget _buildMacTitleBar(bool isDark) {
    return GestureDetector(
      onPanStart: (details) {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          windowManager.startDragging();
        }
      },
      onDoubleTap: () async {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }
      },
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1117), const Color(0xFF161A23)]
                : [const Color(0xFFF5F7FA), const Color(0xFFEEF2F7)],
          ),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App branding
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated live signal dot — fixed size, stable layout
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: Center(child: const _LiveSignalDot()),
                  ),
                  const SizedBox(width: 9),
                  _AnimatedBrandingText(isDark: isDark),

                  // --- GLOBAL CALL STATUS DASHBOARD ---
                  if (CallState.isCallActive)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(name: CallState.activeUserName!, avatar: CallState.avatar!))),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.call, size: 10, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                "${CallState.activeUserName} • ${_formatCallDuration()}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Mac window control dots
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  _macDot(const Color(0xFFFF5F56), 'Close', () {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      windowManager.close();
                    }
                  }),
                  const SizedBox(width: 9),
                  _macDot(const Color(0xFFFFBD2E), 'Minimize', () {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      windowManager.minimize();
                    }
                  }),
                  const SizedBox(width: 9),
                  _macDot(const Color(0xFF28CA41), 'Maximize', () async {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Stack(
      children: [
        // Content below header and above bottom nav
        Padding(
          padding: EdgeInsets.only(
            top: kGlobalHeaderHeight,
            bottom: 70 + MediaQuery.of(context).padding.bottom, // Adjusted for sleek nav
          ),
          child: _buildContentArea(),
        ),
        // Global floating header (top)
        Positioned(
          top: 0, left: 0, right: 0,
          child: _buildGlobalHeader(isDark, isDesktop: false, isMobile: true, isDesktopOS: false),
        ),
        // Bottom nav
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildBottomNav(isDark),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(bool isDark) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: kGlobalHeaderHeight,
            bottom: 70 + MediaQuery.of(context).padding.bottom, // Adjusted for sleek nav
          ),
          child: _buildContentArea(),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: _buildGlobalHeader(isDark, isDesktop: false, isMobile: false, isDesktopOS: false),
        ),
        // Bottom nav
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildBottomNav(isDark),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Row(
      children: [
        _buildSidebar(isDark, isExpanded: true),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: kGlobalHeaderHeight),
                child: _buildContentArea(),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildGlobalHeader(isDark, isDesktop: true, isMobile: false, isDesktopOS: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Global blurred floating header — appears on ALL pages
  Widget _buildGlobalHeader(bool isDark, {
    required bool isDesktop,
    required bool isMobile,
    bool isDesktopOS = false,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: kGlobalHeaderHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: isDark
                  ? const Color(0xFF0F1117).withOpacity(0.85)
                  : const Color(0xFFF8FAFC).withOpacity(0.92),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: app branding on mobile/tablet only (Expanded to take remaining space)
                  Expanded(
                    child: !isDesktop
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grid_view_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 7),
                            Flexible(
                              child: RichText(
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'ebm ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.80),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'central',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                        color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.45),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                  ),

                  // Right: action icons — never overflow, shrink-wrap
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _headerIcon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        isDark,
                        () => ref.read(themeNotifierProvider.notifier).toggleTheme(),
                      ),
                      if (!isMobile) ...[const SizedBox(width: 4), _headerIcon(Icons.search_rounded, isDark, () {})],
                      const SizedBox(width: 4),
                      _headerIcon(Icons.notifications_outlined, isDark, () {}),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        child: Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary, size: 16),
                      ),
                      if (!isDesktop) ...[
                        const SizedBox(width: 12),
                        _headerIcon(Icons.menu_rounded, isDark, () {
                          _scaffoldKey.currentState?.openEndDrawer();
                        }),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Divider: mouse-tracking on desktop, elegant shadow on mobile/tablet
            if (isDesktopOS)
              _MouseTrackDivider(isDark: isDark)
            else
              _MobileDivider(isDark: isDark),
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

  Widget _buildDrawer(bool isDark) {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Drawer(
        width: 280.0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _buildSidebar(isDark, isExpanded: true, isDrawer: true),
      ),
    );
  }

  Widget _buildSidebar(bool isDark, {required bool isExpanded, bool isDrawer = false}) {
    final width = isDrawer ? double.infinity : (isExpanded ? 240.0 : 80.0);
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
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))),
          ),
          child: Column(
            crossAxisAlignment: isExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(height: isDrawer ? MediaQuery.of(context).padding.top + 24 : 24),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'ebm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextSpan(
                          text: ' central',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: isDark ? Colors.white60 : Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Scrollable Sidebar Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _sidebarItem(0, Icons.sensors_rounded, 'Live', isExpanded, isDark, hasStatusIndicator: true),
                  _buildExpandableSidebarItem(
                    index: 23,
                    icon: Icons.dashboard_customize_rounded,
                    label: 'Overview',
                    isExpanded: isExpanded,
                    isDark: isDark,
                    subItems: [
                      _SubMenuItem(index: 23, label: 'Real Time', icon: Icons.speed_rounded),
                      _SubMenuItem(index: 24, label: 'Finance', icon: Icons.payments_outlined),
                      _SubMenuItem(index: 25, label: 'Tasks', icon: Icons.task_alt_rounded),
                      _SubMenuItem(index: 26, label: 'Projects', icon: Icons.assignment_rounded),
                      _SubMenuItem(index: 27, label: 'Logistics', icon: Icons.local_shipping_outlined),
                      _SubMenuItem(index: 28, label: 'Inventory', icon: Icons.inventory_2_outlined),
                      _SubMenuItem(index: 29, label: 'HRM', icon: Icons.people_outline),
                    ],
                  ),
                  _sidebarItem(1, Icons.home_filled, 'Home', isExpanded, isDark),
                  _buildExpandableSidebarItem(
                    index: 17,
                    icon: Icons.analytics_rounded,
                    label: 'Analysis',
                    isExpanded: isExpanded,
                    isDark: isDark,
                    subItems: [
                      _SubMenuItem(index: 18, label: 'Company', icon: Icons.business_rounded),
                      _SubMenuItem(index: 19, label: 'Projects', icon: Icons.assignment_rounded),
                      _SubMenuItem(index: 20, label: 'Plan', icon: Icons.event_note_rounded),
                      _SubMenuItem(index: 21, label: 'Console', icon: Icons.terminal_rounded),
                      _SubMenuItem(index: 22, label: 'Tasks', icon: Icons.task_alt_rounded),
                    ],
                  ),
                  _sidebarItem(2, Icons.auto_awesome_motion, 'Board', isExpanded, isDark),
                  _sidebarItem(3, Icons.business_center, 'Departments', isExpanded, isDark),
                  _sidebarItem(4, Icons.add_circle, 'Add', isExpanded, isDark),
                  _sidebarItem(5, Icons.chat_bubble, 'Chat', isExpanded, isDark),
                  _sidebarItem(6, Icons.person, 'Profile', isExpanded, isDark),
                  _buildExpandableSidebarItem(
                    index: 7,
                    icon: Icons.outlined_flag_rounded,
                    label: 'Black Flag',
                    isExpanded: isExpanded,
                    isDark: isDark,
                    subItems: [
                      _SubMenuItem(index: 11, label: 'Community', icon: Icons.diversity_1_rounded),
                    ],
                  ),
                  _sidebarItem(8, Icons.fort_rounded, 'Empire', isExpanded, isDark),
                  _sidebarItem(9, Icons.security_rounded, 'Security', isExpanded, isDark),
                  _sidebarItem(10, Icons.public_rounded, 'Geo Analysis', isExpanded, isDark),
                  _buildExpandableSidebarItem(
                    index: 12,
                    icon: Icons.language_rounded,
                    label: 'Online Geo',
                    isExpanded: isExpanded,
                    isDark: isDark,
                    subItems: [
                      _SubMenuItem(index: 13, label: 'Web Zone', icon: Icons.web_rounded),
                      _SubMenuItem(index: 14, label: 'App Zone', icon: Icons.app_shortcut_rounded),
                      _SubMenuItem(index: 15, label: 'Software Zone', icon: Icons.terminal_rounded),
                    ],
                  ),
                  _sidebarItem(16, Icons.payments_rounded, 'Pay Manager', isExpanded, isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildExpandableSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isExpanded,
    required bool isDark,
    required List<_SubMenuItem> subItems,
  }) {
    final isSelected = _currentIndex == index || subItems.any((s) => s.index == _currentIndex);
    final isOpen = _expandedMenus.contains(label);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
              if (isOpen) {
                _expandedMenus.remove(label);
              } else {
                _expandedMenus.add(label);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10), // Reduced gap
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), // Refined padding
            decoration: BoxDecoration(
              color: _currentIndex == index ? primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _currentIndex == index ? Border.all(color: primaryColor.withOpacity(0.1), width: 0.5) : null,
            ),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                // Selection Pill
                if (_currentIndex == index && isExpanded)
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
                Icon(icon, color: isSelected ? primaryColor : unselectedColor, size: 22), // Refined icon size
                if (isExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13, // Refined font size
                        color: isSelected ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9)) : unselectedColor,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16, // Smaller arrow
                    color: isSelected ? primaryColor : unselectedColor.withOpacity(0.5),
                  ),
                ]
              ],
            ),
          ),
        ),
        if (isOpen && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: subItems.asMap().entries.map((entry) {
                final int i = entry.key;
                final sub = entry.value;
                final bool isLast = i == subItems.length - 1;
                final isSubSelected = _currentIndex == sub.index;

                return IntrinsicHeight(
                  child: Row(
                    children: [
                      // Vertical Tree Line Logic
                      Column(
                        children: [
                          Container(
                            width: 1.0,
                            height: 18, // Height to reach the branch
                            margin: const EdgeInsets.only(left: 10),
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.0,
                                margin: const EdgeInsets.only(left: 10),
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              ),
                            ),
                        ],
                      ),
                      // Horizontal connection line
                      Container(
                        width: 14,
                        height: 1.0,
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      ),
                      
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => _currentIndex = sub.index);
                            if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                              _scaffoldKey.currentState?.closeEndDrawer();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSubSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(sub.icon, size: 16, color: isSubSelected ? primaryColor : unselectedColor.withOpacity(0.7)),
                                const SizedBox(width: 10),
                                Text(
                                  sub.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSubSelected ? (isDark ? Colors.white : Colors.black) : unselectedColor.withOpacity(0.8),
                                    fontWeight: isSubSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
  Widget _sidebarItem(int index, IconData icon, String label, bool isExpanded, bool isDark, {bool hasStatusIndicator = false}) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeEndDrawer();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: primaryColor.withOpacity(0.1), width: 0.5) : null,
        ),
        child: Row(
          mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            // Selection Pill
            if (isSelected && isExpanded)
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
            if (hasStatusIndicator)
              _AnimatedStatusIcon(
                icon: icon,
                size: 22,
                isSelected: isSelected,
                defaultColor: unselectedColor,
                activeColor: primaryColor,
              )
            else
              Icon(icon, color: isSelected ? primaryColor : unselectedColor, size: 22),
            if (isExpanded) ...[
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9)) : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0F1117).withOpacity(0.95) : const Color(0xFFF8FAFC).withOpacity(0.98);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final fixedHeight = 62.0 + (bottomPadding > 0 ? bottomPadding : 0); // Sleek reduced height

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: fixedHeight,
          padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 0, left: 8, right: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              )
            ]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                _bottomNavItem(1, Icons.home_filled, 'Home', isDark),
                _bottomNavItem(23, Icons.dashboard_customize_rounded, 'Overview', isDark),
                _bottomNavItem(3, Icons.business_center_rounded, 'Workplace', isDark),
                _bottomNavItem(5, Icons.chat_bubble_rounded, 'Chat', isDark),
                _bottomNavItem(2, Icons.auto_awesome_motion_rounded, 'Board', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 12, vertical: 8), // Sleeker padding
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(isDark ? 0.2 : 0.12) : Colors.transparent, // Better contrast
          borderRadius: BorderRadius.circular(20), // Modern smaller pill radius
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.05 : 0.95,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack, // Bouncy snappy modern animation
              child: Icon(
                icon,
                color: isSelected ? primaryColor : unselectedColor,
                size: 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: isSelected ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w800, // Extra bold for a highly modern look
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCallDuration() {
    if (CallState.startTime == null) return "Connecting...";
    final duration = DateTime.now().difference(CallState.startTime!);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

class _SubMenuItem {
  final int index;
  final String label;
  final IconData icon;
  _SubMenuItem({required this.index, required this.label, required this.icon});
}

class _AnimatedStatusIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool isSelected;
  final Color defaultColor;
  final Color activeColor;

  const _AnimatedStatusIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.isSelected,
    required this.defaultColor,
    required this.activeColor,
  });

  @override
  State<_AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<_AnimatedStatusIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Once per second
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getFlowColor(double value) {
    // Realistic Premium Color Spectrum
    if (value < 0.2) return const Color(0xFFFF1744); // Deep Crimson
    if (value < 0.4) return const Color(0xFF00C853); // Rich Emerald
    if (value < 0.6) return const Color(0xFFFFD600); // Vivid Gold
    if (value < 0.8) return const Color(0xFF00E5FF); // Electric Cyan
    return const Color(0xFFD500F9); // Deep Magenta
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final flowColor = _getFlowColor(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Realistic Wave 1 (Fast outer ring)
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size * 0.9,
                height: widget.size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: flowColor.withOpacity(_pulseAnimation.value * 0.4),
                    width: 1.0,
                  ),
                ),
              ),
            ),
            // Realistic Wave 2 (Medium pulse)
            Transform.scale(
              scale: _scaleAnimation.value * 0.75,
              child: Container(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: flowColor.withOpacity(_pulseAnimation.value * 0.15),
                ),
              ),
            ),
            // Realistic Wave 3 (Inner core glow)
            Transform.scale(
              scale: _scaleAnimation.value * 0.5,
              child: Container(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: flowColor.withOpacity(_pulseAnimation.value * 0.25),
                  boxShadow: [
                    BoxShadow(
                      color: flowColor.withOpacity(_pulseAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            // Main Icon with premium color flow
            Icon(
              widget.icon,
              size: widget.size,
              color: flowColor,
            ),
          ],
        );
      },
    );
  }
}

// Premium 3D Mac Dot Button — instant click, smooth hover
class _MacDotButton extends StatefulWidget {
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MacDotButton({required this.color, required this.tooltip, required this.onTap});

  @override
  State<_MacDotButton> createState() => _MacDotButtonState();
}

class _MacDotButtonState extends State<_MacDotButton> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _currentScale => _pressed ? 0.82 : _scaleAnim.value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          _ctrl.forward();
        },
        onExit: (_) {
          setState(() { _hovered = false; _pressed = false; });
          _ctrl.reverse();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            setState(() => _pressed = true);
            widget.onTap(); // Fire INSTANTLY on press-down
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _currentScale,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 0.85,
                  colors: [
                    Color.lerp(Colors.white, widget.color, _pressed ? 0.75 : 0.50)!,
                    widget.color,
                    Color.lerp(widget.color, Colors.black, _pressed ? 0.40 : 0.22)!,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_pressed ? 0.9 : (_hovered ? 0.72 : 0.42)),
                    blurRadius: _pressed ? 18 : (_hovered ? 12 : 5),
                    spreadRadius: _pressed ? 2 : (_hovered ? 1 : 0),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated live signal dot — smooth color cycling glow, FIXED size (no layout jitter)
/// Best practice: only animates BoxShadow/color, never changes dimensions
class _LiveSignalDot extends StatefulWidget {
  const _LiveSignalDot();

  @override
  State<_LiveSignalDot> createState() => _LiveSignalDotState();
}

class _LiveSignalDotState extends State<_LiveSignalDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // 6 color stops with last == first for seamless looping
  static const List<Color> _palette = [
    Color(0xFF00E676), // vivid green
    Color(0xFF00BCD4), // cyan
    Color(0xFF7C4DFF), // purple
    Color(0xFFFFAB00), // amber
    Color(0xFFFF5722), // deep orange
    Color(0xFF00E676), // back to green (seamless)
  ];

  @override
  void initState() {
    super.initState();
    // 3 full cycles per second → 333ms period, linear, infinite
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 333),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Interpolates smoothly across the color palette given t in [0, 1)
  Color _colorAt(double t) {
    final segments = _palette.length - 1; // final, not const — runtime value
    final pos = t * segments;
    final idx = pos.floor().clamp(0, segments - 1);
    return Color.lerp(_palette[idx], _palette[idx + 1], pos - idx)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final color = _colorAt(_ctrl.value);
        // Pulse glow intensity slightly with a sine-like pattern
        final glowPulse = 0.7 + 0.3 * (0.5 - (_ctrl.value - 0.5).abs()) * 2;
        return Container(
          width: 7,  // FIXED — never changes
          height: 7, // FIXED — never changes
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              // Inner tight glow
              BoxShadow(
                color: color.withOpacity(0.90 * glowPulse),
                blurRadius: 6,
                spreadRadius: 1,
              ),
              // Outer diffuse halo
              BoxShadow(
                color: color.withOpacity(0.45 * glowPulse),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mouse & touch tracking spotlight divider line
/// The glow spotlight follows cursor/finger along the line in real-time
class _MouseTrackDivider extends StatefulWidget {
  final bool isDark;
  const _MouseTrackDivider({required this.isDark});

  @override
  State<_MouseTrackDivider> createState() => _MouseTrackDividerState();
}

class _MouseTrackDividerState extends State<_MouseTrackDivider>
    with SingleTickerProviderStateMixin {
  double _mouseX = 0.5; // normalized 0.0 → 1.0
  bool _isHovered = false;
  late AnimationController _opacityCtrl;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _opacityCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacityAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _opacityCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _opacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _opacityCtrl.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _opacityCtrl.reverse();
      },
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          setState(() =>
            _mouseX = (event.localPosition.dx / box.size.width).clamp(0.0, 1.0));
        }
      },
      child: GestureDetector(
        onPanUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            setState(() =>
              _mouseX = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0));
          }
        },
        child: AnimatedBuilder(
          animation: _opacityAnim,
          builder: (context, _) {
            return SizedBox(
              height: 8, // generous hit area for touch
              child: CustomPaint(
                painter: _SpotlightLinePainter(
                  mouseX: _mouseX,
                  color: primary,
                  isDark: widget.isDark,
                  intensity: _opacityAnim.value,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpotlightLinePainter extends CustomPainter {
  final double mouseX;
  final Color color;
  final bool isDark;
  final double intensity;

  const _SpotlightLinePainter({
    required this.mouseX,
    required this.color,
    required this.isDark,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final spotX = mouseX * size.width;
    final spotWidth = size.width * 0.28;

    // Base dim line (always visible across full width)
    final basePaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        color.withOpacity(isDark ? 0.10 : 0.07),
        color.withOpacity(isDark ? 0.10 : 0.07),
        Colors.transparent,
      ], stops: const [0.0, 0.15, 0.85, 1.0])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), basePaint);

    // Moving spotlight glow centered at cursor
    final leftEdge = (spotX - spotWidth).clamp(0.0, size.width);
    final rightEdge = (spotX + spotWidth).clamp(0.0, size.width);
    if (rightEdge <= leftEdge) return;

    final spotPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.45 * intensity),
          color.withOpacity(0.95 * intensity),
          color.withOpacity(0.45 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(leftEdge, 0, rightEdge - leftEdge, size.height))
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(leftEdge, y), Offset(rightEdge, y), spotPaint);

    // Bright white core at the cursor tip
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.60 * intensity)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawLine(
      Offset((spotX - 24).clamp(0, size.width), y),
      Offset((spotX + 24).clamp(0, size.width), y),
      corePaint,
    );

    // Extra outer halo for dramatic effect
    final haloPaint = Paint()
      ..color = color.withOpacity(0.18 * intensity)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset((spotX - spotWidth * 0.6).clamp(0, size.width), y),
      Offset((spotX + spotWidth * 0.6).clamp(0, size.width), y),
      haloPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightLinePainter old) =>
      old.mouseX != mouseX || old.intensity != intensity || old.isDark != isDark;
}

/// A premium, static divider for mobile and tablet views.
/// Features a subtle gradient line and a soft ambient shadow for depth.
class _MobileDivider extends StatelessWidget {
  final bool isDark;
  const _MobileDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.25),
            Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.6 : 0.45),
            Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
    );
  }
}

/// Animated branding text — cycles colors every 10 seconds
class _AnimatedBrandingText extends StatefulWidget {
  final bool isDark;
  const _AnimatedBrandingText({required this.isDark});

  @override
  State<_AnimatedBrandingText> createState() => _AnimatedBrandingTextState();
}

class _AnimatedBrandingTextState extends State<_AnimatedBrandingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  // 7 vibrant colors + base color (start/end)
  static const List<Color> _rainbow = [
    Color(0xFF00E676), // Green
    Color(0xFF00BCD4), // Cyan
    Color(0xFF7C4DFF), // Purple
    Color(0xFFFF4081), // Pink
    Color(0xFFFFAB00), // Amber
    Color(0xFFFF5722), // Orange
    Color(0xFF2979FF), // Blue
  ];

  @override
  void initState() {
    super.initState();
    // 10 second cycle: 2s animation, 8s pause
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final double t = _ctrl.value; // 0.0 -> 1.0 (10s)
        Color? currentColor;

        // Wave happens in first 2 seconds (0.0 -> 0.2)
        if (t < 0.2) {
          final double animT = t / 0.2; // 0.0 -> 1.0
          final segments = _rainbow.length - 1;
          final pos = animT * segments;
          final idx = pos.floor().clamp(0, segments - 1);
          currentColor = Color.lerp(_rainbow[idx], _rainbow[idx + 1], pos - idx)!;
        }

        final baseColor = widget.isDark ? Colors.white : Colors.black;
        final baseOpacity = widget.isDark ? 0.75 : 0.70;
        final contrastOpacity = widget.isDark ? 0.40 : 0.45;

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'ebm ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: currentColor != null 
                    ? currentColor.withOpacity(baseOpacity + 0.15) 
                    : baseColor.withOpacity(baseOpacity),
                  letterSpacing: 0.3,
                ),
              ),
              TextSpan(
                text: 'central',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: currentColor != null 
                    ? currentColor.withOpacity(contrastOpacity + 0.15) 
                    : baseColor.withOpacity(contrastOpacity),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
