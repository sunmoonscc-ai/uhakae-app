import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreferencesService {
  static late final SharedPreferences _prefs;

  // 앱 시작 시 main()에서 한 번 호출하여 초기화합니다.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    favoritesNotifier.value = favorites;
  }

  // --- 설정 키(Keys) ---
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _defaultRegionKey = 'defaultRegion';
  static const String _isAdminKey = 'isAdmin';
  static const String _userRegionKey = 'userRegion';
  static const String _favoritesKey = 'favorites';
  
  static final ValueNotifier<List<Map<String, dynamic>>> favoritesNotifier = ValueNotifier([]);
  
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
      'uhak2026@gmail.com',
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

// --- 즐겨찾기(Favorites) ---
  static List<Map<String, dynamic>> get favorites {
    final strList = _prefs.getStringList(_favoritesKey) ?? [];
    return strList.map((str) => jsonDecode(str) as Map<String, dynamic>).toList();
  }

  static Future<void> _syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'favorites': favorites,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error syncing favorites to firestore: $e');
      }
    }
  }

  static Future<void> syncFavoritesWithFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['favorites'] is List) {
          final List<dynamic> remoteList = data['favorites'];
          final remoteFavorites = remoteList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          
          final localFavorites = favorites;
          final Map<String, Map<String, dynamic>> mergedMap = {};
          
          // 리모트를 맵에 추가
          for (var item in remoteFavorites) {
            mergedMap[item['id'].toString()] = item;
          }
          // 로컬을 맵에 추가 (로컬을 덮어씌움)
          for (var item in localFavorites) {
            mergedMap[item['id'].toString()] = item;
          }
          
          final mergedList = mergedMap.values.toList();
          final strList = mergedList.map((e) => jsonEncode(e)).toList();
          await _prefs.setStringList(_favoritesKey, strList);
          favoritesNotifier.value = mergedList;
          
          // 병합된 결과를 서버에 업로드
          await _syncToFirestore();
        } else {
          // 서버에 배열이 없으면 로컬 내용으로 서버 생성
          await _syncToFirestore();
        }
      }
    } catch (e) {
      debugPrint('Error merging favorites from firestore: $e');
    }
  }

  static Future<void> addFavorite(Map<String, dynamic> item) async {
    final list = favorites;
    if (!list.any((e) => e['id'] == item['id'])) {
      list.add(item);
      final strList = list.map((e) => jsonEncode(e)).toList();
      await _prefs.setStringList(_favoritesKey, strList);
      favoritesNotifier.value = list;
      await _syncToFirestore();
    }
  }

  static Future<void> removeFavorite(String id) async {
    final list = favorites;
    list.removeWhere((e) => e['id'] == id);
    final strList = list.map((e) => jsonEncode(e)).toList();
    await _prefs.setStringList(_favoritesKey, strList);
    favoritesNotifier.value = list;
    await _syncToFirestore();
  }

  static Future<void> updateFavoriteBusinessData(String id, Map<String, dynamic> businessData) async {
    final list = favorites;
    final index = list.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      list[index]['businessData'] = businessData;
      list[index]['title'] = businessData['name'] ?? list[index]['title'];
      final strList = list.map((e) => jsonEncode(e)).toList();
      await _prefs.setStringList(_favoritesKey, strList);
      favoritesNotifier.value = list;
      await _syncToFirestore();
    }
  }

  static bool isFavorite(String id) {
    return favorites.any((e) => e['id'] == id);
  }
}
