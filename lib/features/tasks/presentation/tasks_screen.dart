import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/providers/task_provider.dart';
import 'task_workspace_screen.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import '../../workplace/providers/company_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  // ignore: unused_field
  final Set<String> _selectedTaskIds = {};
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, barrierColor: Colors.black.withOpacity(0.7), builder: (ctx) => const _CreateTaskDialog());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Read local task provider state
    final tp = ref.watch(taskProvider);
    final allTasks = tp.allTasks.where((t) {
      if (_searchQuery.isNotEmpty && !t.title.toLowerCase().contains(_searchQuery)) return false;
      if (_tabCtrl.index == 0) return !t.isArchived;
      return t.isArchived;
    }).toList();

    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    // Premium Deep Green from user image
    const premiumGreen = Color(0xFF0D7A57);
    final primaryColor = premiumGreen;

    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isDesktop 
        ? FloatingActionButton.extended(
            onPressed: () => _showCreateDialog(context),
            backgroundColor: primaryColor,
            elevation: 0,
            icon: const Icon(IconsaxPlusBold.add, color: Colors.white),
            label: const Text('Create Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : FloatingActionButton(
            onPressed: () => _showCreateDialog(context),
            backgroundColor: primaryColor,
            elevation: 0,
            child: const Icon(IconsaxPlusBold.add, color: Colors.white),
          ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 7), // Exact 7px top space (4+3)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDark, textColor, subColor, primaryColor, isDesktop),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('Active', 0, isDark, primaryColor, tp.allTasks.where((t) => !t.isArchived).length),
                        _buildFilterTab('Archived', 1, isDark, primaryColor, tp.allTasks.where((t) => t.isArchived).length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Task List
          Expanded(
            child: allTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconsaxPlusLinear.document_text_1, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 16),
                        Text('No tasks found.', style: TextStyle(color: subColor)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 8),
                    itemCount: allTasks.length,
                    itemBuilder: (context, index) {
                      final task = allTasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(taskId: task.id)));
                          },
                          child: GlassContainer(
                            borderRadius: 12.0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(task.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(IconsaxPlusBold.task, color: _getStatusColor(task.status), size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${task.taskNumber} • ${task.status.displayName}',
                                      style: TextStyle(fontSize: 12, color: subColor),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(task.status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      task.status.displayName,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(task.status)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    task.dueDate != null ? task.dueDate.toString().substring(0, 10) : 'No due date',
                                    style: TextStyle(fontSize: 11, color: subColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color textColor, Color subColor, Color primaryColor, bool isDesktop) {
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
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: TextStyle(color: textColor, fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: subColor, fontSize: 12),
                  prefixIcon: Icon(IconsaxPlusLinear.search_normal, color: subColor, size: 16),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderButton(IconsaxPlusLinear.filter, () => _showFilterPopup(context), isDark, primaryColor, isDesktop),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, int index, bool isDark, Color primaryColor, int count) {
    final isSelected = _tabCtrl.index == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _tabCtrl.animateTo(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Text(
                title,
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
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap, bool isDark, Color primaryColor, bool isDesktop) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Material(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isDark ? Colors.white38 : Colors.black38, size: 16),
              if (isDesktop) ...[
                const SizedBox(width: 8),
                Text('Filter', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const premiumGreen = Color(0xFF0D7A57);
    final primaryColor = premiumGreen;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Center(
        child: Container(
          width: 320,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, spreadRadius: -4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(IconsaxPlusLinear.filter_search, color: primaryColor, size: 22),
                    const SizedBox(width: 12),
                    Text('Smart Filters', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildFilterOption('Active Tasks', 0, isDark, primaryColor),
              _buildFilterOption('Archived / Drafts', 1, isDark, primaryColor),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, int index, bool isDark, Color primaryColor) {
    final isSelected = _tabCtrl.index == index;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: () {
        _tabCtrl.animateTo(index);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(color: textColor, fontSize: 14))),
            if (isSelected) Icon(IconsaxPlusBold.tick_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.inProgress: return Colors.blue;
      case TaskStatus.review: return Colors.orange;
      case TaskStatus.done: return Colors.green;
      case TaskStatus.completed: return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ── Quick Create Dialog Interface ──
class _CreateTaskDialog extends ConsumerStatefulWidget {
  const _CreateTaskDialog();

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _iCodeCtrl = TextEditingController();
  
  Project? _selectedProject;
  Plan? _selectedPlan;
  
  Project? _matchedProject;
  Plan? _matchedPlan;

  late final AnimationController _anim;
  late final Animation<double> _scaleAnim;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _anim.forward();

    _iCodeCtrl.addListener(_onICodeChanged);
  }

  void _onICodeChanged() {
    final code = _iCodeCtrl.text.trim().toLowerCase();
    
    if (_matchedPlan != null && _matchedPlan!.icode.toLowerCase() != code) {
      setState(() {
        _matchedPlan = null;
        _matchedProject = null;
        if (_selectedPlan != null) {
          _selectedPlan = null;
          _selectedProject = null;
        }
      });
    }

    if (code.isEmpty) return;
    
    final pp = ref.read(projectProvider).maybeWhen(data: (d) => d, orElse: () => <Project>[]);
    for (var project in pp) {
      for (var plan in project.plans) {
        if (plan.icode.toLowerCase() == code) {
          if (_matchedPlan?.id != plan.id) {
            setState(() {
              _matchedProject = project;
              _matchedPlan = plan;
            });
          }
          return;
        }
      }
    }
  }

  void _attachMatchedPlan() {
    if (_matchedPlan != null && _matchedProject != null) {
      setState(() {
        _selectedProject = _matchedProject;
        _selectedPlan = _matchedPlan;
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _iCodeCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_titleCtrl.text.isEmpty) return;

    setState(() => _isCreating = true);

    final tp = ref.read(taskProvider.notifier);
    final cp = ref.read(companyProvider).value;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000).toRadixString(16).toUpperCase().padLeft(4, '0');
    final newNumber = 'TSK-${(tp.allTasks.length + 1).toString().padLeft(3, '0')}-$randomSuffix';

    final newTask = SystemTask(
      id: newId,
      taskNumber: newNumber,
      title: _titleCtrl.text,
      author: 'Super Admin',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      planId: _selectedPlan?.id,
      projectId: _selectedProject?.id,
    );

    final companyId = _selectedProject?.companyId ?? cp?.selectedCompanyId ?? ((cp?.companies.isNotEmpty ?? false) ? cp!.companies.first.id : '1');

    final createdTask = await tp.addTask(newTask, companyId: companyId);

    if (!mounted) return;
    Navigator.pop(context);
    if (createdTask != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(taskId: createdTask.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    const primaryColor = Color(0xFF0D7A57); // Premium Deep Green

    final ppProjects = ref.watch(projectProvider).maybeWhen(data: (d) => d, orElse: () => <Project>[]);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, spreadRadius: -10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(IconsaxPlusBold.edit_2, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Create Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(IconsaxPlusLinear.close_circle, color: subColor, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        labelStyle: TextStyle(color: subColor, fontSize: 12),
                        hintText: 'E.g., Update marketing copy',
                        hintStyle: TextStyle(color: subColor.withOpacity(0.5), fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _iCodeCtrl,
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Smart Link (Plan iCode)',
                        labelStyle: TextStyle(color: subColor, fontSize: 12),
                        hintText: 'Paste PLN-001 or browse...',
                        hintStyle: TextStyle(color: subColor.withOpacity(0.5), fontSize: 12),
                        prefixIcon: Icon(IconsaxPlusLinear.scan_barcode, size: 16, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                        suffixIcon: _matchedPlan != null && _selectedPlan?.id != _matchedPlan?.id
                            ? IconButton(
                                icon: const Icon(IconsaxPlusBold.tick_circle, color: Colors.green),
                                onPressed: _attachMatchedPlan,
                              )
                            : (_selectedPlan != null && _selectedPlan?.id == _matchedPlan?.id)
                                ? IconButton(
                                    icon: const Icon(IconsaxPlusLinear.close_circle, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _iCodeCtrl.clear();
                                        _matchedPlan = null;
                                        _matchedProject = null;
                                        _selectedPlan = null;
                                        _selectedProject = null;
                                      });
                                    },
                                  )
                                : PopupMenuButton<Map<String, dynamic>>(
                                    icon: Icon(IconsaxPlusLinear.arrow_down_1, size: 16, color: primaryColor),
                                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (data) {
                                      final Project p = data['project'];
                                      final Plan plan = data['plan'];
                                      _iCodeCtrl.text = plan.icode;
                                      setState(() {
                                        _matchedProject = p;
                                        _matchedPlan = plan;
                                      });
                                      _attachMatchedPlan();
                                    },
                                    itemBuilder: (context) {
                                      List<PopupMenuEntry<Map<String, dynamic>>> items = [];
                                      for (var p in ppProjects) {
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
                      ),
                    ),
                    if (_selectedPlan != null && _selectedProject != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(IconsaxPlusBold.tick_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11),
                                  children: [
                                    const TextSpan(text: 'Attached to '),
                                    TextSpan(text: '${_selectedPlan!.title} Console', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    TextSpan(text: ' in ${_selectedProject!.name}.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
                    ] else if (_matchedPlan != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(IconsaxPlusBold.info_circle, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Click the tick icon to attach to ${_matchedPlan!.title}.',
                                style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _handleCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isCreating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
