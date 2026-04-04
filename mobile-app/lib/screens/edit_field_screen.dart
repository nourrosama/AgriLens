import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/fields_provider.dart';

/// Edit field screen — matches TSX EditField.tsx exactly:
/// Pre-filled form, delete confirmation dialog, success view, fixed save button
class EditFieldScreen extends StatefulWidget {
  final String fieldId;
  const EditFieldScreen({super.key, required this.fieldId});

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showSuccess = false;
  bool _showDeleteConfirm = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _areaCtrl;
  String? _cropType;
  String? _soilType;
  String? _irrigationType;
  FieldData? _field;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final fieldsProvider = context.read<FieldsProvider>();
      _field = fieldsProvider.getField(widget.fieldId);
      _nameCtrl = TextEditingController(text: _field?.name ?? '');
      _locationCtrl = TextEditingController(text: _field?.location ?? '');
      _areaCtrl = TextEditingController(text: _field?.area ?? '');
      _cropType = _field?.cropType;
      _soilType = _field?.soilType;
      _irrigationType = _field?.irrigationType;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate() && _field != null) {
      _formKey.currentState!.save();

      await context.read<FieldsProvider>().updateField(
        _field!.id,
        name: _nameCtrl.text,
        location: _locationCtrl.text,
        area: _areaCtrl.text,
        cropType: _cropType,
        soilType: _soilType,
        irrigationType: _irrigationType,
      );

      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/field-overview/${widget.fieldId}');
      });
    }
  }

  Future<void> _confirmDelete() async {
    if (_field != null) {
      await context.read<FieldsProvider>().deleteField(_field!.id);
      if (!mounted) {
        return;
      }
      context.go('/fields');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();

    // Delete confirmation dialog
    if (_showDeleteConfirm) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 48,
                    color: Color(0xFFF44336),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.isRTL ? 'حذف الحقل؟' : 'Delete Field?',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.isRTL
                      ? 'لا يمكن التراجع عن هذا الإجراء. سيتم حذف جميع بيانات الحقل نهائياً.'
                      : 'This action cannot be undone. All field data will be permanently removed.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      lang.isRTL ? 'نعم، احذف الحقل' : 'Yes, Delete Field',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showDeleteConfirm = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.border,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      lang.t('common.cancel'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Success view
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.isRTL ? 'تم التحديث بنجاح!' : 'Updated Successfully!',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.isRTL
                      ? 'تم تحديث معلومات الحقل'
                      : 'Field information has been updated',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main form
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    lang.isRTL ? 'تعديل الحقل' : 'Edit Field',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Form body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        lang.isRTL ? 'اسم الحقل' : 'Field Name',
                        _nameCtrl,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        lang.isRTL ? 'الموقع' : 'Location',
                        _locationCtrl,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        '${lang.isRTL ? 'المساحة' : 'Area'} (${lang.t('units.feddan')})',
                        _areaCtrl,
                        isNumber: true,
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        lang.isRTL ? 'نوع المحصول' : 'Crop Type',
                        _cropType,
                        [
                              'wheat',
                              'rice',
                              'corn',
                              'tomatoes',
                              'potatoes',
                              'cotton',
                              'onions',
                              'beans',
                              'other',
                            ]
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(lang.t('crops.$c')),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _cropType = v),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        lang.isRTL ? 'نوع التربة' : 'Soil Type',
                        _soilType,
                        ['clay', 'sandy', 'loamy', 'silty']
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(lang.t('soil.$s')),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _soilType = v),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        lang.isRTL ? 'نوع الري' : 'Irrigation Type',
                        _irrigationType,
                        ['drip', 'sprinkler', 'surface', 'manual', 'rainfed']
                            .map(
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(lang.t('irrigation.$i')),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _irrigationType = v),
                      ),
                      const SizedBox(height: 24),

                      // Delete button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _showDeleteConfirm = true),
                          icon: const Icon(Icons.delete_outline, size: 24),
                          label: Text(
                            lang.isRTL ? 'حذف الحقل' : 'Delete Field',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            foregroundColor: const Color(0xFFF44336),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 80,
                      ), // Space for fixed bottom button
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Fixed bottom save button
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: fieldsProvider.isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              fieldsProvider.isLoading
                  ? lang.t('common.loading')
                  : lang.t('common.save'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
