import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/company_external_quota.dart';
import '../providers/company_external_quota_provider.dart';

class QuotaEditScreen extends ConsumerStatefulWidget {
  final CompanyExternalQuota quota;

  const QuotaEditScreen({
    super.key,
    required this.quota,
  });

  @override
  ConsumerState<QuotaEditScreen> createState() => _QuotaEditScreenState();
}

class _QuotaEditScreenState extends ConsumerState<QuotaEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _tagController;
  late TextEditingController _earnDescController;
  late TextEditingController _earnAmountController;
  late TextEditingController _expenseDescController;
  late TextEditingController _expenseAmountController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quota.title);
    _tagController = TextEditingController(text: widget.quota.tag);
    _earnDescController = TextEditingController(text: widget.quota.earnDescription);
    _earnAmountController = TextEditingController(
      text: widget.quota.earn > 0 ? widget.quota.earn.toStringAsFixed(2) : '',
    );
    _expenseDescController = TextEditingController(text: widget.quota.expenseDescription);
    _expenseAmountController = TextEditingController(
      text: widget.quota.expense > 0 ? widget.quota.expense.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _earnDescController.dispose();
    _earnAmountController.dispose();
    _expenseDescController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final earnVal = double.tryParse(_earnAmountController.text) ?? 0.0;
    final expenseVal = double.tryParse(_expenseAmountController.text) ?? 0.0;

    final now = DateTime.now();
    final currentTimeString = DateFormat('hh:mm a').format(now);

    final String earnTime = (earnVal > 0 && widget.quota.earnTime.isEmpty)
        ? currentTimeString
        : widget.quota.earnTime;

    final String expenseTime = (expenseVal > 0 && widget.quota.expenseTime.isEmpty)
        ? currentTimeString
        : widget.quota.expenseTime;

    // Auto-update date to real system datetime on every save
    final updated = widget.quota.copyWith(
      title: _titleController.text.trim(),
      tag: _tagController.text.trim(),
      earn: earnVal,
      expense: expenseVal,
      earnDescription: _earnDescController.text.trim(),
      earnTime: earnTime,
      expenseDescription: _expenseDescController.text.trim(),
      expenseTime: expenseTime,
      date: now,
    );

    try {
      await ref
          .read(companyExternalQuotaProvider(widget.quota.companyId).notifier)
          .updateQuota(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quota updated successfully.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quota: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quota'),
        content: const Text(
          'Are you sure you want to move this quota to the Recycle Bin? You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(companyExternalQuotaProvider(widget.quota.companyId).notifier)
          .deleteQuota(widget.quota.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quota moved to Recycle Bin.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete quota: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sectionBg = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.02);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final scaffoldBg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F1117).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Quota',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Manrope',
              ),
            ),
            Text(
              widget.quota.qid,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _delete,
            tooltip: 'Delete Quota',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Breakpoints
            final isMobile = w < 600;
            final isTablet = w >= 600 && w < 960;
            final isDesktop = w >= 960;

            // On large screens, constrain and center content
            final contentMaxWidth = double.infinity;
            final hPad = isMobile ? 16.0 : isTablet ? 24.0 : 40.0;
            final vPad = isMobile ? 16.0 : 24.0;
            // Two-column layout on tablet and desktop
            final useSideBySide = isTablet || isDesktop;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Metadata card ──────────────────────────────
                        _buildSectionCard(
                          isDark: isDark,
                          bg: sectionBg,
                          border: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Quota Metadata', isDark),
                              const SizedBox(height: 16),
                              if (useSideBySide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildTitleField(textColor, hintColor, inputBg, borderColor)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildTagField(textColor, hintColor, inputBg, borderColor)),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildTitleField(textColor, hintColor, inputBg, borderColor),
                                    const SizedBox(height: 14),
                                    _buildTagField(textColor, hintColor, inputBg, borderColor),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Earn / Expense ─────────────────────────────
                        if (useSideBySide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildEarnSection(sectionBg, inputBg, borderColor, textColor, hintColor),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildExpenseSection(sectionBg, inputBg, borderColor, textColor, hintColor),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildEarnSection(sectionBg, inputBg, borderColor, textColor, hintColor),
                              const SizedBox(height: 20),
                              _buildExpenseSection(sectionBg, inputBg, borderColor, textColor, hintColor),
                            ],
                          ),

                        const SizedBox(height: 28),

                        // ── Actions ────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: hintColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 20 : 28,
                                  vertical: 13,
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section card wrapper ─────────────────────────────────────────────
  Widget _buildSectionCard({
    required bool isDark,
    required Color bg,
    required Color border,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Section label ────────────────────────────────────────────────────
  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.primaryContainer : AppColors.primary,
        fontFamily: 'Manrope',
        letterSpacing: 0.3,
      ),
    );
  }

  // ── Earn Section ─────────────────────────────────────────────────────
  Widget _buildEarnSection(Color bg, Color inputBg, Color borderColor, Color textColor, Color hintColor) {
    return _buildSectionCard(
      isDark: Theme.of(context).brightness == Brightness.dark,
      bg: bg,
      border: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Earn Transactions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
              Text(
                'Optional',
                style: TextStyle(fontSize: 10, color: hintColor, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Amount
          _fieldLabel('Earn Amount (\$)', hintColor),
          const SizedBox(height: 6),
          _buildAmountField(
            controller: _earnAmountController,
            color: AppColors.success,
            hint: '0.00',
          ),
          const SizedBox(height: 14),

          // Description
          _fieldLabel('Earn Description', hintColor),
          const SizedBox(height: 6),
          _buildTextArea(
            controller: _earnDescController,
            hint: 'Enter earning description...',
            textColor: textColor,
            hintColor: hintColor,
            inputBg: inputBg,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  // ── Expense Section ──────────────────────────────────────────────────
  Widget _buildExpenseSection(Color bg, Color inputBg, Color borderColor, Color textColor, Color hintColor) {
    return _buildSectionCard(
      isDark: Theme.of(context).brightness == Brightness.dark,
      bg: bg,
      border: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: AppColors.error, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Expense Transactions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
              Text(
                'Optional',
                style: TextStyle(fontSize: 10, color: hintColor, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Amount
          _fieldLabel('Expense Amount (\$)', hintColor),
          const SizedBox(height: 6),
          _buildAmountField(
            controller: _expenseAmountController,
            color: AppColors.error,
            hint: '0.00',
          ),
          const SizedBox(height: 14),

          // Description
          _fieldLabel('Expense Description', hintColor),
          const SizedBox(height: 6),
          _buildTextArea(
            controller: _expenseDescController,
            hint: 'Enter expense description...',
            textColor: textColor,
            hintColor: hintColor,
            inputBg: inputBg,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, Color hintColor) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, color: hintColor, fontWeight: FontWeight.w700, letterSpacing: 0.2),
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required Color color,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          hintText: hint,
          hintStyle: TextStyle(color: color.withValues(alpha: 0.35), fontSize: 16),
          prefixText: '\$ ',
          prefixStyle: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    required Color textColor,
    required Color hintColor,
    required Color inputBg,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: 3,
        style: TextStyle(color: textColor, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontSize: 13),
        ),
      ),
    );
  }

  // ── Title Field ──────────────────────────────────────────────────────
  Widget _buildTitleField(Color textColor, Color hintColor, Color inputBg, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Title', hintColor),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextFormField(
            controller: _titleController,
            style: TextStyle(color: textColor, fontSize: 14),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              hintText: 'Enter quota title',
              hintStyle: TextStyle(color: hintColor),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
        ),
      ],
    );
  }

  // ── Tag Field ────────────────────────────────────────────────────────
  Widget _buildTagField(Color textColor, Color hintColor, Color inputBg, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Tag', hintColor),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextFormField(
            controller: _tagController,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              hintText: 'e.g. Infrastructure, Marketing',
              hintStyle: TextStyle(color: hintColor),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tag is required' : null,
          ),
        ),
      ],
    );
  }
}
