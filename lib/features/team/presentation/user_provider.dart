import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';

final userListProvider = NotifierProvider<UserListNotifier, AsyncValue<List<dynamic>>>(() {
  return UserListNotifier();
});

class UserListNotifier extends Notifier<AsyncValue<List<dynamic>>> {
  ApiService get _api => ref.watch(apiServiceProvider);

  @override
  AsyncValue<List<dynamic>> build() {
    // Initial fetch
    _fetchInitial();
    return const AsyncValue.loading();
  }

  Future<void> _fetchInitial() async {
    // Small delay to ensure build is complete if needed, 
    // but usually calling it immediately is fine.
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get('/users');
      // Laravel paginate returns data in 'data' field
      final List<dynamic> users = response['data'] ?? [];
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await _api.delete('/users/$id');
      await fetchUsers();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    try {
      await _api.post('/users', data);
      await fetchUsers();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    try {
      await _api.put('/users/$id', data);
      await fetchUsers();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateInvitation(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/governance/invite', data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> fetchActivities() async {
    try {
      final response = await _api.get('/users/activities');
      return response['data'] ?? [];
    } catch (e) {
      rethrow;
    }
  }
}

final userActivitiesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(userListProvider.notifier).fetchActivities();
});
