import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/chat_service.dart';

class ChatProfileViewScreen extends ConsumerStatefulWidget {
  final int? userId;
  final String? receiverType;

  const ChatProfileViewScreen({super.key, this.userId, this.receiverType});

  @override
  ConsumerState<ChatProfileViewScreen> createState() => _ChatProfileViewScreenState();
}

class _ChatProfileViewScreenState extends ConsumerState<ChatProfileViewScreen> {
  Map<String, dynamic>? _remoteProfile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _loadRemoteProfile();
    }
  }

  Future<void> _loadRemoteProfile() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(chatServiceProvider);
      // We need a way to get OTHER user profile. 
      // For now, let's assume getProfileInfo can take a userId or there's a findUserByChatId
      // I'll stick to local authState if it's the current user.
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isMe = widget.userId == null || widget.userId == authState.userId;
    final isAi = widget.receiverType == 'ai';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // Profile Data
    final String displayName = isAi ? 'AI Assistant' : (isMe ? (authState.name ?? 'User') : 'User');
    final String displayHandle = isAi ? 'OFFICIAL_AI' : (isMe ? (authState.chatProfileId ?? 'ID_NOT_SET') : 'USER');
    final String displayBio = isAi ? 'EBM Central HD AI Engine' : (isMe ? (authState.chatBio ?? 'No bio yet...') : '');
    final String displayAbout = isAi ? 'I am a highly advanced artificial intelligence designed to assist with management, coding, and creative tasks within the EBM ecosystem.' : (isMe ? (authState.chatAbout ?? 'No additional information.') : '');

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0B1120) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(displayName, displayHandle, isAi),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(
                    label: 'NICKNAME',
                    value: isMe ? (authState.chatNickname ?? displayName) : displayName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildProfileSection(
                    label: 'BIO',
                    value: displayBio,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildProfileSection(
                    label: 'ABOUT',
                    value: displayAbout,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  if (!isAi) _buildUidCard(isMe ? authState.userId?.toString() : widget.userId?.toString(), isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(String name, String handle, bool isAi) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B1120), Color(0xFF1E293B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isAi 
                    ? const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent])
                    : const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                  boxShadow: [BoxShadow(color: (isAi ? Colors.amberAccent : Colors.cyanAccent).withOpacity(0.3), blurRadius: 30)],
                ),
                child: Center(
                  child: isAi 
                    ? const Icon(Icons.auto_awesome, size: 50, color: Colors.white)
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text(
                "@$handle",
                style: GoogleFonts.outfit(color: isAi ? Colors.amberAccent : Colors.cyanAccent, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection({required String label, required String value, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white24 : Colors.black38,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ],
    );
  }

  Widget _buildUidCard(String? uid, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UNIQUE CHAT UID',
                style: GoogleFonts.outfit(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Text(
                uid ?? '...',
                style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
