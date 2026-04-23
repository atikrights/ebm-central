import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Add', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _addCard(context, 'Project', Icons.account_tree, Colors.blue),
                  _addCard(context, 'Member', Icons.person_add, Colors.orange),
                  _addCard(context, 'Transaction', Icons.receipt_long, Colors.green),
                  _addCard(context, 'Report', Icons.assessment, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addCard(BuildContext context, String title, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
