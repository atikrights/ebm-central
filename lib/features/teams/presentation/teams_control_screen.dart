import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          children: [
            // Team Avatar (Smaller & Compact)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.08),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
              ),
              child: const Icon(Icons.group_work_rounded, size: 48, color: Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            Text(
              team.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: Text(
                'ID: ${team.teamCode}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                'Enterprise business operations team management and synchronization.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            
            // Member Sections (Premium & Compact)
            _buildMemberSection('Admin Identity', admins, Icons.admin_panel_settings_rounded, isDark),
            _buildMemberSection('Manager Control', managers, Icons.manage_accounts_rounded, isDark),
            _buildMemberSection('Staff Directory', staffs, Icons.badge_rounded, isDark),
          ],
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.blueAccent.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white30 : Colors.black38,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(isDark ? 0.2 : 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(
                icon,
                size: 80,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'This section provides centralized management for $title. You can configure rules, view logs, and manage team-specific identities here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Placeholder for future settings/content
            _buildPlaceholderSection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderSection(BuildContext context, bool isDark) {
    return Column(
      children: List.generate(3, (index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(isDark ? 0.3 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: const Center(
          child: Icon(Icons.more_horiz, color: Colors.grey),
        ),
      )),
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
