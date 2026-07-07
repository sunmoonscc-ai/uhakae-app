import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:study_abroad_app/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/preferences_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final bool isForced;
  const ProfileEditScreen({super.key, this.isForced = false});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneKrController = TextEditingController();
  final _phonePhController = TextEditingController();
  final _schoolController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  
  String? _selectedSchool;
  final List<String> _schoolList = [
    '바기오_BECI', '바기오_CIJ', '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu', '세부_BK Academy', '세부_Blue Ocean', '세부_E FRIENDS',
    '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
    '세부_QQ', '세부_SEL Academy', '세부_SMEAG capital', '세부_SMEAG encanto', '세부_Winning English',
    '클락_E&G',
  ];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _fetchUserData(user.email);
    }
  }

  Future<void> _fetchUserData(String? email) async {
    if (email == null) return;
    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) {
        final data = result.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _phoneKrController.text = data['phone_kr'] ?? '';
          _phonePhController.text = data['phone_ph'] ?? '';
          
          if (PreferencesService.isAdmin) {
             _selectedSchool = null;
             _schoolController.text = '';
             _startDateController.text = '';
             _endDateController.text = '';
          } else {
            final fetchedSchool = data['school'] ?? '';
            if (_schoolList.contains(fetchedSchool)) {
              _selectedSchool = fetchedSchool;
            }
            _schoolController.text = fetchedSchool;
            _startDateController.text = data['start_date'] ?? '';
            _endDateController.text = data['end_date'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneKrController.dispose();
    _phonePhController.dispose();
    _schoolController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);
        
        final QuerySnapshot result = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
            
        final Map<String, dynamic> updateData = {
          'name': _nameController.text,
          'phone_kr': _phoneKrController.text,
          'phone_ph': _phonePhController.text,
          'school': _schoolController.text,
          'start_date': _startDateController.text,
          'end_date': _endDateController.text,
        };

        if (result.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(result.docs.first.id)
              .update(updateData);
        } else {
          updateData['email'] = user.email;
          await FirebaseFirestore.instance
              .collection('users')
              .add(updateData);
        }

        // 선택한 학교를 바탕으로 userRegion 갱신
        final parts = _schoolController.text.split('_');
        final userRegion = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '전체';
        await PreferencesService.setUserRegion(userRegion);

        if (mounted) {
          UiUtils.showPopup(context, '회원정보가 저장되었습니다.');
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showPopup(context, '오류 발생: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        final year = picked.year.toString();
        final month = picked.month.toString().padLeft(2, '0');
        final day = picked.day.toString().padLeft(2, '0');
        controller.text = '$year-$month-$day';
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDarkMode, {String? hint, bool isDate = false, TextInputType? keyboardType, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isDate || !enabled,
          enabled: enabled,
          keyboardType: keyboardType,
          onTap: (isDate && enabled) ? () => _selectDate(context, controller) : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? (isDarkMode ? Colors.grey[900] : Colors.white) : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            suffixIcon: isDate ? Icon(Icons.calendar_today, color: isDarkMode ? Colors.white54 : Colors.black54) : null,
          ),
          style: TextStyle(
            color: enabled ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white54 : Colors.black54),
          ),
          validator: label == '이름' ? (value) {
            if (value == null || value.isEmpty) {
              return '이름을 입력해주세요.';
            }
            return null;
          } : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSchoolDropdown(bool isDarkMode) {
    final bool isAdmin = PreferencesService.isAdmin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어학원',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSchool,
          hint: Text(
            '어학원을 선택하세요',
            style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: !isAdmin ? (isDarkMode ? Colors.grey[900] : Colors.white) : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14),
          items: _schoolList.map((school) {
            return DropdownMenuItem(
              value: school,
              child: Text(school),
            );
          }).toList(),
          onChanged: isAdmin ? null : (val) {
            setState(() {
              _selectedSchool = val;
              if (val != null) _schoolController.text = val;
            });
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isForced,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
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
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '회원정보 수정',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이메일',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: user.email,
                      readOnly: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField('이름', _nameController, isDarkMode, hint: '이름을 입력하세요'),
                    _buildTextField('휴대전화 (한국)', _phoneKrController, isDarkMode, hint: '예: 010-1234-5678', keyboardType: TextInputType.phone),
                    _buildTextField('휴대전화 (필리핀)', _phonePhController, isDarkMode, hint: '예: 0917-123-4567', keyboardType: TextInputType.phone),
                    _buildSchoolDropdown(isDarkMode),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('수업시작일', _startDateController, isDarkMode, hint: '시작 날짜를 선택하세요', isDate: true, enabled: !PreferencesService.isAdmin)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('수업종료(예정)일', _endDateController, isDarkMode, hint: '종료 날짜를 선택하세요', isDate: true, enabled: !PreferencesService.isAdmin)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '저장하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
