import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/auth/auth_provider.dart';
import 'chat_models.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref: ref);
});

class ChatService {
  final Ref ref;

  ChatService({required this.ref});

  // ── Chat Profile ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.get('/chat/profile');
    return response as Map<String, dynamic>;
  }

  Future<bool> setupProfile(String nickname) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.post('/chat/profile/setup', {'chat_nickname': nickname});
    return response != null;
  }

  Future<Map<String, dynamic>> setupProfileWithResponse(String nickname) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.post('/chat/profile/setup', {'chat_nickname': nickname});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({String? nickname, String? bio, String? about}) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.post('/chat/profile/update', {
      if (nickname != null) 'chat_nickname': nickname,
      if (bio != null) 'chat_bio': bio,
      if (about != null) 'chat_about': about,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfileInfo() async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.get('/chat/profile');
    return response as Map<String, dynamic>;
  }

  // ── Direct Messages ─────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final List data = await apiService.get('/dm/conversations');
      return data.map((e) => Conversation.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DirectMessage>> getMessages(int userId) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final Map<String, dynamic> data = await apiService.get('/dm/messages/$userId');
      final List messages = data['data'];
      return messages.map((e) => DirectMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<DirectMessage?> sendMessage({
    required int receiverId,
    String? message,
    String type = 'text',
    dynamic file,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    final Map<String, String> fields = {
      'receiver_id': receiverId.toString(),
      if (message != null) 'message': message,
      'message_type': type,
    };

    final List<http.MultipartFile> files = [];
    if (file != null && file is http.MultipartFile) {
      files.add(file);
    }

    final response = await apiService.postMultipart('/dm/send', fields, files);
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markAsRead(int senderId) async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.patch('/dm/read/$senderId');
  }

  Future<ChatUser?> findUserByChatId(String chatId) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final response = await apiService.get('/dm/find/$chatId');
      return ChatUser.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Returns all users in the same team as the current user.
  Future<List<Map<String, dynamic>>> getTeamUsers() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final Map<String, dynamic> body = await apiService.get('/teams/members');
      final List members = body['members'] ?? [];
      return members.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> findUserByNumber(String number) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final response = await apiService.get('/chat/profile/find/$number');
      return Map<String, dynamic>.from(response);
    } catch (_) {
      return null;
    }
  }

  // ── Legacy / AI Methods ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getChats(String receiverType) async {
    if (int.tryParse(receiverType) != null) {
      final otherId = int.parse(receiverType);
      final messages = await getMessages(otherId);
      return messages.map((m) => {
        'id': m.id,
        'sender': m.sender?.name ?? 'User',
        'message': m.message,
        'isMe': m.senderId != otherId,
        'status': m.status,
        'created_at': m.createdAt.toIso8601String(),
      }).toList();
    }

    final apiService = ref.read(apiServiceProvider);
    final List data = await apiService.get('/chats?receiver_type=$receiverType');
    return data.map<Map<String, dynamic>>((item) {
      final isAi = item['is_ai'] == true;
      return {
        'id': item['id'],
        'message': item['message'] ?? '',
        'isMe': !isAi,
        'sender': isAi ? 'AI Assistant' : 'Me',
        'created_at': item['created_at'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDeltaSync(int lastId) async {
    final apiService = ref.read(apiServiceProvider);
    final List data = await apiService.get('/dm/sync?last_id=$lastId');
    final myIdStr = ref.read(authProvider).userId?.toString() ?? '';
    return data.map<Map<String, dynamic>>((e) {
      final bool isMe = e['sender_id']?.toString() == myIdStr;
      return {
        'id': e['id'],
        'sender': isMe ? 'Me' : (e['sender']?['name'] ?? 'User'),
        'message': e['message'],
        'isMe': isMe,
        'status': e['status'] ?? 'sent',
        'created_at': e['created_at'] ?? DateTime.now().toIso8601String(),
        'sender_id': e['sender_id']?.toString(),
        'receiver_id': e['receiver_id']?.toString(),
      };
    }).toList();
  }

  Future<String> getAiReply(String prompt) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.post('/chat/ai/generate', {'message': prompt});
    return response['reply'] ?? '';
  }

  Future<String> draftMessage(String text) async {
    return "Draft: $text";
  }

  Future<Map<String, dynamic>?> syncMessage(String receiverType, String text) async {
    if (int.tryParse(receiverType) != null) {
      final msg = await sendMessage(receiverId: int.parse(receiverType), message: text);
      return msg?.toJson();
    } else {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/chats', {'receiver_type': receiverType, 'message': text});
      return response as Map<String, dynamic>;
    }
  }

  Future<bool> clearChat(String receiverType) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.delete('/chats/clear', {'receiver_type': receiverType});
    return response != null;
  }
}
