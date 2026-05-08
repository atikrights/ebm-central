import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/company.dart';

// ─────────────────────────────────────────────
// Company State Model
// ─────────────────────────────────────────────
class CompanyState {
  final List<Company> companies;
  final List<String> categories;
  final String searchQuery;
  final String? filterCategory;
  final String? selectedCompanyId;
  final bool isLoading;

  CompanyState({
    this.companies = const [],
    this.categories = const [],
    this.searchQuery = '',
    this.filterCategory,
    this.selectedCompanyId,
    this.isLoading = true,
  });

  CompanyState copyWith({
    List<Company>? companies,
    List<String>? categories,
    String? searchQuery,
    String? filterCategory,
    String? selectedCompanyId,
    bool? isLoading,
  }) {
    return CompanyState(
      companies: companies ?? this.companies,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategory: filterCategory ?? this.filterCategory,
      selectedCompanyId: selectedCompanyId ?? this.selectedCompanyId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─────────────────────────────────────────────
// Company Notifier (Riverpod v3 — uses AsyncNotifier)
// ─────────────────────────────────────────────
class CompanyNotifier extends AsyncNotifier<CompanyState> {
  static const String _storageKey = 'ebm_central_company_registry_v2';
  bool _isSyncing = false; // Guard to prevent concurrent API pile-up

  @override
  Future<CompanyState> build() async {
    // 1. First, try to load from local storage for immediate UI
    final localData = await _loadFromStorage();
    
    // 2. Start a periodic timer for real-time updates (every 30 seconds)
    _startPeriodicSync();
    
    return localData ?? CompanyState(isLoading: false);
  }

  void _startPeriodicSync() {
    // Sync immediately on startup
    _syncInBackground();
    
    // Background refresh every 2 seconds for a 'fast' real-time feel
    Future.delayed(const Duration(seconds: 2), () {
      if (state.hasValue) {
         _startPeriodicSync();
      }
    });
  }

  Future<void> _syncInBackground() async {
    if (_isSyncing) return; // Prevent concurrent pile-up
    _isSyncing = true;
    try {
      final auth = ref.read(authProvider);
      if (!auth.isLoggedIn) { _isSyncing = false; return; }

      final api = ref.read(apiServiceProvider);
      // Fetch both in parallel
      final results = await Future.wait([
        api.get('/companies'),
        api.get('/categories'),
      ]);

      final dynamic companyRes = results[0];
      final dynamic catRes = results[1];

      if (companyRes is List && catRes is List) {
        final companies = companyRes.map((m) => Company.fromMap(m)).toList();
        final serverCategories = catRes.map((c) => c['name'].toString()).toList();
        final currentState = state.value ?? CompanyState();

        // ✅ FIX: Improved change detection to catch field-level updates and category content changes
        final bool hasChanges = json.encode(companies.map((c) => c.toMap()).toList()) != 
                               json.encode(currentState.companies.map((c) => c.toMap()).toList()) ||
                               json.encode(serverCategories) != json.encode(currentState.categories.where((c) => c != 'All').toList());

        // ✅ Trust backend for visibility
        // Remove any existing 'all' (case-insensitive) to prevent duplicates before adding UI 'All'
        final List<String> finalCategories = serverCategories
            .where((c) => c.toLowerCase() != 'all')
            .toList();
            
        finalCategories.insert(0, 'All');

        // Ensure UI doesn't break if the selected category was deleted
        String? validFilter = currentState.filterCategory;
        if (validFilter != null && !finalCategories.contains(validFilter)) {
          validFilter = null;
        }

        if (hasChanges || validFilter != currentState.filterCategory) {
          state = AsyncData(currentState.copyWith(
            companies: companies,
            categories: finalCategories,
            filterCategory: validFilter,
            isLoading: false,
          ));
          _saveToStorage(state.value!);
        }
      }
    } catch (_) {
      // Silent fail — keep existing UI
    } finally {
      _isSyncing = false;
    }
  }

  Future<CompanyState?> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final dynamic decoded = json.decode(jsonStr);
        if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid JSON structure');
        
        final companies = (decoded['companies'] as List).map((m) => Company.fromMap(m)).toList();
        final categories = List<String>.from(decoded['categories'] ?? []);
        
        return CompanyState(
          companies: companies,
          categories: categories,
          isLoading: false,
          selectedCompanyId: companies.isNotEmpty ? companies.first.id : null,
        );
      } catch (e) {
        debugPrint('SharedPreferences corrupted: $e. Clearing cache.');
        await prefs.remove(_storageKey);
        return null;
      }
    }
    return null;
  }

  Future<void> _saveToStorage(CompanyState currentState) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'companies': currentState.companies.map((c) => c.toMap()).toList(),
      'categories': currentState.categories,
    };
    await prefs.setString(_storageKey, json.encode(data));
  }

  // ── Public Actions ──────────────────────────
  
  // ── Public Actions ──────────────────────────

  /// Full sync — does NOT show a loading spinner. Updates silently in-place.
  Future<void> syncWithDatabase() async {
    try {
      final api = ref.read(apiServiceProvider);
      final List<dynamic> companyRes = await api.get('/companies');
      final List<dynamic> catRes = await api.get('/categories');

      final companies = companyRes.map((m) => Company.fromMap(m)).toList();
      final serverCats = catRes.map((c) => c['name'].toString()).toList();

      // ✅ Trust backend for visibility
      final List<String> finalCategories = serverCats
          .where((c) => c.toLowerCase() != 'all')
          .toList();
      finalCategories.insert(0, 'All');

      final current = state.value;
      if (current == null) return;

      // Ensure UI doesn't break if the selected category was deleted
      String? validFilter = current.filterCategory;
      if (validFilter != null && !finalCategories.contains(validFilter)) {
        validFilter = null;
      }

      final newState = current.copyWith(
        companies: companies,
        categories: finalCategories,
        filterCategory: validFilter,
        isLoading: false,
      );
      state = AsyncData(newState);
      _saveToStorage(newState);
    } catch (_) {
      // Silent fail — keep existing UI state
    }
  }

  void setSearchQuery(String query) {
    if (state.value == null) return;
    state = AsyncData(state.value!.copyWith(searchQuery: query));
  }

  void setCategoryFilter(String? category) {
    if (state.value == null) return;
    state = AsyncData(CompanyState(
      companies: state.value!.companies,
      categories: state.value!.categories,
      searchQuery: state.value!.searchQuery,
      filterCategory: category,
      selectedCompanyId: state.value!.selectedCompanyId,
      isLoading: state.value!.isLoading,
    ));
  }

  Future<void> addCompany(Company company) async {
    if (state.value == null) return;
    
    final oldState = state.value!;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempCompany = company.copyWith(id: tempId);
    
    // Add locally for instant UI
    state = AsyncData(oldState.copyWith(
      companies: [...oldState.companies, tempCompany]
    ));

    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/companies', company.toMap());
      
      // Force refresh to get real ID and links
      await syncWithDatabase();
    } catch (e) {
      // Revert and report error
      state = AsyncData(oldState);
      rethrow; 
    }
  }

  Future<void> updateCompany(Company company) async {
    if (state.value == null) return;
    
    final oldState = state.value!;
    // Optimistic Update
    state = AsyncData(oldState.copyWith(
      companies: oldState.companies.map((c) => c.id == company.id ? company : c).toList(),
    ));

    try {
      final api = ref.read(apiServiceProvider);
      await api.put('/companies/${company.id}', company.toMap());
      await syncWithDatabase(); // Ensure sync with backend calculated fields
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> deleteCompany(String id) async {
    if (state.value == null) return;
    
    final oldState = state.value!;
    try {
      final api = ref.read(apiServiceProvider);
      // Optimistic Update
      state = AsyncData(oldState.copyWith(
        companies: oldState.companies.where((c) => c.id != id).toList()
      ));
      
      await api.delete('/companies/$id');
      await syncWithDatabase(); // Refresh to ensure sync
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> archiveCompany(String id) async {
    if (state.value == null) return;
    
    final oldState = state.value!;
    try {
      final api = ref.read(apiServiceProvider);
      // Optimistic Update
      state = AsyncData(oldState.copyWith(
        companies: oldState.companies.map((c) => c.id == id ? c.copyWith(status: CompanyStatus.archived) : c).toList(),
      ));

      // Assuming we have an update endpoint that can change status
      await api.put('/companies/$id', {'status': CompanyStatus.archived.index});
      _saveToStorage(state.value!);
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> restoreCompany(String id) async {
    if (state.value == null) return;
    
    final oldState = state.value!;
    try {
      final api = ref.read(apiServiceProvider);
      // Optimistic Update
      state = AsyncData(oldState.copyWith(
        companies: oldState.companies.map((c) => c.id == id ? c.copyWith(status: CompanyStatus.active) : c).toList(),
      ));

      await api.put('/companies/$id', {'status': CompanyStatus.active.index});
      await syncWithDatabase(); // Full sync after restore
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> manageCategory(String? oldName, String newName, List<String> assignedCompanyIds) async {
    if (state.value == null) return;
    final currentState = state.value!;

    // 1. INSTANT OPTIMISTIC UI UPDATE
    final updatedCategories = [...currentState.categories];
    if (oldName != null && oldName != newName) {
      final index = updatedCategories.indexOf(oldName);
      if (index != -1) updatedCategories[index] = newName;
    } else if (oldName == null && !updatedCategories.contains(newName)) {
      updatedCategories.add(newName);
    }

    final updatedCompanies = currentState.companies.map((c) {
      final cats = List<String>.from(c.categories);
      if (oldName != null) cats.remove(oldName);
      cats.remove(newName);
      if (assignedCompanyIds.contains(c.id)) {
        cats.add(newName);
      }
      return c.copyWith(categories: cats.toSet().toList());
    }).toList();

    state = AsyncData(CompanyState(
      companies: updatedCompanies,
      categories: updatedCategories,
      searchQuery: currentState.searchQuery,
      filterCategory: currentState.filterCategory == oldName ? newName : currentState.filterCategory,
      selectedCompanyId: currentState.selectedCompanyId,
      isLoading: currentState.isLoading,
    ));

    // 2. BACKGROUND CONCURRENT API SYNC
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/categories', {'name': newName});

      final futures = <Future>[];
      for (var company in currentState.companies) {
        final isCurrentlyAssigned = company.categories.contains(oldName ?? newName);
        final shouldBeAssigned = assignedCompanyIds.contains(company.id);

        if (isCurrentlyAssigned != shouldBeAssigned || (oldName != null && isCurrentlyAssigned)) {
           final cats = List<String>.from(company.categories);
           if (oldName != null) cats.remove(oldName);
           cats.remove(newName);
           if (shouldBeAssigned) cats.add(newName);
           
           futures.add(api.put('/companies/${company.id}', {'categories': cats.toSet().toList()}));
        }
      }

      if (oldName != null && oldName != newName) {
         final oldId = oldName.toLowerCase().replaceAll(' ', '_');
         futures.add(api.delete('/categories/$oldId'));
      }

      await Future.wait(futures); // Run all updates simultaneously
      await syncWithDatabase(); // Final verify
    } catch (e) {
      await syncWithDatabase(); 
    }
  }

  Future<void> deleteCategory(String category) async {
    if (state.value == null) return;
    final currentState = state.value!;

    // 1. INSTANT OPTIMISTIC UI UPDATE
    state = AsyncData(CompanyState(
      companies: currentState.companies.map((c) => c.copyWith(
        categories: c.categories.where((cat) => cat != category).toList(),
      )).toList(),
      categories: currentState.categories.where((c) => c != category).toList(),
      searchQuery: currentState.searchQuery,
      filterCategory: currentState.filterCategory == category ? null : currentState.filterCategory,
      selectedCompanyId: currentState.selectedCompanyId,
      isLoading: currentState.isLoading,
    ));
    
    // 2. BACKGROUND API SYNC
    try {
      final api = ref.read(apiServiceProvider);
      final catId = category.toLowerCase().replaceAll(' ', '_');
      
      final futures = <Future>[];
      futures.add(api.delete('/categories/$catId'));

      for (var company in currentState.companies) {
         if (company.categories.contains(category)) {
            final cats = company.categories.where((cat) => cat != category).toList();
            futures.add(api.put('/companies/${company.id}', {'categories': cats}));
         }
      }
      
      await Future.wait(futures);
      await syncWithDatabase();
    } catch (e) {
      await syncWithDatabase();
    }
  }
}

// ─────────────────────────────────────────────
// Provider (Riverpod v3 — AsyncNotifierProvider)
// ─────────────────────────────────────────────
final companyProvider = AsyncNotifierProvider<CompanyNotifier, CompanyState>(() {
  return CompanyNotifier();
});

final filteredCompaniesProvider = Provider<List<Company>>((ref) {
  final asyncState = ref.watch(companyProvider);
  
  return asyncState.maybeWhen(
    data: (state) {
      return state.companies.where((c) {
        // Only hide archived (Draft) companies from the main grid — Admins see them in the Draft Box
        if (c.status == CompanyStatus.archived) return false;
        
        final matchesSearch = c.name.toLowerCase().contains(state.searchQuery.toLowerCase());
        
        // Category filter: if filtering by a category, show companies that belong to it
        // 'All' shows everything. Pending companies with no categories also pass through.
        final matchesCategory = state.filterCategory == null || 
          state.filterCategory == 'All' ||
          c.categories.any((cat) => cat.toLowerCase() == state.filterCategory!.toLowerCase()) ||
          (c.status == CompanyStatus.pending && c.categories.isEmpty);
          
        return matchesSearch && matchesCategory;
      }).toList();
    },
    orElse: () => [],
  );
});

final archivedCompaniesProvider = Provider<List<Company>>((ref) {
  final asyncState = ref.watch(companyProvider);
  return asyncState.maybeWhen(
    data: (state) => state.companies.where((c) => c.status == CompanyStatus.archived).toList(),
    orElse: () => [],
  );
});
