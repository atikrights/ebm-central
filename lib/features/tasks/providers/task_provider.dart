import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_task.dart';
import '../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';

class TaskProvider extends ChangeNotifier {
  final Ref _ref;
  List<SystemTask> _tasks = [];
  bool _isLoading = false;

  TaskProvider(this._ref);

  bool get isLoading => _isLoading;
  List<SystemTask> get allTasks => _tasks;

  // Sync method using real API
  Future<void> syncWithDatabase({String? projectId, String? planId, String? companyId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = _ref.read(apiServiceProvider);
      String endpoint = '/tasks';
      final params = <String>[];
      if (companyId != null) params.add('company_id=$companyId');
      if (projectId != null) params.add('project_id=$projectId');
      if (planId != null) params.add('plan_id=$planId');
      if (params.isNotEmpty) {
        endpoint += '?' + params.join('&');
      }

      final response = await api.get(endpoint);
      if (response is List) {
        _tasks = response.map((m) => SystemTask.fromMap(m)).toList();
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Sync Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(SystemTask task, {required String companyId}) async {
    try {
      final api = _ref.read(apiServiceProvider);
      final response = await api.post('/tasks', {
        ...task.toMap(),
        'company_id': companyId,
      });

      if (response != null) {
        final newTask = SystemTask.fromMap(response);
        _tasks.insert(0, newTask);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Add Task Error: $e');
    }
  }

  Future<void> updateTask(SystemTask task) async {
    try {
      final api = _ref.read(apiServiceProvider);
      final response = await api.put('/tasks/${task.id}', task.toMap());
      if (response != null) {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx != -1) {
          _tasks[idx] = SystemTask.fromMap(response);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Update Task Error: $e');
    }
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final updated = _tasks[idx].copyWith(status: status);
      await updateTask(updated);
    }
  }

  Future<void> removeTask(String taskId) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.delete('/tasks/$taskId');
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ TaskProvider Remove Task Error: $e');
    }
  }
}

// Riverpod provider for the ChangeNotifier
final taskProvider = ChangeNotifierProvider<TaskProvider>((ref) {
  return TaskProvider(ref);
});
