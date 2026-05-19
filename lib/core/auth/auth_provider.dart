import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';
import '../../features/chat/data/websocket_service.dart';

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
  bool get isSubAdmin => role?.toUpperCase() == 'SUB_ADMIN';
  bool get isManager => role?.toUpperCase() == 'MANAGER';
  bool get canCreateItems => isSuperAdmin || isAdmin || isSubAdmin || isManager;

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
    
    // ── Listen to real-time security context evictions ───────────────
    ref.listenSelf((previous, current) {
      if (current.isLoggedIn && current.userId != null) {
        ref.read(webSocketServiceProvider).init(
          userId: current.userId!,
          token: current.token,
        );
      } else {
        ref.read(webSocketServiceProvider).disconnect();
      }
    });

    ref.read(webSocketServiceProvider).addListener((event) {
      if (event.eventName == 'data.updated') {
        try {
          final dynamic rawData = event.data;
          final Map<String, dynamic> data = rawData is String
              ? Map<String, dynamic>.from(json.decode(rawData))
              : Map<String, dynamic>.from(rawData as Map);

          if (data['type'] == 'security_eviction') {
            final bool canLogin = data['can_login'] ?? true;
            if (!canLogin) {
              logout();
            } else {
              _restoreSession();
            }
          }
        } catch (e) {
          debugPrint("Error handling pusher security eviction: $e");
        }
      }
    });

    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('ebm_secure_device_id') ?? '';
    
    // Attempt to read encrypted token. If not present, fall back to plain token (migration)
    String? token = await SecureLocalStore.readDecrypted('auth_token', deviceId);
    if (token == null) {
      token = prefs.getString('auth_token');
      if (token != null && deviceId.isNotEmpty) {
        await SecureLocalStore.saveEncrypted('auth_token', token, deviceId);
        await prefs.remove('auth_token'); // clean up legacy unencrypted key
      }
    }
    
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

  Future<Map<String, dynamic>> _getDeviceDetails() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('ebm_secure_device_id');
    if (deviceId == null) {
      final random = math.Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      values[6] = (values[6] & 0x0f) | 0x40;
      values[8] = (values[8] & 0x3f) | 0x80;
      
      final buffer = StringBuffer();
      for (int i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
          buffer.write('-');
        }
        buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
      }
      deviceId = buffer.toString();
      await prefs.setString('ebm_secure_device_id', deviceId);
    }

    String osType = 'unknown';
    String deviceName = 'Unknown Client';
    
    if (kIsWeb) {
      osType = 'web';
      deviceName = 'Web Browser';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          osType = 'android';
          deviceName = 'Android Device';
          break;
        case TargetPlatform.iOS:
          osType = 'ios';
          deviceName = 'iOS Device';
          break;
        case TargetPlatform.windows:
          osType = 'windows';
          deviceName = 'Windows App';
          break;
        case TargetPlatform.macOS:
          osType = 'macos';
          deviceName = 'Mac App';
          break;
        case TargetPlatform.linux:
          osType = 'linux';
          deviceName = 'Linux App';
          break;
        default:
          break;
      }
    }

    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'os_type': osType,
      'fingerprint_data': {
        'platform': osType,
        'app_version': '1.0.0',
        'is_web': kIsWeb,
      },
    };
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiServiceProvider);
      final deviceDetails = await _getDeviceDetails();
      final response = await api.post('/login', {
        'email': email,
        'password': password,
        ...deviceDetails,
      });

      final String token = response['access_token'];
      final userData = response['user'];
      final String role = userData['role'];
      final String name = userData['name'];

      // EBM Central: super_admin, admin, sub_admin only (matches backend AuthController guard)
      final allowedRoles = ['SUPER_ADMIN', 'ADMIN', 'SUB_ADMIN'];
      if (!allowedRoles.contains(role.toUpperCase())) {
        state = state.copyWith(
          isLoading: false,
          error: 'Access Denied! EBM Central is restricted to Administrators only.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final String deviceId = deviceDetails['device_id'];

      // Save token securely with Device-Bound Encryption
      await SecureLocalStore.saveEncrypted('auth_token', token, deviceId);
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
      final deviceDetails = await _getDeviceDetails();
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
      final String deviceId = deviceDetails['device_id'];

      // Save token securely with Device-Bound Encryption
      await SecureLocalStore.saveEncrypted('auth_token', authToken, deviceId);
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
    await SecureLocalStore.clear('auth_token');
    
    final api = ref.read(apiServiceProvider);
    api.clearToken();
    
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

// ─── Secure Local Store (Device-Bound Encryption Wrapper) ───────────────────────
class SecureLocalStore {
  static enc.Key _deriveKey(String deviceId) {
    const rawSalt = 'ebm_secure_salt_789_dbe_key';
    final combined = '$deviceId|$rawSalt';
    // Use SHA-256 to ensure the key is always perfectly 32 bytes and heavily scrambled
    final hash = crypto.sha256.convert(utf8.encode(combined));
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  static final _iv = enc.IV.fromLength(16);

  static Future<void> saveEncrypted(String key, String value, String deviceId) async {
    if (deviceId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final aesKey = _deriveKey(deviceId);
    final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    
    final encrypted = encrypter.encrypt(value, iv: _iv);
    await prefs.setString('enc_$key', encrypted.base64);
  }

  static Future<String?> readDecrypted(String key, String deviceId) async {
    if (deviceId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final base64Value = prefs.getString('enc_$key');
    if (base64Value == null) return null;

    try {
      final aesKey = _deriveKey(deviceId);
      final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(base64Value, iv: _iv);
      
      // Validation: If the decrypted token contains non-printable control characters 
      // or non-ASCII garbage characters (due to encryption/decryption key misalignment),
      // it means the key/token changed or it's corrupted.
      final cleanDecrypted = decrypted.trim();
      final hasNonAsciiOrControl = cleanDecrypted.codeUnits.any((char) => char < 32 || char > 126);
      if (hasNonAsciiOrControl) {
        await clear(key); // wipe the corrupted token
        return null;
      }
      
      return cleanDecrypted;
    } catch (_) {
      await clear(key);
      return null;
    }
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('enc_$key');
  }
}
