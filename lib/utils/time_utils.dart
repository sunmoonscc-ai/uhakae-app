import 'package:flutter/material.dart';

class TimeUtils {
  static DateTime getPhilippineTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }

  static bool isOpenNow(String operatingHours) {
    if (operatingHours.trim().isEmpty) return false;
    
    final phTime = getPhilippineTime();
    final currentMin = phTime.hour * 60 + phTime.minute;
    
    // hh:mm ~ hh:mm 패턴 찾기
    final timeRanges = RegExp(r'(\d{1,2}:\d{2})\s*[~-]\s*(\d{1,2}:\d{2})').allMatches(operatingHours);
    if (timeRanges.isEmpty) return false;
    
    bool isOpen = false;
    
    for (final match in timeRanges) {
      final start = match.group(1)!;
      final end = match.group(2)!;
      
      final startNormalized = _normalizeTime(start);
      final endNormalized = _normalizeTime(end);
      
      int startMin = int.parse(startNormalized.split(':')[0]) * 60 + int.parse(startNormalized.split(':')[1]);
      int endMin = int.parse(endNormalized.split(':')[0]) * 60 + int.parse(endNormalized.split(':')[1]);
      
      if (endMin < startMin) {
        // 영업이 다음날 새벽까지 이어지는 경우 (예: 10:00 ~ 02:00)
        if (currentMin >= startMin || currentMin <= endMin) {
          isOpen = true;
          break;
        }
      } else {
        // 같은 날 내에 영업이 끝나는 경우 (예: 09:00 ~ 18:00)
        if (currentMin >= startMin && currentMin <= endMin) {
          isOpen = true;
          break;
        }
      }
    }
    
    return isOpen;
  }
  
  static String _normalizeTime(String timeStr) {
    final parts = timeStr.split(':');
    final h = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    return '$h:$m';
  }
}
