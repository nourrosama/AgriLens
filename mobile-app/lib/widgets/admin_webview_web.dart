// Web implementation — embeds an <iframe> via HtmlElementView
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminWebView extends StatefulWidget {
  final String url;
  const AdminWebView({super.key, required this.url});

  @override
  State<AdminWebView> createState() => _AdminWebViewState();
}

class _AdminWebViewState extends State<AdminWebView> {
  late final String _viewId;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _viewId = 'admin-iframe-${widget.url.hashCode}';
    ui.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      return html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
    });

    // Listen for logout message from the cross-origin iframe
    _msgSub = html.window.onMessage.listen((event) {
      try {
        final data = event.data is String
            ? jsonDecode(event.data as String)
            : event.data;
        if (data is Map && data['type'] == 'agrilens_logout') {
          if (mounted) context.go('/login');
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
