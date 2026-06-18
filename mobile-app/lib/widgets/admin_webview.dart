// Conditional export: iframe on web, WebView on Android/iOS
export 'admin_webview_stub.dart'
    if (dart.library.html) 'admin_webview_web.dart';
