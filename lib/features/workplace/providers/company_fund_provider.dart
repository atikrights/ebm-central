import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/company_fund.dart';
import '../../../core/network/api_service.dart';
import 'package:uuid/uuid.dart';

class CompanyFundNotifier extends StateNotifier<List<CompanyFund>> {
  final String companyId;
  final Ref _ref;

  CompanyFundNotifier(this.companyId, this._ref) : super([]) {
    fetchFunds();
    _ref.read(companyFundTrashedProvider(companyId).notifier).fetchTrashedFunds();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchFunds({bool showTrashed = false}) async {
    try {
      final endpoint = showTrashed 
          ? '/companies/$companyId/funds/trashed' 
          : '/companies/$companyId/funds';
      final dynamic response = await _api.get(endpoint);
      
      if (response is List) {
        final funds = response.map((e) => CompanyFund.fromMap(e as Map<String, dynamic>)).toList();
        // Sort by date descending
        funds.sort((a, b) => b.date.compareTo(a.date));
        state = funds;
      } else {
        state = [];
      }
    } catch (e) {
      debugPrint('Error loading company funds for $companyId: $e');
      state = [];
    }
  }

  Future<void> addFund({
    required String title,
    required String description,
    required double amount,
    required String tags,
    required DateTime date,
    String? fid,
  }) async {
    final random = Random();
    final rand1 = random.nextInt(900) + 100; // 3 digits: 100 to 999
    final rand2 = random.nextInt(9000) + 1000; // 4 digits: 1000 to 9999
    final finalFid = (fid != null && fid.trim().isNotEmpty) ? fid.trim() : 'FID-$rand1-$rand2';

    final newFund = CompanyFund(
      id: const Uuid().v4(),
      companyId: companyId,
      title: title,
      description: description,
      amount: amount,
      tags: tags,
      fid: finalFid,
      date: date,
    );
    
    try {
      await _api.post('/companies/$companyId/funds', newFund.toMap());
      await fetchFunds(showTrashed: false);
    } catch (e) {
      debugPrint('Error adding fund: $e');
      rethrow;
    }
  }

  Future<void> updateFund(CompanyFund updatedFund) async {
    try {
      await _api.put('/funds/${updatedFund.id}', updatedFund.toMap());
      await fetchFunds(showTrashed: false);
    } catch (e) {
      debugPrint('Error updating fund: $e');
      rethrow;
    }
  }

  Future<void> deleteFund(String id, {bool isShowingTrashed = false}) async {
    try {
      await _api.delete('/funds/$id');
      await fetchFunds(showTrashed: isShowingTrashed);
      _ref.read(companyFundTrashedProvider(companyId).notifier).fetchTrashedFunds();
    } catch (e) {
      debugPrint('Error deleting fund: $e');
      rethrow;
    }
  }

  Future<void> restoreFund(String id) async {
    try {
      await _api.post('/funds/$id/restore', {});
      await fetchFunds(showTrashed: true);
      _ref.read(companyFundTrashedProvider(companyId).notifier).fetchTrashedFunds();
    } catch (e) {
      debugPrint('Error restoring fund: $e');
      rethrow;
    }
  }

  Future<void> forceDeleteFund(String id) async {
    try {
      await _api.delete('/funds/$id/force-delete');
      await fetchFunds(showTrashed: true);
      _ref.read(companyFundTrashedProvider(companyId).notifier).fetchTrashedFunds();
    } catch (e) {
      debugPrint('Error force deleting fund: $e');
      rethrow;
    }
  }
}

final companyFundProvider = StateNotifierProvider.family<CompanyFundNotifier, List<CompanyFund>, String>((ref, companyId) {
  return CompanyFundNotifier(companyId, ref);
});

final companyFundTrashedProvider = StateNotifierProvider.family<CompanyFundTrashedNotifier, List<CompanyFund>, String>((ref, companyId) {
  return CompanyFundTrashedNotifier(companyId, ref);
});

class CompanyFundTrashedNotifier extends StateNotifier<List<CompanyFund>> {
  final String companyId;
  final Ref _ref;

  CompanyFundTrashedNotifier(this.companyId, this._ref) : super([]) {
    fetchTrashedFunds();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchTrashedFunds() async {
    try {
      final dynamic response = await _api.get('/companies/$companyId/funds/trashed');
      if (response is List) {
        state = response.map((e) => CompanyFund.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading trashed funds: $e');
    }
  }
}
