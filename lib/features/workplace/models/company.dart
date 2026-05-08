import 'dart:convert';

enum CompanyStatus { active, onHold, archived, pending, declined }

class Company {
  final String id;
  final String name;
  final String? logoUrl;
  final List<String> categories;
  final String website;
  
  // Stats
  final int activeEmployees;
  final int managerCount;
  final int staffCount;
  final double annualRevenue;
  final double healthScore; 
  final double budgetUtilized;
  
  // Status
  final CompanyStatus status;
  
  // Contact
  final String primaryEmail;
  final String phone;
  final String location;
  
  // Relational Data
  final List<String> projectIds;
  final DateTime createdAt;

  // Blueprint / Record Data
  final String? shortDescription;
  final String? fullDescription;
  final String? brandingInfo;
  final String? agreementLink;
  final String? agreementShortDesc;
  final String? agreementFullDesc;
  final String? roadmapExecution;
  final String? targetRoadmap;
  final String? managerSignature;
  final DateTime? managerSignatureTimestamp;
  final String? founderSignature;
  final DateTime? founderSignatureTimestamp;
  final Map<String, String>? socialLinks;
  final List<Map<String, String>> onlinePlatforms;

  Company({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.categories,
    required this.website,
    this.activeEmployees = 0,
    this.managerCount = 0,
    this.staffCount = 0,
    this.annualRevenue = 0.0,
    this.healthScore = 0.9,
    this.budgetUtilized = 0.0,
    this.status = CompanyStatus.active,
    required this.primaryEmail,
    required this.phone,
    required this.location,
    this.projectIds = const [],
    DateTime? createdAt,
    this.shortDescription,
    this.fullDescription,
    this.brandingInfo,
    this.agreementLink,
    this.agreementShortDesc,
    this.agreementFullDesc,
    this.roadmapExecution,
    this.targetRoadmap,
    this.managerSignature,
    this.managerSignatureTimestamp,
    this.founderSignature,
    this.founderSignatureTimestamp,
    this.socialLinks,
    this.onlinePlatforms = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  Company copyWith({
    String? id,
    String? name,
    String? logoUrl,
    List<String>? categories,
    String? website,
    int? activeEmployees,
    int? managerCount,
    int? staffCount,
    double? annualRevenue,
    double? healthScore,
    double? budgetUtilized,
    CompanyStatus? status,
    String? primaryEmail,
    String? phone,
    String? location,
    List<String>? projectIds,
    DateTime? createdAt,
    String? shortDescription,
    String? fullDescription,
    String? brandingInfo,
    String? agreementLink,
    String? agreementShortDesc,
    String? agreementFullDesc,
    String? roadmapExecution,
    String? targetRoadmap,
    String? managerSignature,
    DateTime? managerSignatureTimestamp,
    String? founderSignature,
    DateTime? founderSignatureTimestamp,
    Map<String, String>? socialLinks,
    List<Map<String, String>>? onlinePlatforms,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      categories: categories ?? this.categories,
      website: website ?? this.website,
      activeEmployees: activeEmployees ?? this.activeEmployees,
      managerCount: managerCount ?? this.managerCount,
      staffCount: staffCount ?? this.staffCount,
      annualRevenue: annualRevenue ?? this.annualRevenue,
      healthScore: healthScore ?? this.healthScore,
      budgetUtilized: budgetUtilized ?? this.budgetUtilized,
      status: status ?? this.status,
      primaryEmail: primaryEmail ?? this.primaryEmail,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt ?? this.createdAt,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      brandingInfo: brandingInfo ?? this.brandingInfo,
      agreementLink: agreementLink ?? this.agreementLink,
      agreementShortDesc: agreementShortDesc ?? this.agreementShortDesc,
      agreementFullDesc: agreementFullDesc ?? this.agreementFullDesc,
      roadmapExecution: roadmapExecution ?? this.roadmapExecution,
      targetRoadmap: targetRoadmap ?? this.targetRoadmap,
      managerSignature: managerSignature ?? this.managerSignature,
      managerSignatureTimestamp: managerSignatureTimestamp ?? this.managerSignatureTimestamp,
      founderSignature: founderSignature ?? this.founderSignature,
      founderSignatureTimestamp: founderSignatureTimestamp ?? this.founderSignatureTimestamp,
      socialLinks: socialLinks ?? this.socialLinks,
      onlinePlatforms: onlinePlatforms ?? this.onlinePlatforms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'categories': categories,
      'website': website,
      'active_employees': activeEmployees,
      'annual_revenue': annualRevenue,
      'health_score': healthScore,
      'budget_utilized': budgetUtilized,
      'status': status.index,
      'primary_email': primaryEmail,
      'phone': phone,
      'location': location,
      'project_ids': projectIds,
      'created_at': createdAt.toIso8601String(),
      'short_description': shortDescription,
      'full_description': fullDescription,
      'branding_info': brandingInfo,
      'agreement_link': agreementLink,
      'agreement_short_desc': agreementShortDesc,
      'agreement_full_desc': agreementFullDesc,
      'roadmap_execution': roadmapExecution,
      'target_roadmap': targetRoadmap,
      'manager_signature': managerSignature,
      'manager_signature_timestamp': managerSignatureTimestamp?.toIso8601String(),
      'founder_signature': founderSignature,
      'founder_signature_timestamp': founderSignatureTimestamp?.toIso8601String(),
      'social_links': socialLinks,
      'online_platforms': onlinePlatforms,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unnamed Organization',
      logoUrl: map['logo_url'],
      categories: map['categories'] is String 
          ? List<String>.from((_safeJsonDecode(map['categories']) as List? ?? []).map((e) => e?.toString() ?? ''))
          : List<String>.from((map['categories'] as List? ?? []).map((e) => e?.toString() ?? '')),
      website: map['website'] ?? '',
      activeEmployees: map['active_employees'] ?? 0,
      managerCount: map['manager_count'] ?? 0,
      staffCount: map['staff_count'] ?? 0,
      annualRevenue: (map['annual_revenue'] ?? 0).toDouble(),
      healthScore: (map['health_score'] ?? 0.9).toDouble(),
      budgetUtilized: (map['budget_utilized'] ?? 0).toDouble(),
      status: _parseStatus(map['status_text'] ?? map['status']),
      primaryEmail: map['primary_email'] ?? 'contact@organization.reg',
      phone: map['phone'] ?? 'System Direct',
      location: map['location'] ?? 'Global Network',
      projectIds: map['project_ids'] is String
          ? List<String>.from((_safeJsonDecode(map['project_ids']) as List? ?? []).map((e) => e?.toString() ?? ''))
          : List<String>.from((map['project_ids'] as List? ?? []).map((e) => e?.toString() ?? '')),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      shortDescription: map['short_description'],
      fullDescription: map['full_description'],
      brandingInfo: map['branding_info'],
      agreementLink: map['agreement_link'],
      agreementShortDesc: map['agreement_short_desc'],
      agreementFullDesc: map['agreement_full_desc'],
      roadmapExecution: map['roadmap_execution'],
      targetRoadmap: map['target_roadmap'],
      managerSignature: map['manager_signature'],
      managerSignatureTimestamp: map['manager_signature_timestamp'] != null ? DateTime.parse(map['manager_signature_timestamp']) : null,
      founderSignature: map['founder_signature'],
      founderSignatureTimestamp: map['founder_signature_timestamp'] != null ? DateTime.parse(map['founder_signature_timestamp']) : null,
      socialLinks: map['social_links'] is String 
          ? Map<String, String>.from((_safeJsonDecode(map['social_links']) as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
          : (map['social_links'] != null 
              ? Map<String, String>.from((map['social_links'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
              : null),
      onlinePlatforms: map['online_platforms'] is String
          ? List<Map<String, String>>.from((_safeJsonDecode(map['online_platforms']) as List? ?? []).map((e) {
              final map = e as Map? ?? {};
              return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
            }))
          : (map['online_platforms'] != null
              ? List<Map<String, String>>.from((map['online_platforms'] as List).map((e) {
                  final map = e as Map? ?? {};
                  return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
                }))
              : []),
    );
  }

  static CompanyStatus _parseStatus(dynamic value) {
    if (value == null) return CompanyStatus.active;
    if (value is int) {
      if (value < 0 || value >= CompanyStatus.values.length) return CompanyStatus.active;
      return CompanyStatus.values[value];
    }
    if (value is String) {
      final s = value.toLowerCase();
      if (s == 'archived') return CompanyStatus.archived;
      if (s == 'onhold' || s == 'on_hold') return CompanyStatus.onHold;
      if (s == 'pending') return CompanyStatus.pending;
      if (s == 'declined') return CompanyStatus.declined;
      return CompanyStatus.active;
    }
    return CompanyStatus.active;
  }

  static dynamic _safeJsonDecode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return json.decode(value);
    } catch (_) {
      return null;
    }
  }
}
