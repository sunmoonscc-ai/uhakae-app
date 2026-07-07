import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/preferences_service.dart';

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
      'uhakae2026@gmail.com',
  ];

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId:
            '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        // 사용자가 로그인을 취소함
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null && user.email != null) {
        // 화이트리스트(회원) 검사
        bool isAuthorized = false;

        if (_adminEmails.contains(user.email)) {
          isAuthorized = true;
          // 관리자가 Firestore에 없으면 추가, 있으면 last_login 업데이트
          final QuerySnapshot adminCheck = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          if (adminCheck.docs.isEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': user.email,
              'name': user.displayName ?? '관리자',
              'phone_kr': '',
              'school': '관리자',
              'start_date': '',
              'level': '관리자',
              'created_at': FieldValue.serverTimestamp(),
              'last_login': FieldValue.serverTimestamp(),
              'points': 0,
            });
          } else {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(adminCheck.docs.first.id)
                .update({'last_login': FieldValue.serverTimestamp()});
          }
        } else {
          // 2. Firestore의 'users' 컬렉션에 등록된 이메일인지 확인
          final QuerySnapshot result = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();

          if (result.docs.isNotEmpty) {
            final data = result.docs.first.data() as Map<String, dynamic>;
            final level = data['level'] as String? ?? '정회원';

            if (level != '정회원') {
              // 승인 대기 중이거나 거절됨
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn(
                clientId:
                    '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
              ).signOut();

              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    Future.delayed(const Duration(seconds: 2), () {
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop();
                      }
                    });
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          level == '예비' ? '회원 확인중입니다.' : '승인된 사용자만 이용 가능합니다.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              return; // 로그인 중단
            }

            // 활성 회원
            isAuthorized = true;
            final school = data['school'] as String? ?? '';
            final parts = school.split('_');
            final userRegion = (parts.isNotEmpty && parts[0].isNotEmpty)
                ? parts[0]
                : '전체';

            // last_login 업데이트
            await FirebaseFirestore.instance
                .collection('users')
                .doc(result.docs.first.id)
                .update({'last_login': FieldValue.serverTimestamp()});

            await PreferencesService.setAdmin(false);
            await PreferencesService.setUserRegion(userRegion);
          } else {
            // Firestore에 없으면 신규 가입자 팝업 안내
            bool? apply = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text(
                    '안내',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    '유학애 회원만 사용할 수 있습니다.\n\n유학애 회원이시면 신청 버튼을 눌러주시면 확인 후 승인 처리하도록 하겠습니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        '거절',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        '신청',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );

            if (apply == true) {
              // 정보 입력 팝업 띄우기
              final Map<String, String>? formData =
                  await showDialog<Map<String, String>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        _SignUpFormDialog(initialName: user.displayName ?? ''),
                  );

              if (formData != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                  'email': user.email,
                  'name': formData['name'],
                  'phone_kr': formData['phone_kr'],
                  'school': formData['school'],
                  'start_date': formData['start_date'],
                  'level': '예비',
                  'created_at': FieldValue.serverTimestamp(),
                  'points': 1000,
                });

                await FirebaseFirestore.instance.collection('point_history').add({
                  'userId': user.uid,
                  'amount': 1000,
                  'type': 'signup_bonus',
                  'description': '가입 축하금',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                      });
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        content: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            '회원가입이 신청되었습니다.\n관리자 승인 후 이용 가능합니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              }
            }

            await FirebaseAuth.instance.signOut();
            await GoogleSignIn(
              clientId:
                  '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
            ).signOut();

            return; // 로그인 중단
          }
        }

        if (isAuthorized) {
          if (_adminEmails.contains(user.email)) {
            await PreferencesService.setAdmin(true);
            await PreferencesService.setUserRegion('전체'); // 관리자는 전체
          }
          
          // 로그인 성공 시 서버 즐겨찾기 동기화
          await PreferencesService.syncFavoritesWithFirestore(user.uid);

          if (mounted) {
            Navigator.pop(context, true); // 로그인 성공
          }
        } else {
          // 권한 없음 -> 강제 로그아웃
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn(
            clientId:
                '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
          ).signOut();

          if (mounted) {
            UiUtils.showPopup(context, '회원만 사용할 수 있습니다.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showPopup(context, '구글 로그인 실패: $e');
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
      appBar: AppBar(title: const Text('유학애 로그인')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                height: 80,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.school,
                  size: 80,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 64),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text(
                  'Google 계정으로 로그인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                      width: 1,
                    ),
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

class _SignUpFormDialog extends StatefulWidget {
  final String initialName;

  const _SignUpFormDialog({required this.initialName});

  @override
  State<_SignUpFormDialog> createState() => _SignUpFormDialogState();
}

class _SignUpFormDialogState extends State<_SignUpFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneKrController;
  late TextEditingController _startDateController;
  String? _selectedSchool;

  final List<String> _schools = [
    '바기오_BECI',
    '바기오_CIJ',
    '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu',
    '세부_BK Academy',
    '세부_Blue Ocean',
    '세부_E FRIENDS',
    '세부_JJES',
    '세부_JOYFUL EDUCATION',
    '세부_JUNGLE',
    '세부_PIZZA',
    '세부_QQ',
    '세부_SEL Academy',
    '세부_SMEAG capital',
    '세부_SMEAG encanto',
    '세부_Winning English',
    '클락_E&G',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneKrController = TextEditingController();
    _startDateController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneKrController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '가입 정보 입력',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '이름을 입력해주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneKrController,
                decoration: const InputDecoration(labelText: '한국 전화번호'),
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? '전화번호를 입력해주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSchool,
                decoration: const InputDecoration(labelText: '어학원'),
                items: _schools
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSchool = val),
                validator: (val) => val == null ? '어학원을 선택해주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: '연수시작일',
                  hintText: '예: 2026-07-01',
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDateController.text =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                    });
                  }
                },
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? '연수시작일을 선택해주세요.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'phone_kr': _phoneKrController.text.trim(),
                'school': _selectedSchool!,
                'start_date': _startDateController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('확인', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
