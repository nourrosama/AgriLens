import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/connectivity_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';

/// Overlays an offline/online status banner at the top of the app.
/// Uses Stack+Positioned — never wraps child in Column — so layout constraints
/// for the underlying screens are never affected.
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
      // Just came back online — flash the green badge for 3 seconds.
      _showOnlineBadge = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showOnlineBadge = false);
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
    final showBanner = showOffline || _showOnlineBadge;

    // Stack+Positioned: banner floats OVER content without changing its layout
    // constraints. The old Column approach caused ElevatedButton to receive
    // BoxConstraints(w=Infinity) whenever it was inside a Row on any screen.
    //
    // We use MediaQuery.sizeOf() instead of SizedBox.expand() because on
    // Flutter web the ConnectivityBanner Stack can be called as a relayout
    // boundary with unconstrained stored constraints. SizedBox.expand() would
    // then propagate infinity down. MediaQuery.sizeOf() always returns a
    // finite logical screen size regardless of the incoming constraints.
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Main content — use MediaQuery size to guarantee finite, bounded
        // constraints so the navigator/overlay never receives unbounded width.
        SizedBox(width: size.width, height: size.height, child: widget.child),

        // Banner overlay — only mounted when visible.
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
                  // Offline banner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: showOffline ? 40 : 0,
                    color: const Color(0xFFB71C1C),
                    child: showOffline
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                pending > 0
                                    ? (lang.isRTL
                                        ? 'غير متصل — $pending فحص بانتظار المزامنة'
                                        : 'Offline — $pending scan${pending == 1 ? '' : 's'} pending sync')
                                    : (lang.isRTL
                                        ? 'أنت غير متصل بالإنترنت'
                                        : "You're offline"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Back-online flash
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showOnlineBadge ? 40 : 0,
                    color: const Color(0xFF2E7D32),
                    child: _showOnlineBadge
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                lang.isRTL
                                    ? 'عدت للاتصال — جارٍ المزامنة...'
                                    : 'Back online — syncing...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
