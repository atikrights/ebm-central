import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// --- Shared Premium Widgets & Utilities ---

class DashboardColors {
  static const Color primary = Color(0xFF0061FF);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color purple = Color(0xFF9C27B0);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color teal = Color(0xFF009688);
  static const Color orange = Color(0xFFFF5722);
}

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final bool isUp;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.trend,
    required this.isUp,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Switch to compact column layout on very narrow cards
          final isNarrow = constraints.maxWidth < 150;
          if (isNarrow) {
            // Compact vertical layout for small screens
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87)),
                ),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 9,
                    color: isDark ? Colors.white54 : Colors.black54)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10, color: isUp ? DashboardColors.success : DashboardColors.error),
                    Text(trend, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                      color: isUp ? DashboardColors.success : DashboardColors.error)),
                  ],
                ),
              ],
            );
          }
          // Standard horizontal layout
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black54),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87)),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isUp ? DashboardColors.success : DashboardColors.error, size: 11),
                          const SizedBox(width: 3),
                          Text(trend, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                            color: isUp ? DashboardColors.success : DashboardColors.error)),
                          const SizedBox(width: 3),
                          Text('vs last month', style: GoogleFonts.inter(fontSize: 9,
                            color: isDark ? Colors.white38 : Colors.black38)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// --- Specific Dashboard Screens ---

class RecentActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const RecentActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionTable extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const TransactionTable({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          ),
          children: [
            'Description', 'Category', 'Amount', 'Status'
          ].map((h) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(h, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54)),
          )).toList(),
        ),
        ...transactions.map((t) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t['desc'], style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t['cat'], style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t['amount'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: t['isExpense'] ? DashboardColors.error : DashboardColors.success)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DashboardColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Completed', style: GoogleFonts.inter(fontSize: 10, color: DashboardColors.success, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )).toList(),
      ],
    );
  }
}

// --- Specific Dashboard Screens ---

/// 1. REAL TIME DASHBOARD
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Real Time Dashboard',
      stats: [
        StatCard(
          label: 'All Company',
          value: '${_companies.length}',
          trend: '100%',
          isUp: true,
          icon: Icons.business_rounded,
          color: DashboardColors.primary,
        ),
        const StatCard(
          label: 'Total Projects',
          value: '25',
          trend: '20%',
          isUp: true,
          icon: Icons.folder_copy_outlined,
          color: DashboardColors.success,
        ),
        const StatCard(
          label: 'Total Budget',
          value: '\$2,450,000',
          trend: '15%',
          isUp: true,
          icon: Icons.monetization_on_outlined,
          color: DashboardColors.info,
        ),
        const StatCard(
          label: 'Total Expense',
          value: '\$1,320,000',
          trend: '10%',
          isUp: false,
          icon: Icons.trending_down_rounded,
          color: DashboardColors.error,
        ),
        const StatCard(
          label: 'Total Income',
          value: '\$3,750,000',
          trend: '22%',
          isUp: true,
          icon: Icons.payments_rounded,
          color: DashboardColors.teal,
        ),
        const StatCard(
          label: 'Total Balance',
          value: '\$2,430,000',
          trend: '12%',
          isUp: true,
          icon: Icons.account_balance_wallet_rounded,
          color: DashboardColors.indigo,
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Desktop: side-by-side | Tablet/Mobile: stacked
            final isDesktop = constraints.maxWidth > 1024;
            return isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 65, child: _buildLeftBox(context)),
                    const SizedBox(width: 20),
                    Expanded(flex: 35, child: _buildRightBox(context)),
                  ],
                )
              : Column(
                  children: [
                    _buildLeftBox(context),
                    const SizedBox(height: 20),
                    _buildRightBox(context),
                  ],
                );
          },
        ),
      ],
    );
  }

  // ─── Shared constants ───────────────────────────────────────────────────────
  static const double _kChartHeight = 230.0;
  static const double _kRowHeight = 68.0;

  // ─── Single source of truth for all companies ────────────────────────────
  // To add a new company, simply add a new _CompanyData entry here.
  // Both the left (growth) and right (financials) boxes auto-update.
  static const List<_CompanyData> _companies = [
    _CompanyData(name: 'EBM Tech Solutions', domain: 'IT & Software',
      color: DashboardColors.primary, budget: '\$1,200,000', growth: '+24.5%', isUp: true,
      income: '\$450k', expense: '\$210k', profit: '\$240k'),
    _CompanyData(name: 'EBM Agro Farms', domain: 'Agriculture',
      color: DashboardColors.success, budget: '\$850,000', growth: '+18.2%', isUp: true,
      income: '\$320k', expense: '\$180k', profit: '\$140k'),
    _CompanyData(name: 'EBM Real Estate', domain: 'Property',
      color: DashboardColors.error, budget: '\$2,100,000', growth: '-4.1%', isUp: false,
      income: '\$890k', expense: '\$550k', profit: '\$340k'),
    _CompanyData(name: 'EBM Logistics', domain: 'Transport',
      color: DashboardColors.info, budget: '\$640,000', growth: '+8.7%', isUp: true,
      income: '\$280k', expense: '\$120k', profit: '\$160k'),
  ];

  Widget _buildLeftBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Company Growth & Competition',
            subtitle: 'Live tracker for budget and overall growth',
            trailing: _LiveBadge(),
          ),
          const SizedBox(height: 20),
          // Chart — fixed shared height
          SizedBox(
            height: _kChartHeight,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: _companies.asMap().entries.map((entry) {
                  final index = entry.key;
                  final company = entry.value;
                  // Pre-defined elegant paths for the live tracker
                  final paths = [
                    const [FlSpot(0, 40), FlSpot(1, 60), FlSpot(2, 55), FlSpot(3, 80), FlSpot(4, 75), FlSpot(5, 100)],
                    const [FlSpot(0, 20), FlSpot(1, 30), FlSpot(2, 45), FlSpot(3, 40), FlSpot(4, 60), FlSpot(5, 85)],
                    const [FlSpot(0, 70), FlSpot(1, 65), FlSpot(2, 80), FlSpot(3, 75), FlSpot(4, 90), FlSpot(5, 85)],
                    const [FlSpot(0, 50), FlSpot(1, 45), FlSpot(2, 60), FlSpot(3, 55), FlSpot(4, 70), FlSpot(5, 65)],
                  ];
                  final spots = paths[index % paths.length];
                  return LineChartBarData(
                    spots: spots,
                    isCurved: true, 
                    color: company.color, 
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: index == 0 
                      ? BarAreaData(show: true, color: company.color.withValues(alpha: 0.08))
                      : BarAreaData(show: false),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 8),
          // Auto-generated from _companies list
          ..._companies.map((c) => _buildCompanyRow(context, c.name, c.domain, c.color, c.budget, c.growth, c.isUp)),
        ],
      ),
    );
  }

  Widget _buildCompanyRow(BuildContext context, String name, String domain, Color color, String budget, String growth, bool isUp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _kRowHeight,
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.business_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  ],
                ),
                Text(domain, style: GoogleFonts.inter(fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Budget', style: GoogleFonts.inter(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38)),
              Text(budget, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: (isUp ? DashboardColors.success : DashboardColors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10, color: isUp ? DashboardColors.success : DashboardColors.error),
                const SizedBox(width: 3),
                Text(growth, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                  color: isUp ? DashboardColors.success : DashboardColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row matching left box structure
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income vs Expense',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text('All companies combined financials',
                      style: GoogleFonts.inter(fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
              _ChartLegendDot(color: DashboardColors.success, label: 'Income'),
              const SizedBox(width: 12),
              _ChartLegendDot(color: DashboardColors.error, label: 'Expense'),
            ],
          ),
          const SizedBox(height: 20),
          // Income vs Expense Chart — exact same height as left chart
          SizedBox(
            height: _kChartHeight,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.inter(fontSize: 9,
                          color: isDark ? Colors.white30 : Colors.black38),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.inter(fontSize: 9,
                          color: isDark ? Colors.white30 : Colors.black38),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income line (green)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 100), FlSpot(1, 120), FlSpot(2, 115),
                      FlSpot(3, 130), FlSpot(4, 125), FlSpot(5, 150),
                    ],
                    isCurved: true,
                    color: DashboardColors.success,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(radius: 3, color: DashboardColors.success, strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: DashboardColors.success.withValues(alpha: 0.08),
                    ),
                  ),
                  // Expense line (red)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 80), FlSpot(1, 88), FlSpot(2, 92),
                      FlSpot(3, 85), FlSpot(4, 90), FlSpot(5, 100),
                    ],
                    isCurved: true,
                    color: DashboardColors.error,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(radius: 3, color: DashboardColors.error, strokeWidth: 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 8),
          // Auto-generated from _companies list — stays in sync with left box
          ..._companies.map((c) => _buildFinRow(context, c.income, c.expense, c.profit)),
        ],
      ),
    );
  }

  Widget _buildFinRow(BuildContext context, String income, String expense, String profit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _kRowHeight,
      child: Row(
        children: [
          Expanded(child: _FinBlock('Income', income, DashboardColors.success, isDark)),
          Container(width: 1, height: 32, color: isDark ? Colors.white12 : Colors.black12),
          Expanded(child: _FinBlock('Expense', expense, DashboardColors.error, isDark)),
          Container(width: 1, height: 32, color: isDark ? Colors.white12 : Colors.black12),
          Expanded(child: _FinBlock('Profit', profit, DashboardColors.primary, isDark)),
        ],
      ),
    );
  }
}

/// Data model for a single EBM company entry.
/// Adding a new [_CompanyData] to [OverviewScreen._companies] auto-updates
/// both the left Growth box and the right Financials box.
class _CompanyData {
  final String name;
  final String domain;
  final Color color;
  final String budget;
  final String growth;
  final bool isUp;
  final String income;
  final String expense;
  final String profit;

  const _CompanyData({
    required this.name,
    required this.domain,
    required this.color,
    required this.budget,
    required this.growth,
    required this.isUp,
    required this.income,
    required this.expense,
    required this.profit,
  });
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(
          fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DashboardColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardColors.error.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: DashboardColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: DashboardColors.error,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}


class _FinBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _FinBlock(this.label, this.value, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// 2. FINANCE DASHBOARD (Analytics Dashboard in Sidebar)
class OverviewAnalyticsScreen extends StatelessWidget {
  const OverviewAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Finance Dashboard',
      stats: const [
        StatCard(
          label: 'Total Income',
          value: '\$2,450,000',
          trend: '20%',
          isUp: true,
          icon: Icons.attach_money,
          color: DashboardColors.success,
        ),
        StatCard(
          label: 'Total Expense',
          value: '\$1,320,000',
          trend: '15%',
          isUp: true,
          icon: Icons.trending_down,
          color: DashboardColors.error,
        ),
        StatCard(
          label: 'Net Profit',
          value: '\$1,130,000',
          trend: '25%',
          isUp: true,
          icon: Icons.account_balance_wallet_outlined,
          color: DashboardColors.info,
        ),
        StatCard(
          label: 'Total Accounts',
          value: '18',
          trend: '8%',
          isUp: true,
          icon: Icons.account_balance_outlined,
          color: DashboardColors.warning,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Income vs Expense'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [FlSpot(0, 100), FlSpot(1, 120), FlSpot(2, 110), FlSpot(3, 150)],
                              color: DashboardColors.success,
                              isCurved: true,
                              barWidth: 3,
                            ),
                            LineChartBarData(
                              spots: const [FlSpot(0, 80), FlSpot(1, 90), FlSpot(2, 85), FlSpot(3, 100)],
                              color: DashboardColors.error,
                              isCurved: true,
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Cash Flow Overview'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 12, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 6, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: DashboardColors.primary)]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 3. TASKS DASHBOARD (Operations Dashboard in Sidebar)
class OverviewOperationsScreen extends StatelessWidget {
  const OverviewOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Tasks Dashboard',
      stats: const [
        StatCard(
          label: 'Total Tasks',
          value: '320',
          trend: '18%',
          isUp: true,
          icon: Icons.task_alt,
          color: DashboardColors.primary,
        ),
        StatCard(
          label: 'Completed Tasks',
          value: '150',
          trend: '20%',
          isUp: true,
          icon: Icons.check_circle,
          color: DashboardColors.success,
        ),
        StatCard(
          label: 'Pending Tasks',
          value: '80',
          trend: '5%',
          isUp: false,
          icon: Icons.pending_actions,
          color: DashboardColors.warning,
        ),
        StatCard(
          label: 'Overdue Tasks',
          value: '30',
          trend: '15%',
          isUp: true,
          icon: Icons.error_outline,
          color: DashboardColors.error,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Tasks Priority'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(value: 80, color: DashboardColors.error, title: 'High', radius: 60),
                            PieChartSectionData(value: 160, color: DashboardColors.warning, title: 'Medium', radius: 60),
                            PieChartSectionData(value: 80, color: DashboardColors.success, title: 'Low', radius: 60),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Tasks Progress'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [FlSpot(0, 10), FlSpot(1, 15), FlSpot(2, 12), FlSpot(3, 20)],
                              color: DashboardColors.primary,
                              isCurved: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 4. PROJECTS DASHBOARD (Security Dashboard in Sidebar)
class OverviewSecurityScreen extends StatelessWidget {
  const OverviewSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Projects Dashboard',
      stats: const [
        StatCard(
          label: 'Total Projects',
          value: '25',
          trend: '20%',
          isUp: true,
          icon: Icons.folder_open,
          color: DashboardColors.primary,
        ),
        StatCard(
          label: 'Active Projects',
          value: '12',
          trend: '25%',
          isUp: true,
          icon: Icons.play_circle_outline,
          color: DashboardColors.success,
        ),
        StatCard(
          label: 'Completed Projects',
          value: '8',
          trend: '14%',
          isUp: true,
          icon: Icons.check_circle_outline,
          color: DashboardColors.purple,
        ),
        StatCard(
          label: 'Total Budget',
          value: '\$2,450,000',
          trend: '18%',
          isUp: true,
          icon: Icons.monetization_on_outlined,
          color: DashboardColors.info,
        ),
      ],
      children: [
        DashboardCard(
          child: Column(
            children: [
              const SectionHeader(title: 'Project Progress Overview'),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [FlSpot(0, 45), FlSpot(1, 50), FlSpot(2, 55), FlSpot(3, 60), FlSpot(4, 65), FlSpot(5, 70)],
                        color: DashboardColors.primary,
                        isCurved: true,
                        belowBarData: BarAreaData(show: true, color: DashboardColors.primary.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5. TRANSPORT & LOGISTICS DASHBOARD (Efficiency Dashboard in Sidebar)
class OverviewEfficiencyScreen extends StatelessWidget {
  const OverviewEfficiencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Transport & Logistics',
      stats: const [
        StatCard(
          label: 'Total Shipments',
          value: '2,450',
          trend: '12.5%',
          isUp: true,
          icon: Icons.local_shipping_outlined,
          color: DashboardColors.primary,
        ),
        StatCard(
          label: 'Delivered',
          value: '2,150',
          trend: '87.8%',
          isUp: true,
          icon: Icons.done_all,
          color: DashboardColors.success,
        ),
        StatCard(
          label: 'In Transit',
          value: '210',
          trend: '8.6%',
          isUp: true,
          icon: Icons.sync,
          color: DashboardColors.warning,
        ),
        StatCard(
          label: 'Net Profit',
          value: '\$260,450',
          trend: '19.2%',
          isUp: true,
          icon: Icons.attach_money,
          color: DashboardColors.teal,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Shipment Overview'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [FlSpot(0, 100), FlSpot(1, 150), FlSpot(2, 130), FlSpot(3, 180)],
                              color: DashboardColors.primary,
                              isCurved: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: DashboardCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Revenue Overview'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 280, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 310, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 360, color: DashboardColors.primary)]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 390, color: DashboardColors.primary)]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 6. INVENTORY DASHBOARD (Bandwidth Dashboard in Sidebar)
class OverviewBandwidthScreen extends StatelessWidget {
  const OverviewBandwidthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'Inventory Dashboard',
      stats: const [
        StatCard(
          label: 'Total Stock',
          value: '12,450',
          trend: '5%',
          isUp: true,
          icon: Icons.inventory_2_outlined,
          color: DashboardColors.indigo,
        ),
        StatCard(
          label: 'Low Stock',
          value: '42',
          trend: '12%',
          isUp: true,
          icon: Icons.warning_amber_rounded,
          color: DashboardColors.warning,
        ),
        StatCard(
          label: 'Out of Stock',
          value: '8',
          trend: '2%',
          isUp: false,
          icon: Icons.error_outline,
          color: DashboardColors.error,
        ),
        StatCard(
          label: 'Inventory Value',
          value: '\$850,000',
          trend: '10%',
          isUp: true,
          icon: Icons.payments_outlined,
          color: DashboardColors.success,
        ),
      ],
      children: [
        DashboardCard(
          child: Column(
            children: [
              const SectionHeader(title: 'Stock Movement'),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 100, color: DashboardColors.indigo)]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 150, color: DashboardColors.indigo)]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 120, color: DashboardColors.indigo)]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 180, color: DashboardColors.indigo)]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 7. HRM DASHBOARD (Audit Dashboard in Sidebar)
class OverviewAuditScreen extends StatelessWidget {
  const OverviewAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDashboard(
      title: 'HRM Dashboard',
      stats: const [
        StatCard(
          label: 'Total Employees',
          value: '156',
          trend: '4%',
          isUp: true,
          icon: Icons.people_outline,
          color: DashboardColors.teal,
        ),
        StatCard(
          label: 'Attendance',
          value: '94%',
          trend: '2%',
          isUp: true,
          icon: Icons.how_to_reg_outlined,
          color: DashboardColors.success,
        ),
        StatCard(
          label: 'Leave Requests',
          value: '12',
          trend: '5%',
          isUp: false,
          icon: Icons.event_busy_outlined,
          color: DashboardColors.warning,
        ),
        StatCard(
          label: 'Open Positions',
          value: '5',
          trend: '1%',
          isUp: true,
          icon: Icons.work_outline,
          color: DashboardColors.info,
        ),
      ],
      children: [
        DashboardCard(
          child: Column(
            children: [
              const SectionHeader(title: 'Department Distribution'),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(value: 40, color: DashboardColors.teal, title: 'Eng', radius: 60),
                      PieChartSectionData(value: 30, color: DashboardColors.indigo, title: 'Sales', radius: 60),
                      PieChartSectionData(value: 20, color: DashboardColors.purple, title: 'HR', radius: 60),
                      PieChartSectionData(value: 10, color: DashboardColors.orange, title: 'Other', radius: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Base Dashboard Layout ---

class _BaseDashboard extends StatefulWidget {
  final String title;
  final List<StatCard> stats;
  final List<Widget> children;

  const _BaseDashboard({
    required this.title,
    required this.stats,
    required this.children,
  });

  @override
  State<_BaseDashboard> createState() => _BaseDashboardState();
}

class _BaseDashboardState extends State<_BaseDashboard> {
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: _toDate ?? DateTime.now(),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _clearFilter() => setState(() { _fromDate = null; _toDate = null; });

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDark
          ? const ColorScheme.dark(primary: DashboardColors.primary, onPrimary: Colors.white)
          : const ColorScheme.light(primary: DashboardColors.primary, onPrimary: Colors.white),
      ),
      child: child!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFiltered = _fromDate != null || _toDate != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth < 600;
          final isDesktop = outerConstraints.maxWidth > 1024;
          final hPad = isMobile ? 16.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Responsive Header ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Title + breadcrumb (Expanded ensures it never pushes filters off-screen)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(widget.title,
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87)),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('Dashboard > Overview',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 11 : 13,
                                color: isDark ? Colors.white38 : Colors.black38)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right: Date filters + today badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // FROM date filter
                        _DateFilterButton(
                          icon: Icons.date_range_rounded,
                          label: 'From',
                          date: _fromDate,
                          isDesktop: isDesktop,
                          isDark: isDark,
                          accentColor: DashboardColors.primary,
                          onTap: _pickFromDate,
                        ),
                        const SizedBox(width: 8),
                        // TO date filter
                        _DateFilterButton(
                          icon: Icons.event_rounded,
                          label: 'To',
                          date: _toDate,
                          isDesktop: isDesktop,
                          isDark: isDark,
                          accentColor: DashboardColors.teal,
                          onTap: _pickToDate,
                        ),
                        // Clear filter button
                        if (isFiltered) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Clear filter',
                            child: GestureDetector(
                              onTap: _clearFilter,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: DashboardColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: DashboardColors.error.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.close_rounded,
                                  size: 16, color: DashboardColors.error),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Today's date badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 13, color: Colors.blue),
                              if (isDesktop) ...[
                                const SizedBox(width: 6),
                                Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Active filter indicator banner
                if (isFiltered) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: DashboardColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DashboardColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt_rounded, size: 14, color: DashboardColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Filtered: ${_fromDate != null ? DateFormat('dd MMM yyyy').format(_fromDate!) : 'Start'}'
                          '  →  ${_toDate != null ? DateFormat('dd MMM yyyy').format(_toDate!) : 'Today'}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                            color: DashboardColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isMobile ? 16 : 24),
                // ── Stats Grid ─────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    int cols;
                    double ratio;
                    if (constraints.maxWidth > 1200) {
                      cols = 6;
                      ratio = constraints.maxWidth > 1600 ? 2.6 : 2.0;
                    } else if (constraints.maxWidth > 600) {
                      cols = 3;
                      ratio = constraints.maxWidth > 900 ? 2.2 : 1.7;
                    } else {
                      cols = 2;
                      ratio = constraints.maxWidth > 400 ? 1.7 : 1.4;
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: isMobile ? 8 : 12,
                        mainAxisSpacing: isMobile ? 8 : 12,
                        childAspectRatio: ratio,
                      ),
                      itemCount: widget.stats.length,
                      itemBuilder: (context, index) => widget.stats[index],
                    );
                  },
                ),
                SizedBox(height: isMobile ? 16 : 24),
                // ── Dashboard Content ───────────────────────────────────
                ...widget.children.map((child) => Padding(
                  padding: EdgeInsets.only(bottom: isMobile ? 16 : 24),
                  child: child,
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Responsive date filter button.
/// Desktop (isDesktop=true): shows icon + label + selected date.
/// Mobile/Tablet (isDesktop=false): shows icon only with tooltip.
class _DateFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;
  final bool isDesktop;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _DateFilterButton({
    required this.icon,
    required this.label,
    required this.date,
    required this.isDesktop,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    final bgColor = hasDate
        ? accentColor.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white);
    final borderColor = hasDate
        ? accentColor.withValues(alpha: 0.4)
        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0));

    return Tooltip(
      message: hasDate
          ? '$label: ${DateFormat('dd MMM yyyy').format(date!)}'
          : 'Select $label date',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: hasDate ? accentColor : Colors.grey),
              if (isDesktop) ...[
                const SizedBox(width: 6),
                Text(
                  hasDate ? DateFormat('dd MMM').format(date!) : label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: hasDate ? FontWeight.w600 : FontWeight.w500,
                    color: hasDate ? accentColor
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                if (hasDate) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: accentColor),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
