import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../mail/data/mail_service.dart';
import '../data/chat_service.dart';
import 'dart:async';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAiGenerating = false;
  bool _isLoading = true;
  int _selectedChatIndex = 1; // 0: self, 1: ai
  
  Timer? _typewriterTimer;
  late AnimationController _glowController;

  List<Map<String, dynamic>> _currentMessages = [];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(chatServiceProvider);
      final receiverType = _selectedChatIndex == 0 ? 'self' : 'ai';
      final messages = await service.getChats(receiverType);
      
      if (mounted) {
        setState(() {
          if (messages.isEmpty) {
            // Default Welcome Messages
            _currentMessages = [
              if (_selectedChatIndex == 0)
                {'sender': 'System', 'message': 'Welcome to your private space. Personal notes and reminders go here.', 'isMe': false}
              else
                {'sender': 'AI Assistant', 'message': 'Hello! I am your official EBM AI Assistant. How can I help you today?', 'isMe': false}
            ];
          } else {
            _currentMessages = messages;
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typewriterTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startTypewriter(String fullText) {
    _messageController.clear();
    int charIndex = 0;
    _typewriterTimer?.cancel();
    
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (charIndex < fullText.length) {
        if (mounted) {
          setState(() {
            _messageController.text += fullText[charIndex];
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
            charIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _generateAiResponse(String userPrompt) async {
    setState(() => _isAiGenerating = true);
    try {
      final mailService = ref.read(mailServiceProvider);
      final chatService = ref.read(chatServiceProvider);
      
      final response = await mailService.generateAiContent("You are an official EBM Chat Assistant. Respond to this message from the user: $userPrompt");
      final aiResult = response['body'] ?? response['message'] ?? 'I processed your request.';
      
      // Save AI response to DB
      await chatService.sendMessage('ai', aiResult, isAi: true);
      
      if (mounted) {
        setState(() {
          _isAiGenerating = false;
          _currentMessages.add({
            'sender': 'AI Assistant',
            'message': aiResult,
            'isMe': false,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
      }
    }
  }

  Future<void> _draftWithAi() async {
    if (_messageController.text.isEmpty) return;
    
    setState(() => _isAiGenerating = true);
    try {
      final service = ref.read(mailServiceProvider);
      final response = await service.generateAiContent("Draft a short chat message for: ${_messageController.text}");
      final aiResult = response['body'] ?? response['message'] ?? '';
      
      if (mounted) {
        setState(() => _isAiGenerating = false);
        _startTypewriter(aiResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiGenerating = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final receiverType = _selectedChatIndex == 0 ? 'self' : 'ai';
    final chatService = ref.read(chatServiceProvider);

    setState(() {
      _currentMessages.add({
        'sender': 'Me',
        'message': text,
        'isMe': true,
      });
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      // Sync with database (Encrypted)
      await chatService.sendMessage(receiverType, text);
      
      if (_selectedChatIndex == 1) {
        _generateAiResponse(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          _buildChatSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildChatHeader(context),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        itemCount: _currentMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _currentMessages[index];
                          return _buildChatBubble(context, msg['sender'], msg['message'], msg['isMe']);
                        },
                      ),
                ),
                _buildMessageInput(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text("OFFICIAL CHATS", style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          _buildSidebarItem(0, Icons.person_rounded, "Notes (You)"),
          _buildSidebarItem(1, Icons.auto_awesome, "AI Assistant"),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text("End-to-End Encrypted", style: TextStyle(fontSize: 10, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("EBM CENTRAL v1.0", style: theme.textTheme.labelSmall?.copyWith(color: Colors.white24)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedChatIndex == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        if (_selectedChatIndex != index) {
          setState(() {
            _selectedChatIndex = index;
            _currentMessages = [];
          });
          _loadMessages();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? theme.colorScheme.primary : Colors.white38),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _selectedChatIndex == 0 ? Colors.blue : Colors.amber,
            radius: 18,
            child: Icon(_selectedChatIndex == 0 ? Icons.person : Icons.auto_awesome, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedChatIndex == 0 ? "My Personal Space" : "EBM Intelligence", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_selectedChatIndex == 0 ? "Private Notes" : "Online & Learning", style: theme.textTheme.labelSmall?.copyWith(color: Colors.green)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white24),
            tooltip: 'Clear Chat History',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear History?"),
                  content: const Text("This will delete all messages in this chat permanently."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear", style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true) {
                final receiverType = _selectedChatIndex == 0 ? 'self' : 'ai';
                await ref.read(chatServiceProvider).clearChat(receiverType);
                _loadMessages();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, String sender, String message, bool isMe) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : (theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(sender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _selectedChatIndex == 1 ? Colors.amber : theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Text(message, style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9), height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: _isAiGenerating ? [
                BoxShadow(color: Colors.amber.withOpacity(0.2 * _glowController.value), blurRadius: 15, spreadRadius: 2)
              ] : [],
            ),
            child: GlassCard(
              borderRadius: BorderRadius.circular(50),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isAiGenerating 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                      : Icon(Icons.auto_awesome, color: Colors.amber.withOpacity(0.7 + (0.3 * _glowController.value))),
                    tooltip: 'Draft with AI',
                    onPressed: _isAiGenerating ? null : _draftWithAi,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(
                        color: _isAiGenerating ? Colors.amber : (isDark ? Colors.white : Colors.black87),
                      ),
                      decoration: InputDecoration(
                        hintText: _isAiGenerating ? 'AI Intelligence active...' : 'Type a message...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
