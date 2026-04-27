import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../../../core/utils/encryption_helper.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ChatService(api);
});

class ChatService {
  final ApiService _api;

  ChatService(this._api);

  // ─── Fetch chat history (decrypts each message) ───────────────────────────
  Future<List<Map<String, dynamic>>> getChats(String receiverType) async {
    final response = await _api.get('/chats?receiver_type=$receiverType');
    if (response is List) {
      return response.map((e) {
        final data = e as Map<String, dynamic>;
        String decrypted;
        try {
          decrypted = EncryptionHelper.decrypt(data['message']);
        } catch (_) {
          decrypted = data['message']; // fallback if not encrypted
        }
        return {
          'id': data['id'],
          'sender': data['is_ai'] == true
              ? (receiverType == 'ai' ? 'AI Assistant' : 'System')
              : 'Me',
          'message': decrypted,
          'isMe': data['is_ai'] != true,
          'created_at': data['created_at'],
        };
      }).toList();
    }
    return [];
  }

  // ─── Send a user message (encrypted before transmission) ──────────────────
  Future<void> sendMessage(String receiverType, String message, {bool isAi = false}) async {
    final encryptedMessage = EncryptionHelper.encrypt(message);
    await _api.post('/chats', {
      'receiver_type': receiverType,
      'message': encryptedMessage,
      'is_ai': isAi,
    });
  }

  // ─── Get AI reply and store it encrypted ──────────────────────────────────
  /// Calls the backend AI endpoint which applies Super Admin guidelines,
  /// then stores the encrypted AI reply in the database under receiver_type='ai'.
  Future<String> getAiReply(String userMessage) async {
    final response = await _api.post('/chat/ai/generate', {
      'message': userMessage,
    });

    final String reply = response['reply'] ?? 'I could not generate a response.';

    // Store encrypted AI reply in the DB
    await sendMessage('ai', reply, isAi: true);

    return reply;
  }

  // ─── Draft a message using AI (does NOT store the result) ───────────────
  Future<String> draftMessage(String hint) async {
    final response = await _api.post('/chat/ai/generate', {
      'message': 'Draft a short professional reply or message for: $hint',
    });
    return response['reply'] ?? '';
  }

  // ─── Clear chat history ───────────────────────────────────────────────────
  Future<void> clearChat(String receiverType) async {
    await _api.delete('/chats/clear?receiver_type=$receiverType');
  }
}
