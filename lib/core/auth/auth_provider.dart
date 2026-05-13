import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';

// ─────────────────────────────────────────────
// Auth State Model
// ─────────────────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final int? userId;
  final String? token;
  final String? name;
  final String? email;
  final String? role;
  final String? chatProfileId;
  final String? chatNumber;
  final String? chatNickname;
  final String? chatBio;
  final String? chatAbout;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.userId,
    this.token,
    this.name,
    this.email,
    this.role,
    this.chatProfileId,
    this.chatNumber,
    this.chatNickname,
    this.chatBio,
    this.chatAbout,
    this.isLoading = false,
    this.error,
  });

  bool get isAdmin => role?.toUpperCase() == 'ADMIN' || role?.toUpperCase() == 'SUPER_ADMIN';
  bool get isSuperAdmin => role?.toUpperCase() == 'SUPER_ADMIN';

  AuthState copyWith({
    bool? isLoggedIn,
    int? userId,
    String? token,
    String? name,
    String? email,
    String? role,
    String? chatProfileId,
    String? chatNumber,
    String? chatNickname,
    String? chatBio,
    String? chatAbout,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      chatProfileId: chatProfileId ?? this.chatProfileId,
      chatNumber: chatNumber ?? this.chatNumber,
      chatNickname: chatNickname ?? this.chatNickname,
      chatBio: chatBio ?? this.chatBio,
      chatAbout: chatAbout ?? this.chatAbout,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────
// Auth Notifier
// ─────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    final role = prefs.getString('user_role');
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    final chatProfileId = prefs.getString('chat_profile_id');
    final chatNumber = prefs.getString('chat_number');
    final chatNickname = prefs.getString('chat_nickname');
    final chatBio = prefs.getString('chat_bio');
    final chatAbout = prefs.getString('chat_about');

    if (token != null && role != null) {
      final api = ref.read(apiServiceProvider);
      api.setToken(token);
      
      state = AuthState(
        isLoggedIn: true,
        userId: userId,
        token: token,
        name: name,
        email: email,
        role: role,
        chatProfileId: chatProfileId,
        chatNumber: chatNumber,
        chatNickname: chatNickname,
        chatBio: chatBio,
        chatAbout: chatAbout,
      );
    }
  }

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

      if (role.toUpperCase() != 'ADMIN' && role.toUpperCase() != 'SUPER_ADMIN') {
        state = state.copyWith(
          isLoading: false,
          error: 'Access Denied! Only Administrators can access EBM Central.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setInt('user_id', userData['id']);
      await prefs.setString('user_role', role.toUpperCase());
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('chat_profile_id', userData['chat_profile_id'] ?? '');
      await prefs.setString('chat_number', userData['chat_number'] ?? '');
      await prefs.setString('chat_nickname', userData['chat_nickname'] ?? '');
      await prefs.setString('chat_bio', userData['chat_bio'] ?? '');
      await prefs.setString('chat_about', userData['chat_about'] ?? '');

      api.setToken(token);

      state = AuthState(
        isLoggedIn: true,
        userId: userData['id'],
        token: token,
        name: name,
        email: email,
        role: role.toUpperCase(),
        chatProfileId: userData['chat_profile_id'],
        chatNumber: userData['chat_number'],
        chatNickname: userData['chat_nickname'],
        chatBio: userData['chat_bio'],
        chatAbout: userData['chat_about'],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> registerWithToken({
    required String token,
    required String name,
    required String password,
    required String email,
    bool migrateData = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/register', {
        'invitation_token': token,
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'migrate_data': migrateData,
      });

      final String authToken = response['access_token'];
      final userData = response['user'];
      final String role = userData['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authToken);
      await prefs.setInt('user_id', userData['id']);
      await prefs.setString('user_role', role.toUpperCase());
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);

      api.setToken(authToken);

      state = AuthState(
        isLoggedIn: true,
        userId: userData['id'],
        token: authToken,
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }

  void updateChatInfo({String? id, String? number, String? nickname, String? bio, String? about}) {
    state = state.copyWith(
      chatProfileId: id,
      chatNumber: number,
      chatNickname: nickname,
      chatBio: bio,
      chatAbout: about,
    );
    
    // Save to SharedPreferences as well
    SharedPreferences.getInstance().then((prefs) {
      if (id != null) prefs.setString('chat_profile_id', id);
      if (number != null) prefs.setString('chat_number', number);
      if (nickname != null) prefs.setString('chat_nickname', nickname);
      if (bio != null) prefs.setString('chat_bio', bio);
      if (about != null) prefs.setString('chat_about', about);
    });
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
