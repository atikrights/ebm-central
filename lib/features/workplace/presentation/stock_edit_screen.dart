import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/company_stock.dart';
import '../providers/company_stock_provider.dart';

class StockEditScreen extends ConsumerStatefulWidget {
  final CompanyStock stock;

  const StockEditScreen({
    super.key,
    required this.stock,
  });

  @override
  ConsumerState<StockEditScreen> createState() => _StockEditScreenState();
}

class _StockEditScreenState extends ConsumerState<StockEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _stkCodeController;
  late TextEditingController _descriptionController;
  List<CompanyStockAsset> _assets = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.stock.title);
    _stkCodeController = TextEditingController(text: widget.stock.stkCode);
    _descriptionController = TextEditingController(text: widget.stock.description);
    _assets = List.from(widget.stock.assets);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _stkCodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double get _totalMinPrice {
    return _assets.fold(0.0, (sum, item) => sum + item.minPrice);
  }

  double get _totalMaxPrice {
    return _assets.fold(0.0, (sum, item) => sum + item.maxPrice);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.stock.copyWith(
      title: _titleController.text.trim(),
      stkCode: _stkCodeController.text.trim(),
      description: _descriptionController.text.trim(),
      assets: _assets,
      date: DateTime.now(), // Auto-update date to real system datetime on save
    );

    try {
      await ref
          .read(companyStockProvider(widget.stock.companyId).notifier)
          .updateStock(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Stock asset updated successfully.'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to update: $e')),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Delete Stock Asset'),
        content: const Text(
          'Are you sure you want to move this stock asset to the Recycle Bin? You can restore it later.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(companyStockProvider(widget.stock.companyId).notifier)
          .deleteStock(widget.stock.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Stock moved to Recycle Bin.'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addOrEditAsset({CompanyStockAsset? asset, int? index}) {
    final nameCtrl = TextEditingController(text: asset?.name ?? '');
    final minCtrl = TextEditingController(text: asset != null ? asset.minPrice.toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(text: asset != null ? asset.maxPrice.toStringAsFixed(0) : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02);
        final borderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(asset == null ? 'Add Live Asset' : 'Edit Live Asset'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asset Name / Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                    child: TextFormField(
                      controller: nameCtrl,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: 'e.g. Land Property / Office Building',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Asset name is required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Min Est Price (\$)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                              child: TextFormField(
                                controller: minCtrl,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  hintText: 'Min',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final val = double.tryParse(v);
                                  if (val == null || val < 0) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Max Est Price (\$)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                              child: TextFormField(
                                controller: maxCtrl,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  hintText: 'Max',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final val = double.tryParse(v);
                                  if (val == null || val < 0) return 'Invalid';
                                  final minVal = double.tryParse(minCtrl.text);
                                  if (minVal != null && val < minVal) return 'Must be >= Min';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newAsset = CompanyStockAsset(
                    name: nameCtrl.text.trim(),
                    minPrice: double.parse(minCtrl.text),
                    maxPrice: double.parse(maxCtrl.text),
                  );
                  setState(() {
                    if (index == null) {
                      _assets.add(newAsset);
                    } else {
                      _assets[index] = newAsset;
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(asset == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _removeAsset(int index) {
    setState(() {
      _assets.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sectionBg = isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white;
    final inputBg = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final scaffoldBg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1117).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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
              'Configure Live Assets & Valuation',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Manrope',
              ),
            ),
            Text(
              'STK-${widget.stock.stkCode}',
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
            tooltip: 'Delete Stock Asset',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isMobile = w < 720;
            final padding = isMobile ? 16.0 : 28.0;

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info block
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sectionBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'General Stock Info',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryContainer : AppColors.primary,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STK-${widget.stock.stkCode}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Title Field
                      const Text('Title / Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: TextFormField(
                          controller: _titleController,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            hintText: 'Enter stock item title',
                            hintStyle: TextStyle(color: hintColor),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description Field
                      const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(color: textColor, fontSize: 14),
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            hintText: 'Write structural notes, usage context or comments...',
                            hintStyle: TextStyle(color: hintColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Total valuation summary widget
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.primary.withOpacity(0.15), const Color(0xFF1E293B)]
                          : [AppColors.primary.withOpacity(0.08), Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL LIVE VALUATION RANGE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white54 : Colors.black54,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${_totalMinPrice.toStringAsFixed(0)} - \$${_totalMaxPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontFamily: 'Manrope',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Accumulated from ${_assets.length} active asset registries',
                              style: TextStyle(fontSize: 10, color: hintColor),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            );

            final rightColumn = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Assets (${_assets.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryContainer : AppColors.primary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addOrEditAsset(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Asset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_assets.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 36, color: hintColor),
                          const SizedBox(height: 12),
                          Text('No live assets registered yet', style: TextStyle(color: hintColor, fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _assets.length,
                      itemBuilder: (context, idx) {
                        final asset = _assets[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.corporate_fare_rounded, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      asset.name,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Valuation Range: \$${asset.minPrice.toStringAsFixed(0)} - \$${asset.maxPrice.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 10, color: hintColor, fontWeight: FontWeight.w500),
                                    )
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, size: 16, color: hintColor),
                                onPressed: () => _addOrEditAsset(asset: asset, index: idx),
                                style: IconButton.styleFrom(
                                  hoverColor: AppColors.primary.withOpacity(0.1),
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                onPressed: () => _removeAsset(idx),
                                style: IconButton.styleFrom(
                                  hoverColor: AppColors.error.withOpacity(0.1),
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isMobile) ...[
                          leftColumn,
                          const SizedBox(height: 20),
                          rightColumn,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: leftColumn),
                              const SizedBox(width: 20),
                              Expanded(flex: 6, child: rightColumn),
                            ],
                          ),
                        const SizedBox(height: 32),

                        // Actions footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Save Stock configuration',
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
}
