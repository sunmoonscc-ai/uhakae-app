class StringUtils {
  static String maskName(String name) {
    if (name.isEmpty) return '***';
    
    bool isKorean = RegExp(r'^[가-힣]').hasMatch(name);
    
    if (isKorean) {
      return '${name.substring(0, 1)}***';
    } else {
      if (name.length <= 2) return '$name***';
      return '${name.substring(0, 2)}***';
    }
  }
}
