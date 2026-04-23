import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
            ),
            const SizedBox(height: 16),
            Text('Tanvir Ahmed', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('Super Admin', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 40),
            _buildProfileItem(Icons.person_outline, 'Edit Profile'),
            _buildProfileItem(Icons.security, 'Security Settings'),
            _buildProfileItem(Icons.notifications_none, 'Notification Settings'),
            _buildProfileItem(Icons.language, 'Language'),
            const SizedBox(height: 24),
            _buildProfileItem(Icons.logout, 'Logout', color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white70),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: color ?? Colors.white)),
            const Spacer(),
            Icon(Icons.chevron_right, color: (color ?? Colors.white).withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
