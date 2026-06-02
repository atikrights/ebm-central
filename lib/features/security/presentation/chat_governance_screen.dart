import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_service.dart'; // Assume standard API service is imported
import '../../../core/auth/auth_provider.dart';

class ChatGovernanceScreen extends ConsumerStatefulWidget {
  const ChatGovernanceScreen({super.key});

  @override
  ConsumerState<ChatGovernanceScreen> createState() => _ChatGovernanceScreenState();
}

class _ChatGovernanceScreenState extends ConsumerState<ChatGovernanceScreen> {
  bool _isLoadingUsers = true;
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  String _userSearchQuery = "";

  dynamic _selectedUser;
  bool _isLoadingSessions = false;
  List<dynamic> _sessions = [];

  dynamic _selectedSession;
  bool _isLoadingTranscript = false;
  List<dynamic> _transcript = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSystemUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/governance/users');
      if (res is List) {
        setState(() {
          _users = res;
          _filteredUsers = res;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to load system users: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  void _filterUsers(String q) {
    setState(() {
      _userSearchQuery = q;
      _filteredUsers = _users.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final num = (u['chat_number'] ?? '').toString();
        final nick = (u['chat_profile_id'] ?? '').toString().toLowerCase();
        return name.contains(q.toLowerCase()) ||
            email.contains(q.toLowerCase()) ||
            num.contains(q) ||
            nick.contains(q.toLowerCase());
      }).toList();
    });
  }

  Future<void> _selectUser(dynamic user) async {
    setState(() {
      _selectedUser = user;
      _selectedSession = null;
      _sessions = [];
      _transcript = [];
      _isLoadingSessions = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final userId = user['id'];
      final res = await api.get('/governance/chat-history/$userId');
      if (res is List) {
        setState(() {
          _sessions = res;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to fetch chat history: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _selectSession(dynamic session) async {
    setState(() {
      _selectedSession = session;
      _isLoadingTranscript = true;
      _transcript = [];
    });

    try {
      final api = ref.read(apiServiceProvider);
      final userId = _selectedUser['id'];
      final partnerId = session['partner_id'];
      final type = session['type'];

      final res = await api.get(
        '/governance/chat-transcript/$userId?type=$type&partner_id=$partnerId',
      );
      if (res is List) {
        setState(() {
          _transcript = res;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to load live transcript: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoadingTranscript = false);
    }
  }

  Future<void> _moderateMessage(dynamic msg, String action, {String? newContent}) async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/governance/moderate-message', {
        'id': msg['id'],
        'source': msg['source'] ?? 'direct_messages',
        'action': action,
        if (newContent != null) 'new_content': newContent,
      });

      _showSnackbar('Message action executed successfully', Colors.cyanAccent);
      if (_selectedSession != null) {
        // Refresh transcript
        _selectSession(_selectedSession);
      }
    } catch (e) {
      _showSnackbar('Failed to execute moderation: $e', Colors.redAccent);
    }
  }

  Future<void> _wipeSession(dynamic session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Wipe Conversation?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently clear all messages in this conversation? This action is irreversible.',
            style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('WIPE NOW', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      final userId = _selectedUser['id'];
      final partnerId = session['partner_id'];
      final type = session['type'];

      await api.post('/governance/wipe-session/$userId', {
        'partner_id': partnerId,
        'type': type,
      });

      _showSnackbar('Conversation purged successfully.', Colors.cyanAccent);
      _selectUser(_selectedUser); // Refresh channels
    } catch (e) {
      _showSnackbar('Failed to purge session: $e', Colors.redAccent);
    }
  }

  void _showEditDialog(dynamic msg) {
    String text = msg['message'] ?? '';
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(text: text);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Edit Message Content', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _moderateMessage(msg, 'edit', newContent: ctrl.text.trim());
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: col, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // ── LEFT PANELS: Users Explorer ─────────────────────────────────
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              color: isDark ? const Color(0xFF111724) : Colors.white,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Governance Core',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: _filterUsers,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search audit network...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white30),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoadingUsers
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, idx) {
                            final u = _filteredUsers[idx];
                            final isSel = _selectedUser != null && _selectedUser['id'] == u['id'];
                            return ListTile(
                              selected: isSel,
                              selectedTileColor: Colors.cyanAccent.withOpacity(0.06),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isSel ? Colors.cyanAccent : Colors.white10,
                                child: Text(
                                  (u['name'] ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                u['name'] ?? 'Unknown User',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSel ? Colors.cyanAccent : (isDark ? Colors.white : Colors.black87),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: u['is_online'] == true ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    u['role']?.toString().toUpperCase() ?? 'STAFF',
                                    style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              onTap: () => _selectUser(u),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // ── MIDDLE COLUMN: User's Active Channels ───────────────────────
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              color: isDark ? const Color(0xFF0F1420) : const Color(0xFFF8FAFC),
            ),
            child: _selectedUser == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 48, color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 12),
                        Text('Select a user to audit', style: GoogleFonts.outfit(color: Colors.white30)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_selectedUser['name']}\'s Chats',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoadingSessions
                            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                            : _sessions.isEmpty
                                ? Center(child: Text('No active conversations', style: GoogleFonts.outfit(color: Colors.white24)))
                                : ListView.builder(
                                    itemCount: _sessions.length,
                                    itemBuilder: (context, idx) {
                                      final s = _sessions[idx];
                                      final isSel = _selectedSession != null && _selectedSession['id'] == s['id'];
                                      return ListTile(
                                        selected: isSel,
                                        selectedTileColor: Colors.cyanAccent.withOpacity(0.04),
                                        title: Text(
                                          s['partner_name'] ?? 'Channel',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSel ? Colors.cyanAccent : Colors.white70,
                                          ),
                                        ),
                                        subtitle: Text(
                                          s['last_message'] ?? 'No messages yet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: Colors.white30),
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 18, color: Colors.white38),
                                          onSelected: (val) {
                                            if (val == 'wipe') _wipeSession(s);
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'wipe',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                                                  SizedBox(width: 8),
                                                  Text('Wipe Session', style: TextStyle(color: Colors.redAccent)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _selectSession(s),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
          ),

          // ── RIGHT COLUMN: Decrypted Active Message Terminal ─────────────
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0B0F17) : Colors.white,
              child: _selectedSession == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_red_eye_outlined, size: 58, color: isDark ? Colors.white12 : Colors.black12),
                          const SizedBox(height: 16),
                          Text('Man-in-the-Middle Audit Console', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white30, fontWeight: FontWeight.bold)),
                          Text('Select an active session to begin live transcript capture', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white24)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Live Console Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                            color: isDark ? const Color(0xFF0F1420) : Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.terminal, color: Colors.cyanAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AUDIT LOG: ${_selectedUser['name']} ↔ ${_selectedSession['partner_name']}',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.cyanAccent),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Status: Captured, Decrypted and Monitored in real-time.',
                                    style: TextStyle(fontSize: 11, color: Colors.white30),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.04), padding: const EdgeInsets.all(12)),
                                icon: const Icon(Icons.refresh, size: 16, color: Colors.cyanAccent),
                                label: const Text('FORCE LIVE SYNC', style: TextStyle(fontSize: 11, color: Colors.white)),
                                onPressed: () => _selectSession(_selectedSession),
                              ),
                            ],
                          ),
                        ),

                        // Message Feed
                        Expanded(
                          child: _isLoadingTranscript
                              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                              : _transcript.isEmpty
                                  ? Center(child: Text('Console Active: No message stream captured.', style: GoogleFonts.outfit(color: Colors.white24)))
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(24),
                                      reverse: true,
                                      itemCount: _transcript.length,
                                      itemBuilder: (context, idx) {
                                        final m = _transcript[idx];
                                        final bool isSender = m['sender_id'].toString() == _selectedUser['id'].toString();
                                        final bool isHidden = m['status'] == 'hidden';

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: Row(
                                            mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (!isSender) ...[
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Colors.white10,
                                                  child: Text(_selectedSession['partner_name']?[0]?.toUpperCase() ?? 'P', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Column(
                                                crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        isSender ? _selectedUser['name'] : _selectedSession['partner_name'],
                                                        style: const TextStyle(fontSize: 10, color: Colors.white30, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        m['created_at']?.toString().substring(11, 16) ?? '',
                                                        style: const TextStyle(fontSize: 9, color: Colors.white24),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    constraints: const BoxConstraints(maxWidth: 450),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    decoration: BoxDecoration(
                                                      color: isHidden
                                                          ? Colors.redAccent.withOpacity(0.08)
                                                          : (isSender ? const Color(0xFF6366F1).withOpacity(0.12) : const Color(0xFF1E293B)),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isHidden
                                                            ? Colors.redAccent.withOpacity(0.3)
                                                            : (isSender ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isHidden ? '[Message Hidden By Governance Matrix]' : (m['message'] ?? ''),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 13,
                                                        color: isHidden ? Colors.redAccent : const Color(0xDDFFFFFF),
                                                        fontStyle: isHidden ? FontStyle.italic : FontStyle.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  // Governance Actions Row
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      _ActionIndicator(
                                                        icon: Icons.edit_note,
                                                        label: 'Edit',
                                                        onTap: () => _showEditDialog(m),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      _ActionIndicator(
                                                        icon: isHidden ? Icons.visibility : Icons.visibility_off,
                                                        label: isHidden ? 'Show' : 'Hide',
                                                        onTap: () => _moderateMessage(m, 'toggle-visibility'),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      _ActionIndicator(
                                                        icon: Icons.delete_sweep,
                                                        label: 'Destroy',
                                                        color: Colors.redAccent,
                                                        onTap: () => _moderateMessage(m, 'delete'),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (isSender) ...[
                                                const SizedBox(width: 8),
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                                  child: Text(_selectedUser['name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(fontSize: 10, color: Color(0xFF60A5FA))),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionIndicator({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            Icon(icon, size: 12, color: color ?? Colors.white24),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color ?? Colors.white30, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
