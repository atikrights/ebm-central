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
      'earn': earn,
      'expense': expense,
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'tag': tag,
      'qid': qid,
      'earnDescription': earnDescription,
      'earnTime': earnTime,
      'expenseDescription': expenseDescription,
      'expenseTime': expenseTime,
    };
  }

  factory CompanyExternalQuota.fromMap(Map<String, dynamic> map) {
    final String rawId = map['id'] ?? '';
    final String fallbackQid = rawId.length >= 8 
        ? 'QID-${rawId.substring(0, 8).toUpperCase()}'
        : 'QID-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return CompanyExternalQuota(
      id: rawId,
      companyId: map['companyId'] ?? '',
      earn: (map['earn'] ?? 0.0).toDouble(),
      expense: (map['expense'] ?? 0.0).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      title: map['title'] ?? 'Untitled Quota',
      tag: map['tag'] ?? 'General',
      qid: map['qid'] ?? fallbackQid,
      earnDescription: map['earnDescription'] ?? '',
      earnTime: map['earnTime'] ?? '',
      expenseDescription: map['expenseDescription'] ?? '',
      expenseTime: map['expenseTime'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyExternalQuota.fromJson(String source) => CompanyExternalQuota.fromMap(json.decode(source));
}
