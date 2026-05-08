import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricGrid(context),
            const SizedBox(height: 40),
            _buildFinanceSection(context),
            const SizedBox(height: 40),
            _buildQuickActions(context),
            const SizedBox(height: 40),
            _buildRecentTasks(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : (constraints.maxWidth < 900 ? 2 : 3);
        final aspect = isMobile ? 2.5 : 1.3;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: aspect,
          children: [
            MetricCard(
              title: 'Total Revenue',
              value: '\$4.28M',
              hint: '+2.4%',
              color: Theme.of(context).colorScheme.primary,
              icon: Icons.account_balance_wallet,
              bgIcon: Icons.payments,
            ),
            MetricCard(
              title: 'Active Projects',
              value: '18',
              hint: '4 Due',
              color: Theme.of(context).colorScheme.tertiary,
              icon: Icons.rocket_launch,
              bgIcon: Icons.account_tree,
            ),
            MetricCard(
              title: 'Team Size',
              value: '124',
              hint: 'Global',
              color: Colors.blueAccent,
              icon: Icons.diversity_3,
              bgIcon: Icons.groups,
            ),
          ],
        );
      }
    );
  }

  Widget _buildFinanceSection(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Finance Summary', style: theme.textTheme.titleLarge),
              Row(
                children: [
                  _legendDot(theme.colorScheme.primary, 'Income', theme),
                  const SizedBox(width: 16),
                  _legendDot(theme.colorScheme.tertiary, 'Expense', theme),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barChartItem(100, 60, 'JAN', theme),
                _barChartItem(120, 50, 'FEB', theme),
                _barChartItem(150, 90, 'MAR', theme, isActive: true),
                _barChartItem(110, 70, 'APR', theme),
                _barChartItem(130, 80, 'MAY', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _barChartItem(double incomeH, double expenseH, String label, ThemeData theme, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 12, height: incomeH,
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.4),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12, height: expenseH,
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.tertiary : theme.colorScheme.tertiary.withOpacity(0.4),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
        )),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _actionCard('Add Project', Icons.add_circle, true, theme),
              const SizedBox(width: 16),
              _actionCard('New Transaction', Icons.receipt_long, false, theme),
              const SizedBox(width: 16),
              _actionCard('Invite Member', Icons.person_add, false, theme),
              const SizedBox(width: 16),
              _actionCard('View Reports', Icons.insights, false, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionCard(String label, IconData icon, bool isPrimary, ThemeData theme) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isPrimary ? [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isPrimary ? Colors.white : theme.colorScheme.primary, size: 32),
          const SizedBox(height: 16),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isPrimary ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasks(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () {},
              child: Text('View All History', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _activityTile('Project Aether Completed', 'Tech Division', 'Today, 2:40 PM', 'Milestone', theme, isSuccess: true),
        _activityTile('Software License Renewal', 'Operational Expense', 'Today, 11:15 AM', '-\$2,400.00', theme, isExpense: true),
        _activityTile('New Project Lead', 'Marketing Hub', 'Yesterday', 'Pending Review', theme),
      ],
    );
  }

  Widget _activityTile(String title, String subtitle, String time, String status, ThemeData theme, {bool isSuccess = false, bool isExpense = false}) {
    Color iconBg = theme.colorScheme.primary.withOpacity(0.1);
    Color iconColor = theme.colorScheme.primary;
    IconData icon = Icons.check_circle;

    if (isExpense) {
      iconBg = theme.colorScheme.tertiary.withOpacity(0.1);
      iconColor = theme.colorScheme.tertiary;
      icon = Icons.shopping_cart;
    } else if (!isSuccess && !isExpense) {
      iconBg = theme.colorScheme.onSurfaceVariant.withOpacity(0.1);
      iconColor = theme.colorScheme.onSurfaceVariant;
      icon = Icons.hourglass_top;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(
                color: isExpense ? theme.colorScheme.tertiary : (isSuccess ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final Color color;
  final IconData icon;
  final IconData bgIcon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
    required this.icon,
    required this.bgIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(bgIcon, size: 100, color: color.withOpacity(0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: theme.textTheme.headlineMedium),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
