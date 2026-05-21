import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'local_database_service.dart';
import 'chat_repository.dart';
import 'websocket_service.dart';

final chatGlobalProvider = StateNotifierProvider<ChatGlobalNotifier, ChatGlobalState>((ref) {
  return ChatGlobalNotifier(ref);
});

class ChatGlobalState {
  final List<Map<String, dynamic>> sessions;
  final Map<String, List<Map<String, dynamic>>> messages; // partnerId -> messages
  final Map<String, bool> typingStatus; // partnerId -> isTyping
  final bool isLoading;

  ChatGlobalState({
    this.sessions = const [],
    this.messages = const {},
    this.typingStatus = const {},
    this.isLoading = false,
  });

  ChatGlobalState copyWith({
    List<Map<String, dynamic>>? sessions,
    Map<String, List<Map<String, dynamic>>>? messages,
    Map<String, bool>? typingStatus,
    bool? isLoading,
  }) {
    return ChatGlobalState(
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      typingStatus: typingStatus ?? this.typingStatus,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatGlobalNotifier extends StateNotifier<ChatGlobalState> {
  final Ref ref;
  final _db = LocalDatabaseService();
  final _uuid = const Uuid();

  ChatGlobalNotifier(this.ref) : super(ChatGlobalState()) {
    _init();
  }

  Future<void> _init() async {
    _setupWebSocket();
    _performDeltaSync();
  }

  void _setupWebSocket() {
    final ws = ref.read(webSocketServiceProvider);
    
    ws.addListener((event) {
      try {
        final String type = event.eventName;
        final data = event.data is String
            ? jsonDecode(event.data)
            : (event.data ?? {}) as Map<String, dynamic>;

        if (type == 'message.new') {
          _handleNewMessage(data);
        } else if (type == 'message.status') {
          _handleStatusUpdate(data);
        } else if (type == 'user.typing') {
          _handleTyping(data);
        }
      } catch (e) {
        // ignore websocket decode errors
      }
    });
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    final partnerId = data['sender_id'].toString();

    // Update State
    final currentMsgs = state.messages[partnerId] ?? [];
    state = state.copyWith(
      messages: {
        ...state.messages,
        partnerId: [...currentMsgs, data],
      }
    );

    // Persist to DB
    _db.saveMessage(data);
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    // Update local state and DB with delivered/read status
  }

  void _handleTyping(Map<String, dynamic> data) {
    final partnerId = data['sender_id'].toString();
    state = state.copyWith(
      typingStatus: {
        ...state.typingStatus,
        partnerId: data['is_typing'] == true,
      }
    );
  }

  Future<void> _performDeltaSync() async {
    // Fetch missing messages since last ID in DB
  }

  // --- Actions ---

  Future<void> sendMessage(String partnerId, String content) async {
    final clientId = _uuid.v4();
    final tempMsg = {
      'client_id': clientId,
      'message': content,
      'sender_id': 'me',
      'status': 'sending',
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. OPTIMISTIC UI: Add to state immediately
    final currentMsgs = state.messages[partnerId] ?? [];
    state = state.copyWith(
      messages: {
        ...state.messages,
        partnerId: [...currentMsgs, tempMsg],
      }
    );

    // 2. Sync to Backend
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        int.parse(partnerId),
        content,
      );
    } catch (e) {
      // Handle failure: update status to 'failed'
    }
  }
}
