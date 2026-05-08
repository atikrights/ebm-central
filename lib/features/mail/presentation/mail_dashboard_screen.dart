import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/admin_theme.dart';
import 'mail_provider.dart';
import 'mail_settings_screen.dart';

class MailDashboardScreen extends ConsumerWidget {
  const MailDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inboxAsync = ref.watch(mailInboxProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
    final isTablet = size.width >= 700 && size.width < 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Workplace Mail Hub", 
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(mailInboxProvider.notifier).fetchInbox(),
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP STATS SECTION ---
            _buildResponsiveGrid(
              isMobile: isMobile,
              isTablet: isTablet,
              children: [
                _buildStatCard(context, "Total Mails", "1,248", Icons.email_outlined, Colors.blue),
                _buildStatCard(context, "Unread", "24", Icons.mark_email_unread_outlined, Colors.orange),
                _buildStatCard(context, "Storage", "85%", Icons.cloud_outlined, Colors.green),
                _buildStatCard(context, "Sync Status", "Active", Icons.sync_rounded, Colors.purple),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // --- MAIN CONTENT AREA ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Mails List
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, "RECENT INBOX"),
                      const SizedBox(height: 16),
                      inboxAsync.when(
                        data: (mails) => mails.isEmpty 
                          ? _buildEmptyInbox(context)
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: mails.length > 5 ? 5 : mails.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _buildMailTile(context, mails[index]),
                            ),
                        loading: () => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(60),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: theme.colorScheme.primary),
                                const SizedBox(height: 16),
                                Text("Fetching your emails...", style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                              const SizedBox(height: 12),
                              Text("Connection Failed", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                              Text(e.toString(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                            ],
                          )
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {}, 
                          icon: const Icon(Icons.chevron_right_rounded, size: 14),
                          label: Text("VIEW ALL MESSAGES", 
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
                          )
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (!isMobile) ...[
                  const SizedBox(width: 24),
                  // Quick Actions Sidebar (Inside Dashboard)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, "QUICK ACTIONS"),
                        const SizedBox(height: 16),
                        _buildActionBtn(context, "Compose", Icons.edit_note_rounded, theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        _buildUsageCard(context),

                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveGrid({required bool isMobile, required bool isTablet, required List<Widget> children}) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 4),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: children,
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, 
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
              ),
              Text(title, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMailTile(BuildContext context, Map<String, dynamic> mail) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Text(mail['from']?.substring(0, 1).toUpperCase() ?? "M", 
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(mail['from'] ?? "Unknown", 
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), 
                      maxLines: 1, overflow: TextOverflow.ellipsis
                    ),
                    Text(mail['date']?.toString().split(' ')[0] ?? "", 
                      style: theme.textTheme.bodySmall
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(mail['subject'] ?? "No Subject", 
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.8)), 
                  maxLines: 1, overflow: TextOverflow.ellipsis
                ),
                const SizedBox(height: 2),
                Text(mail['snippet'] ?? "", 
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)), 
                  maxLines: 1, overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        if (label == "Mail Settings") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MailSettingsScreen()));
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, 
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("QUOTA USAGE", 
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.85, 
            backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3), 
            color: Colors.green
          ),
          const SizedBox(height: 8),
          Text("4.2 GB of 5 GB used", style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {}, 
            child: Text("UPGRADE PLAN", 
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInbox(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.mail_outline_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("No messages found", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(width: 4, height: 14, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ],
    );
  }
}
