import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_task.dart';
import '../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class TaskProvider extends ChangeNotifier {
  final Ref _ref;
  List<SystemTask> _tasks = [];
  List<SystemTask> _trashedTasks = [];
  bool _isLoading = false;
  Timer? _syncTimer;

  TaskProvider(this._ref) {
    _startPeriodicSync();
    syncWithDatabase();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      syncWithDatabase();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  List<SystemTask> get allTasks => _tasks;
  List<SystemTask> get trashedTasks => _trashedTasks;

  // Sync method using real API
  Future<void> syncWithDatabase({String? projectId, String? planId, String? companyId}) async {
    final api = _ref.read(apiServiceProvider);
    if (api.token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      String endpoint = '/tasks';
      final params = <String>[];
      if (companyId != null) params.add('company_id=$companyId');
      if (projectId != null) params.add('project_id=$projectId');
      if (planId != null) params.add('plan_id=$planId');
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final response = await api.get(endpoint);
      List? rawList;
      if (response is List) {
        rawList = response;
      } else if (response is Map && response['data'] is List) {
        rawList = response['data'];
      }

      if (rawList != null) {
        _tasks = rawList.map((m) => SystemTask.fromMap(m)).toList();
      }
      await syncTrashedTasks();
    } catch (e) {
      debugPrint('❌ TaskProvider Sync Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncTrashedTasks() async {
    final api = _ref.read(apiServiceProvider);
    if (api.token == null) return;

    try {
      final response = await api.get('/tasks/trashed');
      List? rawList;
      if (response is List) {
        rawList = response;
      } else if (response is Map && response['data'] is List) {
        rawList = response['data'];
      }

      if (rawList != null) {
        _trashedTasks = rawList.map((m) => SystemTask.fromMap(m)).toList();
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Sync Trashed Tasks Error: $e');
    }
  }

  Future<SystemTask?> addTask(SystemTask task, {required String companyId}) async {
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
        return newTask;
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Add Task Error: $e');
    }
    return null;
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
      rethrow;
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
      final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        final removedTask = _tasks[taskIdx];
        _tasks.removeAt(taskIdx);
        _trashedTasks.insert(0, removedTask);
        notifyListeners();
      }

      final api = _ref.read(apiServiceProvider);
      await api.delete('/tasks/$taskId');
      await syncWithDatabase(); // background refresh
    } catch (e) {
      debugPrint('❌ TaskProvider Remove Task Error: $e');
      await syncWithDatabase(); // fallback sync
    }
  }

  Future<void> restoreTask(String taskId) async {
    try {
      final taskIdx = _trashedTasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        final task = _trashedTasks[taskIdx];
        _trashedTasks.removeAt(taskIdx);
        _tasks.insert(0, task);
        notifyListeners();
      }

      final api = _ref.read(apiServiceProvider);
      await api.post('/tasks/$taskId/restore', {});
      await syncWithDatabase(); // background refresh
    } catch (e) {
      debugPrint('❌ TaskProvider Restore Task Error: $e');
      await syncWithDatabase(); // fallback sync
    }
  }

  Future<void> forceDeleteTask(String taskId) async {
    try {
      final taskIdx = _trashedTasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        _trashedTasks.removeAt(taskIdx);
        notifyListeners();
      }

      final api = _ref.read(apiServiceProvider);
      await api.delete('/tasks/$taskId/force-delete');
      await syncWithDatabase(); // background refresh
    } catch (e) {
      debugPrint('❌ TaskProvider Force Delete Task Error: $e');
      await syncWithDatabase(); // fallback sync
    }
  }

  Future<void> renewTask(String taskId) async {
    try {
      final taskIdx = _trashedTasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        _trashedTasks.removeAt(taskIdx);
        notifyListeners();
      }

      final api = _ref.read(apiServiceProvider);
      final response = await api.post('/tasks/$taskId/renew', {});
      if (response != null) {
        final renewedTask = SystemTask.fromMap(response);
        _tasks.insert(0, renewedTask);
        notifyListeners();
      } else {
        await syncWithDatabase();
      }
    } catch (e) {
      debugPrint('❌ TaskProvider Renew Task Error: $e');
      await syncWithDatabase(); // fallback sync
    }
  }
}

// Riverpod provider for the ChangeNotifier
final taskProvider = ChangeNotifierProvider<TaskProvider>((ref) {
  return TaskProvider(ref);
});
