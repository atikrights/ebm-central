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
            const SizedBox(height: 32),
            _buildSectionHeader(theme, 'PERSONAL'),
            _buildProfileItem(Icons.person_outline, 'Edit Profile'),
            _buildProfileItem(Icons.security, 'Security Settings'),
            
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'WORKPLACE HUB'),
            _buildProfileItem(
              Icons.mail_outline, 
              'Workplace Mail', 
              onTap: () => Navigator.pushNamed(context, '/mail'),
            ),
            _buildProfileItem(
              Icons.settings_suggest_outlined, 
              'Mail Settings',
              onTap: () => Navigator.pushNamed(context, '/mail/settings'),
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'SYSTEM'),
            _buildProfileItem(Icons.notifications_none, 'Notifications'),
            _buildProfileItem(Icons.language, 'Language'),
            const SizedBox(height: 32),
            _buildProfileItem(Icons.logout, 'Terminate Session', color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: color ?? Colors.white70, size: 20),
              const SizedBox(width: 16),
              Text(title, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right, color: (color ?? Colors.white).withOpacity(0.2), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
