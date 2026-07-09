import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:study_abroad_app/services/preferences_service.dart';
import 'package:study_abroad_app/widgets/admin_notification_badge.dart';
import 'package:study_abroad_app/widgets/user_notification_badge.dart';
import 'community_screen.dart';
import 'admin_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  // 임시 로그인 상태 관리 (실제 연동 전까지 UI 테스트용)
  bool _isLoggedIn = false;
  String _userEmail = '';

  // 관리자 이메일 목록
  final List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
      'uhakae2026@gmail.com',
  ];

  void _loginMock() {
    showDialog(
      context: context,
      builder: (context) {
        String inputEmail = '';
        return AlertDialog(
          title: const Text('이메일 로그인 (테스트용)'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: '이메일을 입력하세요',
              helperText: '관리자 이메일 입력 시 관리 메뉴가 뜹니다.',
            ),
            onChanged: (val) => inputEmail = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoggedIn = true;
                  _userEmail = inputEmail.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
  }

  void _logoutMock() {
    setState(() {
      _isLoggedIn = false;
      _userEmail = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _isLoggedIn && _adminEmails.contains(_userEmail);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('더보기', style: TextStyle(color: Color(0xFF00327D), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (PreferencesService.isAdmin)
            const AdminNotificationBadge()
          else
            const UserNotificationBadge(),
        ],
      ),
      body: ListView(
        children: [
          // 1. 로그인 / 내 정보
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: _isLoggedIn
                ? ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF00327D)),
                    title: Text(_userEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: TextButton(
                      onPressed: _logoutMock,
                      child: const Text('로그아웃', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.login, color: Color(0xFF00327D)),
                    title: const Text('로그인', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _loginMock,
                  ),
          ),
          
          // 2. 일반 메뉴들
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.forum_outlined, color: Colors.black87),
                  title: const Text('커뮤니티'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CommunityScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Colors.black87),
                  title: const Text('설정'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    UiUtils.showPopup(context, '설정 화면은 준비 중입니다.');
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 3. 관리자 메뉴 (관리자에게만 노출)
          if (isAdmin)
            Container(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                title: const Text('관리 (주문 및 컨시어지 관리)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminScreen()),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
