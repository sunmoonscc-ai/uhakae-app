import 'package:flutter/material.dart';
import '../main.dart'; // for rootNavigatorKey

class AdminNotificationManager {
  static OverlayEntry? _overlayEntry;
  static int _pendingCount = 0;

  static VoidCallback? onNavigate;

  static void showNotification(int additionalCount) {
    if (additionalCount <= 0) return;
    
    _pendingCount += additionalCount;
    
    if (_overlayEntry == null) {
      final overlay = rootNavigatorKey.currentState?.overlay;
      if (overlay == null) {
        debugPrint('AdminNotificationManager: overlay is null');
        return;
      }

      _overlayEntry = OverlayEntry(
        builder: (context) => _buildOverlay(context),
      );
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  static void dismiss() {
    _pendingCount = 0;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void _onGoTo() {
    dismiss();
    onNavigate?.call();
  }

  static Widget _buildOverlay(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: MediaQuery.of(context).size.width * 0.05,
      right: MediaQuery.of(context).size.width * 0.05,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.shade700,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '새로운 주문/대여 요청' + (_pendingCount > 1 ? ' (+$_pendingCount)' : ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _onGoTo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('바로가기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: dismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
