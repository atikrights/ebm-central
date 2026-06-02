import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:frontend/core/services/update_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> with SingleTickerProviderStateMixin {
  String _currentVersion = '';
  Map<String, dynamic>? _onlineInfo;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initialFetch();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initialFetch() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      final info = await UpdateService().checkForUpdateFlow();
      if (mounted) setState(() { _onlineInfo = info; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _platformLabel {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Universal';
  }

  IconData get _platformIcon {
    if (Platform.isWindows) return IconsaxPlusBold.monitor;
    if (Platform.isMacOS) return IconsaxPlusBold.monitor;
    if (Platform.isAndroid) return IconsaxPlusBold.mobile;
    if (Platform.isIOS) return IconsaxPlusBold.mobile;
    return IconsaxPlusBold.global;
  }

  bool get _isUpdateAvailable =>
      _onlineInfo != null &&
      (_onlineInfo!['version'] ?? '').toString().isNotEmpty &&
      _currentVersion.isNotEmpty &&
      _onlineInfo!['version'] != _currentVersion;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    const primary = Color(0xFF6366F1);      // Indigo
    const accent  = Color(0xFF8B5CF6);      // Violet
    const success = Color(0xFF10B981);      // Emerald
    const warning = Color(0xFFF59E0B);      // Amber

    final bgTop    = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F8FF);
    final bgBottom = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEEEEFF);

    return Scaffold(
      backgroundColor: bgTop,
      body: Stack(
        children: [
          // Background Gradient & Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgTop, bgBottom],
                ),
              ),
            ),
          ),
          Positioned(top: -80, right: -80,
            child: _GlowBlob(color: primary.withOpacity(0.12), size: 280)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 20, duration: 4.seconds)),

          // Main Scrollable Content
          SafeArea(
            child: _isLoading
                ? _buildLoader(primary)
                : RefreshIndicator(
                    onRefresh: _initialFetch,
                    color: primary,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Section 1: Update Status Hero
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            child: _buildSectionOne(isDark, primary, accent, success, warning),
                          ),
                        ),

                        // Section 2: Device & Platform Info
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: _buildSectionTwo(isDark, primary),
                          ),
                        ),

                        // Section 3: Release Post / What's New
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: _buildSectionThree(isDark, primary, success),
                          ),
                        ),

                        // Footer
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40, bottom: 40),
                            child: Column(
                              children: [
                                Text(
                                  'thanks for ebfic developer Teams',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'App is running in optimized mode',
                                  style: GoogleFonts.outfit(fontSize: 10, color: isDark ? Colors.white10 : Colors.black12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          
          // Sticky Action Button (at bottom)
          if (!_isLoading) _buildFloatingActionButton(isDark, primary, success),
        ],
      ),
    );
  }

  // ──────────────────────── SECTION 1: STATUS HERO ───────────────────────────

  Widget _buildSectionOne(bool isDark, Color primary, Color accent, Color success, Color warning) {
    return ValueListenableBuilder<UpdateState>(
      valueListenable: updateStateNotifier,
      builder: (_, state, __) {
        final isBusy = state == UpdateState.downloading || state == UpdateState.validating || state == UpdateState.installing;
        final isReady = state == UpdateState.readyToInstall;
        final hasUpdate = _isUpdateAvailable;

        Color statusColor = success;
        IconData statusIcon = IconsaxPlusBold.shield_tick;
        String statusTitle = 'Your App is Up to Date';
        String statusSub = 'You are currently running the latest build of ebm central.';

        if (isBusy) {
          statusColor = primary;
          statusIcon = IconsaxPlusBold.refresh_circle;
          statusTitle = 'System Update in Progress';
          statusSub = 'Downloading and preparing your new workstation...';
        } else if (isReady) {
          statusColor = success;
          statusIcon = IconsaxPlusBold.magic_star;
          statusTitle = 'Update Ready to Launch';
          statusSub = 'The update has been securely downloaded and verified.';
        } else if (hasUpdate) {
          statusColor = warning;
          statusIcon = IconsaxPlusBold.notification_1;
          statusTitle = 'New Update Available: v${_onlineInfo!['version']}';
          statusSub = 'A fresh version is available to improve your experience.';
        }

        return Column(
          children: [
            // Top Bar with Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SYSTEM UPDATE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: primary, letterSpacing: 1.5)),
                IconButton(
                  onPressed: () async {
                     await _initialFetch();
                  },
                  icon: Icon(IconsaxPlusLinear.refresh, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Hero Icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final scale = 1.0 + (_pulseController.value * 0.05);
                return Transform.scale(
                  scale: isBusy ? 1.0 : scale,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [statusColor, statusColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [
                        BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    child: isBusy 
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3).animate().scale(begin: const Offset(0.5, 0.5))
                      : Icon(statusIcon, color: Colors.white, size: 40),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Text info
            Text(statusTitle, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text(statusSub, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 32),
            
            _buildVersionDisplay(isDark, primary, success),
            
            // Progress Bar (if busy)
            if (isBusy) ...[
              const SizedBox(height: 40),
              _buildLiveProgressPanel(isDark, state, primary, success),
            ],
          ],
        );
      },
    );
  }

  Widget _buildVersionDisplay(bool isDark, Color primary, Color success) {
    final hasUpdate = _isUpdateAvailable;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVersionChip('CURRENT', _currentVersion, isDark, false),
            if (hasUpdate) ...[
              const SizedBox(width: 12),
              Icon(IconsaxPlusLinear.arrow_right_1, color: primary.withOpacity(0.5), size: 16),
              const SizedBox(width: 12),
              _buildVersionChip('LATEST', (_onlineInfo!['version'] ?? '').toString(), isDark, true),
            ],
          ],
        ),
        
        // Show small inline actions if up to date
        if (!hasUpdate) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallActionBtn(
                onTap: () => UpdateService().openUpdateFolder(),
                icon: IconsaxPlusBold.folder_open,
                label: 'Open setup',
                color: primary,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildSmallActionBtn(
                onTap: () => _initialFetch(),
                icon: IconsaxPlusBold.refresh,
                label: 'Repair',
                color: success,
                isDark: isDark,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ],
      ],
    );
  }

  Widget _buildSmallActionBtn({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionChip(String label, String version, bool isDark, bool isLatest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLatest ? const Color(0xFF10B981).withOpacity(0.3) : (isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: isLatest ? const Color(0xFF10B981) : Colors.grey)),
          Text('v$version', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  // ──────────────────────── SECTION 2: DEVICE INFO ───────────────────────────

  Widget _buildSectionTwo(bool isDark, Color primary) {
    final platforms = [
      {'label': 'Android', 'icon': IconsaxPlusBold.mobile, 'color': const Color(0xFF10B981)},
      {'label': 'iOS', 'icon': IconsaxPlusBold.mobile, 'color': const Color(0xFF3B82F6)},
      {'label': 'Windows', 'icon': IconsaxPlusBold.monitor, 'color': const Color(0xFF6366F1)},
      {'label': 'macOS', 'icon': IconsaxPlusBold.monitor, 'color': const Color(0xFF8B5CF6)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(IconsaxPlusLinear.cpu, size: 18, color: primary),
            const SizedBox(width: 8),
            Text('RUNNING ON DEVICE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: primary, letterSpacing: 1.1)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: platforms.map((p) {
            final isActive = (p['label'] as String) == _platformLabel;
            final c = p['color'] as Color;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isActive ? c.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isActive ? c.withOpacity(0.4) : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Icon(p['icon'] as IconData, color: isActive ? c : Colors.grey.withOpacity(0.5), size: 22),
                    const SizedBox(height: 8),
                    Text(p['label'] as String, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? c : Colors.grey)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ──────────────────────── SECTION 3: RELEASE POST ───────────────────────────

  Widget _buildSectionThree(bool isDark, Color primary, Color success) {
    if (_onlineInfo == null) return const SizedBox.shrink();

    final author    = (_onlineInfo!['author'] ?? 'ebfic teams').toString();
    final avatar    = (_onlineInfo!['author_avatar'] ?? '').toString();
    final notes     = (_onlineInfo!['notes'] ?? 'No release notes available.').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(IconsaxPlusLinear.document_text, size: 18, color: primary),
            const SizedBox(width: 8),
            Text('RELEASE CHANGELOG', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: primary, letterSpacing: 1.1)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 16, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, backgroundColor: primary.withOpacity(0.1)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      Text('Published on GitHub', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('VERIFIED', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: success, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), height: 1),
              const SizedBox(height: 20),
              // Release Notes Text
              Text(
                notes,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────── HELPERS ───────────────────────────

  Widget _buildLiveProgressPanel(bool isDark, UpdateState state, Color primary, Color success) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(IconsaxPlusBold.document_download, color: primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: updateStatusNotifier,
                  builder: (_, msg, __) => Text(msg, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: updateProgressNotifier,
                builder: (_, p, __) => Text('${(p * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: updateProgressNotifier,
            builder: (_, p, __) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: p == 0 ? null : p,
                minHeight: 8,
                backgroundColor: primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDark, Color primary, Color success) {
    return Positioned(
      bottom: 24, left: 20, right: 20,
      child: ValueListenableBuilder<UpdateState>(
        valueListenable: updateStateNotifier,
        builder: (_, state, __) {
          final isBusy  = state == UpdateState.downloading || state == UpdateState.validating || state == UpdateState.installing;
          final isReady = state == UpdateState.readyToInstall;
          final isError = state == UpdateState.error;
          final hasUpdate = _isUpdateAvailable;

          if (!hasUpdate && !isBusy && !isReady && !isError) {
             return const SizedBox.shrink();
          }

          final btnColor = isError ? Colors.redAccent : (isReady ? success : primary);
          
          String btnLabel = 'Download & Install Update';
          if (isBusy) btnLabel = 'Processing Update...';
          if (isReady) btnLabel = 'Install / Open Update';
          if (isError) btnLabel = 'Repair & Download Again';

          final btnIcon = isError ? IconsaxPlusBold.refresh_circle : (isReady ? IconsaxPlusBold.flash : IconsaxPlusBold.document_download);

          return Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: btnColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ElevatedButton(
              onPressed: isBusy ? null : () {
                if (isReady) {
                  UpdateService().openUpdateFolder();
                } else {
                  UpdateService().startDirectUpdate(_onlineInfo!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   if (isBusy)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  else
                    Icon(btnIcon, size: 22),
                  const SizedBox(width: 12),
                  Text(btnLabel, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                ],
              ),
            ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
          );
        },
      ),
    );
  }

  Widget _buildLoader(Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GlowBlob(color: primary.withOpacity(0.15), size: 120).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
          const SizedBox(height: 20),
          CircularProgressIndicator(color: primary, strokeWidth: 2),
          const SizedBox(height: 24),
          Text('Connecting to Secure Cloud...', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
      ),
    );
  }
}
