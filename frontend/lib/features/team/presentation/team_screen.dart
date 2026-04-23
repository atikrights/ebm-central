import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Our Team', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildMemberCard(context, 'Tanvir Ahmed', 'Super Admin', Icons.admin_panel_settings),
            _buildMemberCard(context, 'Sabbir Hossain', 'Manager', Icons.manage_accounts),
            _buildMemberCard(context, 'Naimur Rahman', 'Staff', Icons.person),
            _buildMemberCard(context, 'Karim Ullah', 'Staff', Icons.person),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, String name, String role, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(role, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
