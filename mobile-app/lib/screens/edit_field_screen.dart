import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class EditFieldScreen extends StatefulWidget {
  const EditFieldScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showSuccess = false;
  bool _showDeleteConfirm = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _latitudeCtrl;
  late TextEditingController _longitudeCtrl;
  late TextEditingController _areaCtrl;
  String? _cropType = 'tomato';
  String? _soilType;
  String? _irrigationType;
  FieldData? _field;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final fieldsProvider = context.read<FieldsProvider>();
    _field = fieldsProvider.getField(widget.fieldId);
    _nameCtrl = TextEditingController(text: _field?.name ?? '');
    _locationCtrl = TextEditingController(text: _field?.location ?? '');
    _latitudeCtrl = TextEditingController(
      text: _field?.latitude?.toString() ?? '',
    );
    _longitudeCtrl = TextEditingController(
      text: _field?.longitude?.toString() ?? '',
    );
    _areaCtrl = TextEditingController(text: _field?.area ?? '');
    _soilType = _field?.soilType;
    _irrigationType = _field?.irrigationType;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _field == null) {
      return;
    }

    await context.read<FieldsProvider>().updateField(
      _field!.id,
      name: _nameCtrl.text,
      location: _locationCtrl.text,
      area: _areaCtrl.text,
      latitude: double.tryParse(_latitudeCtrl.text),
      longitude: double.tryParse(_longitudeCtrl.text),
      cropType: _cropType,
      soilType: _soilType,
      irrigationType: _irrigationType,
    );

    if (!mounted) {
      return;
    }
    setState(() => _showSuccess = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/field-overview/${widget.fieldId}');
      }
    });
  }

  Future<void> _confirmDelete() async {
    if (_field == null) {
      return;
    }
    await context.read<FieldsProvider>().deleteField(_field!.id);
    if (!mounted) {
      return;
    }
    context.go('/fields');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();

    if (_showDeleteConfirm) {
      return _deleteView(lang);
    }
    if (_showSuccess) {
      return _successView(lang);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(lang),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        lang.isRTL ? 'Field Name' : 'Field Name',
                        _nameCtrl,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        lang.isRTL ? 'Location' : 'Location',
                        _locationCtrl,
                      ),
                      const SizedBox(height: 20),
                      _buildField('Latitude', _latitudeCtrl, isNumber: true),
                      const SizedBox(height: 20),
                      _buildField('Longitude', _longitudeCtrl, isNumber: true),
                      const SizedBox(height: 20),
                      _buildField(
                        'Area (${lang.t('units.feddan')})',
                        _areaCtrl,
                        isNumber: true,
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Crop Type',
                        _cropType,
                        ['tomato', 'potato', 'apple']
                            .map(
                              (crop) => DropdownMenuItem(
                                value: crop,
                                child: Text(
                                  crop == 'apple'
                                      ? 'Apple'
                                      : lang.t('crops.$crop'),
                                ),
                              ),
                            )
                            .toList(),
                        (value) => setState(() => _cropType = value),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Soil Type',
                        _soilType,
                        ['clay', 'sandy', 'loamy', 'silty']
                            .map(
                              (soil) => DropdownMenuItem(
                                value: soil,
                                child: Text(lang.t('soil.$soil')),
                              ),
                            )
                            .toList(),
                        (value) => setState(() => _soilType = value),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Irrigation Type',
                        _irrigationType,
                        ['drip', 'sprinkler', 'surface', 'manual', 'rainfed']
                            .map(
                              (irrigation) => DropdownMenuItem(
                                value: irrigation,
                                child: Text(lang.t('irrigation.$irrigation')),
                              ),
                            )
                            .toList(),
                        (value) => setState(() => _irrigationType = value),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _showDeleteConfirm = true),
                          icon: const Icon(Icons.delete_outline, size: 24),
                          label: const Text(
                            'Delete Field',
                            style: TextStyle(fontSize: 16),
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
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
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

  Widget _header(LanguageProvider lang) {
    return Container(
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
          const Text(
            'Edit Field',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteView(LanguageProvider lang) {
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
              const Text(
                'Delete Field?',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. All field data will be permanently removed.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
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
                  child: const Text(
                    'Yes, Delete Field',
                    style: TextStyle(fontSize: 16),
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

  Widget _successView(LanguageProvider lang) {
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
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Updated Successfully!',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Field information has been updated',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
            ],
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
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
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
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? '' : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
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
