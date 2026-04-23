import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';

class Task {
  final int id;
  final String name;
  final String type;
  final double amount;
  final String status;
  final String? dueDate;

  Task({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.status,
    this.dueDate,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      amount: double.parse(json['amount'].toString()),
      status: json['status'],
      dueDate: json['due_date'],
    );
  }
}

class TaskNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return _fetchTasks();
  }

  Future<List<Task>> _fetchTasks() async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.get('/tasks');
    final List<dynamic> data = response['data']['data']; // Pagination wrapper
    return data.map((task) => Task.fromJson(task)).toList();
  }

  Future<void> fetchTasks() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTasks());
  }

  Future<void> addTask(Map<String, dynamic> taskData) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.post('/tasks', taskData);
      fetchTasks();
    } catch (e) {
      throw Exception('Failed to add task: $e');
    }
  }
}

// 2. TaskNotifier Provider
final taskProvider = AsyncNotifierProvider<TaskNotifier, List<Task>>(() {
  return TaskNotifier();
});
