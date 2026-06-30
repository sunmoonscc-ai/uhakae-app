import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PreferencesService {
  static late final SharedPreferences _prefs;

  // 앱 시작 시 main()에서 한 번 호출하여 초기화합니다.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 설정 키(Keys) ---
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _defaultRegionKey = 'defaultRegion';
  static const String _isAdminKey = 'isAdmin';
  static const String _userRegionKey = 'userRegion';
  
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

  // --- 기본 지역 설정 ---
  static String get defaultRegion {
    return _prefs.getString(_defaultRegionKey) ?? '전체';
  }

  static Future<void> setDefaultRegion(String value) async {
    await _prefs.setString(_defaultRegionKey, value);
  }

  // --- 사용자 권한 및 지역 ---
  static const List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
  ];

  static bool get isAdmin {
    // SharedPreferences 대신 현재 로그인된 사용자의 이메일을 실시간으로 확인합니다.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      return _adminEmails.contains(user.email);
    }
    return false;
  }

  static Future<void> setAdmin(bool value) async {
    // 더 이상 SharedPreferences에 저장하지 않으므로 사용하지 않거나 비워둡니다.
  }

  static String get userRegion {
    return _prefs.getString(_userRegionKey) ?? '전체';
  }

  static Future<void> setUserRegion(String value) async {
    await _prefs.setString(_userRegionKey, value);
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
