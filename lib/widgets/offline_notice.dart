import 'package:flutter/material.dart';

class OfflineNotice extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineNotice({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              '오프라인 상태입니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '온라인일 때만 가능한 서비스입니다.\n네트워크 연결을 확인해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
