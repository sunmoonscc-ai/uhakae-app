import 'package:flutter/material.dart';
import 'package:study_abroad_app/main.dart'; // To access themeNotifier
import '../services/preferences_service.dart';
import 'info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
        title: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                    (route) => false,
                  );
                },
                child: Image.asset(
                  (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.settings,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '설정',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, ThemeMode currentMode, child) {
          final isDarkMode = currentMode == ThemeMode.dark;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    '다크 모드',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    isDarkMode
                        ? '현재 다크 모드가 적용되어 있습니다.'
                        : '현재 라이트 모드가 적용되어 있습니다.',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  value: isDarkMode,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: (bool value) async {
                    themeNotifier.value = value
                        ? ThemeMode.dark
                        : ThemeMode.light;
                    // 디바이스 로컬 스토리지에 변경된 설정값 저장
                    await PreferencesService.setDarkMode(value);
                  },
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (PreferencesService.isAdmin) ...[
                const SizedBox(height: 16),
                Card(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '기본 지역 설정',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '정보 탭의 기본 지역을 선택합니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        StatefulBuilder(
                          builder: (context, setState) {
                            return DropdownButton<String>(
                              value: PreferencesService.defaultRegion,
                              dropdownColor: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.white,
                              underline: const SizedBox(),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              items: ['전체', '바기오', '클락', '세부', '보홀'].map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) async {
                                if (newValue != null) {
                                  await PreferencesService.setDefaultRegion(
                                    newValue,
                                  );
                                  // 지역 설정이 변경되면 정보 탭의 현재 선택 지역도 즉시 동기화
                                  commonRegionNotifier.value = newValue;
                                  setState(() {});
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    '앱 버전',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
