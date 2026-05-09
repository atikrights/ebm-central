import 'package:flutter/foundation.dart';

/// EBM Global Configuration Management
class AppConfig {
  /// Base API URL (e.g., https://api.ebfic.store/api)
  static String get baseUrl {
    // 1. Check if defined via --dart-define during build
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl.endsWith('/api') ? definedUrl : '$definedUrl/api';
    }

    // 2. Fallback to production if in release mode
    if (kReleaseMode) {
      return 'https://api.ebfic.store/api';
    }

    // 3. Local development fallback
    return 'http://127.0.0.1:8000/api';
  }

  /// Base Domain for WebSockets and Assets (e.g., api.ebfic.store)
  static String get baseDomain {
    final uri = Uri.parse(baseUrl);
    return uri.host;
  }

  /// Broadcasting Auth Endpoint
  static String get authEndpoint => '$baseUrl/broadcasting/auth';

  /// Pusher Configuration
  static const String pusherKey = "194c83322db5de281baf";
  static const String pusherCluster = "ap2";
}
