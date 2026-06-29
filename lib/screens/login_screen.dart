import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  final List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
  ];

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        // 사용자가 로그인을 취소함
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null && user.email != null) {
        // 화이트리스트(회원) 검사
        bool isAuthorized = false;

        // 1. 관리자 이메일인지 확인
        if (_adminEmails.contains(user.email)) {
          isAuthorized = true;
        } else {
          // 2. Firestore의 'users' 컬렉션에 등록된 이메일인지 확인
          final QuerySnapshot result = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
              
          if (result.docs.isNotEmpty) {
            isAuthorized = true;
          }
        }

        if (isAuthorized) {
          if (mounted) {
            Navigator.pop(context, true); // 로그인 성공
          }
        } else {
          // 권한 없음 -> 강제 로그아웃
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn(
            clientId: '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
          ).signOut();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('회원만 사용할 수 있습니다.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구글 로그인 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('유학애 로그인'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                isDarkMode ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
                height: 80,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.school, size: 80, color: isDarkMode ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 64),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Google 계정으로 로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '※ 유학애 회원만 사용할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
