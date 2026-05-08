import 'dart:convert';

class DirectMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String messageType;
  final String? filePath;
  final String? fileName;
  final String status;
  final DateTime createdAt;
  final ChatUser? sender;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.messageType,
    this.filePath,
    this.fileName,
    required this.status,
    required this.createdAt,
    this.sender,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      senderId: json['sender_id'] is int ? json['sender_id'] : int.parse(json['sender_id'].toString()),
      receiverId: json['receiver_id'] is int ? json['receiver_id'] : int.parse(json['receiver_id'].toString()),
      message: json['message'] ?? '',
      messageType: json['message_type'] ?? 'text',
      filePath: json['file_path'],
      fileName: json['file_name'],
      status: json['status'] ?? 'sent',
      createdAt: DateTime.parse(json['created_at']),
      sender: json['sender'] != null ? ChatUser.fromJson(json['sender']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'message_type': messageType,
      'file_path': filePath,
      'file_name': fileName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'sender': sender?.toJson(),
    };
  }
}

class ChatUser {
  final int id;
  final String name;
  final String? uid;
  final String? chatProfileId;
  final String? role;

  ChatUser({
    required this.id,
    required this.name,
    this.uid,
    this.chatProfileId,
    this.role,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'],
      uid: json['uid'],
      chatProfileId: json['chat_profile_id'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uid': uid,
      'chat_profile_id': chatProfileId,
      'role': role,
    };
  }
}

class Conversation {
  final ChatUser user;
  final Map<String, dynamic> lastMessage;
  final int unreadCount;

  Conversation({
    required this.user,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      user: ChatUser.fromJson(json['user']),
      lastMessage: json['last_message'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}
