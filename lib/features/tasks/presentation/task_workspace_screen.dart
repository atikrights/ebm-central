import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

import 'package:universal_html/html.dart' as html; // For Web downloads
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/providers/task_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import 'create_edit_roadmap_step_screen.dart';

class TaskWorkspaceScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskWorkspaceScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskWorkspaceScreen> createState() => _TaskWorkspaceScreenState();
}

class _TaskWorkspaceScreenState extends ConsumerState<TaskWorkspaceScreen> {
  int _selectedIndex = 0;
  bool _isBriefExpanded = false;
  bool _isDetailsExpanded = false;
  bool _isRecordDescExpanded = false;
  bool _isSaving = false;
  final Set<String> _expandedStepIds = {};

  final List<String> _tabNames = ['Overview', 'Records', 'Blueprint', 'Roadmap', 'Trace', 'Settings'];
  final List<IconData> _tabIcons = [
    IconsaxPlusLinear.radar,
    IconsaxPlusLinear.document_text,
    IconsaxPlusLinear.add_circle,
    IconsaxPlusLinear.route_square,
    IconsaxPlusLinear.activity,
    IconsaxPlusLinear.setting_2
  ];

  // Create Task Form Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _startDate;
  DateTime? _endDate;
  final List<SubTask> _subTasks = [];
  final List<RoadmapStep> _roadmapSteps = [];
  final List<TaskDocument> _documents = [];
  final _subTaskTitleCtrl = TextEditingController();
  final _subTaskCostCtrl = TextEditingController();
  final _roadmapStepCtrl = TextEditingController();
  final _roadmapStepDescCtrl = TextEditingController();
  String _roadmapStepPriority = 'Medium';
  final _traceCommentCtrl = TextEditingController();
  String _activeDocTab = 'ALL';
  bool _isDragOver = false;
  final List<String> _docTabs = ['ALL', 'PDF', 'PNG', 'JPG', 'XLS', 'TXT', 'DOC', 'OTHER'];

  String _roadmapSearchQuery = '';
  final _roadmapSearchCtrl = TextEditingController();
  final List<RoadmapStep> _recycledRoadmapSteps = [];

  Future<void> _loadRecycledSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'recycled_steps_${widget.taskId}';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        setState(() {
          _recycledRoadmapSteps.clear();
          _recycledRoadmapSteps.addAll(
            decoded.map((item) => RoadmapStep.fromMap(item as Map<String, dynamic>)),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading recycled steps: $e');
    }
  }

  Future<void> _saveRecycledSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'recycled_steps_${widget.taskId}';
      final data = _recycledRoadmapSteps.map((step) => step.toMap()).toList();
      await prefs.setString(key, json.encode(data));
    } catch (e) {
      debugPrint('Error saving recycled steps: $e');
    }
  }

  bool _isInitialized = false;
  Project? _selectedProject;
  Plan? _selectedPlan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final provider = ref.read(taskProvider);
      final match = provider.allTasks.where((t) => t.id == widget.taskId);
      if (match.isNotEmpty) {
        final task = match.first;
        _titleCtrl.text = task.title;
        _descCtrl.text = task.description;
        _costCtrl.text = task.allocatedCost > 0 ? task.allocatedCost.toStringAsFixed(0) : '';
        _locationCtrl.text = task.location;
        _priority = task.priority;
        _startDate = task.startDate;
        _endDate = task.endDate;
        _subTasks.addAll(task.subTasks);
        _roadmapSteps.addAll(task.roadmapSteps);
        _documents.addAll(task.documents);

        final projects = ref.read(projectProvider).maybeWhen(data: (d) => d, orElse: () => <Project>[]);
        if (task.projectId != null || task.planId != null) {
          for (var proj in projects) {
            if (proj.id == task.projectId) {
              _selectedProject = proj;
            }
            for (var plan in proj.plans) {
              if (plan.id == task.planId) {
                _selectedPlan = plan;
                _selectedProject = proj;
              }
            }
          }
        }
      }
      _isInitialized = true;
      _loadRecycledSteps();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    _locationCtrl.dispose();
    _subTaskTitleCtrl.dispose();
    _subTaskCostCtrl.dispose();
    _roadmapStepCtrl.dispose();
    _roadmapStepDescCtrl.dispose();
    _traceCommentCtrl.dispose();
    _roadmapSearchCtrl.dispose();
    super.dispose();
  }

  static const double _kHeaderH = 54.0;
  static const double _kSidebarW = 240.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(taskProvider);
    final match = provider.allTasks.where((t) => t.id == widget.taskId);
    if (match.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = match.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: Colors.transparent,
              child: _buildSidebar(task, isDark, isDrawer: true),
            )
          : null,
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
                  if (isDesktop) _buildSidebar(task, isDark, isDrawer: false),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: _kHeaderH),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: _buildTabContent(task, isDark),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0, left: 0, right: 0,
                          child: _buildHeader(task, isDark, !isDesktop),
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

  Widget _buildHeader(SystemTask task, bool isDark, bool showMenu) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: _kHeaderH,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1117).withOpacity(0.85)
                  : const Color(0xFFF8FAFC).withOpacity(0.92),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
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
                      _headerIconBtn(Icons.menu_rounded, isDark,
                          () => _scaffoldKey.currentState?.openDrawer()),
                    if (showMenu) const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.taskNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withOpacity(0.85)
                                : Colors.black.withOpacity(0.80),
                          ),
                        ),
                        Text(
                          _tabNames[_selectedIndex],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: isDark
                                ? Colors.white.withOpacity(0.45)
                                : Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headerIconBtn(
                      IconsaxPlusLinear.close_circle,
                      isDark,
                      () => Navigator.pop(context),
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

  Widget _headerIconBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 19,
            color: isDark
                ? Colors.white.withOpacity(0.65)
                : Colors.black.withOpacity(0.60),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(SystemTask task, bool isDark, {required bool isDrawer}) {
    final double width = isDrawer ? 280.0 : _kSidebarW;
    final bgColor = isDark
        ? const Color(0xFF0F1117).withOpacity(0.85)
        : const Color(0xFFF8FAFC).withOpacity(0.92);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isDrawer ? MediaQuery.of(context).padding.top + 24 : 12),

            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.05),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? Colors.white.withOpacity(0.02)
                        : Colors.black.withOpacity(0.01),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 16,
                          color: isDark ? Colors.white60 : Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        'All Tasks',
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

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: List.generate(_tabNames.length, (i) =>
                  _sidebarItem(i, _tabIcons[i], _tabNames[i], isDark,
                      isDrawer: isDrawer)),
              ),
            ),

            // Task identifier card at bottom
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(IconsaxPlusLinear.task_square,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isEmpty ? 'Untitled Task' : task.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          task.taskNumber,
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
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool isDark,
      {bool isDrawer = false}) {
    final isSelected = _selectedIndex == index;
    final primary = AppColors.primary;
    final unselected = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (isDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isSelected ? primary : unselected),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : unselected,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(SystemTask task, bool isDark) {
    final isDark2 = isDark; // keep for tab calls
    final w = MediaQuery.of(context).size.width;
    final pad = w < 768 ? 16.0 : 32.0;
    Widget content;
    switch (_selectedIndex) {
      case 0:
        content = _buildOverviewTab(task, isDark2);
        break;
      case 1:
        content = _buildRecordTab(task, isDark2);
        break;
      case 2:
        content = SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: _buildCreateTaskTab(isDark2),
        );
        break;
      case 3:
        content = SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildRoadmapTab(task, isDark2)],
          ),
        );
        break;
      case 4:
        content = Padding(
          padding: EdgeInsets.all(pad),
          child: _buildTaskTraceTab(task, isDark2),
        );
        break;
      case 5:
        content = SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: _buildSettingsTab(task, isDark2),
        );
        break;
      default:
        content = const SizedBox();
    }
    return KeyedSubtree(
      key: ValueKey(_selectedIndex),
      child: content,
    );
  }

  // ═══════════════════════════════════════════════
  // NEW MENU: RECORD (Premium Layout)
  // ═══════════════════════════════════════════════
  Widget _buildRecordTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    // Dynamic background cover gradient based on priority
    List<Color> gradientColors;
    switch (task.priority) {
      case TaskPriority.critical:
        gradientColors = isDark
            ? [Colors.redAccent.withOpacity(0.4), Colors.orangeAccent.withOpacity(0.1)]
            : [Colors.redAccent.withOpacity(0.15), Colors.orangeAccent.withOpacity(0.05)];
        break;
      case TaskPriority.high:
        gradientColors = isDark
            ? [Colors.orangeAccent.withOpacity(0.4), Colors.amber.withOpacity(0.1)]
            : [Colors.orangeAccent.withOpacity(0.15), Colors.amber.withOpacity(0.05)];
        break;
      case TaskPriority.low:
        gradientColors = isDark
            ? [Colors.teal.withOpacity(0.4), Colors.blueGrey.withOpacity(0.1)]
            : [Colors.teal.withOpacity(0.15), Colors.blueGrey.withOpacity(0.05)];
        break;
      default:
        gradientColors = isDark
            ? [AppColors.primary.withOpacity(0.4), AppColors.secondary.withOpacity(0.1)]
            : [AppColors.primary.withOpacity(0.15), AppColors.secondary.withOpacity(0.05)];
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final isMobile = constraints.maxWidth <= 600;

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HERO: Task Identity Banner (Mirroring Company Records) ──
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Photo Gradient
                  Container(
                    height: isMobile ? 120 : 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          top: -20,
                          child: Icon(IconsaxPlusLinear.task_square,
                              size: 180,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)),
                        ),
                      ],
                    ),
                  ),

                  // Profile/Task Identity Row
                  Transform.translate(
                    offset: const Offset(0, -35),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Logo/Avatar representing task
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Container(
                                  width: isMobile ? 65 : 85,
                                  height: isMobile ? 65 : 85,
                                  decoration: BoxDecoration(
                                    color: _priorityColor(task.priority).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    IconsaxPlusLinear.task_square,
                                    color: _priorityColor(task.priority),
                                    size: isMobile ? 32 : 42,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Identity Details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title.isEmpty ? 'Untitled Task' : task.title,
                                        style: TextStyle(
                                          fontSize: isMobile ? 18 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          // Copyable UID Chip
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: task.taskNumber));
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Text('UID Copied: ${task.taskNumber}'),
                                                backgroundColor: AppColors.primary,
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 1),
                                                margin: const EdgeInsets.all(16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ));
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(IconsaxPlusLinear.copy, size: 12, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    task.taskNumber,
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusColor(task.status).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _statusLabel(task.status),
                                              style: TextStyle(
                                                color: _statusColor(task.status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
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

                          const SizedBox(height: 24),

                          // Description Section with _buildExpandableText
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SCOPE & DESCRIPTION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: _priorityColor(task.priority).withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildExpandableText(
                                text: task.description.isNotEmpty
                                    ? task.description
                                    : 'No description or scope of work has been detailed for this task.',
                                wordLimit: 40,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  height: 1.6,
                                ),
                                isExpanded: _isRecordDescExpanded,
                                onToggle: () => setState(() => _isRecordDescExpanded = !_isRecordDescExpanded),
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

            // ── ACTIONS PANEL (Export ZIP, etc.) ──
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Export Asset Bundle (ZIP)',
                      icon: IconsaxPlusLinear.document_download,
                      color: AppColors.primary,
                      isFullWidth: true,
                      onTap: () => _simulateZipExport(context, task),
                    ),
                  ),
                ],
              ),
            ),

            // ── GRID LAYOUT (Desktop vs Mobile/Tablet) ──
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _buildTaskDetailsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildTimelineSection(task, isDark, textColor, subColor, cardColor, borderColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildFinancialSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildAssetsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildTraceLogsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildTaskDetailsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildTimelineSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildFinancialSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildAssetsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildTraceLogsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _buildRecordSpecsCard(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(IconsaxPlusLinear.info_circle, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'SPECIFICATIONS',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _recordDetailRow('Priority Level', task.priority.name.toUpperCase(), isDark, valueColor: _priorityColor(task.priority), isBoldValue: true),
          _recordDetailRow('Task Location', task.location.isNotEmpty ? task.location : 'Not Specified', isDark, isLast: true),
        ],
      ),
    );
  }

  Widget _buildRecordBudgetCard(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    final totalBudget = task.allocatedCost + task.totalSubTaskCost;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(IconsaxPlusLinear.wallet, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'BUDGET OVERVIEW',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _recordDetailRow('Task Base Cost', '\$${task.allocatedCost.toStringAsFixed(2)}', isDark, isMonospace: true),
          _recordDetailRow('Sub-Tasks Cost', '\$${task.totalSubTaskCost.toStringAsFixed(2)}', isDark, isMonospace: true),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _recordDetailRow('Total Task Budget', '\$${totalBudget.toStringAsFixed(2)}', isDark, isMonospace: true, isLast: true, isBoldValue: true, valueColor: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildRecordDocumentsSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(IconsaxPlusLinear.document_upload, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'ATTACHED DOCUMENTS',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (task.documents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No documents uploaded for this task.',
                  style: TextStyle(fontSize: 12, color: subColor, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...task.documents.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _docColor(d.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_docIcon(d.type), size: 16, color: _docColor(d.type)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${d.type.toUpperCase()} • ${_formatDate(d.uploadedAt)}',
                          style: TextStyle(fontSize: 9, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(IconsaxPlusLinear.export_1, size: 14, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Downloading ${d.name}...'),
                        duration: const Duration(seconds: 1),
                      ));
                    },
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ═══════════════════════════════════════════════
  Widget _buildOverviewTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    // Dynamic background cover gradient based on priority
    List<Color> gradientColors;
    switch (task.priority) {
      case TaskPriority.critical:
        gradientColors = isDark
            ? [Colors.redAccent.withOpacity(0.4), Colors.orangeAccent.withOpacity(0.1)]
            : [Colors.redAccent.withOpacity(0.15), Colors.orangeAccent.withOpacity(0.05)];
        break;
      case TaskPriority.high:
        gradientColors = isDark
            ? [Colors.orangeAccent.withOpacity(0.4), Colors.amber.withOpacity(0.1)]
            : [Colors.orangeAccent.withOpacity(0.15), Colors.amber.withOpacity(0.05)];
        break;
      case TaskPriority.low:
        gradientColors = isDark
            ? [Colors.teal.withOpacity(0.4), Colors.blueGrey.withOpacity(0.1)]
            : [Colors.teal.withOpacity(0.15), Colors.blueGrey.withOpacity(0.05)];
        break;
      default:
        gradientColors = isDark
            ? [AppColors.primary.withOpacity(0.4), AppColors.secondary.withOpacity(0.1)]
            : [AppColors.primary.withOpacity(0.15), AppColors.secondary.withOpacity(0.05)];
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final isMobile = constraints.maxWidth <= 600;

      // Outer layout
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HERO: Task Identity Banner (Mirroring Company Records) ──
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Photo Gradient
                  Container(
                    height: isMobile ? 120 : 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          top: -20,
                          child: Icon(IconsaxPlusLinear.task_square,
                              size: 180,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)),
                        ),
                      ],
                    ),
                  ),

                  // Profile/Task Identity Row
                  Transform.translate(
                    offset: const Offset(0, -35),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Logo/Avatar representing task
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Container(
                                  width: isMobile ? 65 : 85,
                                  height: isMobile ? 65 : 85,
                                  decoration: BoxDecoration(
                                    color: _priorityColor(task.priority).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    IconsaxPlusLinear.task_square,
                                    color: _priorityColor(task.priority),
                                    size: isMobile ? 32 : 42,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Identity Details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title.isEmpty ? 'Untitled Task' : task.title,
                                        style: TextStyle(
                                          fontSize: isMobile ? 18 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          // Copyable UID Chip
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: task.taskNumber));
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Text('UID Copied: ${task.taskNumber}'),
                                                backgroundColor: AppColors.primary,
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 1),
                                                margin: const EdgeInsets.all(16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ));
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(IconsaxPlusLinear.copy, size: 12, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    task.taskNumber,
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusColor(task.status).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _statusLabel(task.status),
                                              style: TextStyle(
                                                color: _statusColor(task.status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
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

                          const SizedBox(height: 24),

                          // Description Section with _buildExpandableText
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SCOPE & DESCRIPTION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: _priorityColor(task.priority).withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildExpandableText(
                                text: task.description.isNotEmpty
                                    ? task.description
                                    : 'No description or scope of work has been detailed for this task.',
                                wordLimit: 40,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
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

            _buildOverviewAnalysisCards(task, isDark, constraints.maxWidth),

            // ── ACTIONS PANEL (Export ZIP, etc.) ──
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Export Asset Bundle (ZIP)',
                      icon: IconsaxPlusLinear.document_download,
                      color: AppColors.primary,
                      isFullWidth: true,
                      onTap: () => _simulateZipExport(context, task),
                    ),
                  ),
                ],
              ),
            ),

            // ── GRID LAYOUT (Desktop vs Mobile/Tablet) ──
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _buildTaskDetailsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildTimelineSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildRoadmapSection(task, isDark, textColor, subColor, cardColor, borderColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildFinancialSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildAssetsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                        const SizedBox(height: 20),
                        _buildTraceLogsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildTaskDetailsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildTimelineSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildFinancialSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildRoadmapSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildAssetsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                  const SizedBox(height: 20),
                  _buildTraceLogsSection(task, isDark, textColor, subColor, cardColor, borderColor),
                ],
              ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
    });
  }

  // Details Widget
  Widget _buildTaskDetailsSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return _recordOverviewCard(
      isDark: isDark,
      title: 'Task Specifications',
      icon: IconsaxPlusLinear.info_circle,
      children: [
        _recordDetailRow('Priority Level', task.priority.name.toUpperCase(), isDark, valueColor: _priorityColor(task.priority), isBoldValue: true),
        _recordDetailRow('Author / Creator', task.author.isNotEmpty ? task.author : 'Admin', isDark),
        _recordDetailRow('Assignee', task.assignee.isNotEmpty ? task.assignee : 'Unassigned', isDark),
        _recordDetailRow('Global Location', task.location.isNotEmpty ? task.location : 'Not Specified', isDark, isLast: true),
        if (_selectedProject != null || _selectedPlan != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'ASSOCIATIONS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedProject != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(IconsaxPlusLinear.folder_open, size: 12, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Project: ${_selectedProject!.name}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (_selectedPlan != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(IconsaxPlusLinear.task_square, size: 12, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Plan: ${_selectedPlan!.title}',
                        style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // Timeline Widget
  Widget _buildTimelineSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    String countdown = 'Not Scheduled';
    if (task.startDate != null && task.endDate != null) {
      final now = DateTime.now();
      if (now.isAfter(task.endDate!)) {
        countdown = 'Ended';
      } else if (now.isBefore(task.startDate!)) {
        final diff = task.startDate!.difference(now).inDays;
        countdown = 'Starts in $diff day${diff == 1 ? '' : 's'}';
      } else {
        final diff = task.endDate!.difference(now).inDays;
        countdown = '$diff day${diff == 1 ? '' : 's'} remaining';
      }
    }

    return _recordOverviewCard(
      isDark: isDark,
      title: 'Operational Schedule',
      icon: IconsaxPlusLinear.calendar,
      children: [
        Row(
          children: [
            Expanded(
              child: _recordDateBlock(
                label: 'Initiation Date',
                date: task.startDate,
                icon: IconsaxPlusLinear.calendar_1,
                color: AppColors.primary,
                isDark: isDark,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
            Container(
              width: 1,
              height: 48,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(
              child: _recordDateBlock(
                label: 'Target Completion',
                date: task.endDate,
                icon: IconsaxPlusLinear.timer_1,
                color: Colors.orangeAccent,
                isDark: isDark,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
          ],
        ),
        if (task.startDate != null && task.endDate != null) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Timeline Status Score',
                style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  countdown.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }

  // Financial Widget
  Widget _buildFinancialSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return _recordOverviewCard(
      isDark: isDark,
      title: 'Commercial Ledger',
      icon: IconsaxPlusLinear.wallet,
      children: [
        _recordDetailRow('Basic Allocation', '\$${task.allocatedCost.toStringAsFixed(2)}', isDark, isMonospace: true),
        _recordDetailRow('Sub-Tasks Overhead', '\$${task.totalSubTaskCost.toStringAsFixed(2)}', isDark, isMonospace: true),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        _recordDetailRow('Total Net Budget', '\$${task.grandTotal.toStringAsFixed(2)}', isDark, isMonospace: true, isLast: true, isBoldValue: true, valueColor: AppColors.success),
        if (task.subTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'ACTIVE SUB-TASKS OVERHEADS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 10),
          ...task.subTasks.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  s.isCompleted ? IconsaxPlusLinear.tick_circle : IconsaxPlusLinear.record_circle,
                  size: 16,
                  color: s.isCompleted ? AppColors.success : subColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight: s.isCompleted ? FontWeight.normal : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${s.additionalCost.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
              ],
            ),
          )),
        ]
      ],
    );
  }

  // Roadmap Widget
  Widget _buildRoadmapSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    if (task.roadmapSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    return _recordOverviewCard(
      isDark: isDark,
      title: 'Strategic Roadmap Steps',
      icon: IconsaxPlusLinear.routing,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: task.roadmapSteps.length,
          itemBuilder: (context, i) {
            final step = task.roadmapSteps[i];
            final isLast = i == task.roadmapSteps.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step marker
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: step.isCompleted ? AppColors.success.withOpacity(0.12) : AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: step.isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Center(
                          child: step.isCompleted
                              ? const Icon(Icons.check, size: 12, color: AppColors.success)
                              : Text(
                                  '${i + 1}',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: step.isCompleted ? AppColors.success.withOpacity(0.3) : borderColor,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Step Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                          if (step.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildRoadmapStepDescription(step.description, step.id, isDark),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Assets Widget
  Widget _buildAssetsSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    if (task.documents.isEmpty) {
      return const SizedBox.shrink();
    }

    return _recordOverviewCard(
      isDark: isDark,
      title: 'Authenticated Assets',
      icon: IconsaxPlusLinear.document_upload,
      children: [
        ...task.documents.map((d) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _docColor(d.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_docIcon(d.type), size: 16, color: _docColor(d.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${d.type.toUpperCase()} • ${_formatDate(d.uploadedAt)}',
                      style: TextStyle(fontSize: 9, color: subColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(IconsaxPlusLinear.export_1, size: 14, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Downloading ${d.name}...'),
                    duration: const Duration(seconds: 1),
                  ));
                },
              ),
            ],
          ),
        )),
      ],
    );
  }

  // Trace Logs Widget
  Widget _buildTraceLogsSection(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return _recordOverviewCard(
      isDark: isDark,
      title: 'Recent Activity Logs',
      icon: IconsaxPlusLinear.activity,
      children: [
        if (task.comments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No activity trace logs recorded.',
                style: TextStyle(fontSize: 12, color: subColor, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ...task.comments.take(4).map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.primaries[c.author.hashCode % Colors.primaries.length].withOpacity(0.15),
                  child: Text(
                    c.author.isNotEmpty ? c.author[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: Colors.primaries[c.author.hashCode % Colors.primaries.length],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            c.author,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          Text(
                            _formatDate(c.createdAt),
                            style: TextStyle(fontSize: 8, color: subColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.content,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  // Record Card Helper
  Widget _recordOverviewCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Record Detail Row Helper
  Widget _recordDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isLast = false,
    bool isBoldValue = false,
    bool isMonospace = false,
    Color? valueColor,
  }) {
    final subTextColor = isDark ? Colors.white38 : Colors.black38;
    final valueTextColor = valueColor ?? (isDark ? Colors.white70 : Colors.black87);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
              fontFamily: isMonospace ? 'Courier New' : null,
              color: valueTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // Record Date Block Helper
  Widget _recordDateBlock({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          date != null ? _formatDate(date) : 'Unscheduled',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
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
              color: AppColors.primary,
              fontSize: (style.fontSize ?? 14) - 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapStepDescription(String text, String stepId, bool isDark) {
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final style = TextStyle(
      color: subColor,
      fontSize: 12.5,
      height: 1.3,
    );
    final words = text.split(RegExp(r'\s+'));
    const int wordLimit = 40; // Same as records page
    if (words.length <= wordLimit) {
      return Text(text, style: style);
    }

    final isExpanded = _expandedStepIds.contains(stepId);
    final displayText = isExpanded ? text : '${words.take(wordLimit).join(' ')}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: style),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedStepIds.remove(stepId);
              } else {
                _expandedStepIds.add(stepId);
              }
            });
          },
          child: Text(
            isExpanded ? 'Collapse' : 'See more',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // TAB 1: CREATE TASK (Full Enterprise Form)
  // ═══════════════════════════════════════════════
  Widget _buildCreateTaskTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);

    InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: subColor, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Create New Task', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text('Fill in all details to register a master task', style: TextStyle(color: subColor, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTask,
              icon: _isSaving 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(IconsaxPlusLinear.tick_circle, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── SECTION 1: Basic Info ──
          _sectionHeader('Basic Information', IconsaxPlusLinear.info_circle, textColor),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleCtrl,
            style: TextStyle(color: textColor),
            decoration: _fieldDeco('Task Title *', IconsaxPlusLinear.task_square),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: _fieldDeco('Description / Scope of Work', IconsaxPlusLinear.document_text),
          ),
          const SizedBox(height: 12),
          _buildPlanSelector(isDark, textColor, subColor, fillColor),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 400;
            final fields = [
              Expanded(
                child: DropdownButtonFormField<TaskPriority>(
                  value: _priority,
                  dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  decoration: _fieldDeco('Priority Level', IconsaxPlusLinear.radar),
                  items: TaskPriority.values.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name.toUpperCase(), style: TextStyle(color: _priorityColor(p), fontWeight: FontWeight.bold, fontSize: 13)),
                  )).toList(),
                  onChanged: (v) { if (v != null) setState(() => _priority = v); },
                ),
              ),
              SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
              Expanded(
                child: TextFormField(
                  controller: _locationCtrl,
                  style: TextStyle(color: textColor),
                  decoration: _fieldDeco('Task Location', IconsaxPlusLinear.location),
                ),
              ),
            ];
            return isWide
                ? Row(children: fields)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
          }),
          const SizedBox(height: 28),

          // ── SECTION 2: Timeline ──
          _sectionHeader('Timeline & Schedule', IconsaxPlusLinear.calendar_1, textColor),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 400;
            return isWide
              ? Row(children: [
                  Expanded(child: _dateButton(isDark, 'Start Date & Time', _startDate, (d) => setState(() => _startDate = d), textColor, subColor)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateButton(isDark, 'End Date & Time', _endDate, (d) => setState(() => _endDate = d), textColor, subColor)),
                ])
              : Column(children: [
                  _dateButton(isDark, 'Start Date & Time', _startDate, (d) => setState(() => _startDate = d), textColor, subColor),
                  const SizedBox(height: 12),
                  _dateButton(isDark, 'End Date & Time', _endDate, (d) => setState(() => _endDate = d), textColor, subColor),
                ]);
          }),
          const SizedBox(height: 28),

          // ── SECTION 3: Financial ──
          _sectionHeader('Financial Allocation', IconsaxPlusLinear.wallet_1, textColor),
          const SizedBox(height: 12),
          TextFormField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: _fieldDeco('Base Task Cost (\$)', IconsaxPlusLinear.money_2),
          ),
          const SizedBox(height: 16),
          // Sub-Tasks
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Sub-Tasks & Additional Costs', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () => _showAddSubTaskDialog(isDark),
              icon: const Icon(IconsaxPlusLinear.add_circle, size: 16, color: AppColors.primary),
              label: const Text('Add Sub-Task', style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ]),
          if (_subTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
              child: Center(child: Text('No sub-tasks added yet.', style: TextStyle(color: subColor, fontSize: 13))),
            )
          else
            ...List.generate(_subTasks.length, (i) {
              final s = _subTasks[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Row(children: [
                  const Icon(IconsaxPlusLinear.record_circle, size: 16, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.title, style: TextStyle(color: textColor, fontSize: 13))),
                  Text('\$${s.additionalCost.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  InkWell(onTap: () => setState(() => _subTasks.removeAt(i)), child: const Icon(IconsaxPlusLinear.close_circle, size: 16, color: Colors.redAccent)),
                ]),
              );
            }),
          if (_subTasks.isNotEmpty) ...[ const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Sub-Task Total: \$${_subTasks.fold(0.0, (s, t) => s + t.additionalCost).toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            )),
          ],
          const SizedBox(height: 28),

          // ── SECTION 4: Documents & Files ──
          _sectionHeader('Documents & Files', IconsaxPlusLinear.document_upload, textColor),
          const SizedBox(height: 16),

          // File Type Tab Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _docTabs.map((tab) {
                final isActive = _activeDocTab == tab;
                final count = tab == 'ALL' ? _documents.length : _documents.where((d) => d.type == tab.toLowerCase()).length;
                return GestureDetector(
                  onTap: () => setState(() => _activeDocTab = tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : fillColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isActive ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12)),
                    ),
                    child: Row(children: [
                      Icon(_docIcon(tab), size: 13, color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54)),
                      const SizedBox(width: 6),
                      Text(tab, style: TextStyle(color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold, fontSize: 12)),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: isActive ? Colors.white.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('$count', style: TextStyle(color: isActive ? Colors.white : AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Drag & Drop Upload Zone
          DragTarget<List<String>>(
            onWillAcceptWithDetails: (_) { setState(() => _isDragOver = true); return true; },
            onLeave: (_) => setState(() => _isDragOver = false),
            onAcceptWithDetails: (_) => setState(() => _isDragOver = false),
            builder: (ctx, candidateData, rejectedData) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: _isDragOver ? AppColors.primary.withValues(alpha: 0.08) : fillColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDragOver ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                  width: _isDragOver ? 2 : 1,
                ),
              ),
              child: Column(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _isDragOver ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, v, _) => Transform.scale(
                    scale: 1.0 + v * 0.08,
                    child: Icon(
                      _isDragOver ? IconsaxPlusLinear.document_download : IconsaxPlusLinear.document_upload,
                      size: 40, color: _isDragOver ? AppColors.primary : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isDragOver ? 'Drop to upload file...' : 'Drag & Drop files here',
                  style: TextStyle(color: _isDragOver ? AppColors.primary : subColor, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('or', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  _uploadChipBtn('Browse Files', IconsaxPlusLinear.folder_open, isDark, () => _pickFiles(null)),
                  ..._docTabs.skip(1).map((t) => _uploadChipBtn(t, _docIcon(t), isDark, () => _pickFiles(t))).toList(),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Filtered Document List
          Builder(builder: (context) {
            final filtered = _activeDocTab == 'ALL'
                ? _documents
                : _documents.where((d) => d.type == _activeDocTab.toLowerCase()).toList();
            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Center(child: Text(_activeDocTab == 'ALL' ? 'No files uploaded yet.' : 'No ${_activeDocTab} files found.', style: TextStyle(color: subColor, fontSize: 13))),
              );
            }
            return Column(
              children: filtered.asMap().entries.map((e) {
                final d = e.value;
                final globalIdx = _documents.indexOf(d);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(children: [
                    // File type icon + badge
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: _docColor(d.type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_docIcon(d.type.toUpperCase()), size: 18, color: _docColor(d.type)),
                        Text(d.type.toUpperCase(), style: TextStyle(color: _docColor(d.type), fontSize: 7, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text('${d.type.toUpperCase()} · ${_formatDate(d.uploadedAt)}', style: TextStyle(color: subColor, fontSize: 11)),
                    ])),
                    // Export button
                    InkWell(
                      onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exporting ${d.name}...'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(padding: const EdgeInsets.all(8), child: Icon(IconsaxPlusLinear.export_2, size: 16, color: AppColors.primary.withValues(alpha: 0.8))),
                    ),
                    // Remove button
                    InkWell(
                      onTap: () => setState(() => _documents.removeAt(globalIdx)),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(IconsaxPlusLinear.close_circle, size: 16, color: Colors.redAccent)),
                    ),
                  ]),
                ).animate().fade(delay: (e.key * 40).ms).slideX(begin: 0.05, end: 0);
              }).toList(),
            );
          }),
          const SizedBox(height: 40),

          // Save Button (bottom)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTask,
              icon: _isSaving 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(IconsaxPlusLinear.tick_circle),
              label: Text(_isSaving ? 'Saving...' : 'Save & Register Task', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════
  // TAB 2: ROADMAP VIEW
  // ═══════════════════════════════════════════════
  /// Generate a step code in the format STP-TASKNUM-N
  /// e.g. task.taskNumber = 'TSK-123456' → 'STP-123456-1'
  String _generateStepCode(SystemTask task) {
    final base = task.taskNumber.replaceAll('TSK-', '').replaceAll('STP-', '');
    final n = task.roadmapSteps.length + 1;
    return 'STP-$base-$n';
  }

  void _addRoadmapStepCustom({
    required SystemTask task,
    required String title,
    required String description,
    required String priority,
    required DateTime? startTime,
    required DateTime? endTime,
    required bool isLocked,
  }) async {
    final newCode = _generateStepCode(task);
    final newStep = RoadmapStep(
      id: newCode,
      title: title,
      description: description,
      status: 'Process',
      priority: priority,
      startTime: startTime,
      endTime: endTime,
      isLocked: isLocked,
    );
    final updatedSteps = List<RoadmapStep>.from(task.roadmapSteps)..add(newStep);
    final updatedTask = task.copyWith(roadmapSteps: updatedSteps);

    try {
      await ref.read(taskProvider).updateTask(updatedTask);
      setState(() {
        _roadmapSteps.clear();
        _roadmapSteps.addAll(updatedSteps);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Step "$title" added successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Sync failed: ${e.toString().replaceAll('ApiException(500): ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      rethrow;
    }
  }

  void _editRoadmapStep({
    required SystemTask task,
    required int index,
    required String title,
    required String description,
    required String priority,
    required DateTime? startTime,
    required DateTime? endTime,
    required bool isLocked,
  }) async {
    final stepToEdit = task.roadmapSteps[index];
    final updatedStep = stepToEdit.copyWith(
      title: title,
      description: description,
      priority: priority,
      startTime: startTime,
      endTime: endTime,
      isLocked: isLocked,
    );
    final updatedSteps = List<RoadmapStep>.from(task.roadmapSteps)..[index] = updatedStep;
    final updatedTask = task.copyWith(roadmapSteps: updatedSteps);

    try {
      await ref.read(taskProvider).updateTask(updatedTask);
      setState(() {
        _roadmapSteps.clear();
        _roadmapSteps.addAll(updatedSteps);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Step "$title" updated successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Sync failed: ${e.toString().replaceAll('ApiException(500): ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      rethrow;
    }
  }

  void _deleteRoadmapStep(SystemTask task, int index) async {
    final step = task.roadmapSteps[index];
    final stepTitle = step.title;
    final updatedSteps = List<RoadmapStep>.from(task.roadmapSteps)..removeAt(index);
    final updatedTask = task.copyWith(roadmapSteps: updatedSteps);

    try {
      await ref.read(taskProvider).updateTask(updatedTask);
      setState(() {
        _roadmapSteps.clear();
        _roadmapSteps.addAll(updatedSteps);
        _recycledRoadmapSteps.add(step);
      });
      await _saveRecycledSteps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Step "$stepTitle" moved to Recycle Bin.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Sync failed: ${e.toString().replaceAll('ApiException(500): ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, SystemTask task, int index) {
    final step = task.roadmapSteps[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text('Delete Step', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text('Are you sure you want to delete step "${step.title}"?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRoadmapStep(task, index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditRoadmapStepDialog(BuildContext context, SystemTask task, int index, RoadmapStep step, bool isDark) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditRoadmapStepScreen(
          step: step,
          taskNumber: task.taskNumber,
          stepIndex: index,
          isParentArchived: task.isArchived,
          onSave: ({
            required String title,
            required String description,
            required String priority,
            required DateTime? startTime,
            required DateTime? endTime,
            required bool isLocked,
          }) async {
            _editRoadmapStep(
              task: task,
              index: index,
              title: title,
              description: description,
              priority: priority,
              startTime: startTime,
              endTime: endTime,
              isLocked: isLocked,
            );
          },
        ),
      ),
    );
  }

  void _showStepRecycleBinDialog(BuildContext context, SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final dialogBg = isDark ? AppColors.darkSurface : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              ),
            ),
            title: Row(
              children: [
                const Icon(IconsaxPlusLinear.trash, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Roadmap Recycle Bin',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
            content: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 300),
              child: _recycledRoadmapSteps.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Icon(
                          IconsaxPlusLinear.trash,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recycled roadmap steps',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _recycledRoadmapSteps.length,
                      itemBuilder: (itemCtx, idx) {
                        final step = _recycledRoadmapSteps[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            step.title,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            step.id,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Restore
                              IconButton(
                                icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.greenAccent, size: 18),
                                onPressed: () async {
                                  final updatedSteps = List<RoadmapStep>.from(task.roadmapSteps)..add(step);
                                  final updatedTask = task.copyWith(roadmapSteps: updatedSteps);
                                  try {
                                    await ref.read(taskProvider).updateTask(updatedTask);
                                    setState(() {
                                      _roadmapSteps.clear();
                                      _roadmapSteps.addAll(updatedSteps);
                                      _recycledRoadmapSteps.removeAt(idx);
                                    });
                                    await _saveRecycledSteps();
                                    setDialogState(() {});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('✅ Step "${step.title}" restored.'),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('❌ Restoration failed: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ));
                                    }
                                  }
                                },
                              ),
                              // Delete permanently
                              IconButton(
                                icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  setState(() {
                                    _recycledRoadmapSteps.removeAt(idx);
                                  });
                                  await _saveRecycledSteps();
                                  setDialogState(() {});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Permanently deleted.'),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cycleRoadmapStepStatus(SystemTask task, int index) async {
    final step = task.roadmapSteps[index];
    if (step.isLocked && !task.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⚠️ This execution step is locked. Make this session Private/Draft to update.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    final String nextStatus;
    switch (step.status) {
      case 'Process':
        nextStatus = 'Complete';
        break;
      case 'Complete':
        nextStatus = 'Hold';
        break;
      case 'Hold':
      default:
        nextStatus = 'Process';
        break;
    }
    final updatedSteps = task.roadmapSteps.asMap().entries.map((entry) {
      if (entry.key == index) {
        return entry.value.copyWith(status: nextStatus);
      }
      return entry.value;
    }).toList();

    final updatedTask = task.copyWith(roadmapSteps: updatedSteps);
    try {
      await ref.read(taskProvider).updateTask(updatedTask);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Step status → $nextStatus'),
          backgroundColor: _stepStatusColor(nextStatus),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Sync failed: ${e.toString().replaceAll('ApiException(500): ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Color _stepStatusColor(String status) {
    switch (status) {
      case 'Complete': return const Color(0xFF10B981);
      case 'Process': return const Color(0xFF6366F1);
      case 'Hold': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6366F1);
    }
  }

  IconData _stepStatusIcon(String status) {
    switch (status) {
      case 'Complete': return Icons.check;
      case 'Process': return Icons.play_arrow_rounded;
      case 'Hold': return Icons.pause;
      default: return Icons.play_arrow_rounded;
    }
  }

  Color _stepPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical': return const Color(0xFFEF4444);
      case 'high': return const Color(0xFFF97316);
      case 'medium': return const Color(0xFF3B82F6);
      case 'low': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF3B82F6);
    }
  }

  Widget _buildRoadmapTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03);

    final totalSteps = task.roadmapSteps.length;
    final completedSteps = task.roadmapSteps.where((s) => s.isCompleted).length;
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

    final filteredSteps = task.roadmapSteps.where((step) {
      if (_roadmapSearchQuery.isEmpty) return true;
      final q = _roadmapSearchQuery.toLowerCase();
      return step.title.toLowerCase().contains(q) ||
          step.description.toLowerCase().contains(q) ||
          step.id.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Execution Roadmap', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text('Step-by-step execution policy for this task', style: TextStyle(color: subColor, fontSize: 13)),
          const SizedBox(height: 24),

          // Search and action row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _roadmapSearchCtrl,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (val) {
                    setState(() {
                      _roadmapSearchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search execution steps...',
                    hintStyle: TextStyle(color: subColor, fontSize: 13),
                    prefixIcon: Icon(IconsaxPlusLinear.search_normal, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Recycle Bin Icon with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      IconsaxPlusLinear.trash,
                      color: _recycledRoadmapSteps.isEmpty ? subColor : Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _showStepRecycleBinDialog(context, task, isDark),
                    tooltip: 'Recycle Bin',
                  ),
                  if (_recycledRoadmapSteps.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_recycledRoadmapSteps.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Create Step Button
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEditRoadmapStepScreen(
                        taskNumber: task.taskNumber,
                        stepIndex: task.roadmapSteps.length,
                        isParentArchived: task.isArchived,
                        onSave: ({
                          required String title,
                          required String description,
                          required String priority,
                          required DateTime? startTime,
                          required DateTime? endTime,
                          required bool isLocked,
                        }) async {
                          _addRoadmapStepCustom(
                            task: task,
                            title: title,
                            description: description,
                            priority: priority,
                            startTime: startTime,
                            endTime: endTime,
                            isLocked: isLocked,
                          );
                        },
                      ),
                    ),
                  );
                },
                tooltip: 'Create Execution Step',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Card
          if (totalSteps > 0)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.primary.withValues(alpha: 0.15), Colors.purple.withValues(alpha: 0.05)]
                      : [AppColors.primary.withValues(alpha: 0.05), Colors.purple.withValues(alpha: 0.02)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roadmap Progress', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('$completedSteps of $totalSteps steps completed (${(progress * 100).toInt()}%)', style: TextStyle(color: subColor, fontSize: 11)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      Icon(
                        progress >= 1.0 ? IconsaxPlusLinear.tick_circle : IconsaxPlusLinear.route_square,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: -0.1, end: 0),

          if (totalSteps == 0)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(IconsaxPlusLinear.route_square, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text('No roadmap steps defined.', style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Click the "+" button to add execution steps.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12)),
                ],
              ),
            )
          else if (filteredSteps.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(IconsaxPlusLinear.search_status, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text('No matching execution steps found.', style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Try refining your search keyword.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12)),
                ],
              ),
            )
          else
            ...filteredSteps.map((step) {
              final originalIndex = task.roadmapSteps.indexOf(step);
              final stepStatusColor = _stepStatusColor(step.status);
              final stepStatusIcon = _stepStatusIcon(step.status);
              final isComplete = step.status == 'Complete';
              final isHold = step.status == 'Hold';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF10B981).withValues(alpha: 0.04)
                        : isHold
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.03)
                            : fillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isComplete
                          ? const Color(0xFF10B981).withValues(alpha: 0.25)
                          : isHold
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                              : isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      width: isComplete || isHold ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // ── 3-State Status Indicator ──────────────────────────
                      Tooltip(
                        message: 'Status: ${step.status} (tap to cycle)',
                        child: GestureDetector(
                          onTap: () => _cycleRoadmapStepStatus(task, originalIndex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? const Color(0xFF10B981)
                                  : stepStatusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: stepStatusColor,
                                width: 1.8,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                stepStatusIcon,
                                size: 14,
                                color: isComplete ? Colors.white : stepStatusColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Step Code & Title & Description ──────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // STP- step code chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: stepStatusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    step.id.startsWith('STP-') ? step.id : 'STP-${task.taskNumber.replaceAll('TSK-', '')}-${originalIndex + 1}',
                                    style: TextStyle(
                                      color: stepStatusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Courier New',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Priority text badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _stepPriorityColor(step.priority).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _stepPriorityColor(step.priority).withValues(alpha: 0.2), width: 0.5),
                                  ),
                                  child: Text(
                                    step.priority.toUpperCase(),
                                    style: TextStyle(
                                      color: _stepPriorityColor(step.priority),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Status text badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: stepStatusColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    step.status.toUpperCase(),
                                    style: TextStyle(
                                      color: stepStatusColor,
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: TextStyle(
                                      color: isComplete
                                          ? textColor.withValues(alpha: 0.45)
                                          : textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      decoration: isComplete ? TextDecoration.lineThrough : null,
                                      decorationColor: textColor.withValues(alpha: 0.4),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (step.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildRoadmapStepDescription(step.description, step.id, isDark),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ── Actions (Edit & Delete) ───────────────────────────
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(IconsaxPlusLinear.edit, size: 15, color: AppColors.primary.withValues(alpha: 0.8)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditRoadmapStepDialog(context, task, originalIndex, step, isDark),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(IconsaxPlusLinear.close_circle, size: 15, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showDeleteConfirmDialog(context, task, originalIndex),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════
  // TAB 3: SETTINGS
  // ═══════════════════════════════════════════════
  Widget _buildSettingsTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Task Core Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 8),
        Text('Manage task metadata and configurations', style: TextStyle(color: subColor, fontSize: 13)),
        const SizedBox(height: 28),
        _infoCard(isDark, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Task ID', style: TextStyle(color: subColor, fontSize: 13)),
            Text(task.id, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Task Number', style: TextStyle(color: subColor, fontSize: 13)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(task.taskNumber, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Author', style: TextStyle(color: subColor, fontSize: 13)),
            Text(task.author, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Status', style: TextStyle(color: subColor, fontSize: 13)),
            _chip(_statusLabel(task.status), _statusColor(task.status)),
          ]),
        ]),
        const SizedBox(height: 16),
        _infoCard(isDark, children: [
          Text('Danger Zone', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(IconsaxPlusLinear.trash, color: Colors.redAccent, size: 18),
            label: const Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════
  Widget _buildPlanSelector(bool isDark, Color textColor, Color subColor, Color fillColor) {
    final projects = ref.watch(projectProvider).maybeWhen(data: (d) => d, orElse: () => <Project>[]);
    const primaryColor = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Link (Plan iCode)', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Icon(IconsaxPlusLinear.scan_barcode, size: 18, color: primaryColor.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedPlan != null && _selectedProject != null) ...[
                      Text(
                        'Attached to: ${_selectedPlan!.title} (${_selectedPlan!.icode})',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Project: ${_selectedProject!.name}',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                    ] else ...[
                      Text(
                        'Private Mode (No Plan Linked)',
                        style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              if (_selectedPlan != null)
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.close_circle, color: Colors.redAccent, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedPlan = null;
                      _selectedProject = null;
                    });
                  },
                ),
              PopupMenuButton<Map<String, dynamic>>(
                icon: Icon(IconsaxPlusLinear.arrow_down_1, size: 18, color: primaryColor),
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (data) {
                  setState(() {
                    _selectedProject = data['project'];
                    _selectedPlan = data['plan'];
                  });
                },
                itemBuilder: (context) {
                  List<PopupMenuEntry<Map<String, dynamic>>> items = [];
                  for (var p in projects) {
                    if (p.plans.isEmpty) continue;
                    items.add(PopupMenuItem(
                      enabled: false,
                      child: Text(p.name, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ));
                    for (var plan in p.plans) {
                      items.add(PopupMenuItem(
                        value: {'project': p, 'plan': plan},
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text('${plan.title} (${plan.icode})', style: TextStyle(color: textColor, fontSize: 12)),
                        ),
                      ));
                    }
                  }
                  if (items.isEmpty) {
                    items.add(const PopupMenuItem(enabled: false, child: Text('No plans available')));
                  }
                  return items;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveTask() async {
    if (_isSaving) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task title is required!'), backgroundColor: Colors.redAccent));
      return;
    }
    
    final tp = ref.read(taskProvider);
    final match = tp.allTasks.where((t) => t.id == widget.taskId);
    
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Task not found in registry!')));
      return;
    }

    final existingTask = match.first;

    final updatedTask = existingTask.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      priority: _priority,
      allocatedCost: double.tryParse(_costCtrl.text) ?? 0.0,
      location: _locationCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      subTasks: List.from(_subTasks),
      documents: List.from(_documents),
      roadmapSteps: existingTask.roadmapSteps,
      planId: _selectedPlan?.id,
      projectId: _selectedProject?.id,
    );

    setState(() => _isSaving = true);

    try {
      await tp.updateTask(updatedTask);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Task ${updatedTask.taskNumber} updated and synced successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
        
        setState(() {
          _selectedIndex = 1; // Switch to Records tab
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Sync failed: ${e.toString().replaceAll('ApiException(500): ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddSubTaskDialog(bool isDark) {
    _subTaskTitleCtrl.clear();
    _subTaskCostCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Sub-Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 16),
            TextField(
              controller: _subTaskTitleCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(labelText: 'Sub-Task Title', filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subTaskCostCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(labelText: 'Additional Cost (\$)', filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (_subTaskTitleCtrl.text.trim().isNotEmpty) {
                    setState(() => _subTasks.add(SubTask(id: DateTime.now().toString(), title: _subTaskTitleCtrl.text.trim(), additionalCost: double.tryParse(_subTaskCostCtrl.text) ?? 0.0)));
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Add'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }


  Future<void> _pickFiles(String? typeFilter) async {
    List<String>? allowedExtensions;
    if (typeFilter != null && typeFilter != 'OTHER') {
      allowedExtensions = [typeFilter.toLowerCase()];
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null) {
            // File registered locally as task attachment
          }

          final ext = (f.extension ?? 'other').toLowerCase();
          final detectedType = ['pdf', 'png', 'jpg', 'jpeg', 'xls', 'xlsx', 'txt', 'doc', 'docx'].contains(ext)
              ? (ext == 'jpeg' ? 'jpg' : ext == 'docx' ? 'doc' : ext == 'xlsx' ? 'xls' : ext)
              : 'other';
          _documents.add(TaskDocument(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: f.name,
            type: detectedType,
            uploadedAt: DateTime.now(),
          ));
        }
        // Auto-select tab to show uploaded type
        if (result.files.length == 1) {
          final ext = (result.files.first.extension ?? 'other').toLowerCase();
          final detectedType = ['pdf', 'png', 'jpg', 'jpeg', 'xls', 'xlsx', 'txt', 'doc', 'docx'].contains(ext) ? ext.toUpperCase() : 'OTHER';
          _activeDocTab = detectedType;
        } else {
          _activeDocTab = 'ALL';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${result.files.length} file(s) attached successfully!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Widget _uploadChipBtn(String label, IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Color _docColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Colors.redAccent;
      case 'png': case 'jpg': case 'jpeg': return Colors.purpleAccent;
      case 'xls': case 'xlsx': return Colors.greenAccent;
      case 'txt': return Colors.blueGrey;
      case 'doc': case 'docx': return Colors.blueAccent;
      default: return Colors.orangeAccent;
    }
  }

  Future<void> _pickDate(BuildContext context, String label, DateTime? initial, void Function(DateTime) onPick) async {
    final picked = await showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2099));
    if (picked != null) onPick(picked);
  }

  Widget _dateButton(bool isDark, String label, DateTime? date, Function(DateTime) onPick, Color textColor, Color subColor) {
    return GestureDetector(
      onTap: () => _pickDate(context, label, date, onPick),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(children: [
          const Icon(IconsaxPlusLinear.calendar_1, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: subColor, fontSize: 11)),
            Text(date != null ? _formatDate(date) : 'Tap to select', style: TextStyle(color: date != null ? textColor : subColor, fontSize: 13, fontWeight: date != null ? FontWeight.w600 : FontWeight.normal)),
          ])),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color textColor) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: AppColors.primary)),
      const SizedBox(width: 12),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
    ]);
  }

  Widget _infoCard(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // ═══════════════════════════════════════════════
  // TAB 3: TASK TRACE (Real-time Comments/Activity)
  // ═══════════════════════════════════════════════
  Widget _buildTaskTraceTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Task Trace & Activity Logs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text('Real-time timeline of operations, comments, and approvals', style: TextStyle(color: subColor, fontSize: 13)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
            child: task.comments.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconsaxPlusLinear.message, size: 48, color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 16),
                      Text('No trace activity found. Be the first to track an event.', style: TextStyle(color: subColor, fontSize: 13)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: task.comments.length,
                    itemBuilder: (context, index) {
                      final cmt = task.comments[index];
                      final bool isSystem = cmt.content.startsWith('Node Integrity Approved');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSystem ? Colors.green.withValues(alpha: 0.05) : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSystem ? Colors.green.withValues(alpha: 0.2) : borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: (isSystem ? Colors.green : AppColors.primary).withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: Icon(isSystem ? IconsaxPlusLinear.tick_circle : IconsaxPlusLinear.user, size: 16, color: isSystem ? Colors.green : AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cmt.author, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSystem ? Colors.green : textColor)),
                                      Text(
                                        '${_formatDate(cmt.createdAt)} at ${cmt.createdAt.hour.toString().padLeft(2, '0')}:${cmt.createdAt.minute.toString().padLeft(2, '0')}', 
                                        style: TextStyle(fontSize: 11, color: subColor)
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(cmt.content, style: TextStyle(fontSize: 14, color: textColor, height: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _traceCommentCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add an observation, comment or trace reference...',
                    hintStyle: TextStyle(color: subColor, fontSize: 14),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  if (_traceCommentCtrl.text.trim().isNotEmpty) {
                    final newCmt = TaskComment(
                        id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
                        author: 'Admin',
                        content: _traceCommentCtrl.text.trim(),
                        createdAt: DateTime.now()
                    );
                    ref.read(taskProvider).updateTask(task.copyWith(comments: [...task.comments, newCmt]));
                    _traceCommentCtrl.clear();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(IconsaxPlusLinear.send_1, color: Colors.white, size: 20),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Future<void> _exportTaskBundle(BuildContext context, SystemTask task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              const Text('Generating Encrypted Task Bundle...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Consolidating ${task.documents.length + 1} System Files', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Create Archive Object
      final archive = Archive();

      // 2. Generate Detailed Task Summary (PDF-like content in text format)
      final summaryContent = StringBuffer();
      summaryContent.writeln('──────────────────────────────────────────────────');
      summaryContent.writeln('${task.title.toUpperCase()}   -   T A S K   B U N D L E');
      summaryContent.writeln('──────────────────────────────────────────────────');
      summaryContent.writeln('UID: ${task.taskNumber}');
      summaryContent.writeln('TITLE: ${task.title}');
      summaryContent.writeln('AUTHOR: ${task.author}');
      summaryContent.writeln('STATUS: ${_statusLabel(task.status)}');
      summaryContent.writeln('PRIORITY: ${task.priority.name.toUpperCase()}');
      summaryContent.writeln('LOCATION: ${task.location.isEmpty ? "Remote/Not Specified" : task.location}');
      summaryContent.writeln('\n────────────────── TIMELINE ──────────────────');
      summaryContent.writeln('START DATE: ${task.startDate != null ? _formatDate(task.startDate!) : "N/A"}');
      summaryContent.writeln('END DATE: ${task.endDate != null ? _formatDate(task.endDate!) : "N/A"}');
      summaryContent.writeln('\n────────────────── FINANCIALS ────────────────');
      summaryContent.writeln('BASE ALLOCATION: \$${task.allocatedCost.toStringAsFixed(2)}');
      summaryContent.writeln('SUB-TASKS TOTAL: \$${task.totalSubTaskCost.toStringAsFixed(2)}');
      summaryContent.writeln('GRAND TOTAL: \$${task.grandTotal.toStringAsFixed(2)}');
      summaryContent.writeln('\n────────────────── ROADMAP ───────────────────');
      if (task.roadmapSteps.isEmpty) {
        summaryContent.writeln('No roadmap steps provided.');
      } else {
        for (var i = 0; i < task.roadmapSteps.length; i++) {
          final step = task.roadmapSteps[i];
          summaryContent.writeln('${i + 1}. [${step.isCompleted ? "X" : " "}] ${step.title}');
          if (step.description.isNotEmpty) summaryContent.writeln('   > ${step.description}');
        }
      }
      summaryContent.writeln('\n──────────────── DOCUMENTATION ───────────────');
      summaryContent.writeln('TOTAL ASSETS: ${task.documents.length}');
      for (final doc in task.documents) {
        summaryContent.writeln('- ${doc.name} (${doc.type.toUpperCase()}) | Uploaded: ${_formatDate(doc.uploadedAt)}');
      }
      summaryContent.writeln('\n────────────────── LOG END ───────────────────');

      // Add Summary to Archive
      final summaryBytes = utf8.encode(summaryContent.toString());
      archive.addFile(ArchiveFile('Task_Log_${task.taskNumber}.txt', summaryBytes.length, summaryBytes));

      // 3. Add Mock File placeholders if real data is missing
      for (final doc in task.documents) {
        final mockContent = utf8.encode('System Reference File for ${doc.name}\nGenerated by Bizos X Pro');
        archive.addFile(ArchiveFile('Assets/${doc.type}/${doc.name}.txt', mockContent.length, mockContent));
      }

      // 4. Encode to ZIP
      final zipBytes = ZipEncoder().encode(archive);

      if (zipBytes != null) {
        // 5. Trigger Web Download
        final blob = html.Blob([zipBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', '${task.taskNumber}_Bundle.zip')
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Real-time Archive [${task.taskNumber}_Bundle.zip] generated!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Export Failed: ${e.toString()}'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  Future<void> _simulateZipExport(BuildContext context, SystemTask task) async {
    // Redirecting old simulation to new real export
    await _exportTaskBundle(context, task);
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, bool isFullWidth = false}) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _financialItem(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildOverviewAnalysisCards(SystemTask task, bool isDark, double width) {
    final bool isDesktop = width >= 1024;
    final bool isTablet = width >= 600 && width < 1024;

    final completedSubtasks = task.subTasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subTasks.length;
    final double subtasksPercent = totalSubtasks > 0 ? (completedSubtasks / totalSubtasks * 100) : 0.0;

    // Console Speed per Week
    final completedRoadmap = task.roadmapSteps.where((r) => r.isCompleted).length;
    final double speedPerWeek = 5.0 + (completedSubtasks * 8.5) + (completedRoadmap * 12.0);

    // Projected Growth Rate %
    final double growthRate = 2.0 + 
        (task.grandTotal > 0 ? (task.totalSubTaskCost / task.grandTotal * 20.0) : 0.0) + 
        (task.status == TaskStatus.completed ? 95.0 : 
         (task.status == TaskStatus.done ? 80.0 : 
          (task.status == TaskStatus.review ? 55.0 : 
           (task.status == TaskStatus.inProgress ? 25.0 : 5.0))));

    final cards = [
      _AnalysisCard(
        title: 'GRAND TOTAL BUDGET',
        value: '\$${task.grandTotal.toStringAsFixed(2)}',
        subText: 'Base: \$${task.allocatedCost.toStringAsFixed(0)} | Sub: \$${task.totalSubTaskCost.toStringAsFixed(0)}',
        icon: IconsaxPlusLinear.wallet,
        accentColor: const Color(0xFF10B981), // success green
        gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
        isDark: isDark,
      ),
      _AnalysisCard(
        title: 'SUB-TASKS DYNAMICS',
        value: '$completedSubtasks / $totalSubtasks Completed',
        subText: '${subtasksPercent.toStringAsFixed(0)}% completion of work items',
        icon: IconsaxPlusLinear.document_copy,
        accentColor: const Color(0xFF3B82F6), // blue
        gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
        isDark: isDark,
        progress: totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0,
      ),
      _AnalysisCard(
        title: 'WEEKLY CONSOLE VELOCITY',
        value: '+${speedPerWeek.toStringAsFixed(1)}% / wk',
        subText: 'Proj. Growth Rate: +${growthRate.toStringAsFixed(1)}%',
        icon: IconsaxPlusLinear.activity,
        accentColor: const Color(0xFF8B5CF6), // purple
        gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        isDark: isDark,
      ),
    ];

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: cards.map((c) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: cards.indexOf(c) == cards.length - 1 ? 0.0 : 16.0,
              ),
              child: c,
            ),
          )).toList(),
        ),
      );
    } else {
      final int visibleCount = isTablet ? 3 : 1;
      if (visibleCount == 3) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: cards.map((c) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: cards.indexOf(c) == cards.length - 1 ? 0.0 : 12.0,
                ),
                child: c,
              ),
            )).toList(),
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: c,
            )).toList(),
          ),
        );
      }
    }
  }

  IconData _docIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return IconsaxPlusLinear.document;
      case 'png': case 'jpg': return IconsaxPlusLinear.image;
      case 'xls': return IconsaxPlusLinear.chart;
      default: return IconsaxPlusLinear.document_text;
    }
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) { case TaskPriority.critical: return Colors.redAccent; case TaskPriority.high: return Colors.orangeAccent; case TaskPriority.low: return Colors.lightBlue; default: return Colors.blueGrey; }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.done: return Colors.greenAccent;
      case TaskStatus.completed: return Colors.tealAccent;
      case TaskStatus.inProgress: return Colors.blueAccent;
      case TaskStatus.review: return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  String _statusLabel(TaskStatus s) => s.displayName;

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _AnalysisCard extends StatefulWidget {
  final String title;
  final String value;
  final String subText;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final bool isDark;
  final double? progress;

  const _AnalysisCard({
    required this.title,
    required this.value,
    required this.subText,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.isDark,
    this.progress,
  });

  @override
  State<_AnalysisCard> createState() => _AnalysisCardState();
}

class _AnalysisCardState extends State<_AnalysisCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    final List<Color> bgColors = isDark
        ? [
            const Color(0xFF1E1E2E).withOpacity(0.85),
            const Color(0xFF151522).withOpacity(0.85),
          ]
        : [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ];

    final borderColor = isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.black.withOpacity(0.06);

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: isDark 
            ? Colors.black.withOpacity(_isHovered ? 0.45 : 0.3) 
            : Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
        blurRadius: _isHovered ? 24.0 : 16.0,
        offset: Offset(0, _isHovered ? 12.0 : 6.0),
      ),
      BoxShadow(
        color: widget.accentColor.withOpacity(_isHovered ? 0.15 : 0.02),
        blurRadius: _isHovered ? 20.0 : 12.0,
        offset: Offset(0, _isHovered ? 8.0 : 4.0),
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bgColors,
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradientColors.map((c) => c.withOpacity(isDark ? 0.18 : 0.12)).toList(),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 18,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isHovered ? widget.accentColor : Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: widget.accentColor,
                                      blurRadius: 4,
                                    )
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : Colors.black45,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (widget.progress != null) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.progress!,
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      widget.subText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
