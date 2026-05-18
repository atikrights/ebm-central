import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/chat/data/websocket_service.dart';
import 'package:frontend/features/governance/presentation/approval_center_screen.dart';
import 'package:frontend/features/projects/providers/project_provider.dart';
import 'package:frontend/features/projects/models/project.dart';
import 'package:frontend/features/tasks/providers/task_provider.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class TeamMember {
  final int id;
  final String name;
  final String email;
  final String role;        // Team pivot role: leader, sub_admin, manager, staff
  final String systemRole;  // User's system role: admin, manager, staff
  final String? chatProfileId;
  final String? uid;

  TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.systemRole,
    this.chatProfileId,
    this.uid,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    // Prefer pivot role (team role) over system role for display categorization
    String pivotRole = '';
    if (json['pivot'] != null && json['pivot']['role'] != null) {
      pivotRole = json['pivot']['role'].toString();
    }
    // Fallback to system role if no pivot
    String systemRole = json['role']?.toString() ?? 'staff';
    String displayRole = pivotRole.isNotEmpty ? pivotRole : systemRole;

    return TeamMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: displayRole,
      systemRole: systemRole,
      chatProfileId: json['chat_profile_id']?.toString(),
      uid: json['uid']?.toString(),
    );
  }

  /// Returns a user-friendly label for the role badge
  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'leader': return 'Admin';
      case 'sub_admin': return 'Sub-Admin';
      case 'manager': return 'Manager';
      case 'staff': return 'Staff';
      default: return role.toUpperCase();
    }
  }

  bool get isAuthority => ['leader', 'sub_admin'].contains(role.toLowerCase());
}

class TeamCompany {
  final int id;
  final String name;
  final String slug;

  TeamCompany({required this.id, required this.name, required this.slug});

  factory TeamCompany.fromJson(Map<String, dynamic> json) {
    return TeamCompany(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class Team {
  final int id;
  final String name;
  final String description;
  final String? logoUrl;
  final String teamCode;
  final List<TeamMember> members;
  final String? leaderName;
  final List<TeamCompany> companies;

  Team({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    required this.teamCode,
    required this.members,
    this.leaderName,
    required this.companies,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    // Parse companies (new architecture: Team hasMany Companies)
    List<TeamCompany> companies = [];
    if (json['companies'] != null) {
      companies = (json['companies'] as List)
          .map((c) => TeamCompany.fromJson(c))
          .toList();
    }

    return Team(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      logoUrl: json['logo_url'],
      teamCode: json['team_code'] ?? '',
      members: (json['members'] as List?)
              ?.map((m) => TeamMember.fromJson(m))
              .toList() ??
          [],
      leaderName: json['leader']?['name']?.toString(),
      companies: companies,
    );
  }

  /// All admins/sub-admins in this team
  List<TeamMember> get authorities =>
      members.where((m) => m.isAuthority).toList();

  /// Managers in this team
  List<TeamMember> get managers =>
      members.where((m) => m.role.toLowerCase() == 'manager').toList();

  /// Staff in this team
  List<TeamMember> get staff =>
      members.where((m) => m.role.toLowerCase() == 'staff').toList();
}

class TeamsResponse {
  final bool hasSeenWelcome;
  final List<Team> teams;
  TeamsResponse({required this.hasSeenWelcome, required this.teams});
  
  factory TeamsResponse.fromJson(Map<String, dynamic> json) {
    bool seen = false;
    if (json['has_seen_welcome'] is bool) {
      seen = json['has_seen_welcome'];
    } else if (json['has_seen_welcome'] is int) {
      seen = json['has_seen_welcome'] == 1;
    }

    return TeamsResponse(
      hasSeenWelcome: seen,
      teams: (json['teams'] as List?)?.map((t) => Team.fromJson(t)).toList() ?? [],
    );
  }
}

final teamsProvider = FutureProvider<TeamsResponse>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.get('/teams');
    return TeamsResponse.fromJson(response);
  } catch (e) {
    // Return a default empty state if API fails for now to avoid crash
    return TeamsResponse(hasSeenWelcome: true, teams: []);
  }
});

class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  bool _hasSeenWelcome = false;
  Timer? _refreshTimer;

  void _onWsEvent(PusherEvent event) {
    if (event.eventName.contains('data.updated') || event.eventName.contains('user.created')) {
      if (mounted) {
        ref.invalidate(teamsProvider);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Real-time listener for "God Mode" updates
    ref.read(webSocketServiceProvider).addListener(_onWsEvent);

    // Auto-refresh fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        ref.invalidate(teamsProvider);
      }
    });
  }

  @override
  void dispose() {
    ref.read(webSocketServiceProvider).removeListener(_onWsEvent);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showWelcomePopup() {
    if (_hasSeenWelcome) return;
    _hasSeenWelcome = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => TeamsWelcomePopup(
          onGetStarted: () async {
            try {
              await ref.read(apiServiceProvider).post('/teams/welcome-seen', {});
            } catch (e) {
              debugPrint('Failed to mark welcome as seen: $e');
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (response) {
          if (!response.hasSeenWelcome) {
            _showWelcomePopup();
          }

          if (response.teams.isEmpty) {
            return const Center(child: Text('No Teams Found in the system.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TEAM GOVERNANCE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalCenterScreen()));
                      },
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: const Text("APPROVAL CENTER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                  Expanded(
                  child: ListView.builder(
                    itemCount: response.teams.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final team = response.teams[index];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team header (shown only when multiple teams)
                          if (response.teams.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 24, bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.group_work_rounded, size: 14, color: Colors.blueAccent),
                                        const SizedBox(width: 6),
                                        Text(team.name.toUpperCase(),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('ID: ${team.teamCode}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
                                  ),
                                ],
                              ),
                            ),
                          isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildTeamColumn('Admins & Sub-Admins', team.authorities, context, team.id)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTeamColumn('Managers', team.managers, context, team.id)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTeamColumn('Staff', team.staff, context, team.id)),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildTeamColumn('Admins & Sub-Admins', team.authorities, context, team.id),
                                  const SizedBox(height: 16),
                                  _buildTeamColumn('Managers', team.managers, context, team.id),
                                  _buildTeamColumn('Staff', team.staff, context, team.id),
                                ],
                              ),
                          const SizedBox(height: 24),
                          _buildTeamProjectsAndTasks(team, context, ref),
                          const SizedBox(height: 48),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamColumn(String title, List<TeamMember> members, BuildContext context, int teamId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${members.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                    onPressed: () => _showInviteDialog(context, title, teamId.toString()),
                    tooltip: 'Invite member',
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          members.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_rounded, size: 16, color: Colors.grey.withOpacity(0.4)),
                    const SizedBox(width: 8),
                    const Text('No members yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final m = members[index];
                  final badgeColor = m.isAuthority
                    ? Colors.blueAccent
                    : (m.role == 'manager' ? Colors.orange : Colors.green);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: badgeColor.withOpacity(0.12),
                          child: Text(m.name[0].toUpperCase(),
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(m.email, style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.7)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.2)),
                          ),
                          child: Text(m.roleLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
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

  void _showInviteDialog(BuildContext context, String roleSection, String teamId) {
    final emailController = TextEditingController();
    bool migrateData = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Invite to $roleSection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (roleSection.contains('Admin'))
                CheckboxListTile(
                  title: const Text('Migrate their existing data?'),
                  subtitle: const Text('Brings their projects/tasks under this team.'),
                  value: migrateData,
                  onChanged: (val) {
                    setDialogState(() => migrateData = val ?? true);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                String roleInTeam = 'staff';
                if (roleSection.contains('Admin')) roleInTeam = 'sub_admin';
                else if (roleSection.contains('Manager')) roleInTeam = 'manager';

                try {
                  await ref.read(apiServiceProvider).post('/teams/$teamId/invite', {
                    'email': email,
                    'role_in_team': roleInTeam,
                    'migrate_data': migrateData,
                  });
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invited $email successfully!')),
                    );
                    ref.refresh(teamsProvider); // Refresh the UI
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamProjectsAndTasks(Team team, BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectState = ref.watch(projectProvider);
    final taskState = ref.watch(taskProvider);

    final companyIds = team.companies.map((c) => c.id.toString()).toSet();
    
    int projectCount = 0;
    int taskCount = 0;

    projectState.whenData((projects) {
      final teamProjects = projects.where((p) => companyIds.contains(p.companyId)).toList();
      projectCount = teamProjects.length;
      
      final teamProjectIds = teamProjects.map((p) => p.id).toSet();
      taskCount = taskState.allTasks.where((t) => teamProjectIds.contains(t.projectId)).length;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.folder_shared_rounded, color: Colors.indigo),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attached Projects', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 4),
                    Text('$projectCount Project${projectCount != 1 ? 's' : ''} in Team View', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 40, width: 1, color: isDark ? Colors.white10 : Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 24)),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.task_alt_rounded, color: Colors.teal),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Team Tasks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 4),
                    Text('$taskCount Active Task${taskCount != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TeamsWelcomePopup extends ConsumerWidget {
  final VoidCallback onGetStarted;
  
  const TeamsWelcomePopup({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_work_rounded, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                'Welcome to Teams!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Build your hierarchy. Invite Sub-Admins, Managers, and Staff to collaborate in real-time. Control your entire ecosystem from one place.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.blueAccent,
                  ),
                  onPressed: onGetStarted,
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}



