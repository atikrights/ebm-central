import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class DepartmentScreen extends StatelessWidget {
  final String departmentName;

  const DepartmentScreen({
    super.key,
    this.departmentName = 'EBFIC FARM & LIVESTOCK',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DefaultTabController(
        length: 4,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Department Header
              Text(
                'Department',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                departmentName,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              
              // Department Summary Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _SummaryMiniCard('Income', '\$12K', theme.colorScheme.primary, theme),
                  _SummaryMiniCard('Expense', '\$4K', theme.colorScheme.tertiary, theme),
                  _SummaryMiniCard('Profit', '\$8K', Colors.blueAccent, theme),
                  _SummaryMiniCard('Active', '3', theme.colorScheme.primary, theme),
                  _SummaryMiniCard('Inactive', '1', theme.colorScheme.onSurfaceVariant, theme),
                  _SummaryMiniCard('Closed', '5', Colors.grey, theme),
                ],
              ),
              const SizedBox(height: 40),

              // Tabs
              TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: '📂 Projects'),
                  Tab(text: '👥 Team'),
                  Tab(text: '💬 Chat'),
                  Tab(text: '📊 Report'),
                ],
              ),
              const SizedBox(height: 24),
              
              // Tab Content (Placeholder with height to demonstrate)
              SizedBox(
                height: 400,
                child: TabBarView(
                  children: [
                    _buildProjectsList(theme),
                    const Center(child: Text('Team Module Widget')),
                    const Center(child: Text('Chat Module Widget')),
                    const Center(child: Text('Report Module Widget')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _SummaryMiniCard(String title, String value, Color color, ThemeData theme) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildProjectsList(ThemeData theme) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project ${index + 1}', style: theme.textTheme.titleLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Active', style: TextStyle(color: theme.colorScheme.primary, fontSize: 10)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Budget: \$50,000', style: theme.textTheme.bodySmall),
                  Text('Tasks: 12', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: 0.6,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        );
      },
    );
  }
}
