import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';

/// A reusable widget that shows all pending-approval projects
/// for Admin / Sub-Admin to approve or reject.
/// Drop this into any screen in EBM Central.
class ProjectApprovalDashboard extends ConsumerStatefulWidget {
  const ProjectApprovalDashboard({super.key});

  @override
  ConsumerState<ProjectApprovalDashboard> createState() =>
      _ProjectApprovalDashboardState();
}

class _ProjectApprovalDashboardState
    extends ConsumerState<ProjectApprovalDashboard> {
  final Set<String> _loadingIds = {};

  Future<void> _approve(String projectId) async {
    setState(() => _loadingIds.add(projectId));
    try {
      await ref.read(projectProvider.notifier).approveProject(projectId);
      if (mounted) {
        _showSnack('✅ Project approved and is now live!', const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Approval failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loadingIds.remove(projectId));
    }
  }

  Future<void> _reject(String projectId, String projectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Project?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"$projectName" will be marked as rejected. The creator will see it as not approved.',
          style: const TextStyle(color: Colors.white60, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _loadingIds.add(projectId));
    try {
      await ref.read(projectProvider.notifier).rejectProject(projectId);
      if (mounted) _showSnack('Project rejected.', Colors.orange);
    } catch (e) {
      if (mounted) _showSnack('❌ Rejection failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loadingIds.remove(projectId));
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectProvider);

    return projectsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.redAccent))),
      data: (projects) {
        final pending = projects.where((p) => !p.isApproved).toList();

        if (pending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF10B981), size: 48),
                ),
                const SizedBox(height: 16),
                const Text('All Clear!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('No projects pending approval.',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header count
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Text(
                    '${pending.length} Pending',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),

            ...pending.map((project) => _buildPendingCard(project)),
          ],
        );
      },
    );
  }

  Widget _buildPendingCard(Project project) {
    final isLoading = _loadingIds.contains(project.id);
    final hasCompany =
        project.companyId != null && project.companyId!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status dot
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // PID badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  project.pid,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Meta info row
          Row(children: [
            _metaChip(
              icon: Icons.person_outline,
              label: 'Manager',
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 8),
            _metaChip(
              icon: hasCompany ? Icons.business : Icons.lock_outline,
              label: hasCompany
                  ? (project.companyName ?? 'Company #${project.companyId}')
                  : 'No Company',
              color: hasCompany
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF64748B),
            ),
            if (project.totalBudget > 0) ...[
              const SizedBox(width: 8),
              _metaChip(
                icon: Icons.account_balance_wallet_outlined,
                label:
                    '\$${project.totalBudget.toStringAsFixed(0)}',
                color: const Color(0xFF10B981),
              ),
            ],
          ]),

          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.4),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Action buttons
          Row(children: [
            // Reject
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    isLoading ? null : () => _reject(project.id, project.name),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            // Approve
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _approve(project.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  isLoading ? 'Approving...' : 'Approve & Go Live',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _metaChip(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
