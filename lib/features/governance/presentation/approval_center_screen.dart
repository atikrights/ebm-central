import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class PendingItems {
  final List<dynamic> projects;
  final List<dynamic> tasks;
  final int total;

  PendingItems({required this.projects, required this.tasks, required this.total});

  factory PendingItems.fromJson(Map<String, dynamic> json) {
    return PendingItems(
      projects: json['projects'] ?? [],
      tasks: json['tasks'] ?? [],
      total: json['total_pending'] ?? 0,
    );
  }
}

final pendingApprovalsProvider = FutureProvider.autoDispose<PendingItems>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/governance/approvals/pending');
  return PendingItems.fromJson(response);
});

class ApprovalCenterScreen extends ConsumerWidget {
  const ApprovalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("MANAGER APPROVAL CENTER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
        data: (data) {
          if (data.total == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(IconsaxPlusLinear.shield_tick, size: 64, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text("All Clear!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("No pending approvals from your team.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (data.projects.isNotEmpty) ...[
                _buildSectionHeader("PENDING PROJECTS", IconsaxPlusLinear.element_3),
                const SizedBox(height: 12),
                ...data.projects.map((p) => _buildApprovalCard(context, ref, p, 'project')),
                const SizedBox(height: 32),
              ],
              if (data.tasks.isNotEmpty) ...[
                _buildSectionHeader("PENDING TASKS", IconsaxPlusLinear.task_square),
                const SizedBox(height: 12),
                ...data.tasks.map((t) => _buildApprovalCard(context, ref, t, 'task')),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Colors.blueAccent)),
      ],
    );
  }

  Widget _buildApprovalCard(BuildContext context, WidgetRef ref, dynamic item, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? item['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Created by: ${item['creator']?['name'] ?? 'Unknown Manager'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _approveItem(context, ref, item['id'], type),
            icon: const Icon(Icons.check, size: 16),
            label: const Text("APPROVE"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withOpacity(0.1),
              foregroundColor: Colors.green,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveItem(BuildContext context, WidgetRef ref, dynamic id, String type) async {
    try {
      await ref.read(apiServiceProvider).post('/governance/approvals/approve', {
        'type': type,
        'id': id,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${type.toUpperCase()} approved successfully!")));
      ref.invalidate(pendingApprovalsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
}
