import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';

import 'settings_screen.dart';
import '../widgets/global_upload_indicator.dart';

class MoreMenuSheet extends StatefulWidget {
  final void Function(Widget)? onNavigate;

  const MoreMenuSheet({super.key, this.onNavigate});

  @override
  State<MoreMenuSheet> createState() => _MoreMenuSheetState();
}

class _MoreMenuSheetState extends State<MoreMenuSheet> {
  final List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
  ];

  void _navigateToLogin() async {
    Navigator.pop(context); // Close the sheet
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _logout() async {
    if (globalUploadingNotifier.value.isNotEmpty) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('경고'),
          content: const Text('현재 백그라운드에서 업체 정보 업로드가 진행 중입니다. 로그아웃하시면 업로드가 중단되고 데이터가 유실될 수 있습니다. 정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await FirebaseAuth.instance.signOut();
    await GoogleSignIn(
      clientId:
          '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
    ).signOut();
    if (mounted) {
      Navigator.pop(context); // 팝업 메뉴 닫기
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;
    final String userEmail = user?.email ?? '';
    final bool isAdmin = isLoggedIn && _adminEmails.contains(userEmail);

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[900]
            : Colors.white, // Theme aware background
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoggedIn)
            ListTile(
              leading: Icon(
                Icons.logout,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                '로그아웃',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 13,
                ),
              ),
              onTap: _logout,
            )
          else
            ListTile(
              leading: Icon(
                Icons.login,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                '로그인',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              onTap: _navigateToLogin,
            ),
          Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          ListTile(
            leading: Icon(
              Icons.person_outline,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            title: Text(
              '회원정보 수정',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              if (isLoggedIn) {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(const ProfileEditScreen());
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  );
                }
              } else {
                UiUtils.showPopup(context, '회원정보 수정은 로그인이 필요합니다.');
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.settings_outlined,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            title: Text(
              '설정',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              if (widget.onNavigate != null) {
                widget.onNavigate!(const SettingsScreen());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
          ),
          if (isAdmin) ...[
            Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              title: Text(
                '관리',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (widget.onNavigate != null) {
                  widget.onNavigate!(const AdminScreen());
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
