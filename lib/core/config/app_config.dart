import 'package:flutter/foundation.dart';

/// EBM Global Configuration Management
class AppConfig {
  /// Base API URL (e.g., https://api.ebfic.store/api)
  static String get baseUrl {
    // 1. Check for build-time definition
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl.endsWith('/api') ? definedUrl : '$definedUrl/api';
    }

    // 2. Web Smart Detection (Universal implementation)
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('ebfic.store')) {
        return 'https://api.ebfic.store/api';
      }
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8000/api';
      }
    }

    // 3. Fallback based on mode
    if (kReleaseMode) {
      return 'https://api.ebfic.store/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Base Domain for WebSockets and Assets (e.g., api.ebfic.store)
  static String get baseDomain {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (_) {
      return 'api.ebfic.store';
    }
  }

  /// Origin for CORS checks (e.g., https://api.ebfic.store)
  static String get origin {
    try {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return 'https://api.ebfic.store';
    }
  }

  /// Check if running on localhost
  static bool get isLocalhost {
    return baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost');
  }

  /// Broadcasting Auth Endpoint
  static String get authEndpoint => '$baseUrl/broadcasting/auth';

  /// Helper for generating asset links
  static String assetLink(String assetId) => '$baseUrl/assets/$assetId/view';

  /// Helper for generating shared asset links
  static String sharedLink(String assetId) => '$baseUrl/assets/$assetId/share';

  /// Pusher Configuration
  static const String pusherKey = "194c83322db5de281baf";
  static const String pusherCluster = "ap2";

  /// Singleton instance for backward compatibility
  static final AppConfig instance = AppConfig._internal();
  AppConfig._internal();
}
