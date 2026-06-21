import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/crop_provider.dart';

/// Calls Nominatim reverse-geocoding and returns a display name or empty string.
Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=$lat&lon=$lng&accept-language=en',
    );
    final resp = await http.get(uri, headers: {'User-Agent': 'AgriLens/1.0'})
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['display_name']?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}

class AddFieldScreen extends StatefulWidget {
  const AddFieldScreen({super.key});
  @override
  State<AddFieldScreen> createState() => _AddFieldScreenState();
}

class _AddFieldScreenState extends State<AddFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  String _name = '',
      _location = '',
      _area = '',
      _latitude = '',
      _longitude = '';
  String? _cropType = 'tomato', _soilType, _irrigationType;
  bool _showSuccess = false;
  bool _isLocating = false;
  XFile? _pickedImage;
  bool _uploadingPhoto = false;
  String? _uploadedPhotoUrl;
  final _apiClient = ApiClient();

  bool get _hasSelectedLocation =>
      _latitudeCtrl.text.trim().isNotEmpty &&
      _longitudeCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _locationNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedImage = picked;
      _uploadingPhoto = true;
    });
    try {
      final response = await _apiClient.multipart(
        '/api/farms/field-photo',
        file: File(picked.path),
        fieldName: 'photo',
        auth: true,
      );
      final url = (response['data'] as Map<String, dynamic>?)?['photo_url']
          ?.toString();
      if (mounted) setState(() => _uploadedPhotoUrl = url);
    } catch (_) {
      if (mounted) setState(() => _uploadedPhotoUrl = null);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _latitude = _latitudeCtrl.text.trim();
      _longitude = _longitudeCtrl.text.trim();

      if (!_hasSelectedLocation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Choose the field location from current location or map.',
            ),
          ),
        );
        return;
      }

      await context.read<FieldsProvider>().addField(
        name: _name,
        location: _location,
        area: _area,
        latitude: double.tryParse(_latitude),
        longitude: double.tryParse(_longitude),
        cropType: _cropType,
        soilType: _soilType,
        irrigationType: _irrigationType,
        photoUrl: _uploadedPhotoUrl,
      );

      if (!mounted) {
        return;
      }
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/fields');
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationMessage('Turn on location services, then try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is required to use current location.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _setSelectedLocation(LatLng(position.latitude, position.longitude));
    } catch (_) {
      _showLocationMessage(
        'Unable to read current location. Try marking it on the map.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _markOnMap() async {
    final initialLat = double.tryParse(_latitudeCtrl.text);
    final initialLng = double.tryParse(_longitudeCtrl.text);
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _FieldLocationPicker(
          initialPoint: initialLat != null && initialLng != null
              ? LatLng(initialLat, initialLng)
              : const LatLng(30.0444, 31.2357),
        ),
      ),
    );

    if (picked == null) {
      return;
    }
    _setSelectedLocation(picked);
  }

  void _setSelectedLocation(LatLng point) {
    setState(() {
      _latitudeCtrl.text = point.latitude.toStringAsFixed(6);
      _longitudeCtrl.text = point.longitude.toStringAsFixed(6);
    });
    _reverseGeocode(point.latitude, point.longitude).then((name) {
      if (mounted && name.isNotEmpty && _locationNameCtrl.text.isEmpty) {
        setState(() => _locationNameCtrl.text = name);
      }
    });
  }

  void _showLocationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
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
                      _textField(
                        lang.t('addField.name'),
                        lang.t('addField.namePlaceholder'),
                        (v) => _name = v,
                        required: true,
                      ),
                      const SizedBox(height: 24),
                      _locationField(lang),
                      const SizedBox(height: 24),
                      _textField(
                        lang.t('addField.area'),
                        lang.t('addField.areaPlaceholder'),
                        (v) => _area = v,
                        required: true,
                        isNumber: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          lang.isRTL
                              ? '٢ فدان = ٨٤٠٠ متر مربع'
                              : '2 Feddan = 8,400 m²',
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _cropGrid(lang),
                      const SizedBox(height: 24),
                      _dropdown(
                        lang.t('addField.soilType'),
                        lang.t('addField.selectSoil'),
                        _soilType,
                        [
                          for (final s in ['clay', 'sandy', 'loamy', 'silty'])
                            DropdownMenuItem(
                              value: s,
                              child: Text(lang.t('soil.$s')),
                            ),
                        ],
                        (v) => setState(() => _soilType = v),
                      ),
                      const SizedBox(height: 24),
                      _dropdown(
                        lang.t('addField.irrigation'),
                        lang.t('addField.selectIrrigation'),
                        _irrigationType,
                        [
                          for (final i in [
                            'drip',
                            'sprinkler',
                            'surface',
                            'manual',
                            'rainfed',
                          ])
                            DropdownMenuItem(
                              value: i,
                              child: Text(lang.t('irrigation.$i')),
                            ),
                        ],
                        (v) => setState(() => _irrigationType = v),
                      ),
                      const SizedBox(height: 24),
                      // Photo
                      Text(
                        lang.t('addField.photo'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _uploadingPhoto ? null : _pickAndUploadImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: _uploadedPhotoUrl != null
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _uploadingPhoto
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : _pickedImage != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(_pickedImage!.path),
                                            fit: BoxFit.cover,
                                          ),
                                          if (_uploadedPhotoUrl == null)
                                            Container(
                                              color: Colors.black26,
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                lang.isRTL
                                                    ? 'تغيير الصورة'
                                                    : 'Change photo',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            lang.t('addField.takePhoto'),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: fieldsProvider.isLoading ? null : _submit,
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
                                : lang.t('addField.submit'),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/fields'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            side: const BorderSide(
                              color: AppColors.border,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            lang.t('common.cancel'),
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
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

  Widget _cropGrid(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${lang.t('addField.cropType')} *',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.25,
          physics: const NeverScrollableScrollPhysics(),
          children: CropProvider.crops.map((crop) {
            final selected = _cropType == crop.value;
            final label = lang.isRTL ? crop.labelAr : crop.labelEn;
            return GestureDetector(
              onTap: () => setState(() => _cropType = crop.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 3 : 2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(crop.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _header(LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/fields'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Transform.flip(
                flipX: lang.isRTL,
                child: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            lang.t('addField.title'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              lang.t('addField.infoBanner'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    String label,
    String hint,
    Function(String) onSaved, {
    bool required = false,
    bool isNumber = false,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
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
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '' : null
              : null,
          onSaved: (v) => onSaved(v ?? ''),
        ),
      ],
    );
  }

  Widget _locationField(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${lang.t('addField.location')} *',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationNameCtrl,
          decoration: InputDecoration(
            hintText: lang.t('addField.locationPlaceholder'),
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF9E9E9E)),
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
          onSaved: (v) => _location = v ?? '',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLocating ? null : _useCurrentLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(_isLocating
                    ? (lang.isRTL ? 'جارٍ التحديد...' : 'Locating...')
                    : (lang.isRTL ? 'موقعي الحالي' : 'Use current')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _markOnMap,
                icon: const Icon(Icons.map_rounded),
                label: Text(lang.t('addField.markOnMap')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_hasSelectedLocation) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isRTL ? 'تم تحديد الموقع' : 'Location selected',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_locationNameCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _locationNameCtrl.text,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dropdown(
    String label,
    String hint,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
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
          validator: required ? (v) => (v == null) ? '' : null : null,
        ),
      ],
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
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                lang.t('addField.successTitle'),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.t('addField.successMessage'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLocationPicker extends StatefulWidget {
  const _FieldLocationPicker({required this.initialPoint});

  final LatLng initialPoint;

  @override
  State<_FieldLocationPicker> createState() => _FieldLocationPickerState();
}

class _FieldLocationPickerState extends State<_FieldLocationPicker> {
  late LatLng _selectedPoint = widget.initialPoint;
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&q=${Uri.encodeComponent(query)}&limit=5&accept-language=en',
      );
      final resp = await http.get(uri, headers: {'User-Agent': 'AgriLens/1.0'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _searchResults = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _searching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(result['lon']?.toString() ?? '') ?? 0;
    final point = LatLng(lat, lon);
    setState(() {
      _selectedPoint = point;
      _searchResults = [];
      _searchCtrl.clear();
    });
    _mapController.move(point, 14);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        title: Text(isRTL ? 'تحديد موقع الحقل' : 'Mark Field Location'),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: isRTL ? 'ابحث عن موقع...' : 'Search for a location...',
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: _search,
                  onChanged: (v) {
                    setState(() {});
                    _debounce?.cancel();
                    if (v.trim().isEmpty) {
                      setState(() => _searchResults = []);
                      return;
                    }
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      () => _search(v),
                    );
                  },
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary, size: 20),
                          title: Text(
                            r['display_name']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 12,
                onTap: (_, point) => setState(() => _selectedPoint = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agrilens.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 56,
                      height: 56,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRTL
                      ? 'اضغط على الخريطة لتحديد موقع الحقل.'
                      : 'Tap the map to place the field marker.',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selectedPoint),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(isRTL ? 'استخدم هذا الموقع' : 'Use this location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
