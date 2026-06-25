import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_theme.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  bool _isSaving = false;
  String? _successMsg;
  late String _selectedLang;
  late String _selectedCurr;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    _selectedLang = prefs.language;
    _selectedCurr = prefs.currency;
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _successMsg = null; });
    await ref.read(preferencesProvider.notifier).updatePreferences(
      language: _selectedLang,
      currency: _selectedCurr,
    );
    if (mounted) {
      setState(() {
        _isSaving = false;
        _successMsg = L10n.get('change_success', _selectedLang);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefs = ref.watch(preferencesProvider);
    final lang = prefs.language;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page Header ──────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.secondary.withOpacity(0.1),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.get('settings', lang),
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Language • Currency • Display',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

                  const SizedBox(height: 8),

                  // ── Live sync badge ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulseDot(color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          L10n.get('live_sync', lang),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 28),

                  // ── Language Section ─────────────────────────────────
                  _SectionHeader(
                    icon: Icons.language_rounded,
                    title: L10n.get('language', lang),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionCard(
                          isSelected: _selectedLang == 'en',
                          isDark: isDark,
                          onTap: () => setState(() => _selectedLang = 'en'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🇺🇸', style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 8),
                              Text(
                                L10n.get('english', lang),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedLang == 'en'
                                      ? AppColors.primary
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              Text(
                                'English',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OptionCard(
                          isSelected: _selectedLang == 'bn',
                          isDark: isDark,
                          onTap: () => setState(() => _selectedLang = 'bn'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🇧🇩', style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 8),
                              Text(
                                L10n.get('bangla', 'bn'),
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedLang == 'bn'
                                      ? AppColors.primary
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              Text(
                                'Bangla',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 28),

                  // ── Currency Section ─────────────────────────────────
                  _SectionHeader(
                    icon: Icons.account_balance_wallet_outlined,
                    title: L10n.get('currency', lang),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionCard(
                          isSelected: _selectedCurr == 'USDT',
                          isDark: isDark,
                          onTap: () => setState(() => _selectedCurr = 'USDT'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF26A17B).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('💵', style: TextStyle(fontSize: 24)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'USDT',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedCurr == 'USDT'
                                      ? const Color(0xFF26A17B)
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              Text(
                                'US Dollar Tether',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _RateBadge(
                                label: '≈ \$1.00',
                                color: const Color(0xFF26A17B),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OptionCard(
                          isSelected: _selectedCurr == 'BDT',
                          isDark: isDark,
                          onTap: () => setState(() => _selectedCurr = 'BDT'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006A4E).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('৳', style: TextStyle(fontSize: 24, fontFamily: 'sans-serif', color: Color(0xFF006A4E), fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'BDT',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedCurr == 'BDT'
                                      ? const Color(0xFF006A4E)
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              Text(
                                'Bangladeshi Taka',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _RateBadge(
                                label: '≈ ৳${prefs.conversionRate.toStringAsFixed(0)}',
                                color: const Color(0xFF006A4E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 32),

                  // ── Preview Box ───────────────────────────────────────
                  _PreviewCard(
                    lang: _selectedLang,
                    curr: _selectedCurr,
                    rate: prefs.conversionRate,
                    isDark: isDark,
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 28),

                  // ── Success Message ───────────────────────────────────
                  if (_successMsg != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMsg!,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),

                  // ── Save Button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        shadowColor: AppColors.primary.withOpacity(0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_done_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  L10n.get('save', _selectedLang),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  const _SectionHeader({required this.icon, required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;
  const _OptionCard({
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : (isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.7)
                : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 16, spreadRadius: 0)]
              : [],
        ),
        child: child,
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RateBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String lang;
  final String curr;
  final double rate;
  final bool isDark;
  const _PreviewCard({required this.lang, required this.curr, required this.rate, required this.isDark});

  String _format(double usdt) {
    if (curr == 'USDT') return '\$${usdt.toStringAsFixed(2)} USDT';
    return '৳${(usdt * rate).toStringAsFixed(0)} BDT';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : AppColors.primary.withOpacity(0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE PREVIEW',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _previewRow(lang == 'bn' ? 'ড্যাশবোর্ড' : 'Dashboard', '', isDark),
              _previewRow(lang == 'bn' ? 'মোট আয়' : 'Total Revenue', _format(12500.00), isDark),
              _previewRow(lang == 'bn' ? 'প্রকল্প ব্যয়' : 'Project Cost', _format(4750.50), isDark),
              _previewRow(lang == 'bn' ? 'নেট ব্যালেন্স' : 'Net Balance', _format(7749.50), isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, bool isDark) {
    final labelFont = lang == 'bn'
        ? GoogleFonts.hindSiliguri(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)
        : GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelFont),
          if (value.isNotEmpty)
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
