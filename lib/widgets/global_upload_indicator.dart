import 'package:flutter/material.dart';

// 전역 업로드 상태 관리
final ValueNotifier<List<String>> globalUploadingNotifier = ValueNotifier<List<String>>([]);

class GlobalUploadManager {
  static OverlayEntry? _overlayEntry;

  static void init(BuildContext context) {
    if (_overlayEntry == null) {
      final overlay = Navigator.of(context).overlay;
      if (overlay != null) {
        _overlayEntry = OverlayEntry(
          builder: (context) => const GlobalUploadIndicator(),
        );
        overlay.insert(_overlayEntry!);
        globalUploadingNotifier.addListener(_onNotifierChanged);
      }
    }
  }

  static void _onNotifierChanged() {
    if (globalUploadingNotifier.value.isEmpty) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      globalUploadingNotifier.removeListener(_onNotifierChanged);
    }
  }
}

class GlobalUploadIndicator extends StatefulWidget {
  const GlobalUploadIndicator({super.key});

  @override
  State<GlobalUploadIndicator> createState() => _GlobalUploadIndicatorState();
}

class _GlobalUploadIndicatorState extends State<GlobalUploadIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: globalUploadingNotifier,
      builder: (context, uploadingList, child) {
        if (uploadingList.isEmpty) return const SizedBox.shrink();

        final text = '[' + uploadingList.join(', ') + '] 정보 업데이트중...';

        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _controller,
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.none, // Need this because it's above Scaffold
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
