import 'package:flutter/foundation.dart';

/// Universal domain-aware configuration for EBM.
class AppConfig {
  AppConfig._internal();
  static final AppConfig instance = AppConfig._internal();

  /// The root origin of the frontend.
  String get origin => kIsWeb ? Uri.base.origin : 'https://central.ebfic.store';

  /// Whether the app is currently running on localhost (dev mode).
  bool get isLocalhost {
    if (kIsWeb) {
      final host = Uri.base.host;
      return host == 'localhost' || host == '127.0.0.1';
    }
    return false;
  }

  // ------ Link Builders ------

  /// Public shareable asset link.
  String assetLink(String assetId) => '$origin/assets/$assetId';

  /// Public shared asset link (for external use).
  String sharedLink(String assetId) => '$origin/shared/$assetId';
}
