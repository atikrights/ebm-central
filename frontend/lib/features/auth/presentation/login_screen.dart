import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/auth/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    await ref.read(authProvider.notifier).login(
      email: email,
      password: password,
    );

    // Navigation handled by GoRouter redirect based on auth state
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for errors and show snackbar
    ref.listen<AuthState>(authProvider, (AuthState? prev, AuthState next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.security, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(next.error!, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (next.isLoggedIn) {
        context.go('/');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated Background ───────────────────
          _buildBackground(isDark),

          // ── Center Content ────────────────────────
          Center(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildGlassCard(isDark, authState),
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
              ? [const Color(0xFF0A0E1A), const Color(0xFF0F172A), const Color(0xFF111827)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF0F9FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Glow blobs
          Positioned(
            top: -120, right: -80,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.12 : 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -60,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.1 : 0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(bool isDark, AuthState authState) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                'EBM Central',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Administrator Access Only',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 36),

              // Email
              _buildField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'admin@ebfic.store',
                icon: Icons.email_outlined,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password
              _buildField(
                controller: _passwordController,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 32),

              // Login Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: authState.isLoading
                        ? [Colors.grey.shade600, Colors.grey.shade700]
                        : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: authState.isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: authState.isLoading ? null : _handleLogin,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Admin only notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.1 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This portal is restricted to Administrators only.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white24 : Colors.black26,
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
