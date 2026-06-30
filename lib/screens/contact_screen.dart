import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  final String region;

  const ContactScreen({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone_outlined,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "'$region' 지역의 연락처 정보는\n현재 수집 및 정리 중입니다.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

  }
}
