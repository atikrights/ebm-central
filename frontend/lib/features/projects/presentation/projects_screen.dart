import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildProjectStats(context, isDark),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Projects', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 12),
            _buildProjectList(context, isDark),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectStats(BuildContext context, bool isDark) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(context, 'Active', '12', const Color(0xFF3CB371), isDark),
          _statItem(context, 'Pending', '5', const Color(0xFFFF8C42), isDark),
          _statItem(context, 'Closed', '28', isDark ? Colors.white54 : Colors.black54, isDark),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value, Color color, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
      ],
    );
  }

  Widget _buildProjectList(BuildContext context, bool isDark) {
    return Expanded(
      child: ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          return _projectCard(context, index, isDark);
        },
      ),
    );
  }

  Widget _projectCard(BuildContext context, int index, bool isDark) {
    final theme = Theme.of(context);
    double progress = (index + 1) * 0.2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Phase ${index + 1} Expansion',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B6E4F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Active', style: TextStyle(color: Color(0xFF3CB371), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dept: Retail Operations',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budget', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                const Text('\$${25000}.00', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3CB371)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
