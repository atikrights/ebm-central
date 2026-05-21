import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../../core/config/app_config.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(
    apiKey: AppConfig.pusherKey,
    host: AppConfig.baseDomain,
    port: 443,
  );
});

/// Returns true only on platforms where pusher_channels_flutter has a
/// native plugin implementation: Android, iOS, and Web.
/// Windows / macOS / Linux desktop → MissingPluginException without this guard.
bool get _isPusherSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class WebSocketService {
  // Nullable so we never call getInstance() on unsupported platforms
  PusherChannelsFlutter? _pusher;

  final String apiKey;
  final String host;
  final int port;

  final List<Function(PusherEvent)> _listeners = [];
  bool _isInitialized = false;

  WebSocketService({
    required this.apiKey,
    required this.host,
    required this.port,
  }) {
    if (_isPusherSupported) {
      _pusher = PusherChannelsFlutter.getInstance();
    }
  }

  void addListener(Function(PusherEvent) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(Function(PusherEvent) listener) {
    _listeners.remove(listener);
  }

  Future<void> init({
    required int userId,
    String? token,
    Function(String)? onConnectionStateChange,
  }) async {
    // Skip entirely on unsupported platforms (Windows, macOS, Linux)
    if (!_isPusherSupported || _pusher == null) {
      debugPrint("WebSocket: Pusher not supported on this platform — skipping.");
      return;
    }

    if (token == null) return;

    if (_isInitialized) {
      // Already initialized — just re-subscribe to user channel
      final prefix = AppConfig.envPrefix;
      await _pusher!.subscribe(channelName: 'private-${prefix}dm.$userId');
      return;
    }

    try {
      await _pusher!.init(
        apiKey: AppConfig.pusherKey,
        cluster: AppConfig.pusherCluster,
        useTLS: true,
        authEndpoint: AppConfig.authEndpoint,
        authParams: {
          'headers': {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          }
        },
        onConnectionStateChange: (currentState, previousState) {
          onConnectionStateChange?.call(currentState);
        },
        onEvent: (event) {
          debugPrint("WS Event: ${event.eventName}");
          for (var listener in List.from(_listeners)) {
            listener(event);
          }
        },
      );

      final prefix = AppConfig.envPrefix;
      await _pusher!.subscribe(channelName: 'private-${prefix}dm.$userId');
      await _pusher!.subscribe(channelName: 'presence-${prefix}chat-presence');
      await _pusher!.subscribe(channelName: 'private-${prefix}ebm-global');

      await _pusher!.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint("WebSocket Init Error: $e");
    }
  }

  Future<void> disconnect() async {
    // Skip on unsupported platforms or if never connected
    if (!_isPusherSupported || _pusher == null || !_isInitialized) return;
    try {
      await _pusher!.disconnect();
    } catch (e) {
      debugPrint("WebSocket Disconnect Error: $e");
    } finally {
      _isInitialized = false;
    }
  }
}
