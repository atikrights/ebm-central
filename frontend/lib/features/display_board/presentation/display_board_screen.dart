import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../shared/widgets/glass_card.dart';

class DisplayBoardScreen extends StatefulWidget {
  const DisplayBoardScreen({super.key});

  @override
  State<DisplayBoardScreen> createState() => _DisplayBoardScreenState();
}

class _DisplayBoardScreenState extends State<DisplayBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background "Water Flow" effects
          Positioned.fill(child: _FluidBackground(isDark: isDark)),
          
          Column(
            children: [
              _buildTabBar(isDark, theme),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLivePage(),
                    _buildNotePage(),
                    _buildNoticePage(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'LIVE'),
          Tab(text: 'NOTE'),
          Tab(text: 'NOTICE'),
        ],
      ),
    );
  }

  Widget _buildLivePage() {
    return _WaterFlowQuotesBoard(
      type: 'Live',
      items: [
        QuoteItem(text: "The web as I envisaged it, we have not seen it yet. The future is still so much bigger than the past.", author: "Tim Berners-Lee", color: Colors.blueAccent, height: 220),
        QuoteItem(text: "Everything is designed. Few things are designed well.", author: "Brian Reed", color: Colors.purpleAccent, height: 180),
        QuoteItem(text: "The best way to predict the future is to create it.", author: "Peter Drucker", color: Colors.orangeAccent, height: 200),
        QuoteItem(text: "Design is thinking made visual.", author: "Saul Bass", color: Colors.cyanAccent, height: 240),
        QuoteItem(text: "Digital design is like painting, except the paint never dries.", author: "Neville Brody", color: Colors.greenAccent, height: 190),
        QuoteItem(text: "Simplicity is about subtracting the obvious and adding the meaningful.", author: "John Maeda", color: Colors.pinkAccent, height: 210),
      ],
    );
  }

  Widget _buildNotePage() {
    return _WaterFlowQuotesBoard(
      type: 'Note',
      items: [
        QuoteItem(text: "Good design is obvious. Great design is transparent.", author: "Joe Sparano", color: Colors.indigoAccent, height: 200),
        QuoteItem(text: "Content precedes design. Design in the absence of content is not design, it’s decoration.", author: "Jeffrey Zeldman", color: Colors.tealAccent, height: 250),
        QuoteItem(text: "Styles come and go. Good design is a language, not a style.", author: "Massimo Vignelli", color: Colors.amberAccent, height: 180),
        QuoteItem(text: "Design added value to our lives.", author: "Dieter Rams", color: Colors.deepPurpleAccent, height: 210),
      ],
    );
  }

  Widget _buildNoticePage() {
    return _WaterFlowQuotesBoard(
      type: 'Notice',
      items: [
        QuoteItem(text: "Public Notice: System upgrade is scheduled for tonight at midnight. Some services may be unavailable.", author: "Network Ops", color: Colors.redAccent, height: 230),
        QuoteItem(text: "New Workspace policy: Please ensure all project files are tagged with the appropriate department ID.", author: "Management", color: Colors.blueGrey, height: 210),
        QuoteItem(text: "Achievement: Our team has surpassed the Q1 targets by 15%. Celebration on Friday!", author: "Leadership", color: Colors.lightBlueAccent, height: 190),
      ],
    );
  }
}

class QuoteItem {
  final String text;
  final String author;
  final Color color;
  final double height;
  QuoteItem({required this.text, required this.author, required this.color, required this.height});
}

class _WaterFlowQuotesBoard extends StatelessWidget {
  final String type;
  final List<QuoteItem> items;

  const _WaterFlowQuotesBoard({required this.type, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
        final columnWidth = (constraints.maxWidth - (columnCount + 1) * 20) / columnCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columnCount, (columnIndex) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: items
                        .asMap()
                        .entries
                        .where((entry) => entry.key % columnCount == columnIndex)
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _QuoteCard(item: entry.value, index: entry.key),
                            ))
                        .toList(),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _QuoteCard extends StatefulWidget {
  final QuoteItem item;
  final int index;

  const _QuoteCard({required this.item, required this.index});

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _controller.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value * (_isHovered ? 1.03 : 1.0),
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_isHovered ? -0.05 : 0.0)
                    ..rotateY(_isHovered ? 0.05 : 0.0),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: GlassCard(
          child: Container(
            constraints: BoxConstraints(minHeight: widget.item.height),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.item.color.withOpacity(isDark ? 0.15 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -15,
                  right: -15,
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 80,
                    color: widget.item.color.withOpacity(0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(26.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.item.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: widget.item.color.withOpacity(0.3), width: 0.5),
                            ),
                            child: Row(
                              children: [
                                _PulseDot(color: widget.item.color),
                                const SizedBox(width: 8),
                                Text(
                                  "TRENDING",
                                  style: TextStyle(
                                    color: widget.item.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.more_vert, size: 18, color: widget.item.color.withOpacity(0.5)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.item.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                          fontSize: 16,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Spacer(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: widget.item.color.withOpacity(0.2),
                            child: Text(
                              widget.item.author[0],
                              style: TextStyle(color: widget.item.color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.item.author,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: widget.item.color.withOpacity(0.8),
                              ),
                            ),
                          ),
                          Icon(Icons.favorite_rounded, size: 16, color: widget.item.color.withOpacity(0.4)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: widget.item.color.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.5 + 0.5 * _ctrl.value),
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 4 * _ctrl.value, spreadRadius: 2 * _ctrl.value)],
        ),
      ),
    );
  }
}

class _FluidBackground extends StatelessWidget {
  final bool isDark;
  const _FluidBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.6),
          radius: 1.5,
          colors: [
            isDark ? const Color(0xFF1A1F2C).withOpacity(0.5) : const Color(0xFFE2E8F0).withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        children: [
          _FloatingBubble(color: Colors.blue.withOpacity(0.05), size: 300, top: -100, left: -50),
          _FloatingBubble(color: Colors.purple.withOpacity(0.05), size: 400, bottom: -150, right: -100),
        ],
      ),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, left, right, bottom;

  const _FloatingBubble({required this.color, required this.size, this.top, this.left, this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
