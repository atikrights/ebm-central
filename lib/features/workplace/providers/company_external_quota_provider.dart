import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_external_quota.dart';
import 'package:uuid/uuid.dart';

class CompanyExternalQuotaNotifier extends StateNotifier<List<CompanyExternalQuota>> {
  final String companyId;
  late final String _storageKey;

  CompanyExternalQuotaNotifier(this.companyId) : super([]) {
    _storageKey = 'ebm_central_external_quota_$companyId';
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        final quotas = decoded.map((e) => CompanyExternalQuota.fromMap(e as Map<String, dynamic>)).toList();
        // Sort by date descending
        quotas.sort((a, b) => b.date.compareTo(a.date));
        state = quotas;
      } catch (e) {
        debugPrint('Error loading external quotas for $companyId: $e');
      }
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((e) => e.toMap()).toList();
    await prefs.setString(_storageKey, json.encode(data));
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
    state = [newQuota, ...state];
    await _saveToStorage();
  }

  Future<void> updateQuota(CompanyExternalQuota updatedQuota) async {
    state = state.map((q) => q.id == updatedQuota.id ? updatedQuota : q).toList();
    await _saveToStorage();
  }

  Future<void> deleteQuota(String id) async {
    state = state.where((q) => q.id != id).toList();
    await _saveToStorage();
  }
}

final companyExternalQuotaProvider = StateNotifierProvider.family<CompanyExternalQuotaNotifier, List<CompanyExternalQuota>, String>((ref, companyId) {
  return CompanyExternalQuotaNotifier(companyId);
});
