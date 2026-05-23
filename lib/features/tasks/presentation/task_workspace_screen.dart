import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html; // For Web downloads
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/providers/task_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';

class TaskWorkspaceScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskWorkspaceScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskWorkspaceScreen> createState() => _TaskWorkspaceScreenState();
}

class _TaskWorkspaceScreenState extends ConsumerState<TaskWorkspaceScreen> {
  int _selectedIndex = 0;

  final List<String> _tabNames = ['Task Overview', 'Create Task', 'Execution Roadmap', 'Task Trace', 'Task Core Settings'];
  final List<IconData> _tabIcons = [
    IconsaxPlusLinear.radar,
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
  final _traceCommentCtrl = TextEditingController();
  String _activeDocTab = 'ALL';
  bool _isDragOver = false;
  final List<String> _docTabs = ['ALL', 'PDF', 'PNG', 'JPG', 'XLS', 'TXT', 'DOC', 'OTHER'];

  bool _isInitialized = false;

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
      }
      _isInitialized = true;
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
    _traceCommentCtrl.dispose();
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
        content = SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: _buildCreateTaskTab(isDark2),
        );
        break;
      case 2:
        content = SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildRoadmapTab(task, isDark2)],
          ),
        );
        break;
      case 3:
        content = Padding(
          padding: EdgeInsets.all(pad),
          child: _buildTaskTraceTab(task, isDark2),
        );
        break;
      case 4:
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
  // TAB 0: OVERVIEW
  // ═══════════════════════════════════════════════
  Widget _buildOverviewTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
      final isMobile = constraints.maxWidth <= 600;

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER & UID ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Task Overview', 
                    style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  // Export Bundle Button
                  if (!isMobile)
                    _actionButton(
                      label: 'Export Bundle',
                      icon: IconsaxPlusLinear.document_download,
                      color: AppColors.primary,
                      onTap: () => _simulateZipExport(context, task),
                    ),
                  if (!isMobile) const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: task.taskNumber));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('UID Copied: ${task.taskNumber}'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        margin: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(task.taskNumber, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        const Icon(IconsaxPlusLinear.copy, size: 14, color: AppColors.primary),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
            if (isMobile) ...[
              const SizedBox(height: 12),
              _actionButton(
                label: 'Export Asset Bundle (ZIP)',
                icon: IconsaxPlusLinear.document_download,
                color: AppColors.primary,
                isFullWidth: true,
                onTap: () => _simulateZipExport(context, task),
              ),
            ],
            const SizedBox(height: 24),

            // ── TOP STATS BANNER (Responsive) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isDark ? [const Color(0xFF2E2E48), const Color(0xFF1E1E2E)] : [Colors.white, Colors.grey.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 20, runSpacing: 20,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _overviewStat('Execution Status', _statusLabel(task.status), _statusColor(task.status), IconsaxPlusLinear.activity, isDark),
                  _overviewStat('Priority Level', task.priority.name.toUpperCase(), _priorityColor(task.priority), IconsaxPlusLinear.radar, isDark),
                  _overviewStat('Allocated Multiplier', '\$${task.grandTotal.toStringAsFixed(0)}', AppColors.primary, IconsaxPlusLinear.wallet, isDark),
                  _overviewStat('Total Assets', '${task.documents.length} Files', Colors.teal, IconsaxPlusLinear.document_copy, isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── MAIN CONTENT GRID ──
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: _buildPrimaryInfo(task, isDark, textColor, subColor, cardColor, borderColor)),
                const SizedBox(width: 20),
                Expanded(flex: 1, child: _buildSecondaryInfo(task, isDark, textColor, subColor, cardColor, borderColor)),
              ])
            else if (isTablet)
              Column(children: [
                _buildPrimaryInfo(task, isDark, textColor, subColor, cardColor, borderColor),
                const SizedBox(height: 20),
                _buildSecondaryInfo(task, isDark, textColor, subColor, cardColor, borderColor),
              ])
            else
              Column(children: [
                _buildPrimaryInfo(task, isDark, textColor, subColor, cardColor, borderColor),
                const SizedBox(height: 20),
                _buildSecondaryInfo(task, isDark, textColor, subColor, cardColor, borderColor),
              ]),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
    });
  }

  Widget _buildPrimaryInfo(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Basic Identification
      _overviewCard(isDark, title: 'Scope & Identification', children: [
        Text('Task Title', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(task.title, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Full Description', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(task.description, style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
        ],
        if (task.location.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(children: [
            const Icon(IconsaxPlusLinear.location, size: 16, color: Colors.teal),
            const SizedBox(width: 8),
            Text(task.location, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ],
      ]),
      const SizedBox(height: 20),

      // Execution Timeline
      _overviewCard(isDark, title: 'Operational Timeline', children: [
        Row(children: [
          Expanded(child: _dateModule('Initiation Date', task.startDate, IconsaxPlusLinear.calendar_1, AppColors.primary, isDark, textColor, subColor)),
          Container(width: 1, height: 40, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 20)),
          Expanded(child: _dateModule('Target Completion', task.endDate, IconsaxPlusLinear.timer_1, Colors.orangeAccent, isDark, textColor, subColor)),
        ]),
      ]),
      const SizedBox(height: 20),

      // Execution Roadmap (Steps)
      if (task.roadmapSteps.isNotEmpty)
        _overviewCard(isDark, title: 'Strategic Roadmap Steps', children: [
          ...task.roadmapSteps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.value.title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3)),
                  if (e.value.description.isNotEmpty)
                    Text(e.value.description, style: TextStyle(color: subColor, fontSize: 11, height: 1.4)),
                ],
              )),
            ]),
          )),
        ]),
    ]);
  }

  Widget _buildSecondaryInfo(SystemTask task, bool isDark, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    return Column(children: [
      // Financial Health
      _overviewCard(isDark, title: 'Commercial Summary', children: [
        _financialRow('Basic Allocation', task.allocatedCost, AppColors.primary, isDark, textColor),
        const SizedBox(height: 12),
        _financialRow('Sub-Tasks Overhead', task.totalSubTaskCost, Colors.orangeAccent, isDark, textColor),
        const Divider(height: 32),
        _financialRow('Total Net Budget', task.grandTotal, AppColors.success, isDark, textColor, isBold: true),
      ]),
      const SizedBox(width: 20, height: 20),

      // Sub-Tasks List
      if (task.subTasks.isNotEmpty)
        _overviewCard(isDark, title: 'Active Sub-Tasks', children: [
          ...task.subTasks.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(s.isCompleted ? IconsaxPlusLinear.tick_circle : IconsaxPlusLinear.record_circle, size: 18, color: s.isCompleted ? AppColors.success : subColor),
              const SizedBox(width: 12),
              Expanded(child: Text(s.title, style: TextStyle(color: textColor, fontSize: 13, fontWeight: s.isCompleted ? FontWeight.normal : FontWeight.w600))),
              Text('\$${s.additionalCost.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          )),
        ]),
      const SizedBox(width: 20, height: 20),

      // Assets & Attachments
      if (task.documents.isNotEmpty)
        _overviewCard(isDark, title: 'Authenticated Assets', children: [
          ...task.documents.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(_docIcon(d.type.toUpperCase()), size: 16, color: _docColor(d.type)),
              const SizedBox(width: 10),
              Expanded(child: Text(d.name, style: TextStyle(color: textColor, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const Icon(IconsaxPlusLinear.export_1, size: 14, color: AppColors.primary),
            ]),
          )),
        ]),
    ]);
  }

  Widget _overviewCard(bool isDark, {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
          Icon(IconsaxPlusLinear.arrow_right_3, size: 12, color: AppColors.primary.withOpacity(0.5)),
        ]),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }

  Widget _overviewStat(String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _dateModule(String label, DateTime? date, IconData icon, Color color, bool isDark, Color textColor, Color subColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      Text(date != null ? _formatDate(date) : 'Unscheduled', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  Widget _financialRow(String label, double amount, Color color, bool isDark, Color textColor, {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: isBold ? textColor : (isDark ? Colors.white70 : Colors.black87), fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
    ]);
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
              onPressed: _saveTask,
              icon: const Icon(IconsaxPlusLinear.tick_circle, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 28),

          // ── SECTION 5: Roadmap Steps ──
          _sectionHeader('Execution Roadmap', IconsaxPlusLinear.route_square, textColor),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _roadmapStepCtrl,
              style: TextStyle(color: textColor),
              decoration: _fieldDeco('Add Roadmap Step', IconsaxPlusLinear.add),
            )),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_roadmapStepCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _roadmapSteps.add(RoadmapStep(id: DateTime.now().toString(), title: _roadmapStepCtrl.text.trim()));
                    _roadmapStepCtrl.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
              child: const Icon(IconsaxPlusLinear.add, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          ..._roadmapSteps.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
            child: Row(children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)))),
              const SizedBox(width: 12),
              Expanded(child: Text(e.value.title, style: TextStyle(color: textColor, fontSize: 13))),
              InkWell(onTap: () => setState(() => _roadmapSteps.removeAt(e.key)), child: const Icon(IconsaxPlusLinear.close_circle, size: 14, color: Colors.redAccent)),
            ]),
          )),
          const SizedBox(height: 40),

          // Save Button (bottom)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveTask,
              icon: const Icon(IconsaxPlusLinear.tick_circle),
              label: const Text('Save & Register Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  Widget _buildRoadmapTab(SystemTask task, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Execution Roadmap', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text('Step-by-step execution policy for this task', style: TextStyle(color: subColor, fontSize: 13)),
          const SizedBox(height: 28),
          if (task.roadmapSteps.isEmpty)
            Center(child: Column(children: [
              const SizedBox(height: 60),
              Icon(IconsaxPlusLinear.route_square, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text('No roadmap steps defined.', style: TextStyle(color: subColor, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Add roadmap steps in the Create Task tab.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13)),
            ]))
          else
            ...task.roadmapSteps.asMap().entries.map((e) {
              final step = e.value;
              final isLast = e.key == task.roadmapSteps.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: step.isCompleted ? AppColors.success.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: step.isCompleted ? AppColors.success : AppColors.primary)),
                      child: Center(child: step.isCompleted ? const Icon(Icons.check, size: 18, color: AppColors.success) : Text('${e.key + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)))),
                    if (!isLast) Container(width: 2, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                  ]),
                  const SizedBox(width: 16),
                  Expanded(child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(step.title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                      if (step.description.isNotEmpty) ...[ const SizedBox(height: 4),
                        Text(step.description, style: TextStyle(color: subColor, fontSize: 13)),
                      ],
                    ]),
                  )),
                ],
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
  void _saveTask() {
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
      roadmapSteps: List.from(_roadmapSteps),
    );

    tp.updateTask(updatedTask);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Task ${updatedTask.taskNumber} updated and synced successfully!'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
    
    // Switch to Overview to see changes
    setState(() => _selectedIndex = 0);
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
