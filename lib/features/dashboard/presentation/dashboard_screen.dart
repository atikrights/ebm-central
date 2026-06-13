import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../chat/data/websocket_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/network/api_service.dart';
import '../../../core/auth/auth_provider.dart';

// FutureProvider to load scoped dashboard metrics
final dashboardMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/dashboard/metrics');
  if (response is Map<String, dynamic>) {
    return response;
  }
  throw Exception('Invalid metrics response format');
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Realtime metrics invalidation on WebSocket data updates
    ref.read(webSocketServiceProvider).addListener(_onWsEvent);

    // Fallback periodic refresh (every 15 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        ref.invalidate(dashboardMetricsProvider);
      }
    });
  }

  @override
  void dispose() {
    ref.read(webSocketServiceProvider).removeListener(_onWsEvent);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onWsEvent(PusherEvent event) {
    final name = event.eventName;
    // Invalidate metrics on any data change event or approval events
    final shouldRefresh = name.contains('data.updated') ||
        name.contains('company.updated') ||
        name.contains('category.updated') ||
        name.contains('project_updated') ||
        name.contains('task_updated') ||
        name.contains('plan_updated') ||
        name.contains('_approved'); // catches project_approved, task_approved, etc.
    if (shouldRefresh && mounted) {
      ref.invalidate(dashboardMetricsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: isDesktop ? 24.0 : 0.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0.0 : 24.0),
                  child: _buildHeader(context),
                ),
                const SizedBox(height: 28),
                // Metrics content row
                _buildMetricsContent(context, constraints),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authProvider);
    final userName = authState.name ?? 'Admin';
    final userRole = authState.role?.toUpperCase() ?? 'ADMIN';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 0.5),
                  ),
                  child: Text(
                    userRole,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Real-time workspace metrics',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Sync button
        IconButton(
          onPressed: () {
            ref.invalidate(dashboardMetricsProvider);
          },
          icon: Icon(
            Icons.sync,
            color: theme.colorScheme.primary,
          ),
          tooltip: 'Sync metrics',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsContent(BuildContext context, BoxConstraints constraints) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return metricsAsync.when(
      data: (data) => _buildCardRow(context, constraints, data),
      loading: () => _buildLoadingState(context, constraints),
      error: (err, stack) => _buildErrorState(context, err, stack),
    );
  }

  Widget _buildCardRow(BuildContext context, BoxConstraints constraints, Map<String, dynamic> data) {
    final double width = constraints.maxWidth;
    
    final bool isDesktop = width >= 1024;
    final bool isTablet = width >= 600 && width < 1024;
    final bool isMobile = width < 600;

    final cards = [
      _MetricCard(
        title: 'Total Company',
        value: '${data['total_company'] ?? 0}',
        icon: Icons.business,
        accentColor: Colors.blue,
        gradientColors: const [Colors.blue, Colors.lightBlue],
      ),
      _MetricCard(
        title: 'Pending Company',
        value: '${data['pending_company'] ?? 0}',
        icon: Icons.pending_actions,
        accentColor: Colors.orange,
        gradientColors: const [Colors.orange, Colors.amber],
      ),
      _MetricCard(
        title: 'Total Projects',
        value: '${data['total_projects'] ?? 0}',
        icon: Icons.assignment_outlined,
        accentColor: Colors.teal,
        gradientColors: const [Colors.teal, Colors.tealAccent],
      ),
      _MetricCard(
        title: 'Pending Projects',
        value: '${data['pending_projects'] ?? 0}',
        icon: Icons.assignment_late_outlined,
        accentColor: Colors.red,
        gradientColors: const [Colors.red, Colors.redAccent],
      ),
      _MetricCard(
        title: 'Total Plan',
        value: '${data['total_plans'] ?? 0}',
        icon: Icons.next_plan_outlined,
        accentColor: Colors.purple,
        gradientColors: const [Colors.purple, Colors.purpleAccent],
      ),
      _MetricCard(
        title: 'Total Tasks',
        value: '${data['total_tasks'] ?? 0}',
        icon: Icons.task_alt,
        accentColor: Colors.indigo,
        gradientColors: const [Colors.indigo, Colors.indigoAccent],
      ),
    ];

    if (isDesktop) {
      const double cardSpacing = 16.0;
      return Row(
        children: cards.map((card) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: cards.indexOf(card) == cards.length - 1 ? 0.0 : cardSpacing,
            ),
            child: card,
          ),
        )).toList(),
      );
    } else {
      final int visibleCount = isTablet ? 3 : 2;
      final double horizontalPadding = isTablet ? 24.0 : 16.0;
      final double cardSpacing = isTablet ? 16.0 : 12.0;
      
      final double cardWidth = (width - (horizontalPadding * 2) - (cardSpacing * (visibleCount - 1))) / visibleCount;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: cards.map((card) {
            final isLast = cards.indexOf(card) == cards.length - 1;
            return Container(
              width: cardWidth,
              margin: EdgeInsets.only(right: isLast ? 0 : cardSpacing),
              child: card,
            );
          }).toList(),
        ),
      );
    }
  }

  Widget _buildLoadingState(BuildContext context, BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final bool isDesktop = width >= 1024;
    final bool isTablet = width >= 600 && width < 1024;
    
    final int visibleCount = isDesktop ? 6 : (isTablet ? 3 : 2);
    final double horizontalPadding = isDesktop ? 0.0 : (isTablet ? 24.0 : 16.0);
    final double cardSpacing = isDesktop ? 16.0 : (isTablet ? 16.0 : 12.0);
    
    final double cardWidth = isDesktop 
        ? (width - (cardSpacing * 5)) / 6 
        : (width - (horizontalPadding * 2) - (cardSpacing * (visibleCount - 1))) / visibleCount;

    final List<Widget> skeletons = List.generate(6, (index) => GlassCard(
      padding: const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ));

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: skeletons.map((skeleton) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: skeletons.indexOf(skeleton) == 5 ? 0 : cardSpacing),
            child: skeleton,
          ),
        )).toList(),
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: skeletons.map((skeleton) {
            final isLast = skeletons.indexOf(skeleton) == skeletons.length - 1;
            return Container(
              width: cardWidth,
              margin: EdgeInsets.only(right: isLast ? 0 : cardSpacing),
              child: skeleton,
            );
          }).toList(),
        ),
      );
    }
  }

  Widget _buildErrorState(BuildContext context, Object error, StackTrace? stackTrace) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to sync metrics',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(dashboardMetricsProvider);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define background colors/gradients
    final List<Color> bgColors = isDark
        ? [
            const Color(0xFF1F222A).withOpacity(0.85),
            const Color(0xFF14151B).withOpacity(0.85),
          ]
        : [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ];

    // Define border color
    final borderColor = isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.black.withOpacity(0.06);

    // Define dual-layered shadows (base soft shadow + accent colored glow)
    final List<BoxShadow> shadows = [
      BoxShadow(
        color: isDark 
            ? Colors.black.withOpacity(_isHovered ? 0.45 : 0.3) 
            : Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
        blurRadius: _isHovered ? 24.0 : 16.0,
        offset: Offset(0, _isHovered ? 12.0 : 6.0),
      ),
      BoxShadow(
        color: widget.accentColor.withOpacity(_isHovered 
            ? (isDark ? 0.18 : 0.12) 
            : (isDark ? 0.03 : 0.01)),
        blurRadius: _isHovered ? 20.0 : 12.0,
        offset: Offset(0, _isHovered ? 8.0 : 4.0),
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bgColors,
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradientColors.map((c) => c.withOpacity(isDark ? 0.18 : 0.12)).toList(),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 20,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isHovered ? widget.accentColor : Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: widget.accentColor,
                                      blurRadius: 4,
                                    )
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
