import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatHomeScreen extends StatefulWidget {
  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final ChatService _chatService = ChatService(baseUrl: 'http://localhost:8000/api');
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final convs = await _chatService.getConversations();
    setState(() {
      _conversations = convs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A), // Sleek Dark Mode
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chats',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadConversations,
              color: Colors.cyanAccent,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 10),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  return _buildConversationItem(conv);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        child: Icon(Icons.chat_bubble_outline, color: Colors.black),
        onPressed: () => _showNewChatDialog(context),
      ),
    );
  }

  Widget _buildConversationItem(Conversation conv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.cyan.withOpacity(0.2),
                    child: Text(
                      conv.user.name[0].toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFF0F172A), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    conv.user.name,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                  Text(
                    _formatTime(conv.lastMessage['created_at']),
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    if (conv.lastMessage['is_mine'])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          conv.lastMessage['status'] == 'read' ? Icons.done_all : Icons.done,
                          size: 16,
                          color: conv.lastMessage['status'] == 'read' ? Colors.cyanAccent : Colors.white38,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        conv.lastMessage['message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    if (conv.unreadCount > 0)
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle),
                        child: Text(
                          conv.unreadCount.toString(),
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              onTap: () {
                // Navigate to Chat Detail
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp);
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _showNewChatDialog(BuildContext context) {
    // Dialog to find user by Chat ID
  }
}
