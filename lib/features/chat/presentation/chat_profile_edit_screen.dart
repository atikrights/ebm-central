import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/chat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

class ChatProfileEditScreen extends ConsumerStatefulWidget {
  const ChatProfileEditScreen({super.key});

  @override
  ConsumerState<ChatProfileEditScreen> createState() => _ChatProfileEditScreenState();
}

class _ChatProfileEditScreenState extends ConsumerState<ChatProfileEditScreen> {
  late ChatService _chatService;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _aboutController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chatService    = ChatService(baseUrl: 'http://localhost:8000/api');
    final authState = ref.read(authProvider);
    _nicknameController = TextEditingController(text: authState.chatNickname);
    _bioController      = TextEditingController(text: authState.chatBio);
    _aboutController    = TextEditingController(text: authState.chatAbout);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _error = 'Nickname cannot be empty.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await _chatService.updateProfile(
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim(),
        about: _aboutController.text.trim(),
      );

      if (response['success'] == true) {
        ref.read(authProvider.notifier).updateChatInfo(
          nickname: _nicknameController.text.trim(),
          bio: _bioController.text.trim(),
          about: _aboutController.text.trim(),
        );
        if (mounted) {
          _showSnack('Profile updated successfully!', Colors.green);
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _error = response['error']?.toString() ?? 'Failed to update.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Connection error. Try again.'; _isLoading = false; });
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _copyChatNumber(String number) {
    Clipboard.setData(ClipboardData(text: number));
    _showSnack('Chat Number copied!', Colors.green.shade700);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final width     = MediaQuery.of(context).size.width;
    final isWide    = width > 700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Chat Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: textColor, fontSize: 18)),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)))
              : TextButton(
                  onPressed: _handleSave,
                  child: Text('SAVE',
                      style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.w900))),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 640.0 : double.infinity),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(isDark),
                const SizedBox(height: 32),
                _buildTextField(label: 'NICKNAME', controller: _nicknameController,
                    hint: 'Your display name...', isDark: isDark),
                const SizedBox(height: 20),
                _buildTextField(label: 'BIO', controller: _bioController,
                    hint: 'A short sentence about you...', maxLength: 160, isDark: isDark),
                const SizedBox(height: 20),
                _buildTextField(label: 'ABOUT', controller: _aboutController,
                    hint: 'Detailed information...', maxLines: 4, isDark: isDark),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13)),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Header ──────────────────────────────
  Widget _buildProfileHeader(bool isDark) {
    final auth       = ref.watch(authProvider);
    final name       = auth.name ?? 'User';
    final chatNumber = auth.chatNumber ?? '';
    final profileId  = auth.chatProfileId ?? '';
    final role       = (auth.role ?? 'STAFF').toUpperCase();

    final Color roleColor = role == 'ADMIN'
        ? const Color(0xFF60A5FA)
        : role == 'MANAGER'
            ? const Color(0xFFFB923C)
            : const Color(0xFF34D399);

    return Center(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [roleColor, roleColor.withOpacity(0.6)]),
              boxShadow: [BoxShadow(color: roleColor.withOpacity(0.35), blurRadius: 20)],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(name,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: roleColor.withOpacity(0.3)),
            ),
            child: Text(role,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900,
                    color: roleColor, letterSpacing: 1)),
          ),
          const SizedBox(height: 20),

          // ── 12-Digit Virtual Chat Number ──
          if (chatNumber.isNotEmpty)
            GestureDetector(
              onTap: () => _copyChatNumber(chatNumber),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.cyanAccent.withOpacity(0.07) : Colors.cyanAccent.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(chatNumber,
                            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900,
                                color: Colors.cyanAccent, letterSpacing: 3)),
                        const SizedBox(width: 10),
                        const Icon(Icons.copy_rounded, size: 16, color: Colors.cyanAccent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('12-DIGIT VIRTUAL CHAT NUMBER  •  TAP TO COPY',
                        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900,
                            letterSpacing: 1.5, color: isDark ? Colors.white30 : Colors.black38)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Text('Complete profile setup to get your 12-digit number.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.orange, fontSize: 12)),
            ),

          if (profileId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('@$profileId',
                style: GoogleFonts.outfit(
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  // ── Text Field ──────────────────────────────────
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                color: isDark ? Colors.white24 : Colors.black38,
                fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.all(16),
            counterStyle: GoogleFonts.outfit(
                color: isDark ? Colors.white24 : Colors.black26, fontSize: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
