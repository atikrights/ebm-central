import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:frontend/core/auth/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_profile_edit_screen.dart';
import 'chat_profile_view_screen.dart';

class ChatSettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Exact Midnight Palette from user reference
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final headerColor = isDark ? Colors.white38 : Colors.black45;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: textColor, fontSize: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader(headerColor, 'Account & Profile'),
          _buildProfileCard(
            context,
            isDark: isDark,
            name: authState.name ?? 'User',
            chatId: authState.chatProfileId ?? authState.userId?.toString() ?? 'ID_NOT_SET',
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(headerColor, 'Privacy & Identity'),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.fingerprint_rounded,
            title: 'Change Chat Profile ID',
            subtitle: 'Update your unique identity suffix',
            onTap: () {
              // Navigate to Setup Screen
            },
          ),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.security_rounded,
            title: 'End-to-End Encryption',
            subtitle: 'Military-grade AES-256 active',
            trailing: const Icon(Icons.verified_user_rounded, color: Colors.cyanAccent, size: 18),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(headerColor, 'Media & Notifications'),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.notifications_active_rounded,
            title: 'Message Notifications',
            subtitle: 'Sound, vibration & alert style',
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.cloud_done_rounded,
            title: 'Data & Storage',
            subtitle: 'Optimize local storage & cache',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(headerColor, 'Advanced'),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.speed_rounded,
            title: 'Voice Call Quality',
            subtitle: 'HD WebRTC low-latency engine',
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            isDark: isDark,
            icon: Icons.delete_forever_rounded,
            title: 'Clear All Chats',
            subtitle: 'Permanently wipe all conversation history',
            isDestructive: true,
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, {required bool isDark, required String name, required String chatId}) {
    final accent = Colors.cyanAccent;
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.05);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatProfileViewScreen()));
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.cyanAccent, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatProfileViewScreen()));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@$chatId".toUpperCase(),
                    style: GoogleFonts.outfit(color: accent.withOpacity(isDark ? 1.0 : 0.9), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatProfileEditScreen()));
            },
            icon: Icon(Icons.mode_edit_outline_rounded, color: isDark ? Colors.white60 : Colors.black38, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(Color color, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 12, top: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color, 
          fontSize: 12, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.8
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final tileBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final accent = isDestructive ? Colors.redAccent : Colors.cyanAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: tileBg,
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              title: Text(
                title,
                style: GoogleFonts.outfit(color: isDestructive ? Colors.redAccent : textColor, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                subtitle,
                style: GoogleFonts.outfit(color: subColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black12, size: 20),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
