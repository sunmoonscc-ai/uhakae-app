import 'package:flutter/material.dart';
import '../main.dart'; // To access themeNotifier

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
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
                  onChanged: (bool value) {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
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
