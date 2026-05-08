import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../models/project.dart';

final projectProvider = StateNotifierProvider<ProjectNotifier, AsyncValue<List<Project>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ProjectNotifier(api);
});

class ProjectNotifier extends StateNotifier<AsyncValue<List<Project>>> {
  final ApiService _api;
  Timer? _timer;

  ProjectNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchProjects();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _backgroundFetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchProjects() async {
    try {
      state = const AsyncValue.loading();
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
        state = AsyncValue.data(projects);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
        state = AsyncValue.data(projects);
      }
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
      final response = await _api.post('/projects', {
        'name': name,
        'company_id': companyId,
        'category': category,
        'description': description,
        'status': status.name,
      });
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
      await _api.put('/projects/$projectId', {
        'company_id': companyId,
      });
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }
}
