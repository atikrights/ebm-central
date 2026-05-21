import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'websocket_service.dart';
import 'chat_models.dart';
import '../../../core/network/api_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.read(apiServiceProvider),
    ref.read(webSocketServiceProvider),
  );
});

class ChatRepository {
  final ApiService _api;
  final WebSocketService _ws;
  
  // Local state for instant UI updates
  final _messageController = StreamController<List<DirectMessage>>.broadcast();
  final List<DirectMessage> _messages = [];
  
  ChatRepository(this._api, this._ws);

  Stream<List<DirectMessage>> get messageStream => _messageController.stream;

  Future<void> init(int userId, String token) async {
    await _ws.init(
      userId: userId,
      token: token,
    );
    _ws.addListener(_handleWsEvent);
  }

  void _handleWsEvent(dynamic event) {
    // pusher_channels_flutter event can be PusherEvent
    try {
      final name = event.eventName;
      final data = event.data is String
          ? jsonDecode(event.data)
          : (event.data ?? {}) as Map<String, dynamic>;

      if (name == 'message.new') {
        _handleIncomingMessage(data);
      } else if (name == 'message.status') {
        _handleStatusUpdate(data);
      }
    } catch (e) {
      debugPrint("ChatRepository WS Event Error: $e");
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final msg = DirectMessage.fromJson(data);
    final String clientId = data['client_id']?.toString() ?? '';

    // Reconcile optimistic UI if client_id matches
    if (clientId.isNotEmpty) {
       final index = _messages.indexWhere((m) => m.clientId == clientId || m.id.toString() == clientId);
       if (index != -1) {
         _messages[index] = msg.copyWith(isMe: true);
         _messageController.add(List.from(_messages));
         return;
       }
    }

    // Check if it already exists by ID
    if (_messages.any((m) => m.id == msg.id)) return;

    _messages.insert(0, msg);
    _messageController.add(List.from(_messages));
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    final msgId = data['id'] ?? data['message_id']; // Accept either for safety
    final status = data['status'];
    
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].id.toString() == msgId.toString()) {
        _messages[i] = _messages[i].copyWith(status: status);
        break;
      }
    }
    _messageController.add(List.from(_messages));
  }

  Future<void> sendMessage(int receiverId, String content) async {
    // 1. Create Optimistic Message with client_id
    final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
    final tempId = DateTime.now().millisecondsSinceEpoch;
    
    final optimisticMsg = DirectMessage(
      id: tempId,
      clientId: clientId, // Using temporary field if model supports it, else we match by id logic
      senderId: 0,
      receiverId: receiverId,
      message: content,
      messageType: 'text',
      status: 'sending',
      createdAt: DateTime.now(),
      isMe: true,
    );

    _messages.insert(0, optimisticMsg);
    _messageController.add(List.from(_messages));

    try {
      // 2. Send to API with client_id
      await _api.post('/dm/send', {
        'receiver_id': receiverId,
        'message': content,
        'message_type': 'text',
        'client_id': clientId,
      });
      // Success reconciliation handled via WebSocket callback
    } catch (e) {
      // 3. Handle Failure
      final index = _messages.indexWhere((m) => m.clientId == clientId || m.id == tempId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: 'failed');
        _messageController.add(List.from(_messages));
      }
    }
  }

  Future<void> loadHistory(int partnerId) async {
    final response = await _api.get('/dm/messages/$partnerId');
    final List<dynamic> data = (response is Map) ? response['data'] : response;
    
    _messages.clear();
    _messages.addAll(data.map((m) => DirectMessage.fromJson(m)).toList().reversed);
    _messageController.add(List.from(_messages));
  }

  void dispose() {
    _messageController.close();
    _ws.removeListener(_handleWsEvent);
    _ws.disconnect();
  }
}
