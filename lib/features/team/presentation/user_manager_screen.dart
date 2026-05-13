import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import 'user_provider.dart';
import '../../../core/theme/admin_theme.dart';

class UserManagerScreen extends ConsumerStatefulWidget {
  final int initialView; // 0: All Users, 1: Add New, 2: Work Tracking
  const UserManagerScreen({super.key, this.initialView = 0});

  @override
  ConsumerState<UserManagerScreen> createState() => _UserManagerScreenState();
}

class _UserManagerScreenState extends ConsumerState<UserManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _activeFilter = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialView == 2 ? 1 : 0);
    
    // If "Add New" was requested, show dialog after build
    if (widget.initialView == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddUserDialog(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Dynamic Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white12,
              border: Border(bottom: BorderSide(color: AdminTheme.primary.withOpacity(0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Governance',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold, 
                              color: AdminTheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Manage your team and track activities',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUserDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add Identity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AdminTheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AdminTheme.primary,
                  unselectedLabelColor: Colors.grey,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'All Users'),
                    Tab(text: 'Work Tracking'),
                  ],
                ),
              ],
            ),
          ),
          
          // Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllUsersView(),
                _buildWorkTrackingView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllUsersView() {
    final usersAsync = ref.watch(userListProvider);
    final auth = ref.watch(authProvider);
    final bool isSuperAdmin = auth.role == 'SUPER_ADMIN' || auth.role == 'SUPER ADMIN';
    
    return usersAsync.when(
      data: (users) {
        List<dynamic> filteredUsers = users;
        
        // Custom filtering logic for Acting Roles
        if (_activeFilter == "SUB_ADMIN") {
          filteredUsers = users.where((u) {
            final teams = u['teams'] as List? ?? [];
            return teams.any((t) => t['pivot']?['role'] == 'sub_admin');
          }).toList();
        } else if (_activeFilter != "All") {
          filteredUsers = users.where((u) => u['role'].toString().toUpperCase() == _activeFilter.toUpperCase()).toList();
        }

        final int totalCount = users.length;
        final int superAdminCount = users.where((u) => u['role'].toString().toUpperCase() == 'SUPER_ADMIN').length;
        final int adminCount = users.where((u) => u['role'].toString().toUpperCase() == 'ADMIN').length;
        final int managerCount = users.where((u) => u['role'].toString().toUpperCase() == 'MANAGER').length;
        final int staffCount = users.where((u) => u['role'].toString().toUpperCase() == 'STAFF').length;
        final int subAdminCount = users.where((u) {
          final teams = u['teams'] as List? ?? [];
          return teams.any((t) => t['pivot']?['role'] == 'sub_admin');
        }).length;

        return RefreshIndicator(
          onRefresh: () => ref.read(userListProvider.notifier).fetchUsers(),
          color: AdminTheme.primary,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text-based Filter Row (Super Admin Style)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTextFilter("All", totalCount),
                      if (isSuperAdmin) ...[
                        _buildFilterDivider(),
                        _buildTextFilter("SUPER_ADMIN", superAdminCount),
                        _buildFilterDivider(),
                        _buildTextFilter("ADMIN", adminCount),
                        _buildFilterDivider(),
                        _buildTextFilter("SUB_ADMIN", subAdminCount),
                      ],
                      _buildFilterDivider(),
                      _buildTextFilter("MANAGER", managerCount),
                      _buildFilterDivider(),
                      _buildTextFilter("STAFF", staffCount),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Table Container
                if (filteredUsers.isEmpty)
                  _buildEmptyState()
                else
                  _buildUserTable(filteredUsers),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AdminTheme.primary)),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildFilterDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text("|", style: TextStyle(color: Colors.grey.withOpacity(0.3))),
  );

  Widget _buildTextFilter(String role, int count) {
    final bool isActive = _activeFilter.toUpperCase() == role.toUpperCase();
    final String label = role.replaceAll("_", " ");
    
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = role),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          "$label ($count)",
          style: TextStyle(
            color: isActive ? AdminTheme.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUserTable(List<dynamic> users) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminTheme.primary.withOpacity(isDark ? 0.05 : 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Container(
                width: 1000, 
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: AdminTheme.primary.withOpacity(0.02),
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, size: 18, color: Colors.grey)),
                    _buildHeaderCell("Username", 220),
                    _buildHeaderCell("Name", 180),
                    _buildHeaderCell("Email", 220),
                    _buildHeaderCell("Role", 120),
                    _buildHeaderCell("Actions", 120),
                  ],
                ),
              ),
              
              // Data Rows
              ...users.map((u) => _buildUserTableRow(u, isDark)).toList(),
              
              // Bottom spacing to feel "open"
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
      ),
    );
  }

  Widget _buildUserTableRow(dynamic user, bool isDark) {
    final String name = user['name'] ?? 'Unknown';
    final String email = user['email'] ?? 'No Email';
    final String role = user['role']?.toString().toUpperCase() ?? 'STAFF';
    final String uid = user['uid'] ?? 'N/A';
    final String username = email.split('@')[0];

    // Detect Acting Role (Sub-Admin in any team)
    final teams = user['teams'] as List? ?? [];
    final bool isSubAdmin = teams.any((t) => t['pivot']?['role'] == 'sub_admin');
    final String actingIn = isSubAdmin ? (teams.firstWhere((t) => t['pivot']?['role'] == 'sub_admin')['name'] ?? 'Team') : '';

    return Container(
      width: 1000,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, size: 16, color: Colors.grey)),
          
          // Username Column (Avatar + Nickname + UID)
          SizedBox(
            width: 220,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AdminTheme.primary.withOpacity(0.1),
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: AdminTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Text(uid, style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Name Column
          SizedBox(width: 180, child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis)),
          
          // Email Column
          SizedBox(width: 220, child: Text(email, style: const TextStyle(fontSize: 13, color: AdminTheme.primary), overflow: TextOverflow.ellipsis)),
          
          // Role Column (Original Role + Acting Badge)
          SizedBox(
            width: 120, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(role, style: const TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey, fontWeight: FontWeight.bold)),
                if (isSubAdmin)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text("ACTING: SUB-ADMIN", style: const TextStyle(fontSize: 7, color: Colors.blueAccent, fontWeight: FontWeight.w900)),
                  ),
              ],
            )
          ),
          
          // Actions Column
          SizedBox(
            width: 120,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.edit, size: 16, color: AdminTheme.primary),
                  onPressed: () => _showEditUserDialog(user),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.trash, size: 16, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, user),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTrackingView() {
    final activitiesAsync = ref.watch(userActivitiesProvider);
    
    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return const Center(
            child: Text('No activity logs found for your team.', style: TextStyle(color: Colors.grey)),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(userActivitiesProvider.future),
          color: AdminTheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(24.0),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              return _buildActivityTile(context, act);
            },
          ).animate().fadeIn(duration: 400.ms),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AdminTheme.primary)),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildActivityTile(BuildContext context, dynamic act) {
    final theme = Theme.of(context);
    final date = DateTime.parse(act['created_at']);
    final formattedDate = DateFormat('MMM d, h:mm a').format(date);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getSeverityColor(act['severity']).withOpacity(0.1),
            child: Icon(_getEventIcon(act['event_type']), color: _getSeverityColor(act['severity']), size: 20),
          ),
          title: Text(
            act['description'] ?? 'No description',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('By: ${act['actor_name']} (${act['actor_role']})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(formattedDate, style: TextStyle(fontSize: 10, color: AdminTheme.primary.withOpacity(0.6))),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical': return Colors.redAccent;
      case 'warning': return Colors.orangeAccent;
      default: return AdminTheme.primary;
    }
  }

  IconData _getEventIcon(String? type) {
    if (type == null) return Icons.info_outline;
    if (type.contains('login')) return Icons.login;
    if (type.contains('create')) return Icons.add_circle_outline;
    if (type.contains('delete')) return Icons.delete_forever;
    if (type.contains('update')) return Icons.edit_note;
    return Icons.event_note;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No users found in this category', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(dynamic user) {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role']?.toString().toLowerCase() ?? 'staff';

    final auth = ref.read(authProvider);
    final role = auth.role?.toUpperCase().replaceAll(' ', '_') ?? 'STAFF';
    final bool isSuperAdmin = role == 'SUPER_ADMIN';
    final bool isAdmin = role == 'ADMIN';
    final bool isManager = role == 'MANAGER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.cardBg,
          title: const Text('Edit Identity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: [
                  if (isSuperAdmin) ...[
                    const DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                    const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  if (isSuperAdmin || isAdmin) ...[
                    const DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  ],
                  const DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
                decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.security)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(userListProvider.notifier).updateUser(user['id'], {
                    'name': nameController.text,
                    'email': emailController.text,
                    'role': selectedRole,
                  });
                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.black),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardBg,
        title: const Text('Delete User?'),
        content: Text('Delete ${user['name']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(userListProvider.notifier).deleteUser(user['id']);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AddIdentityDialog(parentRef: ref),
    );
  }
}

class _AddIdentityDialog extends StatefulWidget {
  final WidgetRef parentRef;
  const _AddIdentityDialog({required this.parentRef});

  @override
  State<_AddIdentityDialog> createState() => _AddIdentityDialogState();
}

class _AddIdentityDialogState extends State<_AddIdentityDialog> with SingleTickerProviderStateMixin {
  late TabController _methodTabController;
  
  // Manual State
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  String _selectedRole = "staff";
  bool _isCreating = false;

  // Link State
  final _linkEmailC = TextEditingController();
  String _selectedLinkRole = "staff";
  bool _isGenerating = false;
  String? _invitationLink;

  @override
  void initState() {
    super.initState();
    _methodTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _methodTabController.dispose();
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _linkEmailC.dispose();
    super.dispose();
  }

  Future<void> _manualCreate() async {
    if (_nameC.text.isEmpty || _emailC.text.isEmpty || _passC.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
       return;
    }
    setState(() => _isCreating = true);
    try {
      await widget.parentRef.read(userListProvider.notifier).createUser({
        'name': _nameC.text,
        'email': _emailC.text,
        'password': _passC.text,
        'role': _selectedRole,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateLink() async {
    if (!_linkEmailC.text.contains("@")) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid email")));
       return;
    }
    setState(() => _isGenerating = true);
    try {
      final res = await widget.parentRef.read(userListProvider.notifier).generateInvitation({
        'email': _linkEmailC.text,
        'role': _selectedLinkRole,
      });
      setState(() {
        _isGenerating = false;
        _invitationLink = res['invitation_link'];
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 550.0 : screenWidth * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AdminTheme.primary.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: -10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(IconsaxPlusLinear.user_add, color: AdminTheme.primary),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Add New Identity", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text("Onboard a new Manager or Staff member", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.1)),
                  ),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TabBar(
                controller: _methodTabController,
                indicatorColor: AdminTheme.primary,
                labelColor: AdminTheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.grey.withOpacity(0.1),
                tabs: const [
                  Tab(text: "Manual Entry"),
                  Tab(text: "Secure Link"),
                ],
              ),
            ),

            // Tab Views
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _methodTabController,
                    children: [
                      _buildManualForm(isDark),
                      _buildLinkForm(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildManualForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_nameC, IconsaxPlusLinear.user, "Full Name", isDark),
        const SizedBox(height: 16),
        _buildTextField(_emailC, IconsaxPlusLinear.sms, "Email Address", isDark),
        const SizedBox(height: 16),
        _buildTextField(_passC, IconsaxPlusLinear.key, "Initial Password", isDark, obscure: true),
        const SizedBox(height: 16),
        _buildRoleSelector(isDark, false),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isCreating ? null : _manualCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isCreating 
              ? const CircularProgressIndicator(color: Colors.black)
              : const Text("CREATE IDENTITY NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkForm(bool isDark) {
    if (_invitationLink != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(IconsaxPlusLinear.tick_circle, color: Colors.greenAccent, size: 64),
          const SizedBox(height: 16),
          const Text("Invitation Ready!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
          const SizedBox(height: 8),
          const Text("Share this link with the candidate", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.primary.withOpacity(0.1)),
            ),
            child: Text(_invitationLink!, style: const TextStyle(fontSize: 12, color: AdminTheme.primary)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _invitationLink!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied to clipboard")));
                  },
                  icon: const Icon(IconsaxPlusLinear.copy, size: 18),
                  label: const Text("Copy"),
                  style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _invitationLink = null),
                  child: const Text("New Link"),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Invite via secure link. They will set their own password.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 24),
        _buildTextField(_linkEmailC, IconsaxPlusLinear.sms, "Recipient Email", isDark),
        const SizedBox(height: 16),
        _buildRoleSelector(isDark, true),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isGenerating ? null : _generateLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isGenerating 
              ? const CircularProgressIndicator(color: Colors.black)
              : const Text("GENERATE SECURITY LINK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, String label, bool isDark, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: Icon(icon, size: 20, color: AdminTheme.primary.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(bool isDark, bool forLink) {
    final currentRole = forLink ? _selectedLinkRole : _selectedRole;
    final auth = widget.parentRef.read(authProvider);
    final role = auth.role?.toUpperCase().replaceAll(' ', '_') ?? 'STAFF';
    final bool isSuperAdmin = role == 'SUPER_ADMIN';
    final bool isAdmin = role == 'ADMIN';
    final bool isManager = role == 'MANAGER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assign Role", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (isSuperAdmin) ...[
              _roleChip("super_admin", "Super Admin", currentRole == "super_admin", forLink),
              const SizedBox(width: 12),
              _roleChip("admin", "Admin", currentRole == "admin", forLink),
              const SizedBox(width: 12),
            ],
            if (isSuperAdmin || isAdmin) ...[
              _roleChip("sub_admin", "Sub-Admin", currentRole == "sub_admin", forLink),
              const SizedBox(width: 12),
              _roleChip("manager", "Manager", currentRole == "manager", forLink),
              const SizedBox(width: 12),
            ],
            _roleChip("staff", "Staff", currentRole == "staff", forLink),
          ],
        ),
      ],
    );
  }

  Widget _roleChip(String value, String label, bool isSelected, bool forLink) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          if (forLink) _selectedLinkRole = value;
          else _selectedRole = value;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AdminTheme.primary : AdminTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AdminTheme.primary : AdminTheme.primary.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AdminTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
