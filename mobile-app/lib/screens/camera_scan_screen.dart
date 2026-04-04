import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  bool _scanning = false;
  bool _showCropSelection = true;
  String _captureMode = 'photo';
  bool _isRecording = false;
  int _recordingTime = 0;
  Timer? _timer;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final crop = context.read<CropProvider>();
    if (crop.hasCropSelected) {
      _showCropSelection = false;
    }
  }

  Future<void> _handleCapture() async {
    final crop = context.read<CropProvider>();
    if (!crop.hasCropSelected) {
      setState(() => _showCropSelection = true);
      return;
    }

    if (_captureMode == 'photo') {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _submitScan(File(photo.path));
      }
    } else {
      // Start/Stop video recording
      if (_isRecording) {
        // Stop recording
        _timer?.cancel();
        setState(() {
          _isRecording = false;
          _scanning = true;
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => _scanning = false);
          context.push('/scan-result');
        });
      } else {
        // Start recording
        setState(() {
          _isRecording = true;
          _recordingTime = 0;
        });
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_recordingTime >= 30) {
              _timer?.cancel();
              _isRecording = false;
              _scanning = true;
              Future.delayed(const Duration(seconds: 2), () {
                if (!mounted) return;
                setState(() => _scanning = false);
                context.push('/scan-result');
              });
              _recordingTime = 0;
            } else {
              _recordingTime++;
            }
          });
        });
      }
    }
  }

  Future<void> _submitScan(File imageFile) async {
    setState(() => _scanning = true);
    final crop = context.read<CropProvider>();
    final scanProvider = context.read<ScanHistoryProvider>();
    final result = await scanProvider.submitScan(
      imageFile: imageFile,
      cropType: crop.selectedCrop,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result != null) {
      context.push('/scan-result', extra: result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scanProvider.errorMessage ?? 'Scan failed'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final crop = context.watch<CropProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View Placeholder
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.width * 0.85 * 4 / 3,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF4CAF50),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'REC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              _formatTime(_recordingTime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_scanning)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF4CAF50),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lang.t('scan.analyzing'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Top Bar - Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // Crop Selection Overlay
          if (_showCropSelection)
            Container(
              color: Colors.black.withValues(alpha: 0.9),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.t('scan.selectCrop'),
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.t('scan.selectCropDesc'),
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        physics: const NeverScrollableScrollPhysics(),
                        children: CropProvider.crops.map((cropInfo) {
                          return GestureDetector(
                            onTap: () {
                              crop.selectCrop(cropInfo.value);
                              setState(() => _showCropSelection = false);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: crop.selectedCrop == cropInfo.value
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE0E0E0),
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cropInfo.emoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    lang.isRTL
                                        ? cropInfo.labelAr
                                        : cropInfo.labelEn,
                                    style: const TextStyle(
                                      color: Color(0xFF424242),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected Crop Indicator
                  if (crop.hasCropSelected && !_showCropSelection)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showCropSelection = true),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              crop.selectedCropInfo?.emoji ?? '',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lang.isRTL
                                  ? (crop.selectedCropInfo?.labelAr ?? '')
                                  : (crop.selectedCropInfo?.labelEn ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Instructions
                  Text(
                    _captureMode == 'photo' 
                      ? lang.t('scan.instruction') 
                      : lang.t('scan.videoInstruction'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _captureMode == 'photo' 
                      ? lang.t('scan.tip1') 
                      : lang.t('scan.videoTip'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Photo Mode Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _captureMode = 'photo';
                            _isRecording = false;
                            _recordingTime = 0;
                            _timer?.cancel();
                          });
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _captureMode == 'photo' 
                              ? const Color(0xFF4CAF50) 
                              : Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: _captureMode == 'photo' 
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Icon(
                            Icons.image_rounded,
                            color: _captureMode == 'photo' ? Colors.white : Colors.white.withValues(alpha: 0.7),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Capture button
                      GestureDetector(
                        onTap: _scanning ? null : _handleCapture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isRecording 
                                ? Colors.red[600] 
                                : (_scanning 
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.5) 
                                    : const Color(0xFF4CAF50)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : const Color(0xFF4CAF50))
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _captureMode == 'photo'
                                ? Icons.camera_alt_rounded
                                : (_isRecording ? Icons.stop_circle_rounded : Icons.videocam_rounded),
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Video Mode Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _captureMode = 'video';
                            _isRecording = false;
                            _recordingTime = 0;
                            _timer?.cancel();
                          });
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _captureMode == 'video' 
                              ? const Color(0xFF4CAF50) 
                              : Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: _captureMode == 'video' 
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Icon(
                            Icons.videocam_rounded,
                            color: _captureMode == 'video' ? Colors.white : Colors.white.withValues(alpha: 0.7),
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Mode Label
                  Text(
                    _captureMode == 'photo' ? lang.t('scan.photoMode') : lang.t('scan.videoMode'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
