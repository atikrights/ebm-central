enum TaskPriority { low, medium, high, critical }
enum TaskStatus { todo, inProgress, review, done, completed }

extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.inProgress: return 'IN PROGRESS';
      case TaskStatus.review: return 'IN REVIEW';
      case TaskStatus.done: return 'DONE';
      case TaskStatus.completed: return 'COMPLETED';
      case TaskStatus.todo: return 'TO DO';
    }
  }
}

class TaskDocument {
  final String id;
  final String name;
  final String type;
  final String? url;
  final DateTime uploadedAt;

  TaskDocument({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    required this.uploadedAt,
  });

  TaskDocument copyWith({String? id, String? name, String? type, String? url, DateTime? uploadedAt}) {
    return TaskDocument(id: id ?? this.id, name: name ?? this.name, type: type ?? this.type, url: url ?? this.url, uploadedAt: uploadedAt ?? this.uploadedAt);
  }
}

class SubTask {
  final String id;
  final String title;
  final double additionalCost;
  final bool isCompleted;

  SubTask({required this.id, required this.title, this.additionalCost = 0.0, this.isCompleted = false});

  SubTask copyWith({String? id, String? title, double? additionalCost, bool? isCompleted}) {
    return SubTask(id: id ?? this.id, title: title ?? this.title, additionalCost: additionalCost ?? this.additionalCost, isCompleted: isCompleted ?? this.isCompleted);
  }
}

class RoadmapStep {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;

  RoadmapStep({required this.id, required this.title, this.description = '', this.isCompleted = false});

  RoadmapStep copyWith({String? id, String? title, String? description, bool? isCompleted}) {
    return RoadmapStep(id: id ?? this.id, title: title ?? this.title, description: description ?? this.description, isCompleted: isCompleted ?? this.isCompleted);
  }
}

class TaskComment {
  final String id;
  final String author;
  final String content;
  final DateTime createdAt;

  TaskComment({required this.id, required this.author, required this.content, required this.createdAt});

  Map<String, dynamic> toMap() => { 'id': id, 'author': author, 'content': content, 'createdAt': createdAt.toIso8601String() };
  factory TaskComment.fromMap(Map<String, dynamic> map) => TaskComment(id: map['id'], author: map['author'], content: map['content'], createdAt: DateTime.parse(map['createdAt']));
}

class SystemTask {
  final String id;
  final String taskNumber;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final double allocatedCost;
  final String author;
  final String assignee;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String location;
  final List<TaskDocument> documents;
  final List<SubTask> subTasks;
  final List<RoadmapStep> roadmapSteps;
  final List<String> subTaskIds;
  final List<TaskComment> comments;
  final String? planId; // Linked to a specific Plan
  final String? projectId; // Linked to a specific Project
  final bool isArchived;

  SystemTask({
    required this.id,
    required this.taskNumber,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.allocatedCost = 0.0,
    this.author = 'Admin',
    this.assignee = 'Unassigned',
    this.dueDate,
    this.startDate,
    this.endDate,
    this.location = '',
    this.documents = const [],
    this.subTasks = const [],
    this.roadmapSteps = const [],
    this.subTaskIds = const [],
    this.comments = const [],
    this.planId,
    this.projectId,
    this.isArchived = false,
  });

  double get totalSubTaskCost => subTasks.fold(0.0, (sum, s) => sum + s.additionalCost);
  double get grandTotal => allocatedCost + totalSubTaskCost;

  SystemTask copyWith({
    String? id, String? taskNumber, String? title, String? description,
    TaskStatus? status, TaskPriority? priority, double? allocatedCost,
    String? author, String? assignee, DateTime? dueDate, DateTime? startDate, DateTime? endDate,
    String? location, List<TaskDocument>? documents, List<SubTask>? subTasks,
    List<RoadmapStep>? roadmapSteps, List<String>? subTaskIds, List<TaskComment>? comments, String? planId, String? projectId,
    bool? isArchived,
  }) {
    return SystemTask(
      id: id ?? this.id, taskNumber: taskNumber ?? this.taskNumber,
      title: title ?? this.title, description: description ?? this.description,
      status: status ?? this.status, priority: priority ?? this.priority,
      allocatedCost: allocatedCost ?? this.allocatedCost, author: author ?? this.author,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate, startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate, location: location ?? this.location,
      documents: documents ?? this.documents, subTasks: subTasks ?? this.subTasks,
      roadmapSteps: roadmapSteps ?? this.roadmapSteps, subTaskIds: subTaskIds ?? this.subTaskIds,
      comments: comments ?? this.comments, planId: planId ?? this.planId, projectId: projectId ?? this.projectId,
      isArchived: isArchived ?? this.isArchived,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskNumber': taskNumber,
      'title': title,
      'description': description,
      'status': status.index,
      'priority': priority.index,
      'allocatedCost': allocatedCost,
      'author': author,
      'assignee': assignee,
      'dueDate': dueDate?.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'location': location,
      'comments': comments.map((c) => c.toMap()).toList(),
      'planId': planId,
      'projectId': projectId,
      'isArchived': isArchived,
    };
  }

  factory SystemTask.fromMap(Map<String, dynamic> map) {
    return SystemTask(
      id: map['id']?.toString() ?? '',
      taskNumber: map['taskNumber'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: TaskStatus.values[map['status'] ?? 0],
      priority: TaskPriority.values[map['priority'] ?? 1],
      allocatedCost: (map['allocatedCost'] ?? 0).toDouble(),
      author: map['author'] ?? 'Admin',
      assignee: map['assignee'] ?? 'Unassigned',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      location: map['location'] ?? '',
      comments: map['comments'] != null
          ? List<TaskComment>.from(map['comments'].map((x) => TaskComment.fromMap(x)))
          : [],
      planId: map['planId']?.toString(),
      projectId: map['projectId']?.toString(),
      isArchived: _parseBool(map['isArchived'] ?? false),
    );
  }

  static bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) {
      final s = val.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'completed' || s == 'active';
    }
    return false;
  }
}
