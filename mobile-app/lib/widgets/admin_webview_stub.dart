// Mobile implementation — uses webview_flutter
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agrilens/core/user_provider.dart';

class AdminWebView extends StatefulWidget {
  final String url;
  const AdminWebView({super.key, required this.url});

  @override
  State<AdminWebView> createState() => _AdminWebViewState();
}

class _AdminWebViewState extends State<AdminWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterAdminLogout',
        onMessageReceived: (_) => _handleAdminLogout(),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          // Inject a hook so _base.js logout() can call back into Flutter.
          _controller.runJavaScript(
            'window._flutterAdminLogout = () => FlutterAdminLogout.postMessage("logout");',
          );
        },
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleAdminLogout() async {
    final up = context.read<UserProvider>();
    await up.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
