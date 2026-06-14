import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/language_provider.dart';

class CropSelectScreen extends StatelessWidget {
  const CropSelectScreen({super.key, this.farmId, this.fieldId});

  final String? farmId;
  final String? fieldId;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final crop = context.watch<CropProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            lang.isRTL ? Icons.arrow_forward : Icons.arrow_back,
            color: const Color(0xFF1E3A5F),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lang.t('scan.selectCrop'),
          style: const TextStyle(
            color: Color(0xFF1E3A5F),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              lang.t('scan.selectCropDesc'),
              style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: CropProvider.crops.map((cropInfo) {
                final selected = crop.selectedCrop == cropInfo.value;
                final label = lang.isRTL ? cropInfo.labelAr : cropInfo.labelEn;
                return GestureDetector(
                  onTap: () {
                    if (!cropInfo.scanEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang
                                .t('scan.cropComingSoon')
                                .replaceAll('{crop}', label),
                          ),
                          backgroundColor: const Color(0xFFF44336),
                        ),
                      );
                      return;
                    }
                    crop.selectCrop(cropInfo.value);
                    final params = <String, String>{
                      'cropType': cropInfo.value,
                    };
                    if ((farmId ?? '').isNotEmpty) params['farmId'] = farmId!;
                    if ((fieldId ?? '').isNotEmpty) params['fieldId'] = fieldId!;
                    context.go(
                      Uri(path: '/scan', queryParameters: params).toString(),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE0E0E0),
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: cropInfo.scanEnabled ? 1.0 : 0.42,
                          child: Text(
                            cropInfo.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF424242),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!cropInfo.scanEnabled) ...[
                          const SizedBox(height: 4),
                          Text(
                            lang.t('scan.comingSoon'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
