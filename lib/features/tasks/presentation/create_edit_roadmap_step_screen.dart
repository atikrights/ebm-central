import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/system_task.dart';

class CreateEditRoadmapStepScreen extends StatefulWidget {
  final RoadmapStep? step;
  final String taskNumber;
  final int stepIndex;
  final bool isParentArchived;
  final Future<void> Function({
    required String title,
    required String description,
    required String priority,
    required DateTime? startTime,
    required DateTime? endTime,
    required bool isLocked,
  }) onSave;

  const CreateEditRoadmapStepScreen({
    super.key,
    this.step,
    required this.taskNumber,
    required this.stepIndex,
    required this.isParentArchived,
    required this.onSave,
  });

  @override
  State<CreateEditRoadmapStepScreen> createState() => _CreateEditRoadmapStepScreenState();
}

class _CreateEditRoadmapStepScreenState extends State<CreateEditRoadmapStepScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _priority;
  DateTime? _startTime;
  DateTime? _endTime;
  late bool _isLocked;
  bool _isSaving = false;

  final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy · hh:mm a');

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.step?.title ?? '');
    _descCtrl = TextEditingController(text: widget.step?.description ?? '');
    _priority = widget.step?.priority ?? 'Medium';
    _startTime = widget.step?.startTime;
    _endTime = widget.step?.endTime;
    _isLocked = widget.step?.isLocked ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initial, bool isDark) async {
    final theme = Theme.of(context);
    final primaryColor = AppColors.primary;
    final dialogBg = isDark ? const Color(0xFF09090D) : Colors.white;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime != null && _endTime != null && _endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ End Date & Time must be after Start Date & Time.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        priority: _priority,
        startTime: _startTime,
        endTime: _endTime,
        isLocked: _isLocked,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Failed to save step: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    final base = widget.taskNumber.replaceAll('TSK-', '').replaceAll('STP-', '');
    final stepCode = widget.step?.id ?? 'STP-$base-${widget.stepIndex + 1}';

    // Check if configuration is locked
    final bool isConfigLocked = (widget.step?.isLocked ?? false) && !widget.isParentArchived;

    InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: subColor, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.7)),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(IconsaxPlusLinear.arrow_left, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.step == null ? 'Create Execution Step' : 'Edit Execution Step',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stepCode,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isConfigLocked)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This step is locked. Change session status to Draft (Private) to edit.',
                            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Form Container Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step Details',
                        style: GoogleFonts.outfit(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Step Title Input
                      TextFormField(
                        controller: _titleCtrl,
                        enabled: !isConfigLocked,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: _fieldDeco('Step Title *', IconsaxPlusLinear.edit),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Step title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Step Description Input
                      TextFormField(
                        controller: _descCtrl,
                        enabled: !isConfigLocked,
                        maxLines: 6,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: _fieldDeco('Step Description (Optional)', IconsaxPlusLinear.document_text),
                      ),
                      const SizedBox(height: 16),

                      // Priority Dropdown
                      DropdownButtonFormField<String>(
                        value: _priority,
                        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: _fieldDeco('Priority Level', Icons.flag_rounded),
                        items: const [
                          DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                          DropdownMenuItem(value: 'High', child: Text('High')),
                          DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                        ],
                        onChanged: isConfigLocked
                            ? null
                            : (val) {
                                if (val != null) setState(() => _priority = val);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Scheduling Container Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time Allocation',
                            style: GoogleFonts.outfit(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          if (_startTime != null || _endTime != null)
                            TextButton(
                              onPressed: isConfigLocked
                                  ? null
                                  : () {
                                      setState(() {
                                        _startTime = null;
                                        _endTime = null;
                                      });
                                    },
                              child: Text(
                                'Clear Times',
                                style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Start Date Time Selector
                      Text('Start Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: isConfigLocked
                            ? null
                            : () async {
                                final picked = await _selectDateTime(context, _startTime ?? DateTime.now(), isDark);
                                if (picked != null) {
                                  setState(() => _startTime = picked);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _startTime == null ? 'Not Set (Default Scheduled Time)' : _dateTimeFormat.format(_startTime!),
                                style: GoogleFonts.outfit(fontSize: 13, color: _startTime == null ? subColor : textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // End Date Time Selector
                      Text('End Date & Time', style: GoogleFonts.outfit(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: isConfigLocked
                            ? null
                            : () async {
                                final picked = await _selectDateTime(context, _endTime ?? DateTime.now().add(const Duration(hours: 1)), isDark);
                                if (picked != null) {
                                  setState(() => _endTime = picked);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _endTime == null ? 'Not Set (Default Scheduled Time)' : _dateTimeFormat.format(_endTime!),
                                style: GoogleFonts.outfit(fontSize: 13, color: _endTime == null ? subColor : textColor, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Settings Container Card
                if (widget.step != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text('Lock Process', style: GoogleFonts.outfit(fontSize: 14, color: textColor, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _isLocked
                            ? 'Locked - No modifications allowed'
                            : 'Unlocked - Editing & status change enabled',
                        style: GoogleFonts.outfit(fontSize: 11, color: subColor),
                      ),
                      value: _isLocked,
                      activeColor: Colors.redAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: isConfigLocked
                          ? null
                          : (val) {
                              setState(() => _isLocked = val);
                            },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(color: subColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isSaving || isConfigLocked) ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                widget.step == null ? 'Create Step' : 'Save Changes',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
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
