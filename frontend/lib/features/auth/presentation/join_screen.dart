import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_service.dart';

class JoinScreen extends ConsumerStatefulWidget {
  final String token;
  const JoinScreen({super.key, required this.token});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen>
    with SingleTickerProviderStateMixin {
  // Validation state
  bool _isValidating = true;
  bool _isValidToken = false;
  String _tokenEmail = '';

  // Form
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _validateToken();
  }

  Future<void> _validateToken() async {
    setState(() => _isValidating = true);
    
    try {
      final api = ref.read(apiServiceProvider);
      // Real API call to validate the token
      final data = await api.get('/governance/invite/validate/${widget.token}');

      if (mounted) {
        setState(() {
          _isValidating = false;
          _isValidToken = true;
          _tokenEmail = data['email'] ?? '';
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _isValidToken = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    final success = await ref.read(authProvider.notifier).registerWithToken(
      token: widget.token,
      name: name,
      password: password,
      email: _tokenEmail,
    );

    if (success && mounted) {
      context.go('/');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(isDark),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _isValidating
                    ? _buildLoadingCard(isDark)
                    : !_isValidToken
                        ? _buildInvalidCard(isDark)
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                              position: _slideAnim,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 460),
                                child: _buildJoinCard(isDark, authState),
                              ),
                            ),
                          ),
              ),
            ),
          ),

          // ── Title Bar (Mac Style) ─────────────────
          if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTitleBar(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(bool isDark) {
    return DragToMoveArea(
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent, // transparent over the animated background
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Mac-style window controls
            _buildWindowButton(Colors.redAccent, () => windowManager.close()),
            const SizedBox(width: 8),
            _buildWindowButton(Colors.orangeAccent, () => windowManager.minimize()),
            const SizedBox(width: 8),
            _buildWindowButton(Colors.greenAccent, () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton(Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF060B18), const Color(0xFF0D1525), const Color(0xFF0A0E1A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF0F9FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -150, right: -100,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.1 : 0.07),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          bottom: -100, left: -80,
          child: Container(
            width: 380, height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.08 : 0.06),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return _glassContainer(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFF3B82F6), strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verifying Invitation...',
            style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking your secure invitation link',
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidCard(bool isDark) {
    return _glassContainer(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'Invalid or Expired Link',
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This invitation link is invalid, has already been used, or has expired. Please contact your Super Administrator for a new link.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13, height: 1.6,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login_rounded, size: 16, color: Color(0xFF3B82F6)),
            label: Text('Go to Login', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard(bool isDark, AuthState authState) {
    return _glassContainer(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Join EBM Central',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete your Administrator profile to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13, color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 32),

          // Invitation Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(isDark ? 0.08 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 10),
                Text('Invitation verified for:', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tokenEmail,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                Tooltip(
                  message: 'Copy email',
                  child: InkWell(
                    onTap: () => Clipboard.setData(ClipboardData(text: _tokenEmail)),
                    child: const Icon(Icons.copy_rounded, size: 14, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Locked Email Field
          _buildLockedField(label: 'Email Address', value: _tokenEmail, isDark: isDark),
          const SizedBox(height: 16),

          // Name Field
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Your full name',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Password
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Min 6 characters',
            icon: Icons.lock_outline_rounded,
            isDark: isDark,
            obscureText: _obscurePass,
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20, color: isDark ? Colors.white38 : Colors.black38),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter password',
            icon: Icons.lock_reset_rounded,
            isDark: isDark,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20, color: isDark ? Colors.white38 : Colors.black38),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 32),

          // Register Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: authState.isLoading
                    ? [Colors.grey.shade600, Colors.grey.shade700]
                    : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: authState.isLoading ? [] : [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.45),
                  blurRadius: 24, offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: authState.isLoading ? null : _handleRegister,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Create My Account',
                              style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Error display
          if (authState.error != null && authState.error!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Text(
                authState.error!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
              ),
            ),

          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Already have an account? Sign in',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassContainer({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(40),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 60, offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLockedField({required String label, required String value, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 20, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(width: 12),
              Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500))),
              Icon(Icons.lock_rounded, size: 16, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14, color: isDark ? Colors.white24 : Colors.black26,
              ),
              prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }
}
