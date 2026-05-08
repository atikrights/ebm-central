import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_task.dart';
import '../../../core/network/api_service.dart';
import 'package:flutter/foundation.dart';

class TaskProvider extends ChangeNotifier {
  List<SystemTask> _tasks = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<SystemTask> get allTasks => _tasks;

  // Sync method
  Future<void> syncWithDatabase() async {
    // dummy sync
    notifyListeners();
  }

  Future<void> addTask(SystemTask task, {String? companyId}) async {
    _tasks.add(task);
    notifyListeners();
  }

  void updateTaskStatus(String taskId, TaskStatus status) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: status);
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
}

// Riverpod provider for the ChangeNotifier
final taskProvider = ChangeNotifierProvider<TaskProvider>((ref) {
  return TaskProvider();
});
