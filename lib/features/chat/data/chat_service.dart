import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import 'chat_models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(baseUrl: AppConfig.baseUrl);
});

class ChatService {
  final String baseUrl;

  ChatService({required this.baseUrl});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ── Chat Profile ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/profile'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      throw Exception('Session expired. Please logout and login again.');
    } else {
      throw Exception('Failed to load profile: ${response.statusCode}');
    }
  }

  Future<bool> setupProfile(String nickname) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/profile/setup'),
      headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'chat_nickname': nickname}),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> setupProfileWithResponse(String nickname) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/profile/setup'),
      headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'chat_nickname': nickname}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateProfile({String? nickname, String? bio, String? about}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/profile/update'),
      headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (nickname != null) 'chat_nickname': nickname,
        if (bio != null) 'chat_bio': bio,
        if (about != null) 'chat_about': about,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getProfileInfo() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/profile'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // ── Direct Messages ─────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/dm/conversations'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => Conversation.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<DirectMessage>> getMessages(int userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/dm/messages/$userId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      List messages = data['data'];
      return messages.map((e) => DirectMessage.fromJson(e)).toList();
    }
    return [];
  }

  Future<DirectMessage?> sendMessage({
    required int receiverId,
    String? message,
    String type = 'text',
    dynamic file,
  }) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/dm/send'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['receiver_id'] = receiverId.toString();
    if (message != null) request.fields['message'] = message;
    request.fields['message_type'] = type;

    if (file != null) {
      if (kIsWeb) {
        if (file is http.MultipartFile) {
          request.files.add(file);
        }
      } else {
         // MultipartFile from UI is cross-platform safe
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return DirectMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  Future<void> markAsRead(int senderId) async {
    final token = await _getToken();
    await http.patch(
      Uri.parse('$baseUrl/dm/read/$senderId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  Future<ChatUser?> findUserByChatId(String chatId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/dm/find/$chatId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return ChatUser.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  /// Returns all users in the same team as the current user.
  /// Uses the team-scoped /teams/members endpoint (backed by TeamHandler).
  /// Admin sees all their subordinates; Sub-Admin/Manager/Staff see teammates.
  Future<List<Map<String, dynamic>>> getTeamUsers() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/teams/members'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List members = body['members'] ?? [];
      return members.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> findUserByNumber(String number) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/profile/find/$number'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    return null;
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
    
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chats?receiver_type=$receiverType'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
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
    throw Exception('Failed to load chats');
  }

  Future<String> getAiReply(String prompt) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/ai/generate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': prompt}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'] ?? '';
    }
    throw Exception('AI Reply failed');
  }

  Future<String> draftMessage(String text) async {
    return "Draft: $text"; 
  }

  Future<Map<String, dynamic>?> syncMessage(String receiverType, String text) async {
    if (int.tryParse(receiverType) != null) {
      final msg = await sendMessage(receiverId: int.parse(receiverType), message: text);
      return msg?.toJson();
    } else {
       final token = await _getToken();
       final response = await http.post(
        Uri.parse('$baseUrl/chats'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'receiver_type': receiverType, 'message': text}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to sync message');
    }
  }
}
