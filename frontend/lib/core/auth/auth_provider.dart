import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';

// ─────────────────────────────────────────────
// Auth State Model
// ─────────────────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final String? name;
  final String? email;
  final String? role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.name,
    this.email,
    this.role,
    this.isLoading = false,
    this.error,
  });

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER ADMIN';

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
    String? email,
    String? role,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────
// Auth Notifier (Riverpod v3 — uses Notifier)
// ─────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Restore session asynchronously after build
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final role = prefs.getString('user_role');
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');

    if (token != null && role != null) {
      final api = ref.read(apiServiceProvider);
      api.setToken(token);
      
      state = AuthState(
        isLoggedIn: true,
        name: name,
        email: email,
        role: role,
      );
    }
  }

  // ── Login with Role Guard ──────────────────
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/login', {
        'email': email,
        'password': password,
      });

      final String token = response['access_token'];
      final userData = response['user'];
      final String role = userData['role'];
      final String name = userData['name'];

      // ── ROLE GUARD: Only ADMIN / SUPER ADMIN allowed ──
      if (role.toUpperCase() != 'ADMIN' && role.toUpperCase() != 'SUPER_ADMIN' && role.toUpperCase() != 'SUPER ADMIN') {
        state = state.copyWith(
          isLoading: false,
          error: 'Access Denied! Only Administrators can access EBM Central.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_role', role.toUpperCase());
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);

      api.setToken(token);

      state = AuthState(
        isLoggedIn: true,
        name: name,
        email: email,
        role: role.toUpperCase(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ── Register via Invitation Token ─────────
  Future<bool> registerWithToken({
    required String token,
    required String name,
    required String password,
    required String email,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/register', {
        'invitation_token': token,
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password, // Assuming backend requires confirmation
      });

      final String authToken = response['access_token'];
      final userData = response['user'];
      final String role = userData['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authToken);
      await prefs.setString('user_role', role.toUpperCase());
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);

      api.setToken(authToken);

      state = AuthState(
        isLoggedIn: true,
        name: name,
        email: email,
        role: role.toUpperCase(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  // ── Logout ────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }
}

// ─────────────────────────────────────────────
// Provider (Riverpod v3 — NotifierProvider)
// ─────────────────────────────────────────────
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
