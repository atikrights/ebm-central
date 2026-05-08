import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_service.dart';
import 'chat_detail_screen.dart';
import '../../../core/auth/auth_provider.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeamUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamUsers() async {
    try {
      final service = ref.read(chatServiceProvider);
      final users = await service.getTeamUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load network members.'; _isLoading = false; });
    }
  }

  void _filter(String q) {
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final name = (u['chat_nickname'] ?? u['name'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();
        final num  = (u['chat_number'] ?? '').toString();
        return name.contains(q.toLowerCase()) || role.contains(q.toLowerCase()) || num.contains(q);
      }).toList();
    });
  }

  void _openDialPad() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SearchUserDialog(service: ref.read(chatServiceProvider)),
    );
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':   return const Color(0xFF60A5FA);
      case 'MANAGER': return const Color(0xFFFB923C);
      default:        return const Color(0xFF34D399);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC);
    final width  = MediaQuery.of(context).size.width;
    
    int crossAxisCount = width > 1400 ? 4 : (width > 1000 ? 3 : (width > 700 ? 2 : 1));
    double childAspectRatio = width > 1400 ? 3.0 : (width > 1000 ? 2.8 : (width > 700 ? 2.5 : 4.5));

    final admins   = _filteredUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'ADMIN').toList();
    final managers = _filteredUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'MANAGER').toList();
    final staff    = _filteredUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'STAFF').toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
        leadingWidth: 100,
        leading: Center(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: isDark ? Colors.white70 : Colors.black54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Network Discovery',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text('Connect with organization members',
                style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white24 : Colors.black38)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: _DialBtn(onTap: _openDialPad, isDark: isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchController, onChanged: _filter, isDark: isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadTeamUsers)
                    : _filteredUsers.isEmpty
                        ? _EmptyState(isDark: isDark)
                        : SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: width > 1200 ? 80 : (width > 800 ? 40 : 20),
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (admins.isNotEmpty) ...[
                                  _SectionHeader(label: 'Administrators', color: _roleColor('ADMIN')),
                                  _buildUserGrid(admins, crossAxisCount, childAspectRatio, isDark, _roleColor('ADMIN')),
                                ],
                                if (managers.isNotEmpty) ...[
                                  _SectionHeader(label: 'Management', color: _roleColor('MANAGER')),
                                  _buildUserGrid(managers, crossAxisCount, childAspectRatio, isDark, _roleColor('MANAGER')),
                                ],
                                if (staff.isNotEmpty) ...[
                                  _SectionHeader(label: 'Team Members', color: _roleColor('STAFF')),
                                  _buildUserGrid(staff, crossAxisCount, childAspectRatio, isDark, _roleColor('STAFF')),
                                ],
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<Map<String, dynamic>> users, int count, double ratio, bool isDark, Color roleColor) {
    if (count == 1) {
      return Column(
        children: users.map((u) => _UserTile(user: u, isDark: isDark, roleColor: roleColor)).toList(),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: ratio,
      ),
      itemBuilder: (context, index) => _UserTile(user: users[index], isDark: isDark, roleColor: roleColor),
    );
  }
}

class _DialBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _DialBtn({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dialpad_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('FIND IDENTITY', 
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;
  const _SearchBar({required this.controller, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: width > 1200 ? 160 : (width > 800 ? 80 : 20),
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Search by nickname, role or virtual 12-digit number...',
                hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Icon(Icons.search_rounded, color: isDark ? Colors.white30 : Colors.black38, size: 28),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 40, 4, 20),
      child: Row(
        children: [
          Container(
            width: 5, height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.3)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 14),
          Text(label.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: color, letterSpacing: 2.5)),
          const SizedBox(width: 20),
          Expanded(child: Divider(color: color.withOpacity(0.08), thickness: 1)),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDark;
  final Color roleColor;
  const _UserTile({required this.user, required this.isDark, required this.roleColor});

  @override
  Widget build(BuildContext context) {
    final name   = user['chat_nickname'] ?? user['name'] ?? 'Unknown';
    final role   = (user['role'] ?? 'STAFF').toString().toUpperCase();
    final number = user['chat_number'] ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            receiverType: user['id'].toString(),
            chatName: name,
            chatColor: roleColor,
          ),
        )),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [roleColor.withOpacity(0.25), roleColor.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(name[0].toUpperCase(),
                      style: GoogleFonts.outfit(color: roleColor, fontWeight: FontWeight.w900, fontSize: 24)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 6),
                    if (number.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: roleColor.withOpacity(0.6)),
                          const SizedBox(width: 6),
                          Text(number,
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: roleColor.withOpacity(0.15)),
                ),
                child: Text(role,
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: roleColor, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 16),
              Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 100, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 24),
          Text('Discovery failed to find matches',
              style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 100, color: Colors.redAccent),
          const SizedBox(height: 24),
          Text(message, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 18)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('RECONNECT NOW'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchUserDialog extends ConsumerStatefulWidget {
  final ChatService service;
  const _SearchUserDialog({required this.service});

  @override
  ConsumerState<_SearchUserDialog> createState() => _SearchUserDialogState();
}

class _SearchUserDialogState extends ConsumerState<_SearchUserDialog> {
  final TextEditingController _digitsController = TextEditingController();
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _digitsController.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    final digits = _digitsController.text.trim();
    if (digits.length != 12) {
      setState(() => _error = 'Identification must be 12 digits');
      return;
    }
    setState(() { _isSearching = true; _error = null; });
    try {
      final user = await widget.service.findUserByNumber(digits);
      if (!mounted) return;
      if (user != null) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            receiverType: user['id'].toString(),
            chatName: user['chat_nickname'] ?? user['name'] ?? 'Unknown',
            chatColor: const Color(0xFF6366F1),
          ),
        ));
      } else {
        setState(() { _error = 'Identity not registered in network'; _isSearching = false; });
      }
    } catch (_) {
      setState(() { _error = 'Discovery synchronization error'; _isSearching = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text   = isDark ? Colors.white : Colors.black87;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 50)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 25)],
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Identity Discovery', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 10),
              Text('Securely connect using unique 12-digit number', 
                   textAlign: TextAlign.center,
                   style: GoogleFonts.outfit(fontSize: 15, color: isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _error != null ? Colors.redAccent.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12)),
                ),
                child: TextField(
                  controller: _digitsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 12,
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: text, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: "",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 24),
                    hintText: '000000000000',
                    hintStyle: TextStyle(color: Colors.white10, letterSpacing: 8),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _startChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: _isSearching
                      ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text('START SECURE SESSION', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ABORT DISCOVERY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black38, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
