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
  final bool isApproved;

  final double minBudget;
  final double maxBudget;
  final String managerSignature;
  final DateTime? managerSignatureTimestamp;
  final String founderSignature;
  final DateTime? founderSignatureTimestamp;
  final double? confirmedBudget;
  final String website;
  final String coverPhotoUrl;
  final String inspirationText;

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
    this.isApproved = true,
    this.minBudget = 0.0,
    this.maxBudget = 0.0,
    this.managerSignature = '',
    this.managerSignatureTimestamp,
    this.founderSignature = '',
    this.founderSignatureTimestamp,
    this.confirmedBudget,
    this.website = '',
    this.coverPhotoUrl = '',
    this.inspirationText = '',
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? map['companyId']?.toString(),
      companyName: map['company']?['name']?.toString() ?? map['companyName']?.toString(),
      pid: map['pid'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      description: map['description'] ?? '',
      status: _parseStatus(map['status']),
      totalBudget: (map['total_budget'] ?? map['totalBudget'] ?? 0).toDouble(),
      consumedBudget: (map['consumed_budget'] ?? map['consumedBudget'] ?? 0).toDouble(),
      startDate: DateTime.parse(map['start_date'] ?? map['startDate'] ?? DateTime.now().toIso8601String()),
      brandColor: _parseColor(map['brand_color'] ?? map['brandColor']),
      taskIds: List<String>.from(map['task_ids'] ?? map['taskIds'] ?? []),
      plans: List<Plan>.from((map['plans'] as List? ?? []).map((p) => Plan.fromMap(p))),
      isApproved: _parseBool(map['is_approved'] ?? map['isApproved']),
      minBudget: (map['min_budget'] ?? map['minBudget'] ?? 0.0).toDouble(),
      maxBudget: (map['max_budget'] ?? map['maxBudget'] ?? 0.0).toDouble(),
      managerSignature: map['manager_signature'] ?? map['managerSignature'] ?? '',
      managerSignatureTimestamp: (map['manager_signature_timestamp'] ?? map['managerSignatureTimestamp']) != null 
          ? DateTime.parse(map['manager_signature_timestamp'] ?? map['managerSignatureTimestamp']) : null,
      founderSignature: map['founder_signature'] ?? map['founderSignature'] ?? '',
      founderSignatureTimestamp: (map['founder_signature_timestamp'] ?? map['founderSignatureTimestamp']) != null 
          ? DateTime.parse(map['founder_signature_timestamp'] ?? map['founderSignatureTimestamp']) : null,
      confirmedBudget: (map['confirmed_budget'] ?? map['confirmedBudget']) != null 
          ? (map['confirmed_budget'] ?? map['confirmedBudget'] as num).toDouble() : null,
      website: map['website'] ?? map['website_url'] ?? '',
      coverPhotoUrl: map['cover_photo_url'] ?? map['coverPhotoUrl'] ?? '',
      inspirationText: map['inspiration_text'] ?? map['inspirationText'] ?? '',
    );
  }

  static bool _parseBool(dynamic val) {
    if (val == null) return true;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) {
      final s = val.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'active';
    }
    return false;
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
