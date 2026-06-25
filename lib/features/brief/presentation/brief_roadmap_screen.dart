import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../tasks/models/system_task.dart';
import '../../tasks/providers/task_provider.dart';
import '../../projects/models/project.dart';
import '../../projects/providers/project_provider.dart';
import '../../teams/presentation/teams_screen.dart';
import 'package:flutter/gestures.dart';

String _generate6DigitCode() {
  final random = Random();
  final num = random.nextInt(900000) + 100000;
  return num.toString();
}

class HourlyTask {
  final String id;
  DateTime startTime;
  DateTime endTime;
  String title;
  String description;
  String priority; // 'Critical', 'High', 'Medium', 'Low'
  String status; // 'Complete', 'Process', 'Hold'
  bool isLocked; // locked status
  final String taskCode; // TST-XXXXXX

  HourlyTask({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description = '',
    this.priority = 'Medium',
    this.status = 'Process', // Default status is 'Process'
    this.isLocked = false,
    String? taskCode,
  }) : taskCode = taskCode ?? 'TST-${_generate6DigitCode()}';

  // Helper to sort tasks chronologically
  int get minutesValue => startTime.millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'title': title,
    'description': description,
    'priority': priority,
    'status': status,
    'isLocked': isLocked,
    'taskCode': taskCode,
  };

  factory HourlyTask.fromJson(Map<String, dynamic> json) => HourlyTask(
    id: json['id'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    title: json['title'],
    description: json['description'] ?? '',
    priority: json['priority'] ?? 'Medium',
    status: json['status'] ?? 'Process',
    isLocked: json['isLocked'] ?? false,
    taskCode: json['taskCode'],
  );
}

class RoadmapSession {
  final String id;
  String sessionLabel; // e.g. "Session 1"
  String objective;
  final List<HourlyTask> tasks;
  final DateTime createdAt;
  DateTime updatedAt;
  String status; // 'Active' or 'Draft'
  String author; // Author name
  final String sessionCode; // SES-XXXXXX

  RoadmapSession({
    required this.id,
    required this.sessionLabel,
    required this.objective,
    required this.tasks,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'Active',
    this.author = 'Super Admin',
    String? sessionCode,
  }) : sessionCode = sessionCode ?? 'SES-${_generate6DigitCode()}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionLabel': sessionLabel,
    'objective': objective,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    'author': author,
    'sessionCode': sessionCode,
  };

  factory RoadmapSession.fromJson(Map<String, dynamic> json) => RoadmapSession(
    id: json['id'],
    sessionLabel: json['sessionLabel'],
    objective: json['objective'],
    tasks: (json['tasks'] as List).map((t) => HourlyTask.fromJson(t)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    status: json['status'] ?? 'Active',
    author: json['author'] ?? 'Super Admin',
    sessionCode: json['sessionCode'],
  );
}

RoadmapSession mapSystemTaskToSession(SystemTask task) {
  String mapPriority(TaskPriority p) {
    switch (p) {
      case TaskPriority.critical: return 'Critical';
      case TaskPriority.high: return 'High';
      case TaskPriority.low: return 'Low';
      default: return 'Medium';
    }
  }

  final steps = task.roadmapSteps;
  final totalSteps = steps.length;
  
  final taskStart = task.startDate ?? DateTime.now();
  final taskEnd = task.endDate ?? taskStart.add(Duration(hours: max(1, totalSteps)));
  final totalDuration = taskEnd.difference(taskStart);
  final stepDuration = totalSteps > 0 
      ? Duration(minutes: (totalDuration.inMinutes / totalSteps).floor())
      : const Duration(hours: 1);

  final List<HourlyTask> hourlyTasks = [];
  for (int i = 0; i < totalSteps; i++) {
    final step = steps[i];
    final stepStart = step.startTime ?? taskStart.add(stepDuration * i);
    final stepEnd = step.endTime ?? stepStart.add(stepDuration);
    
    hourlyTasks.add(HourlyTask(
      id: step.id,
      startTime: stepStart,
      endTime: stepEnd,
      title: step.title,
      description: step.description,
      priority: step.priority,
      status: step.status, // Use the 3-state status directly
      isLocked: step.isLocked,
      taskCode: 'STP-${task.taskNumber.replaceAll('TSK-', '')}-${i + 1}',
    ));
  }

  return RoadmapSession(
    id: task.id,
    sessionLabel: task.title,
    objective: task.description.isNotEmpty ? task.description : 'No description provided.',
    tasks: hourlyTasks,
    createdAt: task.createdAt ?? DateTime.now(),
    updatedAt: task.updatedAt ?? DateTime.now(),
    status: task.isArchived ? 'Draft' : 'Active',
    author: task.author,
    sessionCode: task.taskNumber,
  );
}

class BriefRoadmapScreen extends ConsumerStatefulWidget {
  const BriefRoadmapScreen({super.key});

  @override
  ConsumerState<BriefRoadmapScreen> createState() => _BriefRoadmapScreenState();
}

class _BriefRoadmapScreenState extends ConsumerState<BriefRoadmapScreen> {
  final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy · hh:mm a');
  final DateFormat _taskTimeFormat = DateFormat('MMM dd, hh:mm a');
  late List<RoadmapSession> _roadmapSessions;
  final List<RoadmapSession> _recycledSessions = [];
  bool _isLoading = false;
  String _searchQuery = '';
  // Session status filter — 'All' | 'Active' | 'Draft'
  String _statusFilter = 'All';
  // Company category filter — 'all' means no filter, otherwise holds company id as string
  String _selectedCompanyFilter = 'all';
  final ScrollController _teamScrollCtrl = ScrollController();
  final Set<String> _expandedSessionIds = {};

  Widget _buildSessionObjective(String text, String sessionId, bool isDark) {
    final style = GoogleFonts.outfit(
      fontSize: 11.5,
      color: isDark ? Colors.white54 : Colors.black54,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );
    final words = text.split(RegExp(r'\s+'));
    const int wordLimit = 40; // Same as records page
    if (words.length <= wordLimit) {
      return Text(text, style: style);
    }

    final isExpanded = _expandedSessionIds.contains(sessionId);
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
                _expandedSessionIds.remove(sessionId);
              } else {
                _expandedSessionIds.add(sessionId);
              }
            });
          },
          child: Text(
            isExpanded ? 'Collapse' : 'See more',
            style: GoogleFonts.outfit(
              color: const Color(0xFF6366F1), // primary color
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTaskDescription(String text, String taskId, bool isDark) {
    final style = GoogleFonts.outfit(
      fontSize: 9.5,
      color: isDark ? Colors.white38 : Colors.black38,
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
    final words = text.split(RegExp(r'\s+'));
    const int wordLimit = 40; // Same as records page
    if (words.length <= wordLimit) {
      return Text(text, style: style);
    }

    final isExpanded = _expandedSessionIds.contains(taskId);
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
                _expandedSessionIds.remove(taskId);
              } else {
                _expandedSessionIds.add(taskId);
              }
            });
          },
          child: Text(
            isExpanded ? 'Collapse' : 'See more',
            style: GoogleFonts.outfit(
              color: const Color(0xFF6366F1), // primary color
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  bool get _isAdmin => ref.read(authProvider).canCreateItems;

  @override
  void initState() {
    super.initState();
    _roadmapSessions = [];
    _loadRoadmapData();
  }

  @override
  void dispose() {
    _teamScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoadmapData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(taskProvider).syncWithDatabase();
    } catch (e) {
      debugPrint('Error loading roadmap data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveRoadmapData() async {
    // Deprecated: Data is now securely stored in MySQL via API calls.
  }

  // ─────────────────────────────────────────────────────────
  // COMPANY CATEGORY BAR
  // Full-width horizontal scrollable chip row below search bar.
  // Supports mouse-wheel and touch drag. Filters sessions by company.
  // ─────────────────────────────────────────────────────────
  Widget _buildCompanyCategoryBar(bool isDark, Color primary) {
    final teamsAsync = ref.watch(teamsProvider);

    return teamsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (response) {
        final teams = response.teams;
        if (teams.isEmpty) return const SizedBox.shrink();

        // Extract deduplicated list of active companies under all admin's teams
        final uniqueCompanies = <int, TeamCompany>{};
        for (final team in teams) {
          for (final company in team.companies) {
            uniqueCompanies[company.id] = company;
          }
        }
        final companyList = uniqueCompanies.values.toList();
        if (companyList.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: SizedBox(
            width: double.infinity,
            child: Listener(
              // Mouse wheel horizontal scroll
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final offset = _teamScrollCtrl.offset + event.scrollDelta.dy;
                  _teamScrollCtrl.animateTo(
                    offset.clamp(0.0, _teamScrollCtrl.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: SingleChildScrollView(
                controller: _teamScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // ── "All Companies" chip ────────────────────────────
                    _buildCompanyChip(
                      label: 'All Companies',
                      companyId: 'all',
                      icon: Icons.business_center_rounded,
                      isSelected: _selectedCompanyFilter == 'all',
                      color: primary,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    // ── One chip per company ─────────────────────────────
                    ...companyList.asMap().entries.expand((entry) {
                      final i = entry.key;
                      final company = entry.value;
                      final chipColors = [
                        const Color(0xFF6366F1), // indigo
                        const Color(0xFF10B981), // emerald
                        const Color(0xFFF59E0B), // amber
                        const Color(0xFFEC4899), // pink
                        const Color(0xFF3B82F6), // blue
                        const Color(0xFF8B5CF6), // violet
                      ];
                      final color = chipColors[i % chipColors.length];
                      return [
                        _buildCompanyChip(
                          label: company.name,
                          companyId: company.id.toString(),
                          icon: Icons.apartment_rounded,
                          isSelected: _selectedCompanyFilter == company.id.toString(),
                          color: color,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                      ];
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyChip({
    required String label,
    required String companyId,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCompanyFilter = companyId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.redAccent;
      case 'High':
        return Colors.orangeAccent;
      case 'Medium':
        return Colors.blueAccent;
      case 'Low':
      default:
        return Colors.greenAccent;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Complete':
        return const Color(0xFF10B981); // Emerald
      case 'Process':
        return const Color(0xFF6366F1); // Indigo
      case 'Hold':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Complete':
        return Icons.check_circle_rounded;
      case 'Process':
        return Icons.play_circle_fill_rounded;
      case 'Hold':
      default:
        return Icons.pause_circle_filled_rounded;
    }
  }

  void _showLockedWarning(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This task process is locked. Unlock it in configurations to update.',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initial, bool isDark) async {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF6366F1);
    final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: dialogBg,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: dialogBg,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showAddSessionDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF09090D) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              ),
            ),
            title: Text(
              'Add Roadmap Session',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
            ),
            content: Text(
              'Roadmap Sessions are automatically created when you register tasks with execution roadmaps in the Workplace Console.\n\nPlease navigate to the Workplace or Tasks section to register new tasks.',
              style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSessionConfigDialog(BuildContext context, RoadmapSession session, bool isDark) {
    final titleCtrl = TextEditingController(text: session.sessionLabel);
    final objectiveCtrl = TextEditingController(text: session.objective);
    String status = session.status; // 'Active' or 'Draft'

    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(IconsaxPlusLinear.setting_2, color: const Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    Text('Session Configurations', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Edit Title
                      TextField(
                        controller: titleCtrl,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Session Title',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Edit Objective
                      TextField(
                        controller: objectiveCtrl,
                        maxLines: 2,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Objective / Goal',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Session Status:', style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                status == 'Active' 
                                  ? 'Visible to entire team' 
                                  : 'Private - Visible only to you',
                                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          DropdownButton<String>(
                            value: status,
                            dropdownColor: dialogBg,
                            style: GoogleFonts.outfit(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                            items: ['Active', 'Draft']
                                .map((s) => DropdownMenuItem(
                                      value: s, 
                                      child: Text(
                                        s, 
                                        style: TextStyle(
                                          color: s == 'Active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => status = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      const SizedBox(height: 12),

                      // Delete Session Button
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                        title: Text('Remove Session', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Delete this session and all its tasks', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showConfirmDeleteSessionDialog(context, session, isDark);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        Navigator.pop(ctx);
                        try {
                          final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == session.id);
                          final updatedTask = targetTask.copyWith(
                            title: titleCtrl.text.trim(),
                            description: objectiveCtrl.text.trim(),
                          );
                          await ref.read(taskProvider).updateTask(updatedTask);
                        } catch (e) {
                          debugPrint('Error updating session config: $e');
                          _showErrorSnackBar(context, 'Failed to update session config: $e');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Configurations', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmDeleteSessionDialog(BuildContext context, RoadmapSession session, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              ),
            ),
            title: Text('Remove Session?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            content: Text(
              'Are you sure you want to remove "${session.sessionLabel}"? You can restore it later from the Recycle Bin.',
              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(taskProvider).removeTask(session.id);
                    
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${session.sessionLabel}" moved to Recycle Bin.',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF6366F1),
                        action: SnackBarAction(
                          label: 'UNDO',
                          textColor: Colors.white,
                          onPressed: () async {
                            try {
                              await ref.read(taskProvider).restoreTask(session.id);
                            } catch (err) {
                              debugPrint('Error restoring session: $err');
                            }
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } catch (e) {
                    debugPrint('Error removing session: $e');
                    _showErrorSnackBar(context, 'Failed to remove session: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Remove', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecycleBinDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // The backend (HasTeamScope) already scopes trashed sessions to the
            // current user's role/team — trust the returned list directly.
            final myRecycledSessions = _recycledSessions;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(IconsaxPlusLinear.trash, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recycle Bin',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    if (myRecycledSessions.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: Colors.redAccent),
                        label: Text(
                          'Empty',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (confirmCtx) {
                              return AlertDialog(
                                backgroundColor: dialogBg,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text('Empty Recycle Bin?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                content: Text('This will permanently delete all recycled sessions. This action cannot be undone.', style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(confirmCtx),
                                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () async {
                                      Navigator.pop(confirmCtx);
                                      try {
                                        final trashed = [...ref.read(taskProvider).trashedTasks];
                                        for (var task in trashed) {
                                          await ref.read(taskProvider).forceDeleteTask(task.id);
                                        }
                                        setDialogState(() {});
                                      } catch (e) {
                                        debugPrint('Error emptying Recycle Bin: $e');
                                      }
                                    },
                                    child: Text('Empty All', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
                content: Container(
                  width: 450,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: myRecycledSessions.isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Icon(
                              IconsaxPlusLinear.trash,
                              size: 48,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Recycle Bin is empty',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: myRecycledSessions.length,
                          itemBuilder: (itemCtx, index) {
                            final session = myRecycledSessions[index];
                            return Card(
                              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  width: 0.5,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            session.sessionLabel,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          session.sessionCode,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      session.objective,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${session.tasks.length} Tasks',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF6366F1),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.greenAccent, size: 16),
                                              tooltip: 'Restore',
                                              onPressed: () async {
                                                try {
                                                  await ref.read(taskProvider).restoreTask(session.id);
                                                  setDialogState(() {});
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('"${session.sessionLabel}" restored to roadmap.', style: GoogleFonts.outfit(fontSize: 12)),
                                                      backgroundColor: Colors.green,
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  debugPrint('Error restoring session: $e');
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16),
                                              tooltip: 'Delete Permanently',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (deleteCtx) {
                                                    return AlertDialog(
                                                      backgroundColor: dialogBg,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                      title: Text('Delete Permanently?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                                      content: Text('Are you sure you want to permanently delete "${session.sessionLabel}"? This action is irreversible.', style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(deleteCtx),
                                                          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                          onPressed: () async {
                                                            Navigator.pop(deleteCtx);
                                                            try {
                                                              await ref.read(taskProvider).forceDeleteTask(session.id);
                                                              setDialogState(() {});
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('"${session.sessionLabel}" deleted permanently.', style: GoogleFonts.outfit(fontSize: 12)),
                                                                  backgroundColor: Colors.redAccent,
                                                                  duration: const Duration(seconds: 2),
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              debugPrint('Error permanently deleting session: $e');
                                                            }
                                                          },
                                                          child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Close',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context, RoadmapSession roadmap, bool isDark) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime startDateTime = DateTime.now();
    DateTime endDateTime = DateTime.now().add(const Duration(hours: 1));
    String priority = 'Medium';
    String status = 'Process';

    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isTimeValid = endDateTime.isAfter(startDateTime);
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  ),
                ),
                title: Text(
                  'Add Scheduled Task',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextField(
                        controller: titleCtrl,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Description
                      TextField(
                        controller: descCtrl,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Short Description',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start Date Time Selector
                      Text('Start Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await _selectDateTime(context, startDateTime, isDark);
                          if (picked != null) {
                            setDialogState(() => startDateTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateTimeFormat.format(startDateTime),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // End Date Time Selector
                      Text('End Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await _selectDateTime(context, endDateTime, isDark);
                          if (picked != null) {
                            setDialogState(() => endDateTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateTimeFormat.format(endDateTime),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Validation Error Text
                      if (!isTimeValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Error: End date & time must be after start date & time.',
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Priority Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Priority Level:', style: GoogleFonts.outfit(fontSize: 12, color: textColor)),
                          DropdownButton<String>(
                            value: priority,
                            dropdownColor: dialogBg,
                            style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                            items: ['Low', 'Medium', 'High', 'Critical']
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => priority = val);
                            },
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  ElevatedButton(
                    onPressed: isTimeValid
                        ? () async {
                            if (titleCtrl.text.trim().isNotEmpty) {
                              final newStep = RoadmapStep(
                                id: 'step_${DateTime.now().millisecondsSinceEpoch}',
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                status: 'Process',
                              );
                              Navigator.pop(ctx);
                              try {
                                final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == roadmap.id);
                                final updatedTask = targetTask.copyWith(
                                  roadmapSteps: [...targetTask.roadmapSteps, newStep],
                                );
                                await ref.read(taskProvider).updateTask(updatedTask);
                              } catch (e) {
                                debugPrint('Error adding task step: $e');
                                _showErrorSnackBar(context, 'Failed to add task step: $e');
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Add Task', style: GoogleFonts.outfit(color: isTimeValid ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskConfigDialog(BuildContext context, RoadmapSession roadmap, HourlyTask task, bool isDark) {
    final titleCtrl = TextEditingController(text: task.title);
    final descCtrl = TextEditingController(text: task.description);
    
    DateTime startDateTime = task.startTime;
    DateTime endDateTime = task.endTime;
    String priority = task.priority;
    bool isLockedState = task.isLocked;

    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isTimeValid = endDateTime.isAfter(startDateTime);
            final bool isConfigLocked = task.isLocked && roadmap.status == 'Active';

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(IconsaxPlusLinear.setting_2, color: const Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    Text('Task Configurations', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Warning banner if locked
                      if (isConfigLocked)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 16, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This execution step is locked. To modify or unlock it, make this session Private/Draft first.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent, 
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Edit Title
                      TextField(
                        controller: titleCtrl,
                        enabled: !isConfigLocked,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Edit Description
                      TextField(
                        controller: descCtrl,
                        enabled: !isConfigLocked,
                        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Short Description',
                          labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start Date Time Selector
                      Text('Start Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: isConfigLocked
                            ? null
                            : () async {
                                final picked = await _selectDateTime(context, startDateTime, isDark);
                                if (picked != null) {
                                  setDialogState(() => startDateTime = picked);
                                }
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateTimeFormat.format(startDateTime),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // End Date Time Selector
                      Text('End Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: isConfigLocked
                            ? null
                            : () async {
                                final picked = await _selectDateTime(context, endDateTime, isDark);
                                if (picked != null) {
                                  setDialogState(() => endDateTime = picked);
                                }
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateTimeFormat.format(endDateTime),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Validation Error Text
                      if (!isTimeValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Error: End date & time must be after start date & time.',
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Priority Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Priority:', style: GoogleFonts.outfit(fontSize: 12, color: textColor)),
                          DropdownButton<String>(
                            value: priority,
                            dropdownColor: dialogBg,
                            style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                            items: ['Low', 'Medium', 'High', 'Critical']
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: isConfigLocked
                                ? null
                                : (val) {
                                    if (val != null) setDialogState(() => priority = val);
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Lock Process Switch
                      SwitchListTile(
                        title: Text('Lock Process', style: GoogleFonts.outfit(fontSize: 13, color: textColor, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isLockedState 
                            ? 'Locked - No modifications allowed' 
                            : 'Unlocked - Editing & status change enabled',
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                        ),
                        value: isLockedState,
                        activeColor: Colors.redAccent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: isConfigLocked
                            ? null
                            : (val) {
                                setDialogState(() => isLockedState = val);
                              },
                      ),

                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      const SizedBox(height: 12),

                      // Delete Button Tile
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                        title: Text('Remove Task', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Delete this task from roadmap', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          // Double confirm removal
                          Navigator.pop(ctx);
                          _showConfirmDeleteDialog(context, roadmap, task, isDark);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  ElevatedButton(
                    onPressed: isTimeValid && !isConfigLocked
                        ? () async {
                            if (titleCtrl.text.trim().isNotEmpty) {
                              Navigator.pop(ctx);
                              try {
                                final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == roadmap.id);
                                final updatedSteps = targetTask.roadmapSteps.map((step) {
                                  if (step.id == task.id) {
                                    return step.copyWith(
                                      title: titleCtrl.text.trim(),
                                      description: descCtrl.text.trim(),
                                      priority: priority,
                                      startTime: startDateTime,
                                      endTime: endDateTime,
                                      isLocked: isLockedState,
                                    );
                                  }
                                  return step;
                                }).toList();
                                final updatedTask = targetTask.copyWith(roadmapSteps: updatedSteps);
                                await ref.read(taskProvider).updateTask(updatedTask);
                              } catch (e) {
                                debugPrint('Error updating task step: $e');
                                _showErrorSnackBar(context, 'Failed to update task step config: $e');
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Configurations', style: GoogleFonts.outfit(color: isTimeValid && !isConfigLocked ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmDeleteDialog(BuildContext context, RoadmapSession roadmap, HourlyTask task, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              ),
            ),
            title: Text('Delete Task?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            content: Text(
              'Are you sure you want to remove "${task.title}"? This action cannot be undone.',
              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == roadmap.id);
                    final updatedSteps = targetTask.roadmapSteps.where((step) => step.id != task.id).toList();
                    final updatedTask = targetTask.copyWith(roadmapSteps: updatedSteps);
                    await ref.read(taskProvider).updateTask(updatedTask);
                  } catch (e) {
                    debugPrint('Error deleting task step: $e');
                    _showErrorSnackBar(context, 'Failed to delete task step: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Premium Search Overlay ───────────────────────────────────────────────
  void _showSearchOverlay(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;
    final searchCtrl = TextEditingController(text: _searchQuery);
    String localQuery = _searchQuery;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = localQuery.trim().toLowerCase();
            final List<Map<String, dynamic>> results = [];

            if (query.isNotEmpty) {
              for (final session in _roadmapSessions) {
                final sessionMatches =
                    session.sessionLabel.toLowerCase().contains(query) ||
                    session.objective.toLowerCase().contains(query) ||
                    session.sessionCode.toLowerCase().contains(query);

                final matchingTasks = session.tasks
                    .where((t) =>
                        t.title.toLowerCase().contains(query) ||
                        t.description.toLowerCase().contains(query) ||
                        t.taskCode.toLowerCase().contains(query))
                    .toList();

                if (sessionMatches || matchingTasks.isNotEmpty) {
                  results.add({
                    'session': session,
                    'sessionMatches': sessionMatches,
                    'tasks': matchingTasks,
                  });
                }
              }
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 16,
                    right: 16,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 520),
                      decoration: BoxDecoration(
                        color: dialogBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.50 : 0.13),
                            blurRadius: 50,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Search Input Bar ──────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: searchCtrl,
                                    autofocus: true,
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search sessions, tasks, codes…',
                                      hintStyle: GoogleFonts.outfit(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (v) {
                                      setDialogState(() {
                                        localQuery = v;
                                        _searchQuery = v;
                                      });
                                    },
                                  ),
                                ),
                                if (localQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      searchCtrl.clear();
                                      setDialogState(() {
                                        localQuery = '';
                                        _searchQuery = '';
                                      });
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.black.withOpacity(0.07),
                          ),

                          // ── Results ───────────────────────────────────────
                          Flexible(
                            child: query.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 36),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_rounded, size: 42,
                                            color: isDark ? Colors.white12 : Colors.black12),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Type to search sessions & tasks',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : results.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 36),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.search_off_rounded, size: 42,
                                                color: isDark ? Colors.white12 : Colors.black12),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No results for "$localQuery"',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                        itemCount: results.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                                        itemBuilder: (_, i) {
                                          final entry = results[i];
                                          final session = entry['session'] as RoadmapSession;
                                          final matchingTasks = entry['tasks'] as List<HourlyTask>;
                                          final sessionMatches = entry['sessionMatches'] as bool;

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withOpacity(0.03)
                                                  : Colors.black.withOpacity(0.02),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white.withOpacity(0.06)
                                                    : Colors.black.withOpacity(0.05),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Session row
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: () => Navigator.pop(ctx),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 6,
                                                          height: 6,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: session.status == 'Active'
                                                                ? const Color(0xFF10B981)
                                                                : const Color(0xFFF59E0B),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            session.sessionLabel,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.bold,
                                                              color: sessionMatches
                                                                  ? const Color(0xFF6366F1)
                                                                  : textColor,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          session.sessionCode,
                                                          style: TextStyle(
                                                            fontFamily: 'monospace',
                                                            fontSize: 9,
                                                            color: isDark ? Colors.white38 : Colors.black38,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                // Matching task rows
                                                if (matchingTasks.isNotEmpty) ...[
                                                  Divider(
                                                    height: 1,
                                                    indent: 12,
                                                    endIndent: 12,
                                                    color: isDark
                                                        ? Colors.white.withOpacity(0.05)
                                                        : Colors.black.withOpacity(0.05),
                                                  ),
                                                  ...matchingTasks.map((task) => InkWell(
                                                    onTap: () => Navigator.pop(ctx),
                                                    child: Padding(
                                                      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.subdirectory_arrow_right_rounded,
                                                            size: 13,
                                                            color: isDark ? Colors.white24 : Colors.black26,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  task.title,
                                                                  style: GoogleFonts.outfit(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: textColor,
                                                                  ),
                                                                ),
                                                                if (task.description.isNotEmpty)
                                                                  Text(
                                                                    task.description,
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: GoogleFonts.outfit(
                                                                      fontSize: 10,
                                                                      color: isDark
                                                                          ? Colors.white38
                                                                          : Colors.black38,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: _getPriorityColor(task.priority)
                                                                  .withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              task.priority,
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                                color: _getPriorityColor(task.priority),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                          ),

                          // ── Footer count ─────────────────────────────────
                          if (query.isNotEmpty && results.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: Text(
                                '${results.length} session${results.length == 1 ? '' : 's'} found',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primary = const Color(0xFF6366F1);
    final bgTop = isDark ? Colors.black : const Color(0xFFF8F8FF);
    final bgBottom = isDark ? Colors.black : const Color(0xFFEEEEFF);
    final textColor = isDark ? Colors.white : Colors.black87;

    final isAdmin = ref.watch(authProvider).canCreateItems;

    final taskState = ref.watch(taskProvider);
    final activeTasks = taskState.allTasks;
    _roadmapSessions = activeTasks.map((t) => mapSystemTaskToSession(t)).toList();

    final trashedTasks = taskState.trashedTasks;
    _recycledSessions.clear();
    _recycledSessions.addAll(trashedTasks.map((t) => mapSystemTaskToSession(t)));

    final visibleSessions = _roadmapSessions.where((session) {
      if (_statusFilter == 'Active' && session.status != 'Active') return false;
      if (_statusFilter == 'Draft' && session.status != 'Draft') return false;

      final matchesScope = isAdmin ? true : session.status == 'Active';
      if (!matchesScope) return false;

      // ── Company filter ─────────────────────────────────────────────────────
      if (_selectedCompanyFilter != 'all') {
        final projectState = ref.read(projectProvider).valueOrNull;
        if (projectState != null) {
          // Find the underlying SystemTask for this session
          final sysTask = ref.read(taskProvider).allTasks
              .where((t) => t.id == session.id)
              .firstOrNull;
          if (sysTask != null && sysTask.projectId != null) {
            // Find the project linked to the task
            final project = projectState
                .where((p) => p.id == sysTask.projectId)
                .firstOrNull;
            if (project == null || project.companyId != _selectedCompanyFilter) {
              return false;
            }
          } else {
            return false; // Filter out if no task or projectId
          }
        }
      }

      if (_searchQuery.trim().isEmpty) return true;

      final query = _searchQuery.trim().toLowerCase();
      final titleMatches = session.sessionLabel.toLowerCase().contains(query);
      final descMatches = session.objective.toLowerCase().contains(query);
      final codeMatches = session.sessionCode.toLowerCase().contains(query);
      final taskMatches = session.tasks.any((t) =>
        t.title.toLowerCase().contains(query) ||
        t.description.toLowerCase().contains(query) ||
        t.taskCode.toLowerCase().contains(query)
      );

      return titleMatches || descMatches || codeMatches || taskMatches;
    }).toList();

    return Scaffold(
      backgroundColor: bgTop,
      body: Stack(
        children: [
          // Background Gradient and Glow Glob
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgTop, bgBottom],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.06),
                boxShadow: [
                  BoxShadow(color: primary.withOpacity(0.06), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Search bar, Recycle Bin and Filter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        // Search Input Bar (styled like company list page search bar)
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                            ),
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: TextStyle(color: textColor, fontSize: 13),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: 'Search roadmap sessions and tasks...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  IconsaxPlusLinear.search_normal_1,
                                  size: 16,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Recycle Bin Icon (Admin only)
                        if (isAdmin) ...[
                          Tooltip(
                            message: 'Recycle Bin',
                            child: InkWell(
                              onTap: () => _showRecycleBinDialog(context, isDark),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(IconsaxPlusBold.trash, color: Colors.redAccent, size: 16),
                                    if (_recycledSessions.isNotEmpty)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            '${_recycledSessions.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ).animate().shake(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Filter Icon
                        Tooltip(
                          message: 'Filter status',
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                            ),
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.filter_list_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              tooltip: 'Filter Status',
                              onSelected: (val) {
                                setState(() {
                                  _statusFilter = val;
                                });
                              },
                              color: isDark ? const Color(0xFF09090D) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'All',
                                  child: Text('All Statuses', style: GoogleFonts.outfit(color: textColor, fontSize: 13)),
                                ),
                                PopupMenuItem(
                                  value: 'Active',
                                  child: Text('Active Only', style: GoogleFonts.outfit(color: textColor, fontSize: 13)),
                                ),
                                PopupMenuItem(
                                  value: 'Draft',
                                  child: Text('Draft Only', style: GoogleFonts.outfit(color: textColor, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Company Category Bar ──────────────────────────────────
                  // Full-width horizontal scroll. Filters sessions by company.
                  _buildCompanyCategoryBar(isDark, primary),

                  // Main Timeline Cards Container - FULL WIDTH, ONE BY ONE LIST (Single Column)
                    Expanded(
                      child: _isLoading && _roadmapSessions.isEmpty
                          ? Center(
                              child: CircularProgressIndicator(color: primary),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRoadmapData,
                              color: primary,
                              backgroundColor: isDark ? const Color(0xFF09090D) : Colors.white,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemCount: visibleSessions.length,
                                itemBuilder: (context, index) {
                                  final roadmap = visibleSessions[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20.0),
                                    child: _buildSessionCard(roadmap, isDark, primary, textColor),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildSessionCard(RoadmapSession roadmap, bool isDark, Color primary, Color textColor) {
    final double completeCount = roadmap.tasks.where((t) => t.status == 'Complete').length.toDouble();
    final double processCount = roadmap.tasks.where((t) => t.status == 'Process').length.toDouble();
    final double holdCount = roadmap.tasks.where((t) => t.status == 'Hold').length.toDouble();
    final double totalCount = roadmap.tasks.length.toDouble();
    
    // Calculate progress percentage (Complete counts full, Process counts half, Hold counts zero)
    final double percent = totalCount > 0 
        ? (completeCount + processCount * 0.5) / totalCount 
        : 0.0;

    final isLatestSession = _roadmapSessions.isNotEmpty && roadmap == _roadmapSessions.first;

    final projects = ref.watch(projectProvider).maybeWhen(
      data: (d) => d,
      orElse: () => <Project>[],
    );
    final tasks = ref.watch(taskProvider).allTasks;
    final taskMatches = tasks.where((t) => t.id == roadmap.id);
    SystemTask? targetTask;
    Project? linkedProject;
    Plan? linkedPlan;
    
    if (taskMatches.isNotEmpty) {
      final t = taskMatches.first;
      targetTask = t;
      if (t.projectId != null) {
        final matches = projects.where((p) => p.id == t.projectId);
        if (matches.isNotEmpty) {
          linkedProject = matches.first;
          if (t.planId != null) {
            final planMatches = linkedProject.plans.where((p) => p.id == t.planId);
            if (planMatches.isNotEmpty) {
              linkedPlan = planMatches.first;
            }
          }
        }
      }
    }

    return Container(
      width: double.infinity, // Ensures full-width behavior
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: roadmap.status == 'Draft'
              ? const Color(0xFFF59E0B).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
          width: roadmap.status == 'Draft' ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (linkedProject != null) ...[
                  Text(
                    '${linkedProject.companyName ?? 'Company'}  /  ${linkedProject.name}  /  ${linkedPlan != null ? "${linkedPlan.title} (${linkedPlan.icode})" : "Private Plan"}',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: primary.withOpacity(0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (ref.read(authProvider).canCreateItems) {
                                  _showSessionConfigDialog(context, roadmap, isDark);
                                }
                              },
                              child: Text(
                                roadmap.sessionLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roadmap.status == 'Draft'
                                  ? const Color(0xFFF59E0B).withOpacity(0.12)
                                  : const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: roadmap.status == 'Draft'
                                    ? const Color(0xFFF59E0B).withOpacity(0.3)
                                    : const Color(0xFF10B981).withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  roadmap.status == 'Draft'
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 10,
                                  color: roadmap.status == 'Draft'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  roadmap.status == 'Draft' ? 'DRAFT' : 'ACTIVE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: roadmap.status == 'Draft'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Session Code (Copy on Tap)
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: roadmap.sessionCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Task Code ${roadmap.sessionCode} copied to clipboard', style: GoogleFonts.outfit(fontSize: 12)),
                                  duration: const Duration(milliseconds: 800),
                                  backgroundColor: const Color(0xFF6366F1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                roadmap.sessionCode,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Settings icon for session configuration
                    if (_isAdmin) ...[
                      IconButton(
                        icon: Icon(IconsaxPlusLinear.setting_4, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSessionConfigDialog(context, roadmap, isDark),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Removed Add Task Button since step creation is moved elsewhere
                    if (!_isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 10, color: isDark ? Colors.white30 : Colors.black38),
                            const SizedBox(width: 4),
                            Text('Read-Only (Team Scope)', style: GoogleFonts.outfit(fontSize: 8.5, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    // Collapse Toggle Icon (Exclusive toggle area)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_expandedSessionIds.contains(roadmap.id)) {
                            _expandedSessionIds.remove(roadmap.id);
                          } else {
                            _expandedSessionIds.add(roadmap.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          _expandedSessionIds.contains(roadmap.id) ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Created, Updated Times & Author
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconsaxPlusLinear.calendar, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          'Created: ${_dateTimeFormat.format(roadmap.createdAt)}',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconsaxPlusLinear.timer_1, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${_dateTimeFormat.format(roadmap.updatedAt)}',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconsaxPlusLinear.user, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          'Author: ${roadmap.author}',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Indicator Row & Stats badges
                Row(
                  children: [
                    // Small progress bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(percent * 100).toInt()}%',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: primary),
                    ),
                    const SizedBox(width: 16),
                    
                    // Task Summary Badge: Complete
                    _buildSummaryBadge('${completeCount.toInt()}', const Color(0xFF10B981), isDark),
                    const SizedBox(width: 6),
                    // Task Summary Badge: Process
                    _buildSummaryBadge('${processCount.toInt()}', const Color(0xFF6366F1), isDark),
                    const SizedBox(width: 6),
                    // Task Summary Badge: Hold
                    _buildSummaryBadge('${holdCount.toInt()}', const Color(0xFFF59E0B), isDark),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Dense List of Tasks (Built directly inside the column of the Day Card)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _expandedSessionIds.contains(roadmap.id) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: roadmap.tasks.isEmpty
                ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconsaxPlusLinear.add_circle, size: 24, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 6),
                        Text(
                          'No scheduled tasks.',
                          style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: roadmap.tasks.map((task) {
                      return _buildTaskTimelineItem(roadmap, task, isDark, primary, textColor);
                    }).toList(),
                  ),
                ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSummaryBadge(String count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        count,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTaskTimelineItem(RoadmapSession roadmap, HourlyTask task, bool isDark, Color primary, Color textColor) {
    final priorityColor = _getPriorityColor(task.priority);
    final statusColor = _getStatusColor(task.status);
    final lineColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final bool isMobile = MediaQuery.of(context).size.width < 500;

    final titleWidget = GestureDetector(
      onTap: () {
        if (ref.read(authProvider).canCreateItems) {
          _showTaskConfigDialog(context, roadmap, task, isDark);
        }
      },
      child: Text(
        task.title,
        style: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: task.status == 'Complete' ? Colors.grey : (isDark ? Colors.white : Colors.black87),
          decoration: task.status == 'Complete' ? TextDecoration.lineThrough : null,
        ),
      ),
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ref.read(authProvider).canCreateItems) ...[
          IconButton(
            icon: Icon(IconsaxPlusLinear.setting_2, size: 16, color: isDark ? Colors.white54 : Colors.black54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showTaskConfigDialog(context, roadmap, task, isDark),
          ),
          const SizedBox(width: 8),
          _buildStatusIndicatorBtn(context, roadmap, task, 'Complete', const Color(0xFF10B981)),
          const SizedBox(width: 4),
          _buildStatusIndicatorBtn(context, roadmap, task, 'Process', const Color(0xFF6366F1)),
          const SizedBox(width: 4),
          _buildStatusIndicatorBtn(context, roadmap, task, 'Hold', const Color(0xFFF59E0B)),
        ],
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator (Stitched cleanly without gaps)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top stitch
                Container(width: 2, height: 16, color: lineColor),
                GestureDetector(
                  onTap: () async {
                    if (!_isAdmin) return;
                    if (task.isLocked && roadmap.status == 'Active') {
                      _showLockedWarning(context);
                      return;
                    }
                    final newStatus = task.status == 'Process'
                        ? 'Complete'
                        : (task.status == 'Complete' ? 'Hold' : 'Process');
                    try {
                      final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == roadmap.id);
                      final updatedSteps = targetTask.roadmapSteps.map((step) {
                        if (step.id == task.id) {
                          return step.copyWith(status: newStatus);
                        }
                        return step;
                      }).toList();
                      final updatedTask = targetTask.copyWith(roadmapSteps: updatedSteps);
                      await ref.read(taskProvider).updateTask(updatedTask);
                    } catch (e) {
                      debugPrint('Error updating task status: $e');
                    }
                  },
                  child: Tooltip(
                    message: !_isAdmin
                        ? 'Status: ${task.status}'
                        : (task.isLocked ? 'Locked' : 'Change Status: ${task.status}'),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: task.status == 'Complete'
                            ? const Color(0xFF10B981)
                            : (task.status == 'Process' ? const Color(0xFF6366F1).withOpacity(0.12) : const Color(0xFFF59E0B).withOpacity(0.12)),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          task.status == 'Complete'
                              ? Icons.check
                              : (task.status == 'Process' ? Icons.play_arrow_rounded : Icons.pause),
                          size: 11,
                          color: task.status == 'Complete' ? Colors.white : statusColor,
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom stitch
                Expanded(child: Container(width: 2, color: lineColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Task details panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMobile)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                titleWidget,
                                _buildMiniTag('${_taskTimeFormat.format(task.startTime)} - ${_taskTimeFormat.format(task.endTime)}', primary, isDark, icon: IconsaxPlusLinear.calendar),
                                _buildMiniTag(task.priority.toUpperCase(), priorityColor, isDark),
                                _buildMiniTag(task.status.toUpperCase(), statusColor, isDark),
                                _buildMiniTag(task.taskCode, isDark ? Colors.white54 : Colors.black54, isDark, isCode: true),
                                if (task.isLocked) _buildMiniTag('LOCKED', Colors.redAccent, isDark, icon: Icons.lock_rounded),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          actionsRow,
                        ],
                      )
                    else ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMiniTag('${_taskTimeFormat.format(task.startTime)} - ${_taskTimeFormat.format(task.endTime)}', primary, isDark, icon: IconsaxPlusLinear.calendar),
                          _buildMiniTag(task.priority.toUpperCase(), priorityColor, isDark),
                          _buildMiniTag(task.status.toUpperCase(), statusColor, isDark),
                          _buildMiniTag(task.taskCode, isDark ? Colors.white54 : Colors.black54, isDark, isCode: true),
                          if (task.isLocked) _buildMiniTag('LOCKED', Colors.redAccent, isDark, icon: Icons.lock_rounded),
                        ],
                      ),
                      const SizedBox(height: 6),
                      titleWidget,
                      const SizedBox(height: 8),
                      actionsRow,
                    ],
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildTimelineTaskDescription(task.description, task.id, isDark),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color, bool isDark, {IconData? icon, bool isCode = false}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: isCode ? Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 0.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: isCode 
              ? TextStyle(fontFamily: 'monospace', fontSize: 7.5, fontWeight: FontWeight.bold, color: color)
              : GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
    if (isCode) {
      return InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: text));
        },
        borderRadius: BorderRadius.circular(4),
        child: child,
      );
    }
    return child;
  }

  Widget _buildStatusIndicatorBtn(BuildContext context, RoadmapSession roadmap, HourlyTask task, String targetStatus, Color color) {
    final isActive = task.status == targetStatus;
    final isLocked = task.isLocked && roadmap.status == 'Active';

    return InkWell(
      onTap: isLocked
          ? () => _showLockedWarning(context)
          : () async {
              try {
                final targetTask = ref.read(taskProvider).allTasks.firstWhere((t) => t.id == roadmap.id);
                final updatedSteps = targetTask.roadmapSteps.map((step) {
                  if (step.id == task.id) {
                    // Persist full 3-state status (not just isCompleted boolean)
                    return step.copyWith(status: targetStatus);
                  }
                  return step;
                }).toList();
                final updatedTask = targetTask.copyWith(roadmapSteps: updatedSteps);
                await ref.read(taskProvider).updateTask(updatedTask);
              } catch (e) {
                debugPrint('Error updating task status: $e');
              }
            },
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: isLocked ? 0.35 : 1.0,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4), width: 0.5),
          ),
          child: Center(
            child: Icon(
              targetStatus == 'Complete'
                  ? Icons.check
                  : (targetStatus == 'Process' ? Icons.play_arrow_rounded : Icons.pause),
              size: 12,
              color: isActive ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
