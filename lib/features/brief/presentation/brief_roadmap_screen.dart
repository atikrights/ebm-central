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

  bool get _isAdmin => ref.read(authProvider).canCreateItems;

  @override
  void initState() {
    super.initState();
    _roadmapSessions = [];
    _loadRoadmapData();
  }

  Future<void> _loadRoadmapData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final sessionsDynamic = await api.get('/roadmap/sessions');
      final recycledDynamic = await api.get('/roadmap/sessions/trashed');
      
      if (!mounted) return;
      setState(() {
        if (sessionsDynamic is List) {
          _roadmapSessions = sessionsDynamic.map((s) => RoadmapSession.fromJson(s)).toList();
        } else {
          _roadmapSessions = [];
        }
        if (recycledDynamic is List) {
          _recycledSessions.clear();
          _recycledSessions.addAll(recycledDynamic.map((s) => RoadmapSession.fromJson(s)));
        } else {
          _recycledSessions.clear();
        }
      });
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
    final sessionLabelCtrl = TextEditingController();
    final objectiveCtrl = TextEditingController();

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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sessionLabelCtrl,
                  style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Session Title (e.g. Session 4: Final Verification)',
                    labelStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                  ),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (sessionLabelCtrl.text.trim().isNotEmpty) {
                    final now = DateTime.now();
                    final newSession = RoadmapSession(
                      id: 'session_${now.millisecondsSinceEpoch}',
                      sessionLabel: sessionLabelCtrl.text.trim(),
                      objective: objectiveCtrl.text.trim(),
                      tasks: [],
                      createdAt: now,
                      updatedAt: now,
                      status: 'Active',
                    );
                    Navigator.pop(ctx);
                    try {
                      final api = ref.read(apiServiceProvider);
                      await api.post('/roadmap/sessions', newSession.toJson());
                      _loadRoadmapData();
                    } catch (e) {
                      debugPrint('Error creating session: $e');
                      _showErrorSnackBar(context, 'Failed to create session: $e');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Create', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                          final api = ref.read(apiServiceProvider);
                          await api.put('/roadmap/sessions/${session.id}', {
                            'sessionLabel': titleCtrl.text.trim(),
                            'objective': objectiveCtrl.text.trim(),
                            'status': status,
                          });
                          _loadRoadmapData();
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
                    final api = ref.read(apiServiceProvider);
                    await api.delete('/roadmap/sessions/${session.id}');
                    _loadRoadmapData();
                    
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
                              await api.post('/roadmap/sessions/${session.id}/restore', {});
                              _loadRoadmapData();
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
                                        final api = ref.read(apiServiceProvider);
                                        await api.delete('/roadmap/sessions/empty-trash');
                                        _loadRoadmapData();
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
                                                  final api = ref.read(apiServiceProvider);
                                                  await api.post('/roadmap/sessions/${session.id}/restore', {});
                                                  _loadRoadmapData();
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
                                                              final api = ref.read(apiServiceProvider);
                                                              await api.delete('/roadmap/sessions/${session.id}/force-delete');
                                                              _loadRoadmapData();
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
                              final newTask = HourlyTask(
                                id: 'task_${DateTime.now().millisecondsSinceEpoch}',
                                startTime: startDateTime,
                                endTime: endDateTime,
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                priority: priority,
                                status: status,
                              );
                              Navigator.pop(ctx);
                              try {
                                final api = ref.read(apiServiceProvider);
                                await api.post('/roadmap/sessions/${roadmap.id}/tasks', newTask.toJson());
                                _loadRoadmapData();
                              } catch (e) {
                                debugPrint('Error adding task: $e');
                                _showErrorSnackBar(context, 'Failed to add task: $e');
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
                      // Edit Title
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
                      
                      // Edit Description
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
                            onChanged: (val) {
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
                        onChanged: (val) {
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
                    onPressed: isTimeValid
                        ? () async {
                            if (titleCtrl.text.trim().isNotEmpty) {
                              Navigator.pop(ctx);
                              try {
                                final api = ref.read(apiServiceProvider);
                                await api.put('/roadmap/tasks/${task.id}', {
                                  'title': titleCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'startTime': startDateTime.toIso8601String(),
                                  'endTime': endDateTime.toIso8601String(),
                                  'priority': priority,
                                  'isLocked': isLockedState,
                                });
                                _loadRoadmapData();
                              } catch (e) {
                                debugPrint('Error updating task: $e');
                                _showErrorSnackBar(context, 'Failed to update task config: $e');
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Configurations', style: GoogleFonts.outfit(color: isTimeValid ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    final api = ref.read(apiServiceProvider);
                    await api.delete('/roadmap/tasks/${task.id}');
                    _loadRoadmapData();
                  } catch (e) {
                    debugPrint('Error deleting task: $e');
                    _showErrorSnackBar(context, 'Failed to delete task: $e');
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

    final visibleSessions = _roadmapSessions.where((session) {
      if (isAdmin) return true; // Admins see all (both Active & Draft/Private)
      return session.status == 'Active'; // Team members see only Active
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
                  // Header (Dense Layout)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DAILY SCHEDULE ROADMAP',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: primary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '24-Hour Operations Timeline',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Search icon — always visible, left of Recycle Bin
                              IconButton(
                                icon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: textColor.withOpacity(0.7),
                                ),
                                tooltip: 'Search Sessions & Tasks',
                                onPressed: () =>
                                    _showSearchOverlay(context, isDark),
                              ),
                              if (isAdmin) ...[
                                IconButton(
                                  icon: Badge(
                                    isLabelVisible: _recycledSessions.isNotEmpty,
                                    label: Text(
                                      '${_recycledSessions.length}',
                                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(IconsaxPlusLinear.trash, size: 20, color: textColor.withOpacity(0.7)),
                                  ),
                                  tooltip: 'Recycle Bin',
                                  onPressed: () => _showRecycleBinDialog(context, isDark),
                                ),
                                const SizedBox(width: 8),
                                // Add Session Button
                                ElevatedButton.icon(
                                  onPressed: () => _showAddSessionDialog(context, isDark),
                                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                  label: Text('Add Session', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ).animate().scale(begin: const Offset(0.9, 0.9)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              roadmap.sessionLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
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
                                  content: Text('Session Code ${roadmap.sessionCode} copied to clipboard', style: GoogleFonts.outfit(fontSize: 12)),
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
                    // Conditionally show add task button if newest/latest session and Admin
                    if (_isAdmin && isLatestSession)
                      InkWell(
                        onTap: () => _showAddTaskDialog(context, roadmap, isDark),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: primary),
                              const SizedBox(width: 4),
                              Text('Task', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: primary)),
                            ],
                          ),
                        ),
                      )
                    else if (_isAdmin)
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
                            Text('Read-Only (Tasks Locked)', style: GoogleFonts.outfit(fontSize: 8.5, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else
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
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  roadmap.objective,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

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
          roadmap.tasks.isEmpty
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
    final statusIcon = _getStatusIcon(task.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Small vertical line with timeline indicator dot
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 1.0,
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Task details panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  ),
                ),
                child: Row(
                  children: [
                    // Custom cyclical status indicator action
                    GestureDetector(
                      onTap: () async {
                        if (!_isAdmin) return; // only admin can change status
                        if (task.isLocked) {
                          _showLockedWarning(context);
                          return;
                        }
                        final newStatus = task.status == 'Process'
                            ? 'Complete'
                            : (task.status == 'Complete' ? 'Hold' : 'Process');
                        try {
                          final api = ref.read(apiServiceProvider);
                          setState(() {
                            task.status = newStatus;
                            roadmap.updatedAt = DateTime.now();
                          });
                          await api.put('/roadmap/tasks/${task.id}', {'status': newStatus});
                          _loadRoadmapData();
                        } catch (e) {
                          debugPrint('Error updating task status: $e');
                        }
                      },
                      child: Tooltip(
                        message: !_isAdmin
                            ? 'Status: ${task.status}'
                            : (task.isLocked 
                                ? 'Locked - Unlock in config' 
                                : 'Status: ${task.status} (Tap to change)'),
                        child: Icon(
                          statusIcon,
                          size: 18,
                          color: !_isAdmin 
                              ? Colors.grey 
                              : (task.isLocked ? Colors.grey : statusColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Start - End Timeline Dates
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(IconsaxPlusLinear.calendar, size: 9, color: primary.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_taskTimeFormat.format(task.startTime)} - ${_taskTimeFormat.format(task.endTime)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: primary,
                                    ),
                                  ),
                                ],
                              ),
                              // Priority tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: priorityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.priority.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                    color: priorityColor,
                                  ),
                                ),
                              ),
                              // Status mini tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.status.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              // Task Code (Copy on Tap)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: task.taskCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Task Code ${task.taskCode} copied to clipboard', style: GoogleFonts.outfit(fontSize: 12)),
                                      duration: const Duration(milliseconds: 800),
                                      backgroundColor: const Color(0xFF6366F1),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
                                  ),
                                  child: Text(
                                    task.taskCode,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                              // Locked badge
                              if (task.isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 8, color: Colors.redAccent),
                                      const SizedBox(width: 2),
                                      Text(
                                        'LOCKED',
                                        style: GoogleFonts.outfit(
                                          fontSize: 6.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Task Title (unlimited wrap)
                          Text(
                            task.title,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: task.status == 'Complete'
                                  ? Colors.grey
                                  : (isDark ? Colors.white70 : Colors.black87),
                              decoration: task.status == 'Complete' ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            // Task Desc (unlimited wrap)
                            Text(
                              task.description,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Config button (gear icon) and quick inline buttons (Admin only)
                    if (ref.read(authProvider).canCreateItems) ...[
                      IconButton(
                        icon: Icon(IconsaxPlusLinear.setting_2, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showTaskConfigDialog(context, roadmap, task, isDark),
                      ),
                      const SizedBox(width: 10),

                      // Quick inline change buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusIndicatorBtn(context, roadmap, task, 'Complete', const Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          _buildStatusIndicatorBtn(context, roadmap, task, 'Process', const Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          _buildStatusIndicatorBtn(context, roadmap, task, 'Hold', const Color(0xFFF59E0B)),
                        ],
                      ),
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

  Widget _buildStatusIndicatorBtn(BuildContext context, RoadmapSession roadmap, HourlyTask task, String targetStatus, Color color) {
    final isActive = task.status == targetStatus;
    final isLocked = task.isLocked;
    
    return InkWell(
      onTap: isLocked 
        ? () => _showLockedWarning(context) 
        : () async {
            try {
              final api = ref.read(apiServiceProvider);
              setState(() {
                task.status = targetStatus;
                roadmap.updatedAt = DateTime.now(); // update day card updatedAt time
              });
              await api.put('/roadmap/tasks/${task.id}', {'status': targetStatus});
              _loadRoadmapData();
            } catch (e) {
              debugPrint('Error updating task status: $e');
            }
          },
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: isLocked ? 0.35 : 1.0,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.4), width: 0.5),
          ),
          child: Center(
            child: Icon(
              targetStatus == 'Complete'
                  ? Icons.check
                  : (targetStatus == 'Process' ? Icons.play_arrow_rounded : Icons.pause),
              size: 8,
              color: isActive ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
