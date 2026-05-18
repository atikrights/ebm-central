import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State provider for trashed projects (local to this screen)
// ─────────────────────────────────────────────────────────────────────────────
final _trashedProjectsProvider =
    StateNotifierProvider.autoDispose<_TrashedNotifier, AsyncValue<List<Project>>>(
  (ref) => _TrashedNotifier(ref),
);

class _TrashedNotifier extends StateNotifier<AsyncValue<List<Project>>> {
  final Ref _ref;
  _TrashedNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final projects = await _ref.read(projectProvider.notifier).fetchTrashedProjects();
      state = AsyncValue.data(projects);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> restore(String id) async {
    final ok = await _ref.read(projectProvider.notifier).restoreTrashedProject(id);
    if (ok) await load();
    return ok;
  }

  Future<bool> forceDelete(String id) async {
    final ok = await _ref.read(projectProvider.notifier).forceDeleteProject(id);
    if (ok) await load();
    return ok;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recycle Bin Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProjectRecycleBinScreen extends ConsumerStatefulWidget {
  const ProjectRecycleBinScreen({super.key});

  @override
  ConsumerState<ProjectRecycleBinScreen> createState() =>
      _ProjectRecycleBinScreenState();
}

class _ProjectRecycleBinScreenState
    extends ConsumerState<ProjectRecycleBinScreen> {
  final Set<String> _loadingIds = {};
  String _searchQuery = '';

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleRestore(Project project) async {
    setState(() => _loadingIds.add(project.id));
    final ok =
        await ref.read(_trashedProjectsProvider.notifier).restore(project.id);
    if (mounted) setState(() => _loadingIds.remove(project.id));
    _showSnack(
      ok ? '✅ "${project.name}" restored successfully!' : '❌ Restore failed.',
      ok ? const Color(0xFF10B981) : Colors.redAccent,
    );
  }

  Future<void> _handleForceDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚠️ Permanent Delete',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                  fontSize: 14),
              children: [
                const TextSpan(text: 'This will permanently erase '),
                TextSpan(
                  text: '"${project.name}"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                    text:
                        ' from the database.\n\nThis action CANNOT be undone.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Delete Forever'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _loadingIds.add(project.id));
    final ok = await ref
        .read(_trashedProjectsProvider.notifier)
        .forceDelete(project.id);
    if (mounted) setState(() => _loadingIds.remove(project.id));
    _showSnack(
      ok
          ? '🗑️ "${project.name}" permanently deleted.'
          : '❌ Delete failed. Try again.',
      ok ? Colors.orange : Colors.redAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trashedAsync = ref.watch(_trashedProjectsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => context.go('/projects'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recycle Bin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Soft-deleted projects',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Refresh
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white54 : Colors.black54),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(_trashedProjectsProvider.notifier).load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search deleted projects...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: trashedAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
              error: (e, _) => _buildError(e.toString(), isDark),
              data: (projects) {
                final filtered = projects
                    .where((p) =>
                        p.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        p.pid
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                    .toList();

                if (filtered.isEmpty) return _buildEmpty(isDark);

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _buildTrashedCard(
                          filtered[i], isDark)
                      .animate()
                      .fadeIn(delay: (i * 40).ms)
                      .slideY(begin: 0.05, curve: Curves.easeOutQuad),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashedCard(Project project, bool isDark) {
    final isLoading = _loadingIds.contains(project.id);
    final deletedAt = project.deletedAt;
    final deletedStr = deletedAt != null
        ? DateFormat('MMM d, yyyy · HH:mm').format(deletedAt.toLocal())
        : 'Unknown date';
    final hasCompany =
        project.companyId != null && project.companyId!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(isDark ? 0.04 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Trash icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.redAccent.withOpacity(0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.pid,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Meta row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                icon: Icons.schedule_rounded,
                label: 'Deleted: $deletedStr',
                color: Colors.redAccent,
              ),
              if (hasCompany)
                _chip(
                  icon: Icons.business_rounded,
                  label: project.companyName ?? 'Company #${project.companyId}',
                  color: const Color(0xFF8B5CF6),
                ),
              _chip(
                icon: project.isApproved
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top_rounded,
                label: project.isApproved ? 'Was Approved' : 'Was Pending',
                color: project.isApproved
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Force Delete
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isLoading ? null : () => _handleForceDelete(project),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(
                        color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: const Text('Delete Forever',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              // Restore
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      isLoading ? null : () => _handleRestore(project),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.restore_rounded, size: 16),
                  label: Text(
                    isLoading ? 'Processing...' : 'Restore Project',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_outline_rounded,
                size: 56,
                color: isDark ? Colors.white12 : Colors.black12),
          ),
          const SizedBox(height: 24),
          Text('Recycle Bin is Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.black38,
              )),
          const SizedBox(height: 8),
          Text('All projects are safe and active.',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white24 : Colors.black26)),
        ],
      ),
    );
  }

  Widget _buildError(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text('Failed to load recycle bin',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(_trashedProjectsProvider.notifier).load(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
