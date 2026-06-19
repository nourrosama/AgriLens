import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// Splash screen — shows logo + tagline for 2.5s then navigates to language
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      await _checkForUpdate();
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      while (mounted && !userProvider.isHydrated) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      if (userProvider.isLoggedIn) {
        if (userProvider.isAdmin) {
          context.go('/admin');
          return;
        }
        context.read<ScanHistoryProvider>().syncQueuedScans();
        if (userProvider.isTrialExpired) {
          context.go('/subscription-plans');
          return;
        }
      }
      context.go(userProvider.isLoggedIn ? '/home' : '/onboarding');
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/api/version'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 || !mounted) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final serverVersion = data['version'] as String? ?? '';
      final apkUrl = data['apk_url'] as String? ?? '';

      final info = await PackageInfo.fromPlatform();
      final localVersion = info.version;

      if (_isNewer(serverVersion, localVersion) && mounted) {
        await _showUpdateDialog(apkUrl);
      }
    } catch (_) {
      // Silent fail — don't block app launch if version check fails
    }
  }

  bool _isNewer(String server, String local) {
    final s = server.split('.').map(int.tryParse).toList();
    final l = local.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final sv = i < s.length ? (s[i] ?? 0) : 0;
      final lv = i < l.length ? (l[i] ?? 0) : 0;
      if (sv > lv) return true;
      if (sv < lv) return false;
    }
    return false;
  }

  Future<void> _showUpdateDialog(String apkUrl) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of AgriLens is available. Update now for the latest features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(apkUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.background],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 128, height: 128),
              const SizedBox(height: 24),
              Text(
                'AgriLens',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart Crop Disease Detection',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
