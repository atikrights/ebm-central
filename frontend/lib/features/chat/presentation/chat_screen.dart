import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildChatBubble(context, 'Tanvir', 'Hello team, how is the project going?', false),
                _buildChatBubble(context, 'Me', 'Almost finished the data module.', true),
                _buildChatBubble(context, 'Sabbir', 'Great! I am starting the UI review.', false),
              ],
            ),
          ),
          _buildMessageInput(context, isDark),
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
          color: isMe ? theme.colorScheme.primary : (theme.brightness == Brightness.dark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(sender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Text(message, style: TextStyle(color: isMe ? Colors.white : (theme.brightness == Brightness.dark ? Colors.white : Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        borderRadius: BorderRadius.circular(50),
        child: Row(
          children: [
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {},
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
