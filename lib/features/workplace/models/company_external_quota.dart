import 'dart:convert';

class CompanyExternalQuota {
  final String id;
  final String companyId;
  final double earn;
  final double expense;
  final DateTime date;
  final String title;
  final String tag;
  final String qid;
  final String earnDescription;
  final String earnTime;
  final String expenseDescription;
  final String expenseTime;

  CompanyExternalQuota({
    required this.id,
    required this.companyId,
    required this.earn,
    required this.expense,
    required this.date,
    required this.title,
    required this.tag,
    required this.qid,
    required this.earnDescription,
    required this.earnTime,
    required this.expenseDescription,
    required this.expenseTime,
  });

  CompanyExternalQuota copyWith({
    String? id,
    String? companyId,
    double? earn,
    double? expense,
    DateTime? date,
    String? title,
    String? tag,
    String? qid,
    String? earnDescription,
    String? earnTime,
    String? expenseDescription,
    String? expenseTime,
  }) {
    return CompanyExternalQuota(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      earn: earn ?? this.earn,
      expense: expense ?? this.expense,
      date: date ?? this.date,
      title: title ?? this.title,
      tag: tag ?? this.tag,
      qid: qid ?? this.qid,
      earnDescription: earnDescription ?? this.earnDescription,
      earnTime: earnTime ?? this.earnTime,
      expenseDescription: expenseDescription ?? this.expenseDescription,
      expenseTime: expenseTime ?? this.expenseTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'company_id': companyId,
      'earn': earn,
      'expense': expense,
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'tag': tag,
      'qid': qid,
      'earnDescription': earnDescription,
      'earn_description': earnDescription,
      'earnTime': earnTime,
      'earn_time': earnTime,
      'expenseDescription': expenseDescription,
      'expense_description': expenseDescription,
      'expenseTime': expenseTime,
      'expense_time': expenseTime,
    };
  }

  factory CompanyExternalQuota.fromMap(Map<String, dynamic> map) {
    final String rawId = map['id'] ?? '';
    final String fallbackQid = rawId.length >= 8 
        ? 'QID-${rawId.substring(0, 8).toUpperCase()}'
        : 'QID-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    DateTime parsedDate;
    if (map['date'] == null) {
      parsedDate = DateTime.now();
    } else if (map['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date']).toLocal();
    } else if (map['date'] is String) {
      final dateStr = map['date'] as String;
      // If it doesn't end with Z and doesn't contain a timezone offset, append 'Z'
      // to ensure it is parsed as UTC, then converted to local.
      if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains(RegExp(r'-\d{2}:\d{2}'))) {
        final normalizedStr = dateStr.replaceAll(' ', 'T') + 'Z';
        parsedDate = (DateTime.tryParse(normalizedStr) ?? DateTime.tryParse(dateStr) ?? DateTime.now()).toLocal();
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

    return CompanyExternalQuota(
      id: rawId,
      companyId: (map['companyId'] ?? map['company_id'] ?? '').toString(),
      earn: parseDouble(map['earn']),
      expense: parseDouble(map['expense']),
      date: parsedDate,
      title: map['title'] ?? 'Untitled Quota',
      tag: map['tag'] ?? 'General',
      qid: map['qid'] ?? fallbackQid,
      earnDescription: map['earnDescription'] ?? map['earn_description'] ?? '',
      earnTime: map['earnTime'] ?? map['earn_time'] ?? '',
      expenseDescription: map['expenseDescription'] ?? map['expense_description'] ?? '',
      expenseTime: map['expenseTime'] ?? map['expense_time'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyExternalQuota.fromJson(String source) => CompanyExternalQuota.fromMap(json.decode(source));
}
