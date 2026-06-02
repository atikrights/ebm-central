import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

// --- INLINE MODELS ---
enum NoticePriority { low, medium, high, urgent }

class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String author;
  final DateTime date;
  final NoticePriority priority;
  final IconData icon;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.date,
    this.priority = NoticePriority.medium,
    this.icon = Icons.notifications_active_rounded,
  });
}

enum NoteStatus { active, archived, draft }

class NoteModel {
  final String id;
  final String title;
  final String content;
  final Color color;
  final DateTime date;
  final bool isPinned;
  final NoteStatus status;
  final String author;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    required this.date,
    this.isPinned = false,
    this.status = NoteStatus.active,
    this.author = 'Unknown',
  });
}

// --- DUMMY DATA ---
final List<NoticeModel> dummyNotices = [
  NoticeModel(
    id: '1',
    title: 'New Headquarters Opening',
    content: 'We are excited to announce the opening of our new regional headquarters in the downtown business district. All staff are invited for the inauguration ceremony next Monday at 10:00 AM.',
    author: 'Admin Office',
    date: DateTime.now().subtract(const Duration(hours: 2)),
    priority: NoticePriority.high,
    icon: Icons.business_rounded,
  ),
  NoticeModel(
    id: '2',
    title: 'Salary & Bonus Update',
    content: 'The performance bonuses for the last quarter have been processed. Please check your personal dashboards for the breakdown. The amounts will reflect in your bank accounts by Friday.',
    author: 'HR Department',
    date: DateTime.now().subtract(const Duration(days: 1)),
    priority: NoticePriority.urgent,
    icon: Icons.account_balance_wallet_rounded,
  ),
  NoticeModel(
    id: '3',
    title: 'System Maintenance',
    content: 'The eBM system will undergo routine maintenance this Sunday starting from 12:00 AM for 4 hours. Access to project modules may be limited during this period.',
    author: 'IT Support',
    date: DateTime.now().subtract(const Duration(days: 3)),
    priority: NoticePriority.medium,
    icon: Icons.settings_suggest_rounded,
  ),
  NoticeModel(
    id: '4',
    title: 'Quarterly Review Meeting',
    content: 'The Q2 performance review meeting is scheduled for next Wednesday. Department heads are requested to prepare their presentations by Tuesday afternoon.',
    author: 'CEO Office',
    date: DateTime.now().subtract(const Duration(days: 5)),
    priority: NoticePriority.high,
    icon: Icons.groups_rounded,
  ),
];

final List<NoteModel> globalNotes = [
  NoteModel(
    id: '1',
    title: 'Project Strategy',
    content: 'Focus on implementing the new admin dashboard with real-time analytics. Ensure the UI is dynamic.',
    color: const Color(0xFFFFF475),
    date: DateTime.now(),
    isPinned: true,
    author: 'Admin Office',
  ),
];

// --- SCREEN WIDGET ---
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final ScrollController _pinnedScrollController = ScrollController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _pinnedScrollController.dispose();
    super.dispose();
  }

  void _applyFilter(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    if (_pinnedScrollController.hasClients) {
      _pinnedScrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    }
  }

  void _showFilterDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _FilterPopup(
               isDark: isDark, 
               initialStart: _startDate, 
               initialEnd: _endDate,
               onApply: (s, e) {
                 Navigator.pop(context);
                 _applyFilter(s, e);
               }
            ),
          ),
        );
      }
    );
  }

  List<NoteModel> get _getPinnedNotices {
    var list = globalNotes.where((n) => n.isPinned).toList();
    if (_startDate != null) list = list.where((n) => n.date.isAfter(_startDate!)).toList();
    if (_endDate != null) list = list.where((n) => n.date.isBefore(_endDate!)).toList();
    return list.isEmpty ? globalNotes.where((n) => n.isPinned).take(1).toList() : list; 
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Tooltip(
              message: "Filter Notices by Date",
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showFilterDialog(isDark),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(IconsaxPlusLinear.calendar_search, size: 20, color: isDark ? Colors.white : Colors.black87),
                        if (_startDate != null || _endDate != null) ...[
                          const SizedBox(width: 8),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // HERO SECTION WITH 3D PIN
          SliverToBoxAdapter(
            child: _buildHeroSection(context, isDark, isDesktop),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // SECTION TITLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Text("Recent Activity", 
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                  const Spacer(),
                  Text("${dummyNotices.length} Notices", 
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // UNLIMITED NOTICE LIST
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final notice = dummyNotices[index];
                  return _buildNoticeCard(context, notice, isDark)
                      .animate(delay: (index * 100).ms)
                      .fadeIn(duration: 500.ms)
                      .slideX(begin: 0.1, end: 0);
                },
                childCount: dummyNotices.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDark, bool isDesktop) {
    final pinnedNotices = _getPinnedNotices;
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth < 400
        ? screenWidth * 0.62
        : screenWidth < 700
            ? 210
            : isDesktop
                ? 240
                : 220;
    final double sectionHeight = screenWidth < 400 ? 240 : isDesktop ? 280 : 260;

    final List<List<Color>> cardPalettes = [
      [const Color(0xFF2D1B69), const Color(0xFF4A2080)],   // Deep violet
      [const Color(0xFF1A3A4A), const Color(0xFF1D5166)],   // Deep teal
      [const Color(0xFF3D1A1A), const Color(0xFF5C2020)],   // Deep rose
      [const Color(0xFF1A3D27), const Color(0xFF1B5C38)],   // Deep emerald
      [const Color(0xFF3D2E1A), const Color(0xFF5C4520)],   // Deep amber
    ];
    final List<List<Color>> cardPalettesLight = [
      [const Color(0xFFEDE7F6), const Color(0xFFF3E5F5)],   // Lavender
      [const Color(0xFFE0F7FA), const Color(0xFFE3F2FD)],   // Cyan-Blue
      [const Color(0xFFFFEBEE), const Color(0xFFFCE4EC)],   // Rose
      [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],   // Mint
      [const Color(0xFFFFF8E1), const Color(0xFFFFF3E0)],   // Amber
    ];

    return SizedBox(
      height: sectionHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 40, left: 0, right: 0,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  isDark ? Colors.white30 : Colors.black26,
                  isDark ? Colors.white30 : Colors.black26,
                  Colors.transparent,
                ]),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 2)],
              ),
            ),
          ),

          Positioned.fill(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
              ),
              child: ListView.builder(
                controller: _pinnedScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 16 : 24),
                itemCount: pinnedNotices.length,
                itemBuilder: (context, index) {
                  final notice = pinnedNotices[index];
                  final double rotation = index % 2 == 0 ? 0.018 : -0.012;
                  final palette = isDark
                      ? cardPalettes[index % cardPalettes.length]
                      : cardPalettesLight[index % cardPalettesLight.length];

                  final Color textColor = isDark ? Colors.white : Colors.black87;
                  final String dateStr = DateFormat('MMM dd, hh:mm a').format(notice.date);

                  return SizedBox(
                    width: cardWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 45, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                width: 1.5, height: 35,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white30 : Colors.black26,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 31, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [palette[0].withOpacity(0.95), palette[1]]
                                        : [Colors.white, const Color(0xFFF5F5F5)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08), width: 0.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person, size: 10, color: isDark ? Colors.white60 : Colors.black45),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${notice.author}  ·  $dateStr',
                                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 75, left: 4, right: 4, bottom: 24,
                            child: _HoverAnimatedPinCard(
                              notice: notice,
                              rotation: rotation,
                              paperColor: palette[0],
                              textColor: textColor,
                              isDesktop: isDesktop,
                              theme: Theme.of(context),
                              cardGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [palette[0], palette[1]],
                              ),
                            ),
                          ),

                          Positioned(
                            top: 54, left: 0, right: 0,
                            child: Center(
                              child: Transform.rotate(
                                angle: index % 2 == 0 ? 0.35 : -0.25,
                                alignment: Alignment.bottomCenter,
                                child: const Text('📍', style: TextStyle(fontSize: 30))
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .moveY(begin: -1.0, end: 1.0, duration: 2.5.seconds, curve: Curves.easeInOut)
                                    .shake(hz: 0.5, rotation: 0.02),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, NoticeModel notice, bool isDark) {
    final theme = Theme.of(context);
    final priorityColor = _getPriorityColor(notice.priority);
    final dateStr = DateFormat('MMM dd, yyyy · hh:mm a').format(notice.date);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileNotice = screenWidth < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobileNotice ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6)),
          if (isDark) BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [priorityColor, priorityColor.withOpacity(0.4)],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isMobileNotice ? 14 : 18, 16, isMobileNotice ? 14 : 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [priorityColor.withOpacity(0.2), priorityColor.withOpacity(0.08)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: priorityColor.withOpacity(0.3), width: 0.5),
                            ),
                            child: Icon(notice.icon, size: isMobileNotice ? 18 : 20, color: priorityColor),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobileNotice ? 14 : 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _buildPriorityBadge(notice.priority),
                        ],
                      ),

                      const SizedBox(height: 13),

                      Text(
                        notice.content,
                        style: GoogleFonts.outfit(
                          fontSize: isMobileNotice ? 12.5 : 13,
                          height: 1.65,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 14),

                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            priorityColor.withOpacity(0.3),
                            priorityColor.withOpacity(0.05),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Container(
                            height: 24,
                            width: 24,
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: priorityColor.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Text(
                                notice.author.isNotEmpty ? notice.author[0].toUpperCase() : 'E',
                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: priorityColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Issued by: ${notice.author}',
                              style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [priorityColor.withOpacity(0.15), priorityColor.withOpacity(0.06)]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: priorityColor.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Read', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: priorityColor)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: priorityColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(NoticePriority priority) {
    Color color = _getPriorityColor(priority);
    String label = priority.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
    );
  }

  Color _getPriorityColor(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.urgent: return Colors.redAccent;
      case NoticePriority.high:   return Colors.orangeAccent;
      case NoticePriority.medium: return Colors.blueAccent;
      case NoticePriority.low:    return Colors.greenAccent;
    }
  }
}

// --- FILTER POPUP ---
class _FilterPopup extends StatefulWidget {
  final bool isDark;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final Function(DateTime?, DateTime?) onApply;

  const _FilterPopup({required this.isDark, required this.initialStart, required this.initialEnd, required this.onApply});

  @override
  State<_FilterPopup> createState() => _FilterPopupState();
}

class _FilterPopupState extends State<_FilterPopup> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark 
              ? const ColorScheme.dark(primary: Colors.redAccent, surface: Color(0xFF1E1E2C)) 
              : const ColorScheme.light(primary: Colors.redAccent, surface: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        if (isStart) _start = date;
        else _end = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF16161E).withOpacity(0.85) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(IconsaxPlusBold.calendar_1, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Text("Filter Notices", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 32),
          Text("START DATE", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: textColor.withOpacity(0.5), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _buildDateField(_start, () => _pickDate(true), textColor),
          const SizedBox(height: 24),
          Text("END DATE", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: textColor.withOpacity(0.5), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _buildDateField(_end, () => _pickDate(false), textColor),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() { _start = null; _end = null; });
                    widget.onApply(null, null);
                  },
                  child: Text("Clear", style: GoogleFonts.outfit(color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onApply(_start, _end),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text("Apply Filter", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDateField(DateTime? date, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(IconsaxPlusLinear.calendar, size: 18, color: textColor.withOpacity(0.7)),
            const SizedBox(width: 12),
            Text(
              date != null ? DateFormat('MMMM dd, yyyy').format(date) : "Select date...",
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: date != null ? textColor : textColor.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HOVER ANIMATED PIN CARD ---
class _HoverAnimatedPinCard extends StatefulWidget {
  final NoteModel notice;
  final double rotation;
  final Color paperColor;
  final Color textColor;
  final bool isDesktop;
  final ThemeData theme;
  final LinearGradient? cardGradient;

  const _HoverAnimatedPinCard({
    required this.notice,
    required this.rotation,
    required this.paperColor,
    required this.textColor,
    required this.isDesktop,
    required this.theme,
    this.cardGradient,
  });

  @override
  State<_HoverAnimatedPinCard> createState() => _HoverAnimatedPinCardState();
}

class _HoverAnimatedPinCardState extends State<_HoverAnimatedPinCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;
    final bool isLightCard = widget.paperColor.computeLuminance() > 0.4;
    final Color bodyTextColor = isLightCard ? Colors.black87 : Colors.white;
    final Color subTextColor = isLightCard ? Colors.black54 : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Transform.rotate(
        angle: widget.rotation,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _isHovered ? 1.0 : 0.0,
                child: AnimatedBuilder(
                  animation: _borderController,
                  builder: (_, __) => ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: SweepGradient(
                          center: FractionalOffset.center,
                          colors: [
                            widget.paperColor.withOpacity(0.5),
                            widget.theme.primaryColor.withOpacity(0.35),
                            Colors.purpleAccent.withOpacity(0.3),
                            widget.paperColor.withOpacity(0.5),
                          ],
                          stops: const [0.0, 0.33, 0.66, 1.0],
                          transform: GradientRotation(_borderController.value * 2 * 3.1415926535),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: widget.cardGradient,
                  color: widget.cardGradient == null ? widget.paperColor : null,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    width: 1.0,
                  ),
                  boxShadow: isDark ? [
                    BoxShadow(
                      color: widget.paperColor.withOpacity(_isHovered ? 0.3 : 0.18),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: const Offset(0, 4),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.6 : 0.4),
                      blurRadius: _isHovered ? 20 : 10,
                      offset: Offset(0, _isHovered ? 10 : 5),
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.18),
                      blurRadius: _isHovered ? 4 : 2,
                      offset: Offset(0, _isHovered ? 2 : 1),
                    ),
                  ] : [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.05 : 0.03),
                      blurRadius: _isHovered ? 32 : 20,
                      offset: Offset(0, _isHovered ? 14 : 8),
                      spreadRadius: -3,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.09 : 0.06),
                      blurRadius: _isHovered ? 14 : 8,
                      offset: Offset(0, _isHovered ? 7 : 4),
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.07 : 0.045),
                      blurRadius: _isHovered ? 3 : 2,
                      offset: Offset(0, _isHovered ? 2 : 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 14, 13, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                                ),
                                child: Text(
                                  '📌 PINNED',
                                  style: GoogleFonts.outfit(
                                    color: isDark ? const Color(0xFFFF8A80) : Colors.redAccent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                widget.notice.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: widget.isDesktop ? 14 : 13,
                                  fontWeight: FontWeight.w800,
                                  color: bodyTextColor,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),

                              Expanded(
                                child: Text(
                                  widget.notice.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subTextColor,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.05 : 0.35), width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 18,
                              width: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
                              ),
                              child: Center(
                                child: Text(
                                  widget.notice.author.isNotEmpty ? widget.notice.author[0].toUpperCase() : 'E',
                                  style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: bodyTextColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                widget.notice.author,
                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: subTextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      AnimatedBuilder(
                        animation: _borderController,
                        builder: (_, __) => Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3)),
                            gradient: LinearGradient(
                              colors: [
                                widget.theme.primaryColor.withOpacity(_isHovered ? 0.9 : 0.5),
                                Colors.purpleAccent.withOpacity(_isHovered ? 0.8 : 0.4),
                                widget.paperColor.withOpacity(_isHovered ? 0.9 : 0.5),
                                widget.theme.primaryColor.withOpacity(_isHovered ? 0.9 : 0.5),
                              ],
                              stops: [
                                0.0,
                                _borderController.value.clamp(0.1, 0.45),
                                (_borderController.value + 0.3).clamp(0.5, 0.9),
                                1.0,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
