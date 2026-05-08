import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mail_service.dart';
import 'mail_provider.dart';

class MailSettingsScreen extends ConsumerStatefulWidget {
  const MailSettingsScreen({super.key});

  @override
  ConsumerState<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends ConsumerState<MailSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _imapHostC = TextEditingController(text: "imap.hostinger.com");
  final _imapPortC = TextEditingController(text: "993");
  final _smtpHostC = TextEditingController(text: "smtp.hostinger.com");
  final _smtpPortC = TextEditingController(text: "465");
  final _displayNameC = TextEditingController();
  final _signatureC = TextEditingController();
  
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ref.read(mailServiceProvider).getSettings();
      setState(() {
        _emailC.text = settings['email'] ?? "";
        _imapHostC.text = settings['imap_host'] ?? "imap.hostinger.com";
        _imapPortC.text = settings['imap_port']?.toString() ?? "993";
        _smtpHostC.text = settings['smtp_host'] ?? "smtp.hostinger.com";
        _smtpPortC.text = settings['smtp_port']?.toString() ?? "465";
        _displayNameC.text = settings['display_name'] ?? "";
        _signatureC.text = settings['signature'] ?? "";
      });
    } catch (_) {}
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      await ref.read(mailServiceProvider).testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection Successful!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_emailC.text.isEmpty || _passwordC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(mailServiceProvider).saveSettings({
        'email': _emailC.text,
        'password': _passwordC.text,
        'imap_host': _imapHostC.text,
        'imap_port': int.parse(_imapPortC.text),
        'smtp_host': _smtpHostC.text,
        'smtp_port': int.parse(_smtpPortC.text),
        'display_name': _displayNameC.text,
        'signature': _signatureC.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings saved!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _imapHostC.dispose();
    _imapPortC.dispose();
    _smtpHostC.dispose();
    _smtpPortC.dispose();
    _displayNameC.dispose();
    _signatureC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Workplace Mail Hub", 
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Server Configuration"),
            Tab(text: "Identity & Signature"),
            Tab(text: "Auto-Responder"),
            Tab(text: "Advanced"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServerTab(context),
          _buildIdentityTab(context),
          _buildAutoResponderTab(context),
          _buildAdvancedTab(context),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildServerTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, "BUSINESS ACCOUNT"),
          const SizedBox(height: 16),
          _buildField(context, label: "Email Address", controller: _emailC, icon: Icons.alternate_email_rounded, hint: "hello@domain.com"),
          const SizedBox(height: 16),
          _buildField(context, label: "Password", controller: _passwordC, icon: Icons.lock_outline_rounded, hint: "••••••••", isPassword: true),
          
          const SizedBox(height: 32),
          _buildSectionHeader(context, "INCOMING SERVER (IMAP)"),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 3, child: _buildField(context, label: "Host", controller: _imapHostC, icon: Icons.dns_outlined, hint: "imap.hostinger.com")),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildField(context, label: "Port", controller: _imapPortC, icon: Icons.tag_rounded, hint: "993")),
            ],
          ),
          
          const SizedBox(height: 32),
          _buildSectionHeader(context, "OUTGOING SERVER (SMTP)"),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 3, child: _buildField(context, label: "Host", controller: _smtpHostC, icon: Icons.outbox_rounded, hint: "smtp.hostinger.com")),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildField(context, label: "Port", controller: _smtpPortC, icon: Icons.tag_rounded, hint: "465")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, "PUBLIC IDENTITY"),
          const SizedBox(height: 16),
          _buildField(context, label: "Display Name", controller: _displayNameC, icon: Icons.person_outline_rounded, hint: "e.g. CEO Office"),
          
          const SizedBox(height: 32),
          _buildSectionHeader(context, "EMAIL SIGNATURE"),
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _signatureC,
              maxLines: 10,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText: "-- \nRegards,\nYour Name",
                hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text("Rich text and HTML signatures are supported.", 
                style: theme.textTheme.bodySmall
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoResponderTab(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.primary.withOpacity(0.05);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(Icons.timer_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 32),
            Text("Auto-Responder", 
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),
            Text(
              "Automatically reply to incoming emails when you are away. Perfect for out-of-office notifications.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 48),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: false, 
                onChanged: (v){}, 
                title: Text("Enable Out-of-Office", 
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
                ),
                activeColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader(context, "STORAGE & SYNC"),
        const SizedBox(height: 16),
        _buildAdvancedTile(context, Icons.sync_rounded, "Sync Frequency", "Every 5 minutes"),
        _buildAdvancedTile(context, Icons.cloud_queue_rounded, "Local Cache", "512 MB (Tap to clear)"),
        const SizedBox(height: 32),
        _buildSectionHeader(context, "SECURITY & PROTOCOLS"),
        const SizedBox(height: 16),
        _buildAdvancedTile(context, Icons.security_rounded, "Encryption Method", "SSL/TLS (Standard)"),
        _buildAdvancedTile(context, Icons.vpn_key_outlined, "Authentication", "Password-based (Secure)"),
        _buildAdvancedTile(context, Icons.shield_outlined, "Spam Filter", "EBM Central Guard Active"),
      ],
    );
  }

  Widget _buildAdvancedTile(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          onTap: () {},
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting ? const SizedBox.shrink() : Icon(Icons.bolt_rounded, size: 18, color: theme.colorScheme.primary),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              label: _isTesting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text("TEST CONNECTION", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save_as_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              ),
              label: _isSaving 
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                : Text("SAVE CONFIG", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary)),
            ),
          ),
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

  Widget _buildField(BuildContext context, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), 
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}
