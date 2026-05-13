import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../../../core/auth/auth_provider.dart';
import 'teams_screen.dart'; // To access teamsProvider and models

class TeamsControlScreen extends ConsumerStatefulWidget {
  const TeamsControlScreen({super.key});

  @override
  ConsumerState<TeamsControlScreen> createState() => _TeamsControlScreenState();
}

class _TeamsControlScreenState extends ConsumerState<TeamsControlScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  Timer? _refreshTimer;

  final List<String> _tabs = ['General', 'Setting', 'Teams Profile', 'Activity'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Auto-refresh every 5 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        ref.invalidate(teamsProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamsAsync = ref.watch(teamsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill-shaped Category Tabs (Chat Style)
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;
                      final color = Colors.blueAccent;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                              ? color.withOpacity(isDark ? 0.2 : 0.1) 
                              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.none,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Real-time Sync Indicator
              _buildSyncIndicator(isDark, teamsAsync.isLoading),
            ],
          ),
        ),
        
        // Content Section
        Expanded(
          child: teamsAsync.when(
            data: (response) {
              if (response.teams.isEmpty) {
                return const Center(child: Text('No team data available.'));
              }
              final team = response.teams.first;
              
              return PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedIndex = index);
                },
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildTabContent(context, 'General', Icons.dashboard_customize_rounded),
                  _buildTabContent(context, 'Setting', Icons.settings_rounded),
                  _buildTeamsProfile(context, team, isDark),
                  _buildTabContent(context, 'Activity', Icons.local_activity_rounded),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamsProfile(BuildContext context, Team team, bool isDark) {
    final admins = team.members.where((m) => m.role == 'leader' || m.role == 'sub_admin').toList();
    final managers = team.members.where((m) => m.role == 'manager').toList();
    final staffs = team.members.where((m) => m.role == 'staff').toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          children: [
            // Team Identity Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.08),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                      image: team.logoUrl != null && team.logoUrl!.isNotEmpty
                        ? DecorationImage(image: NetworkImage(team.logoUrl!), fit: BoxFit.cover)
                        : null,
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
                      ],
                    ),
                    child: team.logoUrl == null || team.logoUrl!.isEmpty
                      ? const Icon(Icons.group_work_rounded, size: 60, color: Colors.blueAccent)
                      : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 12),
                      _buildProfileEditTrigger(context, team),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 12, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text(
                          'TEAM ID: ${team.teamCode}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.blueAccent, fontSize: 10, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Text(
                      team.description.isEmpty 
                        ? 'No description provided for this team. Admins can add one to help members understand the team\'s mission.' 
                        : team.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54, 
                        fontSize: 14, 
                        height: 1.6,
                        fontStyle: team.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            // Member Showcase Level Sections
            _buildMemberSection('Primary Authorities', admins, Icons.admin_panel_settings_rounded, isDark),
            _buildMemberSection('Management Layer', managers, Icons.manage_accounts_rounded, isDark),
            _buildMemberSection('Staff Operations', staffs, Icons.badge_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileEditTrigger(BuildContext context, Team team) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.blueAccent),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _showTeamEditDialog(context, team),
        tooltip: 'Modify Team Profile',
      ),
    );
  }

  void _showTeamEditDialog(BuildContext context, Team team) {
    final auth = ref.read(authProvider);
    final isSuperAdmin = auth.isSuperAdmin;
    
    final nameController = TextEditingController(text: team.name);
    final descController = TextEditingController(text: team.description);
    final codeController = TextEditingController(text: team.teamCode);
    final logoController = TextEditingController(text: team.logoUrl ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
              const SizedBox(width: 12),
              const Text('Teams Profile Edit', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Container(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Team Name'),
                  _buildStyledInput(nameController, 'Enter team identity name'),
                  const SizedBox(height: 20),
                  
                  if (isSuperAdmin) ...[
                    _buildFieldLabel('Team Code (SUPER ADMIN ONLY)'),
                    _buildStyledInput(codeController, 'Unique 6-char identifier'),
                    const SizedBox(height: 20),
                  ],

                  _buildFieldLabel('Team Logo URL'),
                  _buildStyledInput(logoController, 'Enter image URL for team logo'),
                  const SizedBox(height: 20),
                  
                  _buildFieldLabel('Team Mission/Description'),
                  _buildStyledInput(descController, 'Describe your team goals...', maxLines: 5),
                  const SizedBox(height: 8),
                  const Text('Note: Changes will be synced to all members in real-time.',
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> payload = {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'logo_url': logoController.text.trim(),
                  };
                  
                  if (isSuperAdmin) {
                    payload['team_code'] = codeController.text.trim();
                  }

                  await ref.read(apiServiceProvider).put('/teams/${team.id}', payload);
                  if (context.mounted && mounted) {
                    Navigator.pop(dialogContext);
                    ref.invalidate(teamsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team identity updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted && mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE IDENTITY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1)),
  );

  Widget _buildStyledInput(TextEditingController controller, String hint, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMemberSection(String title, List<TeamMember> members, IconData icon, bool isDark) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${members.length} MEMBERS',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(isDark ? 0.3 : 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: members.map((m) => _buildMemberAvatar(m, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(TeamMember member, bool isDark) {
    return Tooltip(
      message: '${member.name} (${member.role})',
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blueAccent.withOpacity(0.05),
          child: Text(
            member.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, String title, IconData icon) {
    final teamsAsync = ref.watch(teamsProvider);
    return teamsAsync.when(
      data: (response) {
        if (response.teams.isEmpty) return const SizedBox.shrink();
        final team = response.teams.first;
        
        if (title == 'General') return _buildGeneralTab(context, team);
        if (title == 'Setting') return _buildSettingTab(context, team);
        if (title == 'Activity') return _buildActivityTab(context, team);
        
        return _buildPlaceholderContent(context, title, icon);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildGeneralTab(BuildContext context, Team team) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMembers = team.members.length;
    final admins = team.members.where((m) => m.role == 'leader' || m.role == 'sub_admin').length;
    final staff = team.members.where((m) => m.role == 'staff').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard(context, 'Total Members', totalMembers.toString(), Icons.people_outline, Colors.blueAccent),
              const SizedBox(width: 16),
              _buildStatCard(context, 'Admins', admins.toString(), Icons.admin_panel_settings_outlined, Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(context, 'Staff Members', staff.toString(), Icons.badge_outlined, Colors.greenAccent),
              const SizedBox(width: 16),
              _buildStatCard(context, 'Status', 'Active', Icons.check_circle_outline, Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoTile(context, 'Team Code', team.teamCode, Icons.vpn_key_outlined),
          _buildInfoTile(context, 'Created At', 'May 2026', Icons.calendar_today_outlined),
        ],
      ),
    );
  }

  Widget _buildSettingTab(BuildContext context, Team team) {
    final auth = ref.read(authProvider);
    final isSuperAdmin = auth.isSuperAdmin;

    final nameController = TextEditingController(text: team.name);
    final descController = TextEditingController(text: team.description);
    final codeController = TextEditingController(text: team.teamCode);
    final logoController = TextEditingController(text: team.logoUrl ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: Colors.blueAccent),
              const SizedBox(width: 12),
              const Text('Team Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 24),
          _buildFieldLabel('Team Name'),
          _buildStyledInput(nameController, 'Enter team name'),
          const SizedBox(height: 20),

          _buildFieldLabel('Team Logo URL'),
          _buildStyledInput(logoController, 'Enter logo image URL'),
          const SizedBox(height: 20),
          
          if (isSuperAdmin) ...[
            _buildFieldLabel('Team Code (SUPER ADMIN ONLY)'),
            _buildStyledInput(codeController, 'Unique identifier'),
            const SizedBox(height: 20),
          ],
          
          _buildFieldLabel('Description'),
          _buildStyledInput(descController, 'Enter description', maxLines: 5),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> payload = {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'logo_url': logoController.text.trim(),
                  };
                  
                  if (isSuperAdmin) {
                    payload['team_code'] = codeController.text.trim();
                  }

                  await ref.read(apiServiceProvider).put('/teams/${team.id}', payload);
                  if (context.mounted && mounted) {
                    ref.invalidate(teamsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team settings updated successfully'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(BuildContext context, Team team) {
    return const Center(child: Text('Live Team Activity Stream coming soon...', style: TextStyle(color: Colors.grey)));
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
  );

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent(BuildContext context, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.1),
              ),
              child: Icon(icon, size: 80, color: Colors.blueAccent),
            ),
            const SizedBox(height: 32),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  Widget _buildSyncIndicator(bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isLoading ? Colors.blueAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isLoading ? Icons.sync : Icons.check_circle_outline,
            size: 12,
            color: isLoading ? Colors.blueAccent : Colors.greenAccent.withOpacity(0.5),
          ),
          if (isLoading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
  }
}
