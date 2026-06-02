import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_service.dart';
import 'websocket_service.dart';

final unreadChatCountProvider = StateNotifierProvider<UnreadChatCountNotifier, int>((ref) {
  return UnreadChatCountNotifier(ref);
});

class UnreadChatCountNotifier extends StateNotifier<int> {
  final Ref ref;
  Timer? _refreshTimer;

  UnreadChatCountNotifier(this.ref) : super(0) {
    _init();
  }

  Future<void> _init() async {
    // 1. Listen to WebSocket events
    final ws = ref.read(webSocketServiceProvider);
    ws.addListener((event) {
      if (event.eventName == 'message.new') {
        state = state + 1;
      } else if (event.eventName == 'data.updated' || event.eventName == 'message.status') {
        refreshCount();
      }
    });

    // 2. Perform initial fetch
    await refreshCount();

    // 3. Robust periodic sync (failover fallback)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshCount();
    });
  }

  Future<void> refreshCount() async {
    try {
      final conversations = await ref.read(chatServiceProvider).getConversations();
      int total = 0;
      for (var conv in conversations) {
        total += conv.unreadCount;
      }
      state = total;
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
