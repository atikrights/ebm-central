import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Tasks', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Phase 1 Expansion', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 32),
            _buildTaskItem(context, 'Buy New Seeds', 'Expense', '-\$1,200', '12 April 2026', false),
            _buildTaskItem(context, 'Milk Sales Revenue', 'Income', '+\$4,500', '11 April 2026', true),
            _buildTaskItem(context, 'Labor Payment', 'Expense', '-\$800', '10 April 2026', false),
            _buildTaskItem(context, 'Equipments Maintenance', 'Expense', '-\$350', '09 April 2026', false),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, String title, String type, String amount, String date, bool isIncome) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green : Colors.red,
                )),
                Text(type, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Task Name')),
            const TextField(decoration: InputDecoration(labelText: 'Amount')),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Type: '),
                const Spacer(),
                ChoiceChip(label: const Text('Income'), selected: true, onSelected: (v){}),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Expense'), selected: false, onSelected: (v){}),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Add Task')),
        ],
      ),
    );
  }
}
