import 'dart:convert';

class CompanyStockAsset {
  final String name;
  final double minPrice;
  final double maxPrice;

  CompanyStockAsset({
    required this.name,
    required this.minPrice,
    required this.maxPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'min_price': minPrice,
      'minPrice': minPrice,
      'max_price': maxPrice,
      'maxPrice': maxPrice,
    };
  }

  factory CompanyStockAsset.fromMap(Map<String, dynamic> map) {
    return CompanyStockAsset(
      name: map['name'] ?? '',
      minPrice: (map['min_price'] ?? map['minPrice'] ?? 0.0).toDouble(),
      maxPrice: (map['max_price'] ?? map['maxPrice'] ?? 0.0).toDouble(),
    );
  }
}

class CompanyStock {
  final String id;
  final String companyId;
  final String title;
  final String stkCode;
  final DateTime date;
  final String description;
  final List<CompanyStockAsset> assets;

  CompanyStock({
    required this.id,
    required this.companyId,
    required this.title,
    required this.stkCode,
    required this.date,
    this.description = '',
    this.assets = const [],
  });

  CompanyStock copyWith({
    String? id,
    String? companyId,
    String? title,
    String? stkCode,
    DateTime? date,
    String? description,
    List<CompanyStockAsset>? assets,
  }) {
    return CompanyStock(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      stkCode: stkCode ?? this.stkCode,
      date: date ?? this.date,
      description: description ?? this.description,
      assets: assets ?? this.assets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'company_id': companyId,
      'title': title,
      'stk_code': stkCode,
      'stkCode': stkCode,
      'date': date.millisecondsSinceEpoch,
      'description': description,
      'assets': assets.map((x) => x.toMap()).toList(),
    };
  }

  factory CompanyStock.fromMap(Map<String, dynamic> map) {
    final String rawId = map['id'] ?? '';
    final String fallbackStkCode = rawId.length >= 6 
        ? rawId.substring(0, 6).toUpperCase()
        : 'STK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    DateTime parsedDate;
    if (map['date'] == null) {
      parsedDate = DateTime.now();
    } else if (map['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date']).toLocal();
    } else if (map['date'] is String) {
      final dateStr = map['date'] as String;
      if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains(RegExp(r'-\d{2}:\d{2}'))) {
        final normalizedStr = dateStr.replaceAll(' ', 'T') + 'Z';
        parsedDate = (DateTime.tryParse(normalizedStr) ?? DateTime.tryParse(dateStr) ?? DateTime.now()).toLocal();
      } else {
        parsedDate = (DateTime.tryParse(dateStr) ?? DateTime.now()).toLocal();
      }
    } else {
      parsedDate = DateTime.now();
    }

    List<CompanyStockAsset> parsedAssets = [];
    if (map['assets'] != null) {
      if (map['assets'] is List) {
        parsedAssets = (map['assets'] as List)
            .map((x) => CompanyStockAsset.fromMap(x is String ? json.decode(x) : Map<String, dynamic>.from(x)))
            .toList();
      } else if (map['assets'] is String) {
        try {
          final decoded = json.decode(map['assets']);
          if (decoded is List) {
            parsedAssets = decoded.map((x) => CompanyStockAsset.fromMap(Map<String, dynamic>.from(x))).toList();
          }
        } catch (_) {}
      }
    }

    return CompanyStock(
      id: rawId,
      companyId: (map['companyId'] ?? map['company_id'] ?? '').toString(),
      title: map['title'] ?? 'Untitled Stock',
      stkCode: map['stk_code'] ?? map['stkCode'] ?? fallbackStkCode,
      date: parsedDate,
      description: map['description'] ?? '',
      assets: parsedAssets,
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyStock.fromJson(String source) => CompanyStock.fromMap(json.decode(source));
}
