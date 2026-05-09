import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';
import '../data/websocket_service.dart';
import '../../../core/auth/auth_provider.dart';
import 'chat_detail_screen.dart';
import 'chat_profile_setup_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  bool _isProfileSetup = false;

  @override
  void initState() {
    super.initState();
    _checkProfileAndLoad();
  }

  Future<void> _checkProfileAndLoad() async {
    try {
      final service = ref.read(chatServiceProvider);
      final profile = await service.getProfile();
      
      // Update Auth State with fetched profile info if needed
      final authNotifier = ref.read(authProvider.notifier);
      authNotifier.updateChatInfo(
        id: profile['chat_profile_id']?.toString() ?? '',
        nickname: profile['chat_nickname']?.toString() ?? '',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (profile['chat_nickname'] != null && profile['chat_nickname'].toString().isNotEmpty) {
          await _loadConversations();
          _initWebSocket();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _initWebSocket() {
    final ws = ref.read(webSocketServiceProvider);
    final auth = ref.read(authProvider);
    
    if (auth.userId != null) {
      ws.init(
        userId: auth.userId!,
        token: auth.token,
      );
      ws.addListener(_handleWsEvent);
    }
  }

  void _handleWsEvent(PusherEvent event) {
    if (!mounted) return;
    try {
      final data = event.data is String
          ? jsonDecode(event.data)
          : (event.data ?? {}) as Map<String, dynamic>;

      if (event.eventName == 'message.new') {
        _updateConversationLocally(data);
      } else if (event.eventName == 'data.updated') {
        _loadConversations();
      } else if (event.eventName == 'message.status') {
         setState(() {
            for (var conv in _conversations) {
              if (conv.lastMessage['id'].toString() == data['message_id'].toString()) {
                conv.lastMessage['status'] = data['status'];
              }
            }
         });
      }
    } catch (e) {
      debugPrint("List WS Error: $e");
    }
  }

  @override
  void dispose() {
    ref.read(webSocketServiceProvider).removeListener(_handleWsEvent);
    super.dispose();
  }

  void _updateConversationLocally(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      final String sId = (data['sender_id'] ?? 0).toString();
      final String rId = (data['receiver_id'] ?? 0).toString();
      final String receiverType = data['receiver_type']?.toString() ?? '';
      final String myId = (ref.read(authProvider).userId ?? 0).toString();
      final bool isMe = sId == myId;
      
      final Map<String, dynamic> lastMsgData = {
        'id': data['id'],
        'message': data['message'],
        'isMe': isMe,
        'is_mine': isMe,
        'status': data['status'] ?? 'sent',
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      };

      // 1. Check if it's an Official Chat update
      if (receiverType == 'ai' || (data['is_ai'] == true)) {
        _aiLastMsg = lastMsgData;
        return;
      }
      if (receiverType == 'self' || receiverType == 'notes') {
        _selfLastMsg = lastMsgData;
        return;
      }

      // 2. Handle P2P Conversations
      final String otherUserId = isMe ? rId : sId;
      bool found = false;

      for (int i = 0; i < _conversations.length; i++) {
        final conv = _conversations[i];
        if (conv.user.id.toString() == otherUserId) {
          _conversations[i] = Conversation(
            user: conv.user,
            unreadCount: isMe ? conv.unreadCount : conv.unreadCount + 1,
            lastMessage: lastMsgData,
          );
          // Move to top
          final item = _conversations.removeAt(i);
          _conversations.insert(0, item);
          found = true;
          break;
        }
      }
      
      if (!found) {
        // Completely new P2P conversation from someone else or from my other device, reload to get user info
        _loadConversations(); 
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      final service = ref.read(chatServiceProvider);
      
      // Parallel loading for faster UI response
      final results = await Future.wait([
        service.getConversations().timeout(const Duration(seconds: 10)),
        service.getChats('ai').timeout(const Duration(seconds: 10)),
        service.getChats('self').timeout(const Duration(seconds: 10)),
      ]);

      if (mounted) {
        setState(() {
          _conversations = results[0] as List<Conversation>;
          final aiMsgs = results[1] as List<Map<String, dynamic>>;
          final selfMsgs = results[2] as List<Map<String, dynamic>>;
          
          if (aiMsgs.isNotEmpty) _aiLastMsg = aiMsgs.last;
          if (selfMsgs.isNotEmpty) _selfLastMsg = selfMsgs.last;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load Conversations Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _aiLastMsg;
  Map<String, dynamic>? _selfLastMsg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(authProvider, (previous, next) {
      final wasSetup = previous?.chatNickname != null && previous!.chatNickname!.isNotEmpty;
      final isSetup = next.chatNickname != null && next.chatNickname!.isNotEmpty;
      
      if (!wasSetup && isSetup) {
        _loadConversations();
        _initWebSocket();
      }
    });

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final auth = ref.watch(authProvider);
    final hasNickname = auth.chatNickname != null && auth.chatNickname!.isNotEmpty;

    if (!hasNickname && !_isLoading) {
      return ChatProfileSetupScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          IconButton(icon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54), onPressed: () {}),
          IconButton(icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        color: Colors.cyanAccent,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            // ── Official Chats (Now with Dynamic Info) ────────────────────
            _buildOfficialChatTile(
              context, 
              isDark, 
              name: 'AI Assistant', 
              lastMsg: _aiLastMsg,
              defaultSubtitle: 'How can I help you today?', 
              icon: Icons.auto_awesome, 
              color: Colors.amber,
              receiverType: 'ai',
            ),
            _buildOfficialChatTile(
              context, 
              isDark, 
              name: 'Notes (You)', 
              lastMsg: _selfLastMsg,
              defaultSubtitle: 'Message yourself anything.', 
              icon: Icons.person_pin_circle_rounded, 
              color: Colors.blueAccent,
              receiverType: 'self',
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Divider(color: Colors.white10),
            ),

            // ── P2P Conversations ────────────────────────────────────────
            if (_conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white10),
                    const SizedBox(height: 16),
                    Text('No messages yet. Start a new chat!', style: GoogleFonts.outfit(color: Colors.white24)),
                  ],
                ),
              )
            else
              ..._conversations.map((conv) => _buildConversationItem(conv, isDark)).toList(),
          ],
        ),
      ),
      floatingActionButton: _isProfileSetup ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildConversationItem(Conversation conv, bool isDark) {
    final lastMsg = conv.lastMessage;
    final String status = lastMsg['status'] ?? 'sent';
    final bool isMine = lastMsg['is_mine'] ?? false;
    final int unread = conv.unreadCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.cyan.withOpacity(0.2),
                    child: Text(
                      conv.user.name[0].toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF0F1117) : Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      conv.user.name,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDateTime(lastMsg['created_at']),
                    style: GoogleFonts.outfit(
                      color: unread > 0 ? Colors.cyanAccent : (isDark ? Colors.white38 : Colors.black38),
                      fontSize: 11,
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    if (isMine)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildStatusIcon(status),
                      ),
                    Expanded(
                      child: Text(
                        lastMsg['message'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: unread > 0 ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white60 : Colors.black54),
                          fontSize: 13,
                          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                          ],
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      receiverType: conv.user.id.toString(),
                      chatName: conv.user.name,
                      chatColor: Colors.cyanAccent,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: Colors.cyanAccent);
      case 'delivered':
        return const Icon(Icons.done_all, size: 16, color: Colors.white38);
      case 'sent':
      default:
        return const Icon(Icons.done, size: 16, color: Colors.white38);
    }
  }

  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(date.year, date.month, date.day);

      if (msgDate == today) {
        return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      } else if (msgDate == yesterday) {
        return "Yesterday";
      } else if (now.difference(date).inDays < 7) {
        final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        return weekdays[date.weekday - 1];
      } else {
        return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildOfficialChatTile(
    BuildContext context,
    bool isDark, {
    required String name,
    Map<String, dynamic>? lastMsg,
    required String defaultSubtitle,
    required IconData icon,
    required Color color,
    required String receiverType,
  }) {
    final String message = lastMsg?['message'] ?? defaultSubtitle;
    final String time = lastMsg != null ? _formatDateTime(lastMsg['created_at']) : '';
    final String status = lastMsg?['status'] ?? 'sent';
    final bool isMine = lastMsg?['isMe'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name, 
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              if (isMine && lastMsg != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildStatusIcon(status),
                ),
              Expanded(
                child: Text(
                  message, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)
                ),
              ),
              if (time.isEmpty)
                Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                receiverType: receiverType,
                chatName: name,
                chatColor: color,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _showNewChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String chatId = "";
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('New Chat', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter 12-digit Virtual Number',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => chatId = v,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                onPressed: () async {
                  final service = ref.read(chatServiceProvider);
                  final user = await service.findUserByChatId(chatId);
                  if (user != null) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          receiverType: user.id.toString(),
                          chatName: user.name,
                          chatColor: Colors.cyanAccent,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found.')));
                  }
                },
                child: const Text('Find User', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );
  }
}
