import 'dart:convert';

class CompanyFund {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final double amount;
  final String tags;
  final String fid;
  final DateTime date;

  CompanyFund({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.amount,
    required this.tags,
    required this.fid,
    required this.date,
  });

  CompanyFund copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    double? amount,
    String? tags,
    String? fid,
    DateTime? date,
  }) {
    return CompanyFund(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      tags: tags ?? this.tags,
      fid: fid ?? this.fid,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'company_id': companyId,
      'title': title,
      'description': description,
      'amount': amount,
      'tags': tags,
      'fid': fid,
      'date': date.millisecondsSinceEpoch,
    };
  }

  factory CompanyFund.fromMap(Map<String, dynamic> map) {
    final String rawId = map['id'] ?? '';
    final String fallbackFid = rawId.length >= 8
        ? 'FID-${rawId.substring(0, 8).toUpperCase()}'
        : 'FID-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    DateTime parsedDate;
    if (map['date'] == null) {
      parsedDate = DateTime.now();
    } else if (map['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date']).toLocal();
    } else if (map['date'] is String) {
      final dateStr = map['date'] as String;
      if (!dateStr.endsWith('Z') &&
          !dateStr.contains('+') &&
          !dateStr.contains(RegExp(r'-\d{2}:\d{2}'))) {
        final normalizedStr = dateStr.replaceAll(' ', 'T') + 'Z';
        parsedDate = (DateTime.tryParse(normalizedStr) ??
                DateTime.tryParse(dateStr) ??
                DateTime.now())
            .toLocal();
      } else {
        parsedDate = (DateTime.tryParse(dateStr) ?? DateTime.now()).toLocal();
      }
    } else {
      parsedDate = DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return CompanyFund(
      id: rawId,
      companyId: (map['companyId'] ?? map['company_id'] ?? '').toString(),
      title: map['title'] ?? 'Untitled Fund',
      description: map['description'] ?? '',
      amount: parseDouble(map['amount']),
      tags: map['tags'] ?? '',
      fid: map['fid'] ?? fallbackFid,
      date: parsedDate,
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyFund.fromJson(String source) =>
      CompanyFund.fromMap(json.decode(source));
}
