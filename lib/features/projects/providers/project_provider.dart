import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../models/project.dart';

final trashedCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final response = await api.get('/projects/trashed');
    if (response != null) {
      final List dataList = response is List ? response
          : (response is Map && response['data'] is List ? response['data'] : []);
      return dataList.length;
    }
  } catch (_) {}
  return 0;
});

final projectProvider = StateNotifierProvider<ProjectNotifier, AsyncValue<List<Project>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ProjectNotifier(api, ref);
});

class ProjectNotifier extends StateNotifier<AsyncValue<List<Project>>> {
  final ApiService _api;
  final Ref _ref;
  Timer? _timer;

  ProjectNotifier(this._api, this._ref) : super(const AsyncValue.loading()) {
    fetchProjects();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _backgroundFetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchProjects({bool showLoading = false}) async {
    try {
      // Only show loading spinner on first load (no existing data).
      // Background refreshes must be completely silent to prevent layout flicker.
      final hasData = state is AsyncData;
      if (!hasData || showLoading) {
        state = const AsyncValue.loading();
      }
      final response = await _api.get('/projects');
      if (response != null) {
        final List dataList;
        if (response is List) {
          dataList = response;
        } else if (response is Map && response['data'] is List) {
          dataList = response['data'];
        } else {
          dataList = [];
        }
        final projects = dataList.map((p) => Project.fromMap(p as Map<String, dynamic>)).toList();
        if (mounted) state = AsyncValue.data(projects);
      } else {
        if (mounted) state = const AsyncValue.data([]);
      }
      _ref.invalidate(trashedCountProvider);
    } catch (e, st) {
      // On error: only update state if we don't already have data (preserve stale cache)
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Super Admin: fetch ALL projects including private/unattached from every user.
  Future<List<Project>> fetchAllProjects() async {
    try {
      final response = await _api.get('/projects?all=true');
      if (response != null) {
        final List dataList = response is List ? response
            : (response is Map && response['data'] is List ? response['data'] : []);
        final all = dataList.map((p) => Project.fromMap(p as Map<String, dynamic>)).toList();
        state = AsyncValue.data(all); // update state so UI reflects
        return all;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return [];
  }

  /// Fetch all soft-deleted (trashed) projects. Super Admin only.
  Future<List<Project>> fetchTrashedProjects() async {
    try {
      final response = await _api.get('/projects/trashed');
      if (response != null) {
        final List dataList = response is List ? response
            : (response is Map && response['data'] is List ? response['data'] : []);
        final list = dataList.map((p) => Project.fromMap(p as Map<String, dynamic>)).toList();
        _ref.invalidate(trashedCountProvider);
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Restore a soft-deleted project. Super Admin only.
  Future<bool> restoreTrashedProject(String projectId) async {
    try {
      final response = await _api.post('/projects/$projectId/restore', {});
      if (response != null) {
        await fetchProjects();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Permanently delete a project. Super Admin only.
  Future<bool> forceDeleteProject(String projectId) async {
    try {
      final response = await _api.delete('/projects/$projectId/force-delete');
      if (response != null) {
        _ref.invalidate(trashedCountProvider);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _backgroundFetch() async {
    try {
      final response = await _api.get('/projects');
      if (response != null) {
        final List dataList;
        if (response is List) {
          dataList = response;
        } else if (response is Map && response['data'] is List) {
          dataList = response['data'];
        } else {
          dataList = [];
        }
        final projects = dataList.map((p) => Project.fromMap(p as Map<String, dynamic>)).toList();
        if (mounted && hasListeners) {
          state = AsyncValue.data(projects);
        }
      }
      _ref.invalidate(trashedCountProvider);
    } catch (_) {}
  }



  Future<Project?> createProject({
    required String name,
    required String? companyId,
    String category = 'General',
    String description = '',
    ProjectStatus status = ProjectStatus.draft,
  }) async {
    try {
      // Build the payload — only include company_id when it's actually set.
      // Send as int to match the backend's nullable|integer validation rule.
      final payload = <String, dynamic>{
        'name': name,
        'category': category,
        'description': description,
        'status': status.name,
      };
      if (companyId != null) {
        payload['company_id'] = int.tryParse(companyId) ?? companyId;
      }

      final response = await _api.post('/projects', payload);
      await fetchProjects();
      if (response != null) {
        return Project.fromMap(response as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> linkCompanyToProject(String projectId, String companyId) async {
    try {
      await _api.post('/projects/$projectId/attach-company', {
        'company_id': companyId,
      });
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }

  /// Batch attach multiple projects to a company (Method 1: from Company page)
  Future<List<Map<String, dynamic>>> batchAttachToCompany(
      String companyId, List<String> projectIds) async {
    try {
      final response = await _api.post(
        '/companies/$companyId/attach-projects',
        {'project_ids': projectIds},
      );
      await fetchProjects();
      if (response != null && response['results'] != null) {
        return List<Map<String, dynamic>>.from(response['results']);
      }
    } catch (e) {
      rethrow;
    }
    return [];
  }

  /// Detach a project from its company — returns to creator's private scope
  Future<void> detachCompanyFromProject(String projectId) async {
    try {
      await _api.post('/projects/$projectId/detach-company', {});
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }

  /// Approve a pending project (Admin / Sub-Admin only)
  Future<void> approveProject(String projectId) async {
    try {
      await _api.post('/projects/$projectId/approve', {'is_approved': true});
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  /// Reject / un-approve a project (Admin / Sub-Admin only)
  Future<void> rejectProject(String projectId) async {
    try {
      await _api.post('/projects/$projectId/approve', {'is_approved': false});
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  /// Fetch all unattached projects for the picker modal
  Future<List<Project>> fetchUnattachedProjects() async {
    try {
      final response = await _api.get('/projects/unattached');
      if (response != null) {
        final List dataList = response is List ? response
            : (response is Map && response['data'] is List ? response['data'] : []);
        return dataList.map((p) => Project.fromMap(p as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get all pending-approval projects from current state
  List<Project> get pendingProjects {
    final current = state.value ?? [];
    return current.where((p) => !p.isApproved).toList();
  }

  Future<void> addPlan(String projectId, String title, String description) async {
    try {
      await _api.post('/projects/$projectId/plans', {
        'title': title,
        'description': description,
      });
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  Future<void> removePlan(String projectId, String planId) async {
    try {
      await _api.delete('/plans/$planId');
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  Future<void> updatePlan(String projectId, String planId, String title, String description) async {
    try {
      await _api.put('/plans/$planId', {
        'title': title,
        'description': description,
      });
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  Future<void> assignAuthorToPlan(String projectId, String planId, String author) async {
    try {
      await _api.put('/plans/$planId', {'assigned_to': author});
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    try {
      await _api.put('/projects/$projectId', data);
      await fetchProjects();
    } catch (e) { rethrow; }
  }

  Future<void> deleteProject(String projectId) async {
    final oldState = state;
    if (state is AsyncData<List<Project>>) {
      final currentList = state.value!;
      state = AsyncData(currentList.where((p) => p.id != projectId).toList());
    }

    try {
      await _api.delete('/projects/$projectId');
      _backgroundFetch();
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  /// Search a project by its unique PID securely
  Future<Project?> searchByPid(String pid) async {
    try {
      final response = await _api.get('/projects/search-pid?pid=$pid');
      if (response != null) {
        return Project.fromMap(response as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
