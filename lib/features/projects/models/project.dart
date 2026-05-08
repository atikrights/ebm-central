import 'dart:ui';

enum ProjectStatus { active, completed, onHold, planning, draft }

class Project {
  final String id;
  final String? companyId;
  final String? companyName;
  final String pid;
  final String name;
  final String category;
  final String description;
  final ProjectStatus status;
  final double totalBudget;
  final double consumedBudget;
  final DateTime startDate;
  final Color brandColor;
  final List<String> taskIds;
  final List<Plan> plans;

  Project({
    required this.id,
    this.companyId,
    this.companyName,
    required this.pid,
    required this.name,
    required this.category,
    required this.description,
    required this.status,
    required this.totalBudget,
    required this.consumedBudget,
    required this.startDate,
    required this.brandColor,
    this.taskIds = const [],
    this.plans = const [],
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      companyName: map['company']?['name']?.toString(),
      pid: map['pid'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      description: map['description'] ?? '',
      status: _parseStatus(map['status']),
      totalBudget: (map['total_budget'] ?? 0).toDouble(),
      consumedBudget: (map['consumed_budget'] ?? 0).toDouble(),
      startDate: DateTime.parse(map['start_date'] ?? DateTime.now().toIso8601String()),
      brandColor: _parseColor(map['brand_color']),
      taskIds: List<String>.from(map['task_ids'] ?? []),
      plans: List<Plan>.from((map['plans'] as List? ?? []).map((p) => Plan.fromMap(p))),
    );
  }

  static ProjectStatus _parseStatus(dynamic status) {
    if (status == null) return ProjectStatus.draft;
    
    // If it's already an index (int)
    if (status is int) {
      if (status >= 0 && status < ProjectStatus.values.length) {
        return ProjectStatus.values[status];
      }
      return ProjectStatus.draft;
    }
    
    // If it's a string from API
    if (status is String) {
      final s = status.toLowerCase();
      if (s == 'active' || s == '1') return ProjectStatus.active;
      if (s == 'completed' || s == '4') return ProjectStatus.completed;
      if (s == 'onhold' || s == 'on_hold' || s == '3') return ProjectStatus.onHold;
      if (s == 'planning' || s == '2') return ProjectStatus.planning;
      if (s == 'draft' || s == '0') return ProjectStatus.draft;
    }
    
    return ProjectStatus.active;
  }

  static Color _parseColor(dynamic color) {
    if (color == null) return const Color(0xFF6366F1); // Indigo default
    if (color is String) {
      if (color.startsWith('#')) {
        return Color(int.parse(color.substring(1), radix: 16) + 0xFF000000);
      }
    }
    return const Color(0xFF6366F1);
  }
}

class Plan {
  final String id;
  final String title;
  final String icode;
  final double budget;
  final double consumedBudget;
  final String status;

  Plan({
    required this.id,
    required this.title,
    required this.icode,
    required this.budget,
    required this.consumedBudget,
    required this.status,
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      icode: map['icode'] ?? '',
      budget: (map['budget'] ?? 0).toDouble(),
      consumedBudget: (map['consumed_budget'] ?? 0).toDouble(),
      status: map['status'] ?? 'Active',
    );
  }
}
