import 'package:flutter/material.dart';
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
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8000/api';
      }
      if (RegExp(r'^[0-9]+(?:\.[0-9]+){3}$').hasMatch(host)) {
        return 'http://$host:8000/api';
      }
      final parts = host.split('.');
      if (parts.length > 2) {
        final rootDomain = parts.sublist(parts.length - 2).join('.');
        return 'https://api.$rootDomain/api';
      }
      return 'https://$host/api';
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

  // NOTE: Laravel's broadcasting auth is at /broadcasting/auth (NOT /api/broadcasting/auth)
  static String get authEndpoint => '${baseUrl.replaceFirst('/api', '')}/broadcasting/auth';

  /// Helper for generating asset links
  static String assetLink(String assetId) => '$baseUrl/assets/$assetId/view';

  /// Helper for generating shared asset links
  static String sharedLink(String assetId) => '$baseUrl/assets/$assetId/share';

  static const String pusherKey = "194c83322db5de281baf";
  static const String pusherCluster = "ap2";

  /// Channel Prefix for Environment Isolation
  static String get envPrefix => isLocalhost ? 'local.' : 'prod.';

  static final AppConfig instance = AppConfig._internal();
  AppConfig._internal();
}
