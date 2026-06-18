import 'dart:async';
import 'dart:io' as io;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';

import 'package:agrilens/core/web_file_picker_stub.dart'
    if (dart.library.html) 'package:agrilens/core/web_file_picker.dart'
    as web_picker;

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({
    super.key,
    this.farmId,
    this.fieldId,
    this.initialCropType,
  });

  final String? farmId;
  final String? fieldId;
  final String? initialCropType;

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  bool _scanning = false;
  bool _isCameraLoading = true;
  bool _isRecording = false;
  String _captureMode = 'photo';
  String? _cameraError;
  int _recordingTime = 0;
  Timer? _timer;

  bool get _cameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final crop = context.read<CropProvider>();
    if ((widget.initialCropType ?? '').isNotEmpty) {
      unawaited(crop.selectCrop(widget.initialCropType!));
    }
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;

    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _cameraController = null;
      return;
    }

    if (state == AppLifecycleState.resumed && !_scanning) {
      unawaited(_initializeCamera(cameraIndex: _selectedCameraIndex));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    setState(() {
      _isCameraLoading = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera was found on this device.');
      }

      _cameras = cameras;
      final preferredIndex = cameraIndex ?? _findBackCameraIndex(cameras);
      _selectedCameraIndex = preferredIndex < 0
          ? 0
          : (preferredIndex >= cameras.length
                ? cameras.length - 1
                : preferredIndex);

      final nextController = CameraController(
        cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await nextController.initialize();

      final previousController = _cameraController;
      _cameraController = nextController;
      await previousController?.dispose();

      if (!mounted) return;
      setState(() => _isCameraLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
        _isCameraLoading = false;
      });
    }
  }

  int _findBackCameraIndex(List<CameraDescription> cameras) {
    final backIndex = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    return backIndex >= 0 ? backIndex : 0;
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _handleCapture() async {
    if (_scanning) return;

    final crop = context.read<CropProvider>();
    if (!crop.hasCropSelected) {
      _goToCropSelect();
      return;
    }

    if (!_cameraReady) {
      _showError('Camera is still loading. Please wait a moment.');
      return;
    }

    if (_captureMode == 'photo') {
      await _capturePhoto();
      return;
    }

    if (_isRecording) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  void _goToCropSelect() {
    final params = <String, String>{};
    if ((widget.farmId ?? '').isNotEmpty) params['farmId'] = widget.farmId!;
    if ((widget.fieldId ?? '').isNotEmpty) params['fieldId'] = widget.fieldId!;
    context.push(
      Uri(path: '/crop-select', queryParameters: params).toString(),
    );
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final photo = await controller.takePicture();
      await _submitScan(io.File(photo.path));
    } catch (error) {
      _showError('Failed to capture photo: $error');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_scanning) return;

    final crop = context.read<CropProvider>();
    if (!crop.hasCropSelected) {
      _goToCropSelect();
      return;
    }

    if (kIsWeb) {
      await _pickFromGalleryWeb();
      return;
    }

    try {
      if (_captureMode == 'photo') {
        final photo = await _picker.pickImage(source: ImageSource.gallery);
        if (photo != null) await _submitScan(io.File(photo.path));
        return;
      }
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) await _submitVideo(io.File(video.path));
    } catch (error) {
      _showError('Failed to open gallery: $error');
    }
  }

  Future<void> _pickFromGalleryWeb() async {
    try {
      final result = await web_picker.pickImageFromWeb();
      if (result == null) return;
      final (bytes, name) = result;
      await _submitScanWeb(bytes, name);
    } catch (error) {
      _showError('Failed to open file picker: $error');
    }
  }

  Future<void> _submitScanWeb(Uint8List bytes, String filename) async {
    setState(() => _scanning = true);
    final crop = context.read<CropProvider>();
    final scanProvider = context.read<ScanHistoryProvider>();
    final result = await scanProvider.submitScan(
      imageBytes: bytes,
      imageName: filename,
      cropType: crop.selectedCrop,
      farmId: widget.farmId,
      fieldId: widget.fieldId,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result != null) {
      context.push('/scan-result', extra: result);
    } else if (scanProvider.validationFailure != null) {
      await _showValidationFailure(
        failure: scanProvider.validationFailure!,
        webImageBytes: bytes,
        webImageName: filename,
      );
    } else {
      _showError(scanProvider.errorMessage ?? 'Scan failed');
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.startVideoRecording();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_recordingTime >= 29) {
          timer.cancel();
          unawaited(_stopVideoRecording());
          return;
        }
        setState(() => _recordingTime += 1);
      });
      setState(() {
        _isRecording = true;
        _recordingTime = 0;
      });
    } catch (error) {
      _showError('Failed to start video recording: $error');
    }
  }

  Future<void> _stopVideoRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;

    try {
      final video = await controller.stopVideoRecording();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordingTime = 0;
      });
      await _submitVideo(io.File(video.path));
    } catch (error) {
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordingTime = 0;
      });
      _showError('Failed to stop video recording: $error');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _scanning || _isRecording) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera(cameraIndex: nextIndex);
  }

  Future<void> _submitScan(io.File imageFile) async {
    setState(() => _scanning = true);
    final crop = context.read<CropProvider>();
    final scanProvider = context.read<ScanHistoryProvider>();
    final result = await scanProvider.submitScan(
      imageFile: imageFile,
      cropType: crop.selectedCrop,
      farmId: widget.farmId,
      fieldId: widget.fieldId,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result != null) {
      context.push('/scan-result', extra: result);
    } else if (scanProvider.validationFailure != null) {
      await _showValidationFailure(
        failure: scanProvider.validationFailure!,
        imageFile: imageFile,
      );
    } else {
      _showError(scanProvider.errorMessage ?? 'Scan failed');
    }
  }

  Future<void> _submitVideo(io.File videoFile) async {
    setState(() => _scanning = true);
    final crop = context.read<CropProvider>();
    final scanProvider = context.read<ScanHistoryProvider>();
    final result = await scanProvider.submitVideoScan(
      videoFile: videoFile,
      cropType: crop.selectedCrop,
      farmId: widget.farmId,
      fieldId: widget.fieldId,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result == null) {
      // Upload failed or was queued offline — either way, inform user.
      _showError(scanProvider.errorMessage ?? 'Video upload failed');
      return;
    }
    // Backend accepted the upload and is processing in the background (202).
    // Don't navigate to the result screen — show a snackbar and go back.
    final isAr = context.read<LanguageProvider>().isRTL;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAr
              ? 'تم رفع الفيديو. ستصلك إشعار عند اكتمال التحليل.'
              : "Video uploaded! We'll notify you when analysis is complete.",
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    if (context.canPop()) context.pop();
  }

  String _cropLabel(String cropValue) {
    final cropProvider = context.read<CropProvider>();
    final lang = context.read<LanguageProvider>();
    return cropProvider.getLabel(cropValue, isRTL: lang.isRTL);
  }

  String _validationTitle(ScanValidationFailure failure) {
    switch (failure.errorCode) {
      case 'NOT_A_PLANT':
        return 'Not a plant';
      case 'UNSUPPORTED_CROP':
        return 'Crop not supported';
      case 'CROP_MISMATCH':
        return 'Wrong crop selected';
      default:
        return 'Scan validation failed';
    }
  }

  Future<void> _showValidationFailure({
    required ScanValidationFailure failure,
    io.File? imageFile,
    io.File? videoFile,
    Uint8List? webImageBytes,
    String? webImageName,
  }) async {
    final scanProvider = context.read<ScanHistoryProvider>();
    final detectedLabel = failure.canUseDetectedCrop
        ? _cropLabel(failure.detectedCrop)
        : '';

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_validationTitle(failure)),
          content: Text(failure.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('upload'),
              child: const Text('Upload another scan'),
            ),
            if (failure.errorCode == 'UNSUPPORTED_CROP')
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('choose'),
                child: const Text('Choose supported crop'),
              ),
            if (failure.canUseDetectedCrop)
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('use'),
                child: Text('Use $detectedLabel model'),
              ),
          ],
        );
      },
    );

    scanProvider.clearValidationFailure();
    if (!mounted) return;

    if (action == 'choose') {
      _goToCropSelect();
      return;
    }

    if (action != 'use' || !failure.canUseDetectedCrop) {
      return;
    }

    await context.read<CropProvider>().selectCrop(failure.detectedCrop);
    if (!mounted) return;

    if (webImageBytes != null) {
      await _submitScanWeb(webImageBytes, webImageName ?? 'scan.jpg');
    } else if (imageFile != null) {
      await _submitScan(imageFile);
    } else if (videoFile != null) {
      await _submitVideo(videoFile);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF44336),
      ),
    );
  }

  Widget _buildPreview(LanguageProvider lang) {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCameraLoading || !_cameraReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text(
              lang.t('common.loading'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final controller = _cameraController!;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final crop = context.watch<CropProvider>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview ──────────────────────────────────────────
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              height: MediaQuery.of(context).size.width * 0.88 * 4 / 3,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4CAF50), width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(lang),
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
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
                    ),
                ],
              ),
            ),
          ),

          // ── Close button ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),

          // ── Bottom controls ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Crop indicator chip — tap to change
                  GestureDetector(
                    onTap: _goToCropSelect,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: crop.hasCropSelected
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: crop.hasCropSelected
                              ? Colors.transparent
                              : Colors.white38,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (crop.hasCropSelected) ...[
                            Text(
                              crop.selectedCropInfo?.emoji ?? '',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lang.isRTL
                                  ? (crop.selectedCropInfo?.labelAr ?? '')
                                  : (crop.selectedCropInfo?.labelEn ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ] else ...[
                            const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lang.t('scan.selectCrop'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Photo / Video mode chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ModeChip(
                        label: lang.t('scan.photoMode'),
                        icon: Icons.photo_camera_rounded,
                        selected: _captureMode == 'photo',
                        onTap: () => setState(() {
                          _captureMode = 'photo';
                          _isRecording = false;
                          _recordingTime = 0;
                          _timer?.cancel();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _ModeChip(
                        label: lang.t('scan.videoMode'),
                        icon: Icons.videocam_rounded,
                        selected: _captureMode == 'video',
                        onTap: () => setState(() {
                          _captureMode = 'video';
                          _isRecording = false;
                          _recordingTime = 0;
                          _timer?.cancel();
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action row: gallery | shutter | flip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundActionButton(
                        icon: Icons.photo_library_rounded,
                        label: lang.t('scan.gallery'),
                        onTap: () => unawaited(_pickFromGallery()),
                      ),
                      const SizedBox(width: 28),
                      GestureDetector(
                        onTap: () => unawaited(_handleCapture()),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? Colors.red[600]
                                : (_scanning
                                      ? const Color(
                                          0xFF4CAF50,
                                        ).withValues(alpha: 0.5)
                                      : const Color(0xFF4CAF50)),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? Colors.red
                                        : const Color(0xFF4CAF50))
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _captureMode == 'photo'
                                ? Icons.camera_alt_rounded
                                : (_isRecording
                                      ? Icons.stop_circle_rounded
                                      : Icons.videocam_rounded),
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      _RoundActionButton(
                        icon: Icons.cameraswitch_rounded,
                        label: '',
                        onTap: () => unawaited(_switchCamera()),
                      ),
                    ],
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4CAF50)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
