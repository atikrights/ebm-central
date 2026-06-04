import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/company_external_quota.dart';
import '../../../core/network/api_service.dart';
import 'package:uuid/uuid.dart';

class CompanyExternalQuotaNotifier extends StateNotifier<List<CompanyExternalQuota>> {
  final String companyId;
  final Ref _ref;

  CompanyExternalQuotaNotifier(this.companyId, this._ref) : super([]) {
    fetchQuotas();
    _ref.read(companyExternalQuotaTrashedProvider(companyId).notifier).fetchTrashedQuotas();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchQuotas({bool showTrashed = false}) async {
    try {
      final endpoint = showTrashed 
          ? '/companies/$companyId/external-quotas/trashed' 
          : '/companies/$companyId/external-quotas';
      final dynamic response = await _api.get(endpoint);
      
      if (response is List) {
        final quotas = response.map((e) => CompanyExternalQuota.fromMap(e as Map<String, dynamic>)).toList();
        // Sort by date descending
        quotas.sort((a, b) => b.date.compareTo(a.date));
        state = quotas;
      } else {
        state = [];
      }
    } catch (e) {
      debugPrint('Error loading external quotas for $companyId: $e');
      state = [];
    }
  }

  Future<void> addQuota({required String title, required String tag}) async {
    final random = Random();
    final rand1 = random.nextInt(900) + 100; // 3 digits: 100 to 999
    final rand2 = random.nextInt(9000) + 1000; // 4 digits: 1000 to 9999
    final qid = 'QID-$rand1-$rand2';

    final newQuota = CompanyExternalQuota(
      id: const Uuid().v4(),
      companyId: companyId,
      earn: 0.0,
      expense: 0.0,
      date: DateTime.now(),
      title: title,
      tag: tag,
      qid: qid,
      earnDescription: '',
      earnTime: '',
      expenseDescription: '',
      expenseTime: '',
    );
    
    try {
      await _api.post('/companies/$companyId/external-quotas', newQuota.toMap());
      await fetchQuotas(showTrashed: false);
    } catch (e) {
      debugPrint('Error adding quota: $e');
      rethrow;
    }
  }

  Future<void> updateQuota(CompanyExternalQuota updatedQuota) async {
    try {
      await _api.put('/external-quotas/${updatedQuota.id}', updatedQuota.toMap());
      await fetchQuotas(showTrashed: false);
    } catch (e) {
      debugPrint('Error updating quota: $e');
      rethrow;
    }
  }

  Future<void> deleteQuota(String id, {bool isShowingTrashed = false}) async {
    try {
      await _api.delete('/external-quotas/$id');
      await fetchQuotas(showTrashed: isShowingTrashed);
      _ref.read(companyExternalQuotaTrashedProvider(companyId).notifier).fetchTrashedQuotas();
    } catch (e) {
      debugPrint('Error deleting quota: $e');
      rethrow;
    }
  }

  Future<void> restoreQuota(String id) async {
    try {
      await _api.post('/external-quotas/$id/restore', {});
      await fetchQuotas(showTrashed: true);
      _ref.read(companyExternalQuotaTrashedProvider(companyId).notifier).fetchTrashedQuotas();
    } catch (e) {
      debugPrint('Error restoring quota: $e');
      rethrow;
    }
  }

  Future<void> forceDeleteQuota(String id) async {
    try {
      await _api.delete('/external-quotas/$id/force-delete');
      await fetchQuotas(showTrashed: true);
      _ref.read(companyExternalQuotaTrashedProvider(companyId).notifier).fetchTrashedQuotas();
    } catch (e) {
      debugPrint('Error force deleting quota: $e');
      rethrow;
    }
  }
}

final companyExternalQuotaProvider = StateNotifierProvider.family<CompanyExternalQuotaNotifier, List<CompanyExternalQuota>, String>((ref, companyId) {
  return CompanyExternalQuotaNotifier(companyId, ref);
});

final companyExternalQuotaTrashedProvider = StateNotifierProvider.family<CompanyExternalQuotaTrashedNotifier, List<CompanyExternalQuota>, String>((ref, companyId) {
  return CompanyExternalQuotaTrashedNotifier(companyId, ref);
});

class CompanyExternalQuotaTrashedNotifier extends StateNotifier<List<CompanyExternalQuota>> {
  final String companyId;
  final Ref _ref;

  CompanyExternalQuotaTrashedNotifier(this.companyId, this._ref) : super([]) {
    fetchTrashedQuotas();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<void> fetchTrashedQuotas() async {
    try {
      final dynamic response = await _api.get('/companies/$companyId/external-quotas/trashed');
      if (response is List) {
        state = response.map((e) => CompanyExternalQuota.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading trashed quotas: $e');
    }
  }
}
