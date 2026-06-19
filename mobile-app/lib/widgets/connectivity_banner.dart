import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/connectivity_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _showOnlineBadge = false;
  bool _wasOffline = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    if (_wasOffline && isOnline) {
      _showOnlineBadge = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showOnlineBadge = false);
        }
      });
    }

    _wasOffline = !isOnline;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final lang = context.watch<LanguageProvider>();
    final scanHistory = context.watch<ScanHistoryProvider>();
    final pending = scanHistory.queuedCount;
    final showOffline = !connectivity.isOnline;
    final showOnline = _showOnlineBadge || scanHistory.isSyncingQueuedScans;
    final showBanner = showOffline || showOnline;
    final offlineText = pending > 0
        ? lang.t('offline.pendingSync').replaceAll('{count}', '$pending')
        : lang.t('offline.offline');
    final onlineText = scanHistory.isSyncingQueuedScans
        ? lang.t('offline.syncingCount').replaceAll('{count}', '$pending')
        : scanHistory.lastSyncFailedCount > 0
        ? lang.t('offline.syncFailed')
        : scanHistory.lastSyncCompletedCount > 0
        ? lang.t('offline.synced')
        : lang.t('offline.backOnline');
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        SizedBox(width: size.width, height: size.height, child: widget.child),
        if (showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusBar(
                    visible: showOffline,
                    color: const Color(0xFFB71C1C),
                    icon: Icons.wifi_off,
                    text: offlineText,
                  ),
                  _StatusBar(
                    visible: showOnline,
                    color: const Color(0xFF2E7D32),
                    icon: Icons.wifi,
                    text: onlineText,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.visible,
    required this.color,
    required this.icon,
    required this.text,
  });

  final bool visible;
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: visible ? 40 : 0,
      color: color,
      child: visible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
