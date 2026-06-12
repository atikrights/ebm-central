import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

class BriefItem {
  final String id;
  final String title;
  final String owner;
  final DateTime created;
  final String urgency; // 'Low', 'Medium', 'High', 'Critical'
  final double progress; // 0.0 to 1.0
  final String summary;

  BriefItem({
    required this.id,
    required this.title,
    required this.owner,
    required this.created,
    required this.urgency,
    required this.progress,
    required this.summary,
  });
}

class BriefCentralScreen extends StatefulWidget {
  const BriefCentralScreen({super.key});

  @override
  State<BriefCentralScreen> createState() => _BriefCentralScreenState();
}

class _BriefCentralScreenState extends State<BriefCentralScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<BriefItem> _briefs = [
    BriefItem(
      id: '1',
      title: 'Infrastructure Scale-Up Framework',
      owner: 'Admin Office',
      created: DateTime.now().subtract(const Duration(days: 2)),
      urgency: 'Critical',
      progress: 0.85,
      summary: 'Upgrade load-balancer specifications and database index matrices to process million-scale datasets.',
    ),
    BriefItem(
      id: '2',
      title: 'Real-time WebSocket Latency Optimizations',
      owner: 'IT Operations',
      created: DateTime.now().subtract(const Duration(days: 5)),
      urgency: 'High',
      progress: 0.40,
      summary: 'Minimize messaging delays between microservices using compressed binary payloads.',
    ),
    BriefItem(
      id: '3',
      title: 'Authority Matrix Verification Security',
      owner: 'CEO Security Group',
      created: DateTime.now().subtract(const Duration(days: 8)),
      urgency: 'Medium',
      progress: 1.0,
      summary: 'Consolidate multiple super admin permissions structures into a unified access control layer.',
    ),
    BriefItem(
      id: '4',
      title: 'Multipurpose Media CDN Deployment',
      owner: 'Creative Devs',
      created: DateTime.now().subtract(const Duration(days: 12)),
      urgency: 'Low',
      progress: 0.15,
      summary: 'Optimize asset loading using automated edge cache strategies and fast regional replication.',
    ),
  ];

  List<BriefItem> get _filteredBriefs {
    if (_searchQuery.trim().isEmpty) return _briefs;
    return _briefs.where((b) {
      return b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.owner.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.summary.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'Critical':
        return Colors.redAccent;
      case 'High':
        return Colors.orangeAccent;
      case 'Medium':
        return Colors.blueAccent;
      case 'Low':
      default:
        return Colors.greenAccent;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primary = const Color(0xFF6366F1);
    final bgTop = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F8FF);
    final bgBottom = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEEEEFF);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgTop,
      body: Stack(
        children: [
          // Background Gradient and Glow Blob
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
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.06),
                boxShadow: [
                  BoxShadow(color: primary.withOpacity(0.06), blurRadius: 90, spreadRadius: 40),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Panel
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BRIEF CENTRAL',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                  letterSpacing: 1.5,
                                ),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                              const SizedBox(height: 6),
                              Text(
                                'Overview & Master Hub',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  height: 1.1,
                                ),
                              ).animate().fadeIn(delay: 100.ms, duration: 450.ms).slideY(begin: 0.15, end: 0),
                              const SizedBox(height: 6),
                              Text(
                                'Create, distribute, and track status metrics for organization brief cards.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                            ],
                          ),
                        ),
                        // Top Add Icon Action
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(IconsaxPlusBold.add_circle, color: Colors.white, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ).animate().fadeIn(delay: 150.ms).scale(begin: const Offset(0.8, 0.8)),
                      ],
                    ),
                  ),
                ),

                // Metrics Grid Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildMetricCard('Total', '${_briefs.length}', primary, isDark, IconsaxPlusBold.folder_open),
                        _buildMetricCard('Active', '${_briefs.where((b) => b.progress < 1.0 && b.progress > 0).length}', const Color(0xFF6366F1), isDark, IconsaxPlusBold.refresh_circle),
                        _buildMetricCard('Completed', '${_briefs.where((b) => b.progress >= 1.0).length}', const Color(0xFF10B981), isDark, IconsaxPlusBold.shield_tick),
                        _buildMetricCard('Queue', '${_briefs.where((b) => b.progress == 0.15).length}', const Color(0xFFF59E0B), isDark, IconsaxPlusBold.timer_1),
                      ],
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
                  ),
                ),

                // Search Bar Input
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.outfit(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          icon: Icon(IconsaxPlusLinear.search_normal, color: primary, size: 20),
                          hintText: 'Search briefs, creators, summaries...',
                          hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Brief List Headers
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Container(width: 4, height: 16, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Operations Briefs',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),

                // Brief Items List View
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  sliver: _filteredBriefs.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(IconsaxPlusLinear.close_circle, size: 40, color: isDark ? Colors.white24 : Colors.black26),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Brief Cards Found',
                                    style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _filteredBriefs[index];
                              return _buildBriefListItem(context, item, isDark, primary, textColor)
                                  .animate(delay: (index * 100).ms)
                                  .fadeIn(duration: 450.ms)
                                  .slideX(begin: 0.05, end: 0);
                            },
                            childCount: _filteredBriefs.length,
                          ),
                        ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, bool isDark, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefListItem(BuildContext context, BriefItem item, bool isDark, Color primary, Color textColor) {
    final urgencyColor = _getUrgencyColor(item.urgency);
    final dateStr = DateFormat('MMM dd').format(item.created);
    final progressPct = (item.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: urgencyColor.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  item.urgency.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: urgencyColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Sub-info Row
          Row(
            children: [
              Icon(IconsaxPlusLinear.user, size: 12, color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(width: 4),
              Text(
                'By: ${item.owner}  ·  $dateStr',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Summary Text
          Text(
            item.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Progress Row
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    valueColor: AlwaysStoppedAnimation<Color>(item.progress >= 1.0 ? const Color(0xFF10B981) : primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPct%',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: item.progress >= 1.0 ? const Color(0xFF10B981) : primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
