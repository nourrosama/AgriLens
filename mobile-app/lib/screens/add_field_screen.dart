import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class AddFieldScreen extends StatefulWidget {
  const AddFieldScreen({super.key});
  @override
  State<AddFieldScreen> createState() => _AddFieldScreenState();
}

class _AddFieldScreenState extends State<AddFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '', _location = '', _area = '';
  String? _cropType, _soilType, _irrigationType;
  bool _showSuccess = false;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      debugPrint('Field: $_name, Location: $_location, Area: $_area');
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/fields');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    if (_showSuccess) return _successView(lang);

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
                      _infoBanner(lang),
                      const SizedBox(height: 24),
                      _textField(lang.t('addField.name'), lang.t('addField.namePlaceholder'), (v) => _name = v, required: true),
                      const SizedBox(height: 24),
                      _locationField(lang),
                      const SizedBox(height: 24),
                      _textField(lang.t('addField.area'), lang.t('addField.areaPlaceholder'), (v) => _area = v, required: true, isNumber: true),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(lang.isRTL ? '٢ فدان = ٨٤٠٠ متر مربع' : '2 Feddan = 8,400 m²',
                            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
                      ),
                      const SizedBox(height: 24),
                      _dropdown(lang.t('addField.cropType'), lang.t('addField.selectCrop'), _cropType,
                          [for (final c in ['wheat', 'rice', 'corn', 'tomatoes', 'potatoes', 'cotton', 'onions', 'beans', 'other'])
                            DropdownMenuItem(value: c, child: Text(lang.t('crops.$c')))],
                          (v) => setState(() => _cropType = v), required: true),
                      const SizedBox(height: 24),
                      _dropdown(lang.t('addField.soilType'), lang.t('addField.selectSoil'), _soilType,
                          [for (final s in ['clay', 'sandy', 'loamy', 'silty'])
                            DropdownMenuItem(value: s, child: Text(lang.t('soil.$s')))],
                          (v) => setState(() => _soilType = v)),
                      const SizedBox(height: 24),
                      _dropdown(lang.t('addField.irrigation'), lang.t('addField.selectIrrigation'), _irrigationType,
                          [for (final i in ['drip', 'sprinkler', 'surface', 'manual', 'rainfed'])
                            DropdownMenuItem(value: i, child: Text(lang.t('irrigation.$i')))],
                          (v) => setState(() => _irrigationType = v)),
                      const SizedBox(height: 24),
                      // Photo
                      Text(lang.t('addField.photo'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.primary, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.camera_alt_rounded, size: 48, color: AppColors.primary),
                            const SizedBox(height: 12),
                            Text(lang.t('addField.takePhoto'), style: const TextStyle(color: AppColors.primary, fontSize: 18)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(lang.t('addField.submit'), style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/fields'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            side: const BorderSide(color: AppColors.border, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(lang.t('common.cancel'), style: const TextStyle(fontSize: 20, color: AppColors.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/fields'),
          child: Padding(padding: const EdgeInsets.all(8),
              child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary))),
        ),
        const SizedBox(width: 16),
        Text(lang.t('addField.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoBanner(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(child: Text(lang.t('addField.infoBanner'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 16))),
      ]),
    );
  }

  Widget _textField(String label, String hint, Function(String) onSaved, {bool required = false, bool isNumber = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label${required ? ' *' : ''}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
      const SizedBox(height: 12),
      TextFormField(
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? '' : null : null,
        onSaved: (v) => onSaved(v ?? ''),
      ),
    ]);
  }

  Widget _locationField(LanguageProvider lang) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${lang.t('addField.location')} *', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
      const SizedBox(height: 12),
      TextFormField(
        decoration: InputDecoration(
          hintText: lang.t('addField.locationPlaceholder'),
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          prefixIcon: const Icon(Icons.location_on, color: Color(0xFF9E9E9E)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (v) => (v == null || v.isEmpty) ? '' : null,
        onSaved: (v) => _location = v ?? '',
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.map_rounded, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(lang.t('addField.markOnMap'), style: const TextStyle(color: AppColors.primary, fontSize: 16)),
      ]),
    ]);
  }

  Widget _dropdown(String label, String hint, String? value, List<DropdownMenuItem<String>> items,
      Function(String?) onChanged, {bool required = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label${required ? ' *' : ''}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: required ? (v) => (v == null) ? '' : null : null,
      ),
    ]);
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
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 24),
            Text(lang.t('addField.successTitle'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(lang.t('addField.successMessage'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}
