import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late final SharedPreferences _prefs;

  // 앱 시작 시 main()에서 한 번 호출하여 초기화합니다.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 설정 키(Keys) ---
  static const String _isDarkModeKey = 'isDarkMode';
  
  // 향후 다른 설정들의 키를 여기에 추가할 수 있습니다.
  // static const String _isNotificationsEnabledKey = 'isNotificationsEnabled';

  // --- 다크 모드 설정 ---
  static bool get isDarkMode {
    // 저장된 값이 없으면 기본적으로 false(라이트 모드)를 반환합니다.
    return _prefs.getBool(_isDarkModeKey) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_isDarkModeKey, value);
  }

  // --- 향후 추가될 설정 예시 ---
  /*
  static bool get isNotificationsEnabled {
    return _prefs.getBool(_isNotificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_isNotificationsEnabledKey, value);
  }
  */
}
