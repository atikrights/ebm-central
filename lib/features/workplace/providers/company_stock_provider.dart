import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/company_stock.dart';
import '../../../core/network/api_service.dart';
import 'package:uuid/uuid.dart';

class CompanyStockNotifier extends StateNotifier<List<CompanyStock>> {
  final String companyId;
  final Ref _ref;

  CompanyStockNotifier(this.companyId, this._ref) : super([]) {
    fetchStocks();
    _ref.read(companyStockTrashedProvider(companyId).notifier).fetchTrashedStocks();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchStocks({bool showTrashed = false}) async {
    try {
      final endpoint = showTrashed 
          ? '/companies/$companyId/stocks/trashed' 
          : '/companies/$companyId/stocks';
      final dynamic response = await _api.get(endpoint);
      
      if (response is List) {
        final stocks = response.map((e) => CompanyStock.fromMap(e as Map<String, dynamic>)).toList();
        // Sort by date descending
        stocks.sort((a, b) => b.date.compareTo(a.date));
        state = stocks;
      } else {
        state = [];
      }
    } catch (e) {
      debugPrint('Error loading company stocks for $companyId: $e');
      state = [];
    }
  }

  Future<void> addStock({required String title, String stkCode = ''}) async {
    final newStock = CompanyStock(
      id: const Uuid().v4(),
      companyId: companyId,
      title: title,
      stkCode: stkCode,
      date: DateTime.now(),
    );
    
    try {
      await _api.post('/companies/$companyId/stocks', newStock.toMap());
      await fetchStocks(showTrashed: false);
    } catch (e) {
      debugPrint('Error adding stock: $e');
      rethrow;
    }
  }

  Future<void> updateStock(CompanyStock updatedStock) async {
    try {
      await _api.put('/stocks/${updatedStock.id}', updatedStock.toMap());
      await fetchStocks(showTrashed: false);
    } catch (e) {
      debugPrint('Error updating stock: $e');
      rethrow;
    }
  }

  Future<void> deleteStock(String id, {bool isShowingTrashed = false}) async {
    try {
      await _api.delete('/stocks/$id');
      await fetchStocks(showTrashed: isShowingTrashed);
      _ref.read(companyStockTrashedProvider(companyId).notifier).fetchTrashedStocks();
    } catch (e) {
      debugPrint('Error deleting stock: $e');
      rethrow;
    }
  }

  Future<void> restoreStock(String id) async {
    try {
      await _api.post('/stocks/$id/restore', {});
      await fetchStocks(showTrashed: true);
      _ref.read(companyStockTrashedProvider(companyId).notifier).fetchTrashedStocks();
    } catch (e) {
      debugPrint('Error restoring stock: $e');
      rethrow;
    }
  }

  Future<void> forceDeleteStock(String id) async {
    try {
      await _api.delete('/stocks/$id/force-delete');
      await fetchStocks(showTrashed: true);
      _ref.read(companyStockTrashedProvider(companyId).notifier).fetchTrashedStocks();
    } catch (e) {
      debugPrint('Error force deleting stock: $e');
      rethrow;
    }
  }
}

final companyStockProvider = StateNotifierProvider.family<CompanyStockNotifier, List<CompanyStock>, String>((ref, companyId) {
  return CompanyStockNotifier(companyId, ref);
});

final companyStockTrashedProvider = StateNotifierProvider.family<CompanyStockTrashedNotifier, List<CompanyStock>, String>((ref, companyId) {
  return CompanyStockTrashedNotifier(companyId, ref);
});

class CompanyStockTrashedNotifier extends StateNotifier<List<CompanyStock>> {
  final String companyId;
  final Ref _ref;

  CompanyStockTrashedNotifier(this.companyId, this._ref) : super([]) {
    fetchTrashedStocks();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchTrashedStocks() async {
    try {
      final dynamic response = await _api.get('/companies/$companyId/stocks/trashed');
      if (response is List) {
        state = response.map((e) => CompanyStock.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading trashed stocks: $e');
    }
  }
}
