import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../models/company_fund.dart';
import '../../../../core/theme/app_theme.dart';

class FundManageDialog extends StatefulWidget {
  final CompanyFund? fund;
  final Function({
    required String title,
    required String description,
    required double amount,
    required String tags,
    required DateTime date,
    String? fid,
  }) onSave;

  const FundManageDialog({
    Key? key,
    this.fund,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FundManageDialog> createState() => _FundManageDialogState();
}

class _FundManageDialogState extends State<FundManageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _tagsController;
  late TextEditingController _fidController;
  late DateTime _selectedDate;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy · hh:mm a');

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.fund?.title ?? '');
    _descriptionController = TextEditingController(text: widget.fund?.description ?? '');
    _amountController = TextEditingController(
      text: widget.fund != null ? widget.fund!.amount.toStringAsFixed(2) : '',
    );
    _tagsController = TextEditingController(text: widget.fund?.tags ?? '');
    _fidController = TextEditingController(text: widget.fund?.fid ?? '');
    _selectedDate = widget.fund?.date ?? DateTime.now();

    // If creating a new fund, generate a preview/placeholder FID
    if (widget.fund == null && _fidController.text.isEmpty) {
      final random = Random();
      final rand1 = random.nextInt(900) + 100;
      final rand2 = random.nextInt(9000) + 1000;
      _fidController.text = 'FID-$rand1-$rand2';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _tagsController.dispose();
    _fidController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isDark) async {
    final theme = Theme.of(context);
    final primaryColor = AppColors.primary;
    final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: dialogBg,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: dialogBg,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: dialogBg,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Normalize tags: split by comma, trim, limit to 5, and join back with comma
      final rawTags = _tagsController.text.trim();
      final tagList = rawTags
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(5)
          .toList();
      final normalizedTags = tagList.join(', ');

      widget.onSave(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.tryParse(_amountController.text.trim()) ?? 0.0,
        tags: normalizedTags,
        date: _selectedDate,
        fid: _fidController.text.trim().isNotEmpty ? _fidController.text.trim() : null,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.fund == null ? IconsaxPlusLinear.add_square : IconsaxPlusLinear.edit,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.fund == null ? 'Add Company Fund' : 'Edit Company Fund',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tracking ID (FID)
                Text(
                  'Fund Tracker UID (FID)',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    controller: _fidController,
                    readOnly: true,
                    style: GoogleFonts.outfit(
                      color: textColor.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'e.g. FID-123-4567',
                      hintStyle: GoogleFonts.outfit(color: hintColor),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: hintColor),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-gen',
                              style: GoogleFonts.outfit(color: hintColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Tracking ID is missing';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Fund Title',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    controller: _titleController,
                    style: GoogleFonts.outfit(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'e.g. Marketing Grant',
                      hintStyle: GoogleFonts.outfit(color: hintColor),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                Text(
                  'Fund Amount',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'e.g. 50000.00',
                      hintStyle: GoogleFonts.outfit(color: hintColor),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amt = double.tryParse(value);
                      if (amt == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Tags (Up to 5, comma-separated)
                Text(
                  'Tags (Max 5, comma-separated)',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    controller: _tagsController,
                    style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'e.g. Marketing, Investment, Tech',
                      hintStyle: GoogleFonts.outfit(color: hintColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date & Time Picker
                Text(
                  'Fund Date & Time',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _selectDateTime(context, isDark),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateFormat.format(_selectedDate),
                          style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                        ),
                        Icon(
                          IconsaxPlusLinear.calendar,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Description',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintText: 'Provide a brief reason or notes for the fund...',
                      hintStyle: GoogleFonts.outfit(color: hintColor),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(color: hintColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
