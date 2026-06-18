import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/core/session_storage.dart';
import 'package:agrilens/widgets/admin_webview.dart';

/// Admin dashboard — only reachable when user.role == 'admin'.
/// Loads the Flask admin panel directly (skipping the web login screen)
/// by passing the Flutter JWT to /admin/auto-login on the same server.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Change to your machine's LAN IP when testing on a physical device.
  static const String _baseUrl = 'http://127.0.0.1:5000';

  String? _autoLoginUrl;

  @override
  void initState() {
    super.initState();
    _buildUrl();
  }

  Future<void> _buildUrl() async {
    final token = await SessionStorage().readToken();
    if (!mounted) return;
    setState(() {
      _autoLoginUrl = token != null && token.isNotEmpty
          ? '$_baseUrl/admin/auto-login?token=$token'
          : '$_baseUrl/admin/';
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await userProvider.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _autoLoginUrl == null
          ? const Center(child: CircularProgressIndicator())
          : AdminWebView(url: _autoLoginUrl!),
    );
  }
}
