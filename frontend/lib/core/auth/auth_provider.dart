import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // TODO: Replace with real API call: POST /api/auth/login
      await Future.delayed(const Duration(seconds: 2));

      String? simulatedRole;
      String? simulatedName;

      if (email == 'admin@ebfic.store' && password == 'admin123') {
        simulatedRole = 'ADMIN';
        simulatedName = 'Admin User';
      } else if (email == 'super@ebfic.store' && password == 'super123') {
        simulatedRole = 'SUPER ADMIN';
        simulatedName = 'Super Admin';
      } else if (email.contains('@')) {
        // Non-admin user — DENY
        simulatedRole = 'STAFF';
        simulatedName = 'Staff Member';
      } else {
        throw Exception('Invalid credentials');
      }

      // ── ROLE GUARD: Only ADMIN / SUPER ADMIN allowed ──
      if (simulatedRole != 'ADMIN' && simulatedRole != 'SUPER ADMIN') {
        state = state.copyWith(
          isLoading: false,
          error: 'Access Denied! Only Administrators can access EBM Central.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'demo_token_${DateTime.now().millisecondsSinceEpoch}');
      await prefs.setString('user_role', simulatedRole);
      await prefs.setString('user_name', simulatedName);
      await prefs.setString('user_email', email);

      state = AuthState(
        isLoggedIn: true,
        name: simulatedName,
        email: email,
        role: simulatedRole,
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
      // TODO: Call POST /api/invite/register
      await Future.delayed(const Duration(seconds: 2));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'token_$token');
      await prefs.setString('user_role', 'ADMIN');
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);

      state = AuthState(
        isLoggedIn: true,
        name: name,
        email: email,
        role: 'ADMIN',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
