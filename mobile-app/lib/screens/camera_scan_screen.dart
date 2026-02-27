import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// Camera scan screen — mockup camera view with capture button
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  bool _scanning = false;

  void _handleCapture() {
    setState(() => _scanning = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.push('/scan-result');
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera viewfinder placeholder
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.width * 1.1,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _scanning
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 64,
                            color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(lang.t('scan.analyzing'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20)),
                      ],
                    )
                  : null,
            ),
          ),

          // Top bar — close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                children: [
                  Text(lang.t('scan.instruction'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(lang.t('scan.tip1'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Gallery button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.image_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 24),
                      // Capture button
                      GestureDetector(
                        onTap: _scanning ? null : _handleCapture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _scanning
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(width: 24),
                      const SizedBox(width: 56, height: 56),
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
