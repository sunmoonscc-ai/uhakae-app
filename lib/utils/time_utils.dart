import 'package:flutter/material.dart';

class TimeUtils {
  static bool isOpenNow(String operatingHours) {
    if (operatingHours.trim().isEmpty) return false;
    
    // 영업시간 텍스트 (예: 월~금 09:00~10:00 토 09:00~09:30)
    // 혹은 단일 시간 (예: 09:00 - 22:00)
    
    final now = DateTime.now();
    // Dart 요일: 1(월) ~ 7(일)
    final weekDay = now.weekday;
    final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // 단순 파싱: "09:00 - 22:00" 같은 형태가 가장 많음.
    // 일단 전체 문자열에서 현재 요일에 해당하는 부분을 찾거나, 요일이 없으면 매일로 간주.
    
    // 더 정교하게 만들 수 있지만, 현재는 가장 많이 쓰이는 hh:mm~hh:mm 혹은 hh:mm-hh:mm 패턴을 찾아서
    // 현재 시간이 그 사이에 있는지 확인.
    
    final timeRanges = RegExp(r'(\d{1,2}:\d{2})\s*[~-]\s*(\d{1,2}:\d{2})').allMatches(operatingHours);
    if (timeRanges.isEmpty) return false; // 시간을 찾을 수 없으면 알 수 없음.
    
    // 요일 파싱은 복잡하므로, 일단 패턴 매칭된 모든 시간대 중 하나라도 일치하면 영업중으로 간주.
    // (완벽한 분석은 요일 매칭이 필요하지만, 대략적인 추정)
    bool isOpen = false;
    
    for (final match in timeRanges) {
      final start = match.group(1)!;
      final end = match.group(2)!;
      
      final startNormalized = _normalizeTime(start);
      final endNormalized = _normalizeTime(end);
      
      if (currentTimeStr.compareTo(startNormalized) >= 0 && currentTimeStr.compareTo(endNormalized) <= 0) {
        isOpen = true;
        break;
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
