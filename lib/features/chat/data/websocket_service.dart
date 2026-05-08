import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(
    apiKey: 'ebm_key', // From .env or Reverb config
    host: '127.0.0.1',
    port: 8080,
  );
});

class WebSocketService {
  late PusherChannelsFlutter pusher;
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
    pusher = PusherChannelsFlutter.getInstance();
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
    if (token == null) return;
    if (_isInitialized) {
      // Re-subscribe to user channels if ID changed, otherwise skip re-init
      await pusher.subscribe(channelName: 'private-dm.$userId');
      return;
    }

    try {
      await pusher.init(
        apiKey: "194c83322db5de281baf",
        cluster: "ap2", 
        useTLS: true,
        authEndpoint: "http://127.0.0.1:8000/broadcasting/auth",
        authParams: {
          'headers': {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          }
        },
        onConnectionStateChange: (currentState, previousState) {
          if (onConnectionStateChange != null) {
            onConnectionStateChange(currentState);
          }
        },
        onEvent: (event) {
          debugPrint("WS Event: ${event.eventName}");
          for (var listener in List.from(_listeners)) {
            listener(event);
          }
        },
      );

      await pusher.subscribe(channelName: 'private-dm.$userId');
      await pusher.subscribe(channelName: 'presence-chat-presence');
      await pusher.subscribe(channelName: 'private-ebm-global');

      await pusher.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint("WebSocket Init Error: $e");
    }
  }

  Future<void> disconnect() async {
    await pusher.disconnect();
    _isInitialized = false;
  }
}
