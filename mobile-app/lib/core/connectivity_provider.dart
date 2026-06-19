import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'scan_history_provider.dart';

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider() {
    _init();
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _retryTimer;
  bool _didInitialSync = false;

  // Holds a reference to ScanHistoryProvider so we can trigger sync.
  ScanHistoryProvider? _scanHistory;

  void attachScanHistory(ScanHistoryProvider sh) {
    _scanHistory = sh;
    if (_isOnline && !_didInitialSync) {
      _didInitialSync = true;
      scheduleMicrotask(
        () => _scanHistory?.syncQueuedScans(notifyStart: false),
      );
    }
    _configureRetryTimer();
  }

  Future<void> _init() async {
    // Check current status on startup.
    final results = await Connectivity().checkConnectivity();
    _setOnline(_isConnected(results));

    // Listen for changes.
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final nowOnline = _isConnected(results);
      final wasOffline = !_isOnline;
      _setOnline(nowOnline);

      // Auto-sync queued scans when we come back online.
      if (nowOnline && wasOffline) {
        _scanHistory?.syncQueuedScans();
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    _configureRetryTimer();
    notifyListeners();
  }

  void _configureRetryTimer() {
    if (!_isOnline || _scanHistory == null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    _retryTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isOnline) {
        _scanHistory?.syncQueuedScans(notifyStart: false);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
