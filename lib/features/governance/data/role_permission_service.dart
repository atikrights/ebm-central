// lib/features/governance/data/role_permission_service.dart
//
// EBM Dynamic Policy Engine — API Service Layer
// Handles all role, permission, and policy API calls.

import '../../../core/network/api_service.dart';

class RolePermissionService {
  final ApiService _api;
  RolePermissionService(this._api);

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Fetch all permissions grouped by tab category.
  Future<Map<String, dynamic>> fetchPermissions() async {
    final data = await _api.get('/governance/permissions');
    return data as Map<String, dynamic>;
  }

  // ── Roles ────────────────────────────────────────────────────────────────

  /// Fetch all roles with their permissions and policies.
  Future<List<dynamic>> fetchRoles() async {
    final data = await _api.get('/governance/roles');
    return data as List<dynamic>;
  }

  /// Create a new custom role.
  Future<Map<String, dynamic>> createRole({
    required String name,
    required String label,
    String? color,
    String? icon,
  }) async {
    final data = await _api.post('/governance/roles', {
      'name': name,
      'label': label,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
    });
    return data as Map<String, dynamic>;
  }

  /// Update a role's label/color/icon.
  Future<Map<String, dynamic>> updateRole(
      int roleId, Map<String, dynamic> fields) async {
    final data = await _api.put('/governance/roles/$roleId', fields);
    return data as Map<String, dynamic>;
  }

  /// Delete a custom role.
  Future<void> deleteRole(int roleId) async {
    await _api.delete('/governance/roles/$roleId');
  }

  // ── Permission Matrix ─────────────────────────────────────────────────────

  /// Bulk-sync permissions for a role.
  /// [permissions] = { "wipe_chat_history": true, "create_users": false }
  Future<void> syncPermissions(
      int roleId, Map<String, bool> permissions) async {
    await _api.post('/governance/roles/$roleId/permissions/sync', {
      'permissions': permissions,
    });
  }

  /// Toggle a single permission for a role.
  Future<Map<String, dynamic>> togglePermission(
      int roleId, String permKey) async {
    // PATCH via put workaround (ApiService uses http.put for PATCH too)
    final data =
        await _api.patch('/governance/roles/$roleId/permissions/$permKey');
    return data as Map<String, dynamic>;
  }

  // ── Role Policy ───────────────────────────────────────────────────────────

  /// Update advanced policy settings for a role.
  Future<Map<String, dynamic>> updatePolicy(
      int roleId, Map<String, dynamic> policy) async {
    final data =
        await _api.put('/governance/roles/$roleId/policy', policy);
    return data as Map<String, dynamic>;
  }

  // ── My Permissions ────────────────────────────────────────────────────────

  /// Returns the current user's full permission map + effective policy.
  Future<Map<String, dynamic>> fetchMyPermissions() async {
    final data = await _api.get('/me/permissions');
    return data as Map<String, dynamic>;
  }

  // ── User ↔ Custom Role ────────────────────────────────────────────────────

  /// Assign a custom role to a user.
  Future<void> assignRoleToUser(int userId, int roleId) async {
    await _api.post('/governance/users/$userId/roles/assign',
        {'role_id': roleId});
  }

  /// Remove a custom role from a user.
  Future<void> removeRoleFromUser(int userId, int roleId) async {
    await _api.delete('/governance/users/$userId/roles/$roleId');
  }
}
