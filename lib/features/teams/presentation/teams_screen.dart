import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/governance/presentation/approval_center_screen.dart';


// Models
class TeamMember {
  final String name;
  final String email;
  final String role;
  TeamMember({required this.name, required this.email, required this.role});
  
  factory TeamMember.fromJson(Map<String, dynamic> json) {
    String parsedRole = json['role'] ?? '';
    if (json['pivot'] != null && json['pivot']['role'] != null) {
      parsedRole = json['pivot']['role'];
    }
    
    return TeamMember(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: parsedRole,
    );
  }
}

class Team {
  final String id;
  final String name;
  final String teamCode;
  final List<TeamMember> members;
  Team({required this.id, required this.name, required this.teamCode, required this.members});
  
  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      teamCode: json['team_code'] ?? '',
      members: (json['members'] as List?)?.map((m) => TeamMember.fromJson(m)).toList() ?? [],
    );
  }
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

  @override
  void initState() {
    super.initState();
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
            return const Center(child: Text('No Teams Found. Create one.'));
          }
          final team = response.teams.first; // Display the first team for now
          
          final admins = team.members.where((m) => m.role == 'admin' || m.role == 'sub_admin' || m.role == 'leader').toList();
          final managers = team.members.where((m) => m.role == 'manager').toList();
          final staffs = team.members.where((m) => m.role == 'staff').toList();

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
                  child: isDesktop 
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTeamColumn('Admins (Sub-Admins)', admins, context, team.id)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTeamColumn('Managers', managers, context, team.id)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTeamColumn('Staff', staffs, context, team.id)),
                        ],
                      )
                    : ListView(
                        children: [
                          _buildTeamColumn('Admins (Sub-Admins)', admins, context, team.id),
                          const SizedBox(height: 16),
                          _buildTeamColumn('Managers', managers, context, team.id),
                          const SizedBox(height: 16),
                          _buildTeamColumn('Staff', staffs, context, team.id),
                        ],
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamColumn(String title, List<TeamMember> members, BuildContext context, String teamId) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                onPressed: () {
                  _showInviteDialog(context, title, teamId);
                },
              )
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          members.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No members yet.', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: Text(m.name[0], style: const TextStyle(color: Colors.blueAccent)),
                    ),
                    title: Text(m.name),
                    subtitle: Text(m.email, style: const TextStyle(fontSize: 12)),
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
