import 'package:flutter/material.dart';
import '../main.dart'; // To access themeNotifier
import '../services/preferences_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        title: Row(
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.settings, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              '설정',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
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
                  side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
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
                    isDarkMode ? '현재 다크 모드가 적용되어 있습니다.' : '현재 라이트 모드가 적용되어 있습니다.',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  value: isDarkMode,
                  activeColor: Colors.tealAccent,
                  onChanged: (bool value) async {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    // 디바이스 로컬 스토리지에 변경된 설정값 저장
                    await PreferencesService.setDarkMode(value);
                  },
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: isDarkMode ? Colors.white : Colors.black),
                  title: Text('앱 버전', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                  trailing: Text('1.0.0', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
