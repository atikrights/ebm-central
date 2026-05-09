import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../data/chat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

class ChatProfileSetupScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ChatProfileSetupScreen> createState() => _ChatProfileSetupScreenState();
}

class _ChatProfileSetupScreenState extends ConsumerState<ChatProfileSetupScreen> {
  // final ChatService _chatService = ChatService(baseUrl: 'http://localhost:8000/api'); // REMOVED HARDCODED URL
  final TextEditingController _nameController = TextEditingController();
  String _fullChatId = "...";
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final authState = ref.read(authProvider);
    final chatService = ref.read(chatServiceProvider); // Use provider
    
    if (authState.chatProfileId != null && authState.chatProfileId!.isNotEmpty) {
      setState(() {
        _fullChatId = authState.chatProfileId!;
        _isLoading = false;
      });
    }

    try {
      final data = await chatService.getProfile();
      if (mounted) {
        setState(() {
          _fullChatId = data['chat_profile_id'] ?? _fullChatId;
          _isLoading = false;
        });
        ref.read(authProvider.notifier).updateChatInfo(
          id: data['chat_profile_id'],
          number: data['chat_number'],
          nickname: data['chat_nickname'],
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        
        // If it's a session error, show message but don't crash
        if (_error!.contains('Session expired')) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_error!), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _handleSetup() async {
    final chatService = ref.read(chatServiceProvider); // Use provider
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = "Please enter your name.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await chatService.setupProfileWithResponse(_nameController.text.trim());
      
      if (response['success'] == true) {
        ref.read(authProvider.notifier).updateChatInfo(
          id: response['chat_profile_id'],
          number: response['chat_number'],
          nickname: _nameController.text.trim()
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = response['error'] ?? "Failed to activate profile.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Connection error. Please try again.";
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_fullChatId != "..." && _fullChatId != "Generating...") {
      Clipboard.setData(ClipboardData(text: _fullChatId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat Virtual Number copied!', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.cyanAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -120, right: -60, child: _GlowCircle(color: Colors.cyanAccent.withOpacity(0.06))),
            Positioned(bottom: -120, left: -60, child: _GlowCircle(color: Colors.blueAccent.withOpacity(0.06))),
          ] else ...[
            Positioned(top: -120, right: -60, child: _GlowCircle(color: Colors.cyanAccent.withOpacity(0.03))),
            Positioned(bottom: -120, left: -60, child: _GlowCircle(color: Colors.blueAccent.withOpacity(0.03))),
          ],

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 360 : 380),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      decoration: BoxDecoration(
                        color: isDark 
                          ? Colors.white.withOpacity(0.04) 
                          : Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.cyanAccent.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.05), 
                            blurRadius: 40, 
                            offset: const Offset(0, 20)
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeaderIcon(isDark),
                          const SizedBox(height: 24),
                          _buildTitle(isDark),
                          const SizedBox(height: 12),
                          _buildDescription(isDark),
                          const SizedBox(height: 36),
                          _buildIdDisplay(isDark),
                          const SizedBox(height: 28),
                          _buildNameField(isDark),
                          if (_error != null) _buildErrorText(),
                          const SizedBox(height: 36),
                          _buildContinueButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(isDark ? 0.12 : 0.08),
        shape: BoxShape.circle,
        boxShadow: [
          if (isDark) BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20),
        ],
      ),
      child: const Icon(Icons.forum_rounded, size: 38, color: Colors.cyanAccent),
    );
  }

  Widget _buildTitle(bool isDark) {
    return Text(
      'Profile Setup',
      style: GoogleFonts.outfit(
        fontSize: 26, 
        fontWeight: FontWeight.w800, 
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDescription(bool isDark) {
    return Text(
      'Official EBM Central Chat System.\nSetup your profile here to proceed to the chat.',
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        color: isDark ? Colors.white38 : Colors.blueGrey[400], 
        fontSize: 13, 
        height: 1.5,
      ),
    );
  }

  Widget _buildIdDisplay(bool isDark) {
    final authState = ref.watch(authProvider);
    String displayId = authState.chatNumber ?? _fullChatId;
    
    // Split ID to highlight last 4 digits
    String baseId = "";
    String suffixId = "";
    if (displayId.length > 4) {
      baseId = displayId.substring(0, displayId.length - 4);
      suffixId = displayId.substring(displayId.length - 4);
    } else {
      baseId = displayId;
    }

    return Tooltip(
      message: 'Click to copy',
      child: InkWell(
        onTap: _copyToClipboard,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 26, 
                        fontWeight: FontWeight.w900, 
                        color: isDark ? Colors.white : const Color(0xFF0F172A), 
                        letterSpacing: 2.5
                      ),
                      children: [
                        TextSpan(text: baseId),
                        TextSpan(
                          text: suffixId,
                          style: TextStyle(
                            color: Colors.cyanAccent.withOpacity(isDark ? 0.8 : 1.0),
                            shadows: [
                              if (isDark) BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.copy_all_rounded, size: 18, color: Colors.cyanAccent.withOpacity(0.6)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '12-DIGIT VIRTUAL CHAT NUMBER',
                style: GoogleFonts.outfit(
                  color: Colors.cyanAccent.withOpacity(0.8), 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 2
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR NICKNAME', 
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white24 : Colors.blueGrey[300], 
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.5
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: GoogleFonts.outfit(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.blueGrey[50]?.withOpacity(0.5),
            hintText: 'e.g. Your Name...',
            hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.blueGrey[200], fontSize: 15),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.blueGrey[100]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.blueGrey[100]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
      ],
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        _error!, 
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(color: Colors.redAccent.withOpacity(0.9), fontSize: 12, height: 1.4)
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.25), 
            blurRadius: 25, 
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent, 
          foregroundColor: Colors.black, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
          elevation: 0
        ),
        onPressed: _isLoading ? null : _handleSetup,
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : Text(
              'ACTIVATE CHAT PROFILE', 
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8)
            ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  const _GlowCircle({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320, 
      height: 320, 
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 40)]
      ),
    );
  }
}
