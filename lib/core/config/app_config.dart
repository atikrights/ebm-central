import 'package:flutter/foundation.dart';

/// EBM Global Configuration Management
class AppConfig {
  /// Base API URL (e.g., https://api.ebfic.store/api)
  static String get baseUrl {
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl.endsWith('/api') ? definedUrl : '$definedUrl/api';
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.endsWith('ebfic.store')) {
        return 'https://api.ebfic.store/api';
      }
      if (host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.')) {
        return 'http://127.0.0.1:8000/api';
      }
    }

    if (kReleaseMode) {
      return 'https://api.ebfic.store/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static String get baseDomain {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (_) {
      return 'api.ebfic.store';
    }
  }

  static String get origin {
    try {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return 'https://api.ebfic.store';
    }
  }

  static bool get isLocalhost {
    return baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost');
  }

  static String get authEndpoint => '$baseUrl/broadcasting/auth';

  static const String pusherKey = "194c83322db5de281baf";
  static const String pusherCluster = "ap2";

  /// Channel Prefix for Environment Isolation
  static String get envPrefix => isLocalhost ? 'local.' : 'prod.';

  static final AppConfig instance = AppConfig._internal();
  AppConfig._internal();
}
