// lib/features/governance/presentation/authority_matrix_screen.dart
//
// EBM Authority Matrix — Ultimate Role & Permission Control Panel
// Designed for Super Admin. Tab-based matrix UI with real-time toggles.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_service.dart';
import '../data/role_permission_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _rpServiceProvider = Provider<RolePermissionService>((ref) {
  return RolePermissionService(ref.watch(apiServiceProvider));
});

final _rolesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.watch(_rpServiceProvider).fetchRoles();
});

final _permissionsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(_rpServiceProvider).fetchPermissions();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AuthorityMatrixScreen extends ConsumerStatefulWidget {
  const AuthorityMatrixScreen({super.key});

  @override
  ConsumerState<AuthorityMatrixScreen> createState() =>
      _AuthorityMatrixScreenState();
}

class _AuthorityMatrixScreenState
    extends ConsumerState<AuthorityMatrixScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  // Local state: track unsaved toggles per role per permission key
  // { roleId: { permKey: bool } }
  final Map<int, Map<String, bool>> _pendingChanges = {};

  final List<String> _tabGroups = [
    'governance',
    'security',
    'communication',
    'projects',
    'users',
    'assets',
  ];

  final Map<String, String> _tabLabels = {
    'governance': 'Governance',
    'security': 'Security',
    'communication': 'Communication',
    'projects': 'Projects',
    'users': 'Users',
    'assets': 'Assets & Config',
  };

  final Map<String, IconData> _tabIcons = {
    'governance': Icons.gavel_rounded,
    'security': Icons.shield_rounded,
    'communication': Icons.chat_bubble_rounded,
    'projects': Icons.folder_rounded,
    'users': Icons.group_rounded,
    'assets': Icons.inventory_2_rounded,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabGroups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _togglePermission(int roleId, String permKey, bool currentValue,
      bool isSuperAdminOnly, String roleName) {
    if (isSuperAdminOnly) return; // 🔒 Super Admin only — immutable

    setState(() {
      _pendingChanges[roleId] ??= {};
      _pendingChanges[roleId]![permKey] = !currentValue;
    });
  }

  Future<void> _saveAllChanges(List<dynamic> roles) async {
    if (_pendingChanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final service = ref.read(_rpServiceProvider);

    try {
      for (final entry in _pendingChanges.entries) {
        await service.syncPermissions(entry.key, entry.value);
      }

      _pendingChanges.clear();
      ref.invalidate(_rolesProvider);
      ref.invalidate(_permissionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Policy changes saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showCreateRoleDialog() async {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String selectedColor = '#6c757d';
    final colors = [
      '#6c757d', '#00e5ff', '#7c3aed', '#0ea5e9',
      '#10b981', '#f59e0b', '#ef4444', '#ec4899',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2433),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_rounded,
                  color: Color(0xFF00E5FF), size: 22),
              SizedBox(width: 10),
              Text('Create Custom Role',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(nameCtrl, 'Role Key (e.g. finance_lead)',
                    'Lowercase, underscores only'),
                const SizedBox(height: 12),
                _dialogField(
                    labelCtrl, 'Display Name', 'e.g. Finance Lead'),
                const SizedBox(height: 16),
                const Text('Badge Color',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () =>
                          setDlgState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hexToColor(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || labelCtrl.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(_rpServiceProvider).createRole(
                        name: nameCtrl.text.trim(),
                        label: labelCtrl.text.trim(),
                        color: selectedColor,
                      );
                  ref.invalidate(_rolesProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Custom role created!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Role'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
      TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF151C2C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(_rolesProvider);
    final permsAsync = ref.watch(_permissionsProvider);
    final authState = ref.watch(authProvider);
    // Fixed: AuthState uses a direct 'role' string property, not a 'user' map
    final isSuperAdmin = authState.role?.toLowerCase() == 'super_admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0E1A),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C3AED)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.security_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Authority Matrix',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Define granular access policies for each role across the ecosystem',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSuperAdmin) ...[
                  // Create Role button
                  OutlinedButton.icon(
                    onPressed: _showCreateRoleDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Role'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save Changes button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isSaving
                        ? const SizedBox(
                            width: 140,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            key: const ValueKey('save_btn'),
                            onPressed: _pendingChanges.isEmpty
                                ? null
                                : () => rolesAsync.whenData(
                                    (roles) => _saveAllChanges(roles)),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: Text(
                              _pendingChanges.isEmpty
                                  ? 'No Changes'
                                  : 'Save ${_pendingChanges.values.fold(0, (s, m) => s + m.length)} Changes',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pendingChanges.isEmpty
                                  ? const Color(0xFF1E2433)
                                  : const Color(0xFF00E5FF),
                              foregroundColor: _pendingChanges.isEmpty
                                  ? Colors.white38
                                  : Colors.black,
                              disabledBackgroundColor:
                                  const Color(0xFF1E2433),
                              disabledForegroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Tab Bar ──────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF20), Color(0xFF7C3AED20)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF40)),
              ),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: _tabGroups.map((g) {
                return Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabIcons[g]!, size: 14),
                      const SizedBox(width: 6),
                      Text(_tabLabels[g]!),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Matrix Content ───────────────────────────────────────────────
          Expanded(
            child: rolesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              data: (roles) => permsAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (grouped) => TabBarView(
                  controller: _tabController,
                  children: _tabGroups.map((group) {
                    final perms = (grouped[group] as List?) ?? [];
                    return _buildMatrixTab(
                        roles, perms, isSuperAdmin);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTab(
      List<dynamic> roles, List<dynamic> perms, bool isSuperAdmin) {
    if (perms.isEmpty) {
      return const Center(
        child: Text('No permissions in this category.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2D3D)),
        ),
        child: Column(
          children: [
            // ── Table Header Row ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1321),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Permission label column
                  const SizedBox(
                    width: 240,
                    child: Text(
                      'PERMISSION MODULE',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  // Role columns
                  ...roles.map((role) {
                    final color = _hexToColor(role['color'] ?? '#6c757d');
                    return SizedBox(
                      width: 90,
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: color.withOpacity(0.4)),
                            ),
                            child: Icon(
                              _roleIcon(role['name']),
                              color: color,
                              size: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            role['label'] ?? '',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Permission Rows ───────────────────────────────────────
            ...perms.asMap().entries.map((entry) {
              final i = entry.key;
              final perm = entry.value as Map<String, dynamic>;
              final isLast = i == perms.length - 1;
              final isSuperAdminOnly =
                  perm['is_super_admin_only'] as bool? ?? false;
              final isDangerous =
                  perm['is_dangerous'] as bool? ?? false;

              return Container(
                decoration: BoxDecoration(
                  border: !isLast
                      ? const Border(
                          bottom: BorderSide(
                              color: Color(0xFF1E2D3D), width: 0.5))
                      : null,
                  borderRadius: isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(16))
                      : null,
                ),
                child: InkWell(
                  borderRadius: isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(16))
                      : null,
                  hoverColor: const Color(0xFF1E2433),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // Permission info
                        SizedBox(
                          width: 240,
                          child: Row(
                            children: [
                              if (isDangerous)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF444420),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    border: Border.all(
                                        color:
                                            const Color(0xFFEF444440)),
                                  ),
                                  child: const Text('⚠',
                                      style: TextStyle(fontSize: 10)),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      perm['label'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (perm['description'] != null)
                                      Text(
                                        perm['description'],
                                        style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Role toggles
                        ...roles.map((role) {
                          final roleId =
                              role['id'] as int? ?? 0;
                          final roleName =
                              role['name'] as String? ?? '';

                          // Determine current granted state
                          bool isGranted = false;

                          // Check pending changes first
                          if (_pendingChanges[roleId]
                                  ?.containsKey(perm['key']) ==
                              true) {
                            isGranted =
                                _pendingChanges[roleId]![perm['key']]!;
                          } else {
                            // Fallback: check role.permissions list
                            final rolePerms =
                                role['permissions'] as List? ?? [];
                            final match = rolePerms.firstWhere(
                              (p) => p['key'] == perm['key'],
                              orElse: () => null,
                            );
                            isGranted =
                                match?['is_granted'] == true;
                          }

                          final isLocked = isSuperAdminOnly &&
                              roleName != 'super_admin';
                          final isSuperAdminRow =
                              roleName == 'super_admin';

                          return SizedBox(
                            width: 90,
                            child: Center(
                              child: isSuperAdminRow
                                  ? _buildLockedBadge(
                                      const Color(0xFF00E5FF))
                                  : isLocked
                                      ? _buildLockedBadge(
                                          Colors.white24)
                                      : isSuperAdmin
                                          ? _buildToggle(
                                              isGranted,
                                              isDangerous,
                                              () => _togglePermission(
                                                roleId,
                                                perm['key'],
                                                isGranted,
                                                isSuperAdminOnly,
                                                roleName,
                                              ),
                                            )
                                          : _buildReadOnlyBadge(
                                              isGranted),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(
      bool isGranted, bool isDangerous, VoidCallback onTap) {
    final activeColor =
        isDangerous ? const Color(0xFFEF4444) : const Color(0xFF00E5FF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isGranted
              ? activeColor.withOpacity(0.15)
              : const Color(0xFF1E2433),
          shape: BoxShape.circle,
          border: Border.all(
            color: isGranted ? activeColor.withOpacity(0.6) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Icon(
          isGranted ? Icons.check_rounded : Icons.close_rounded,
          color: isGranted ? activeColor : Colors.white24,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildLockedBadge(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(Icons.lock_rounded, color: color, size: 16),
    );
  }

  Widget _buildReadOnlyBadge(bool isGranted) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isGranted
            ? const Color(0xFF10B98120)
            : const Color(0xFF1E2433),
        shape: BoxShape.circle,
        border: Border.all(
          color: isGranted ? const Color(0xFF10B98140) : Colors.white12,
        ),
      ),
      child: Icon(
        isGranted ? Icons.check_rounded : Icons.remove_rounded,
        color: isGranted ? const Color(0xFF10B981) : Colors.white24,
        size: 18,
      ),
    );
  }

  IconData _roleIcon(String? name) {
    switch (name) {
      case 'super_admin':
        return Icons.lock_rounded;
      case 'admin':
        return Icons.shield_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      case 'staff':
        return Icons.group_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
