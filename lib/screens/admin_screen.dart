import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/firebase_storage_service.dart';
import 'school_admin_detail_screen.dart';
import 'post_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _selectedTab = '사용자 관리';
  String _postAdminRegion = '전체';
  String _postAdminSubTab = '공지사항'; // 게시물 관리 하위 탭
  String _userAdminRegion = '전체'; // 사용자 관리 탭의 선택된 지역
  String _userAdminSchool = '어학원 선택'; // 사용자 관리 탭의 선택된 어학원
  String _userAdminSubTab = '전체 회원'; // '신청자', '전체 회원', '연수종료'
  String _schoolAdminRegionTab = '전체'; // 어학원 관리 탭의 선택된 지역
  
  // 정렬 관련 상태
  String _userSortField = 'name';
  bool _userSortDescending = false;
  String _schoolAdminSortField = '어학원명';
  bool _schoolAdminSortDescending = false;
  String _personalNoticeSortField = 'name';
  bool _personalNoticeSortDescending = false;

  final List<String> _tabs = ['게시물 관리', '사용자 관리', '어학원 관리', '정보 관리', '컨시어지 관리'];
  final List<String> _regions = ['전체', '바기오', '클락', '세부', '보홀'];
  
  final List<String> _schoolList = [
    '바기오_BECI', '바기오_CIJ', '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu', '세부_BK Academy', '세부_Blue Ocean', '세부_E FRIENDS',
    '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
    '세부_QQ', '세부_SEL Academy', '세부_SMEAG capital', '세부_SMEAG encanto', '세부_Winning English',
    '클락_E&G',
  ];

  // 주문 상태 맵
  final Map<String, String> statusLabels = {
    'pending': '접수 대기',
    'approved': '승인 및 준비중',
    'completed': '완료',
    'returned': '반납 완료'
  };

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
      if (mounted) {
        UiUtils.showPopup(context, '주문 상태가 업데이트되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showPopup(context, '오류 발생: $e');
      }
    }
  }

  Future<void> _showEditUserDialog(BuildContext context, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final phoneKrCtrl = TextEditingController(text: data['phone_kr'] ?? '');
    final startDateCtrl = TextEditingController(text: data['start_date'] ?? '');
    String? selectedSchool = data['school'];
    
    String selectedLevel = data['level'] ?? '정회원';
    final List<String> levels = ['정회원', '예비', '연수종료'];
    if (!levels.contains(selectedLevel)) {
      levels.add(selectedLevel);
    }
    String createdAtStr = '알 수 없음';
    if (data['created_at'] != null) {
      final Timestamp ts = data['created_at'];
      final dt = ts.toDate();
      createdAtStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    final List<String> schools = [
      '바기오_BECI', '바기오_CIJ', '바기오_PINES',
      '보홀_Mint',
      '세부_B\'Cebu', '세부_BK Academy', '세부_Blue Ocean', '세부_E FRIENDS',
      '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
      '세부_QQ', '세부_SEL Academy', '세부_SMEAG capital', '세부_SMEAG encanto', '세부_Winning English',
      '클락_E&G',
    ];

    if (!schools.contains(selectedSchool) && selectedSchool != null && selectedSchool.isNotEmpty) {
      schools.add(selectedSchool);
    } else if (selectedSchool == null || selectedSchool.isEmpty) {
      selectedSchool = schools.first;
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('회원 정보 수정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: data['email'] ?? '이메일 없음',
                        decoration: const InputDecoration(labelText: '이메일'),
                        readOnly: true,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: createdAtStr,
                        decoration: const InputDecoration(labelText: '가입일시'),
                        readOnly: true,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('이하 수정 가능', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: '이름'),
                        validator: (val) => (val == null || val.trim().isEmpty) ? '이름을 입력해주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedLevel,
                        decoration: const InputDecoration(labelText: '회원등급'),
                        items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (val) => setState(() => selectedLevel = val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneKrCtrl,
                        decoration: const InputDecoration(labelText: '전화번호'),
                        keyboardType: TextInputType.phone,
                        validator: (val) => (val == null || val.trim().isEmpty) ? '전화번호를 입력해주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSchool,
                        decoration: const InputDecoration(labelText: '어학원'),
                        items: schools.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => selectedSchool = val),
                        validator: (val) => val == null ? '어학원을 선택해주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: startDateCtrl,
                        decoration: const InputDecoration(labelText: '연수시작일', hintText: '예: 2026-07-01'),
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
                              startDateCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                        validator: (val) => (val == null || val.trim().isEmpty) ? '연수시작일을 선택해주세요.' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                        'name': nameCtrl.text.trim(),
                        'level': selectedLevel,
                        'phone_kr': phoneKrCtrl.text.trim(),
                        'school': selectedSchool,
                        'start_date': startDateCtrl.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        UiUtils.showPopup(context, '정보가 수정되었습니다.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('저장', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showEditSchoolDialog(BuildContext context, String schoolName, bool isDarkMode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (loadingCtx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance.collection('schools').doc(schoolName).get();
      final data = doc.exists ? doc.data()! : {};

      final locationCtrl = TextEditingController(text: data['location'] ?? '');
      final repNameCtrl = TextEditingController(text: data['rep_name'] ?? '');
      
      // 연락처(대표, 기타)
      final contactMainCtrl = TextEditingController(text: data['contact_main'] ?? '');
      final contactSubCtrl = TextEditingController(text: data['contact_sub'] ?? '');
      
      // 이메일(대표, 기타)
      final emailMainCtrl = TextEditingController(text: data['email_main'] ?? '');
      final emailSubCtrl = TextEditingController(text: data['email_sub'] ?? '');
      
      // 입금계좌(은행이름, 계좌번호, 명의)
      String? selectedBank = data['bank_name'];
      if (selectedBank != null && selectedBank.isEmpty) selectedBank = null;
      final bankAccountNumCtrl = TextEditingController(text: data['bank_account_num'] ?? '');
      final bankAccountOwnerCtrl = TextEditingController(text: data['bank_account_owner'] ?? '');
      
      final descriptionCtrl = TextEditingController(text: data['description'] ?? '');
      final featuresCtrl = TextEditingController(text: data['features'] ?? '');
      
      List<String> bankList = [
        '--- 한국 은행 ---',
        '경남은행', '광주은행', '국민은행', '기업은행', '농협은행', '대구은행', 
        '부산은행', '새마을금고', '수협은행', '신한은행', '신협', '우리은행', 
        '우체국', '전북은행', '제주은행', '카카오뱅크', '케이뱅크', '토스뱅크', 
        '하나은행', '한국투자증권', 'SC제일은행',
        '--- 필리핀 은행 ---',
        'BDO', 'BPI', 'Metrobank', 'PNB', 'RCBC', 'Security Bank', 'UnionBank'
      ];
      
      if (selectedBank != null && !bankList.contains(selectedBank)) {
        bankList.add(selectedBank);
      }

      final formKey = GlobalKey<FormState>();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 로딩 다이얼로그 닫기
        
        await showDialog(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (stateContext, setState) {
                bool isSaving = false;
                return AlertDialog(
                  title: Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: locationCtrl,
                              decoration: const InputDecoration(labelText: '주소'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: repNameCtrl,
                              decoration: const InputDecoration(labelText: '대표자 이름'),
                            ),
                            const SizedBox(height: 12),
                            // 대표자 연락처 (2개)
                            Row(
                              children: [
                                Expanded(child: TextFormField(
                                  controller: contactMainCtrl,
                                  decoration: const InputDecoration(labelText: '연락처 (대표)'),
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(
                                  controller: contactSubCtrl,
                                  decoration: const InputDecoration(labelText: '연락처 (기타)'),
                                )),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 대표자 이메일 (2개)
                            Row(
                              children: [
                                Expanded(child: TextFormField(
                                  controller: emailMainCtrl,
                                  decoration: const InputDecoration(labelText: '이메일 (대표)'),
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(
                                  controller: emailSubCtrl,
                                  decoration: const InputDecoration(labelText: '이메일 (기타)'),
                                )),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 입금계좌 (은행이름 드롭다운, 계좌번호, 명의)
                            DropdownButtonFormField<String>(
                              value: selectedBank,
                              decoration: const InputDecoration(labelText: '은행이름'),
                              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                              items: bankList.map((String bank) {
                                bool isSeparator = bank.startsWith('---');
                                return DropdownMenuItem<String>(
                                  value: isSeparator ? null : bank,
                                  enabled: !isSeparator,
                                  child: Text(bank, style: TextStyle(
                                    color: isSeparator ? Colors.grey : (isDarkMode ? Colors.white : Colors.black),
                                    fontWeight: isSeparator ? FontWeight.bold : FontWeight.normal,
                                  )),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => selectedBank = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(flex: 3, child: TextFormField(
                                  controller: bankAccountNumCtrl,
                                  decoration: const InputDecoration(labelText: '계좌번호'),
                                )),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: TextFormField(
                                  controller: bankAccountOwnerCtrl,
                                  decoration: const InputDecoration(labelText: '명의'),
                                )),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descriptionCtrl,
                              decoration: const InputDecoration(labelText: '어학원 소개'),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: featuresCtrl,
                              decoration: const InputDecoration(labelText: '메모'),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
                      child: const Text('취소', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => isSaving = true);
                          try {
                            await FirebaseFirestore.instance.collection('schools').doc(schoolName).set({
                              'location': locationCtrl.text,
                              'rep_name': repNameCtrl.text,
                              'contact_main': contactMainCtrl.text,
                              'contact_sub': contactSubCtrl.text,
                              'email_main': emailMainCtrl.text,
                              'email_sub': emailSubCtrl.text,
                              'bank_name': selectedBank ?? '',
                              'bank_account_num': bankAccountNumCtrl.text,
                              'bank_account_owner': bankAccountOwnerCtrl.text,
                              'description': descriptionCtrl.text,
                              'features': featuresCtrl.text,
                              'updated_at': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                            
                            if (context.mounted) {
                              Navigator.of(dialogContext, rootNavigator: true).pop();
                              UiUtils.showPopup(context, '어학원 정보가 저장되었습니다.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(dialogContext, rootNavigator: true).pop();
                              UiUtils.showPopup(context, '저장 실패: $e');
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: isSaving 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('저장', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              }
            );
          }
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        UiUtils.showPopup(context, '정보를 불러오지 못했습니다: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        title: Row(
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.admin_panel_settings, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              '관리',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 상단 탭 영역
          Container(
            color: Colors.white,
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final tabName = _tabs[index];
                final isSelected = _selectedTab == tabName;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTab = tabName;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      tabName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black54,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 탭 내용 영역
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_selectedTab == '게시물 관리') {
      return Column(
        children: [
          // 지역 선택 바
          Container(
            color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _regions.map((reg) {
                  final isSelected = _postAdminRegion == reg;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _postAdminRegion = reg;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text(
                        reg,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDarkMode ? Colors.blue[200] : Colors.blue[700])
                              : (isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // 하위 탭 (공지사항, 개별공지, 자유게시판)
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildPostAdminSubTabItem('공지사항', isDarkMode),
                _buildPostAdminSubTabItem('개별공지', isDarkMode),
                _buildPostAdminSubTabItem('자유게시판', isDarkMode),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: _postAdminSubTab == '공지사항'
                ? _buildPostList('notice', isDarkMode)
                : _postAdminSubTab == '개별공지'
                    ? _buildPersonalNoticeTab(isDarkMode)
                    : _buildPostList('community', isDarkMode),
          ),
        ],
      );
    }

    if (_selectedTab == '사용자 관리') {
      // 선택된 지역에 따른 어학원 목록 필터링
      List<String> availableSchools = ['어학원 선택'];
      if (_userAdminRegion == '전체') {
        availableSchools.addAll(_schoolList);
      } else {
        availableSchools.addAll(_schoolList.where((school) => school.startsWith('${_userAdminRegion}_')));
      }

      // 만약 선택된 어학원이 필터링된 목록에 없다면 '어학원 선택'으로 초기화
      if (!availableSchools.contains(_userAdminSchool)) {
        _userAdminSchool = '어학원 선택';
      }

      return Column(
        children: [
          // 1. 상단 지역 선택 바
          Container(
            color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _regions.map((reg) {
                  final isSelected = _userAdminRegion == reg;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _userAdminRegion = reg;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text(
                        reg,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDarkMode ? Colors.blue[200] : Colors.blue[700])
                              : (isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // 2. 어학원 필터 및 정렬 컨트롤 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                // 어학원 드롭다운
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _userAdminSchool,
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14),
                      items: availableSchools.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _userAdminSchool = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 3. 사용자 목록 대시보드 출력
          Expanded(
            child: _buildUserDashboard(isDarkMode),
          ),
        ],
      );
    }

    if (_selectedTab == '어학원 관리') {
      final List<String> regions = ['전체', '바기오', '클락', '세부', '보홀'];
      
      final sortedSchools = _schoolList
          .where((school) => _schoolAdminRegionTab == '전체' || school.startsWith('${_schoolAdminRegionTab}_'))
          .toList();
      
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final schoolDataMap = { for (var doc in docs) doc.id: doc.data() as Map<String, dynamic> };

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                ),
                child: Row(
                  children: regions.map((region) {
                    final isSelected = _schoolAdminRegionTab == region;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _schoolAdminRegionTab = region;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            region,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4, 
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_schoolAdminSortField == '어학원명') {
                              _schoolAdminSortDescending = !_schoolAdminSortDescending;
                            } else {
                              _schoolAdminSortField = '어학원명';
                              _schoolAdminSortDescending = false;
                            }
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('어학원명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
                            if (_schoolAdminSortField == '어학원명')
                              Icon(_schoolAdminSortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3, 
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_schoolAdminSortField == '대표자 이름') {
                              _schoolAdminSortDescending = !_schoolAdminSortDescending;
                            } else {
                              _schoolAdminSortField = '대표자 이름';
                              _schoolAdminSortDescending = false;
                            }
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('대표자 이름', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
                            if (_schoolAdminSortField == '대표자 이름')
                              Icon(_schoolAdminSortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                          ],
                        ),
                      ),
                    ),
                    Expanded(flex: 5, child: Text('메모', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
                  ],
                ),
              ),
              Expanded(
                child: sortedSchools.isEmpty 
                    ? Center(
                        child: Text('해당 지역에 등록된 어학원이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
                      )
                    : Builder(
                        builder: (context) {
                          sortedSchools.sort((aId, bId) {
                            final aData = schoolDataMap[aId] ?? {};
                            final bData = schoolDataMap[bId] ?? {};
                            
                            int result = 0;
                            if (_schoolAdminSortField == '어학원명') {
                              String aName = aId.replaceFirst(RegExp(r'^[^_]+_'), '');
                              String bName = bId.replaceFirst(RegExp(r'^[^_]+_'), '');
                              result = aName.compareTo(bName);
                            } else if (_schoolAdminSortField == '대표자 이름') {
                              String aRep = (aData['rep_name'] ?? '').toString();
                              String bRep = (bData['rep_name'] ?? '').toString();
                              result = aRep.compareTo(bRep);
                            }
                            
                            return _schoolAdminSortDescending ? -result : result;
                          });

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            itemCount: sortedSchools.length,
                        itemBuilder: (context, index) {
                          final schoolId = sortedSchools[index];
                          final displaySchoolName = schoolId.replaceFirst('${_schoolAdminRegionTab}_', '');
                          final schoolData = schoolDataMap[schoolId] ?? {};
                          final repName = schoolData['rep_name'] ?? '-';
                          final memo = schoolData['features'] ?? '-';

                          return InkWell(
                            onTap: () => _showEditSchoolDialog(context, schoolId, isDarkMode),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isDarkMode ? Colors.grey[850] : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        displaySchoolName,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        repName.toString().isEmpty ? '-' : repName,
                                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        memo.toString().isEmpty ? '-' : memo,
                                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
              ),
            ],
          );
        },
      );
    }

    if (_selectedTab == '컨시어지 관리') {
      return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('현재 접수된 주문이 없습니다.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final orderId = docs[index].id;
                          final currentStatus = data['status'] ?? 'pending';
                          final itemName = data['item_name'] ?? '알 수 없는 상품';
                          final type = data['type'] == 'buy' ? '구매 대행' : '대여';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.white,
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '[$type] $itemName',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentStatus == 'pending' 
                                              ? Colors.orange.shade100 
                                              : currentStatus == 'approved' 
                                                  ? Colors.blue.shade100 
                                                  : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusLabels[currentStatus] ?? currentStatus,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: currentStatus == 'pending' 
                                              ? Colors.orange.shade800 
                                              : currentStatus == 'approved' 
                                                  ? Colors.blue.shade800 
                                                  : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('User ID: ${data['user_id']} | Order ID: $orderId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (currentStatus == 'pending')
                                        ElevatedButton(
                                          onPressed: () => _updateOrderStatus(orderId, 'approved'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                                          child: const Text('승인(준비중) 처리', style: TextStyle(color: Colors.white)),
                                        ),
                                      if (currentStatus == 'approved')
                                        ElevatedButton(
                                          onPressed: () => _updateOrderStatus(orderId, 'completed'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                          child: const Text('완료 처리', style: TextStyle(color: Colors.white)),
                                        ),
                                      if (currentStatus == 'completed' && data['type'] == 'rent')
                                        ElevatedButton(
                                          onPressed: () => _updateOrderStatus(orderId, 'returned'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                          child: const Text('반납 완료', style: TextStyle(color: Colors.white)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
    }
    
    return Center(child: Text('$_selectedTab 기능은 준비 중입니다.'));
  }

  Widget _buildUserDashboard(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        
        final List<String> adminEmails = [
          'cebufriends79@gmail.com',
          'slptas05@gmail.com',
          'sunmoon.scc@gmail.com',
          'hdcc6th@gmail.com',
        ];

        // 클라이언트 단 공통 지역 및 어학원 필터링
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'] as String? ?? '';
          if (adminEmails.contains(email)) return false;
          
          final school = data['school'] as String? ?? '';
          
          if (_userAdminRegion != '전체') {
            if (!school.startsWith('${_userAdminRegion}_')) return false;
          }
          if (_userAdminSchool != '어학원 선택') {
            if (school != _userAdminSchool) return false;
          }
          return true;
        }).toList();

        // 정렬 공통 로직
        var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
        modifiableDocs.sort((a, b) {
          final aMap = a.data() as Map<String, dynamic>;
          final bMap = b.data() as Map<String, dynamic>;

          String sortKey = _userSortField;
          String aVal = (aMap[sortKey] ?? '').toString().toLowerCase();
          String bVal = (bMap[sortKey] ?? '').toString().toLowerCase();
          return _userSortDescending ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
        });

        // 3가지 분류로 데이터 나누기
        final pendingDocs = <QueryDocumentSnapshot>[];
        final activeDocs = <QueryDocumentSnapshot>[];
        final endedDocs = <QueryDocumentSnapshot>[];

        for (var doc in modifiableDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final level = data['level'] as String? ?? '정회원'; // 새로 추가된 level 기준 (기존 유저는 정회원)
          
          if (level == '예비') {
            pendingDocs.add(doc);
          } else if (level == '연수종료') {
            endedDocs.add(doc);
          } else {
            activeDocs.add(doc);
          }
        }

        List<QueryDocumentSnapshot> currentDocs = [];
        if (_userAdminSubTab == '신청자') {
          currentDocs = pendingDocs;
        } else if (_userAdminSubTab == '연수종료') {
          currentDocs = endedDocs;
        } else {
          currentDocs = activeDocs;
        }

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  _buildSubTabItem('신청자', pendingDocs.length, isDarkMode),
                  _buildSubTabItem('전체 회원', activeDocs.length, isDarkMode),
                  _buildSubTabItem('연수종료', endedDocs.length, isDarkMode),
                ],
              ),
            ),
            Expanded(
              child: _buildDashboardColumn(
                _userAdminSubTab == '신청자' ? '회원가입 신청자' : (_userAdminSubTab == '연수종료' ? '연수종료 회원 목록' : '전체 회원 목록'),
                currentDocs,
                isDarkMode,
                showApprove: _userAdminSubTab == '신청자',
                isTop: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubTabItem(String title, int count, bool isDarkMode) {
    final isSelected = _userAdminSubTab == title;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _userAdminSubTab = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$title $count',
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSortHeader(String title, String field, int flex, bool isDarkMode) {
    bool isSelected = _userSortField == field;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _userSortDescending = !_userSortDescending;
            } else {
              _userSortField = field;
              _userSortDescending = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
            if (isSelected)
              Icon(_userSortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardColumn(String title, List<QueryDocumentSnapshot> docs, bool isDarkMode, {bool showApprove = false, bool isTop = false}) {
    return Container(
      decoration: BoxDecoration(
        border: isTop ? Border(
          bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
        ) : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                Text('${docs.length}명', style: TextStyle(color: isDarkMode ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
              border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildUserSortHeader('이름', 'name', 4, isDarkMode),
                _buildUserSortHeader('전화', 'phone_kr', 5, isDarkMode),
                _buildUserSortHeader('어학원', 'school', 6, isDarkMode),
                _buildUserSortHeader('연수시작일', 'start_date', 4, isDarkMode),
                const SizedBox(width: 45), // 처리 버튼 공간
              ],
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? Center(
                    child: Text(
                      '해당하는 사용자가 없습니다.',
                      style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final name = data['name'] ?? '이름 없음';
                      final phoneKr = data['phone_kr'] ?? '';
                      final phonePh = data['phone_ph'] ?? '';
                      String displaySchool = data['school'] ?? '소속 미정';
                      if (_userAdminRegion != '전체' && displaySchool.startsWith('${_userAdminRegion}_')) {
                        displaySchool = displaySchool.replaceFirst('${_userAdminRegion}_', '');
                      }
                      final startDate = data['start_date'] ?? '미정';

                      return InkWell(
                        onTap: () => _showEditUserDialog(context, doc),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    name,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        phoneKr.isNotEmpty ? '(K) $phoneKr' : '(K) 번호 미정',
                                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (phonePh.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '(P) $phonePh',
                                          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: Text(
                                    displaySchool,
                                    style: TextStyle(color: isDarkMode ? Colors.blue[200] : Colors.blue[700], fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    startDate,
                                    style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 45,
                                  child: showApprove
                                      ? SizedBox(
                                          height: 24,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('가입 처리', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  content: const Text('회원가입 신청을 어떻게 처리하시겠습니까?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('취소', style: TextStyle(color: Colors.grey)),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        Navigator.pop(ctx);
                                                        await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();
                                                        if (mounted) UiUtils.showPopup(context, '가입을 거절했습니다.');
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      child: const Text('거절', style: TextStyle(color: Colors.white)),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        Navigator.pop(ctx);
                                                        await FirebaseFirestore.instance.collection('users').doc(doc.id).update({'level': '정회원'});
                                                        if (mounted) UiUtils.showPopup(context, '가입을 승인했습니다.');
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                                      child: const Text('승인', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              backgroundColor: Colors.blueGrey,
                                            ),
                                            child: const Text('처리', style: TextStyle(fontSize: 11, color: Colors.white)),
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(String category, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        if (_postAdminRegion != '전체') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final docRegion = data['region'] as String? ?? '세부';
            return docRegion == _postAdminRegion;
          }).toList();
        }

        var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
        modifiableDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          return bTime.compareTo(aTime);
        });

        if (modifiableDocs.isEmpty) {
          return Center(
            child: Text(
              '게시물이 없습니다.',
              style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: modifiableDocs.length,
          itemBuilder: (context, index) {
            final doc = modifiableDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? '제목 없음';
            final authorName = data['author_name'] ?? '익명';
            
            String timeAgo = '';
            if (data['created_at'] != null) {
              final dt = (data['created_at'] as Timestamp).toDate();
              timeAgo = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              elevation: 1,
              child: ListTile(
                onTap: () {
                  // data 맵에 id 추가 (PostDetailScreen 등에서 필요할 수 있음)
                  data['id'] = doc.id;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(postData: data),
                    ),
                  );
                },
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                subtitle: Text('$authorName | $timeAgo', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('삭제 확인'),
                            content: const Text('이 게시물을 정말 삭제하시겠습니까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
                          if (mounted) UiUtils.showPopup(context, '삭제되었습니다.');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostAdminSubTabItem(String title, bool isDarkMode) {
    final isSelected = _postAdminSubTab == title;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _postAdminSubTab = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalNoticeTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        
        final List<String> adminEmails = [
          'cebufriends79@gmail.com',
          'slptas05@gmail.com',
          'sunmoon.scc@gmail.com',
          'hdcc6th@gmail.com',
        ];

        // 어드민 필터 및 지역 필터
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'] as String? ?? '';
          if (adminEmails.contains(email)) return false;
          
          final school = data['school'] as String? ?? '';
          if (_postAdminRegion != '전체') {
            if (!school.startsWith('${_postAdminRegion}_')) return false;
          }
          return true;
        }).toList();

        final activeDocs = <QueryDocumentSnapshot>[];
        final endedDocs = <QueryDocumentSnapshot>[];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final level = data['level'] as String? ?? '정회원';
          if (level == '연수종료') {
            endedDocs.add(doc);
          } else if (level != '예비') { // 정회원
            activeDocs.add(doc);
          }
        }

        // 정렬
        void sortDocs(List<QueryDocumentSnapshot> list) {
          list.sort((a, b) {
            final aMap = a.data() as Map<String, dynamic>;
            final bMap = b.data() as Map<String, dynamic>;
            String aVal = (aMap[_personalNoticeSortField] ?? '').toString().toLowerCase();
            String bVal = (bMap[_personalNoticeSortField] ?? '').toString().toLowerCase();
            return _personalNoticeSortDescending ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
          });
        }
        
        sortDocs(activeDocs);
        sortDocs(endedDocs);

        return Column(
          children: [
            _buildPersonalNoticeHeader(isDarkMode),
            Expanded(
              child: _buildPersonalNoticeList(activeDocs, isDarkMode, '정회원 목록'),
            ),
            if (endedDocs.isNotEmpty) ...[
              Container(height: 1, color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
              Container(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                padding: const EdgeInsets.all(8),
                alignment: Alignment.centerLeft,
                child: Text('연수종료 회원 목록', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              ),
              SizedBox(
                height: 180, // 약 3줄 정도가 보이도록 고정 높이 지정
                child: _buildPersonalNoticeList(endedDocs, isDarkMode, '연수종료 회원 목록', hideHeader: true),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPersonalNoticeHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildPersonalNoticeSortHeader('이름', 'name', 3, isDarkMode),
          _buildPersonalNoticeSortHeader('어학원', 'school', 5, isDarkMode),
          _buildPersonalNoticeSortHeader('연수시작일', 'start_date', 4, isDarkMode),
          _buildPersonalNoticeSortHeader('연수종료일', 'end_date', 4, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildPersonalNoticeSortHeader(String title, String field, int flex, bool isDarkMode) {
    bool isSelected = _personalNoticeSortField == field;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _personalNoticeSortDescending = !_personalNoticeSortDescending;
            } else {
              _personalNoticeSortField = field;
              _personalNoticeSortDescending = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
            if (isSelected)
              Icon(_personalNoticeSortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalNoticeList(List<QueryDocumentSnapshot> docs, bool isDarkMode, String title, {bool hideHeader = false}) {
    if (docs.isEmpty) {
      return Center(
        child: Text('해당하는 회원이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        final name = data['name'] ?? '이름 없음';
        
        String displaySchool = data['school'] ?? '소속 미정';
        if (_postAdminRegion != '전체' && displaySchool.startsWith('${_postAdminRegion}_')) {
          displaySchool = displaySchool.replaceFirst('${_postAdminRegion}_', '');
        }
        
        final startDate = data['start_date'] ?? '미정';
        final endDate = data['end_date'] ?? '미정';

        return InkWell(
          onTap: () => _showPersonalNoticeUserDialog(context, doc.id, name, isDarkMode),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(displaySchool, style: TextStyle(color: isDarkMode ? Colors.blue[200] : Colors.blue[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(startDate, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(endDate, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPersonalNoticeUserDialog(BuildContext context, String userId, String userName, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$userName 님의 개별공지 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                    IconButton(icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('personal_notices')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (ctx, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다: ${snapshot.error}', style: TextStyle(color: Colors.red, fontSize: 12)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('등록된 개별공지가 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                      }

                      final notices = snapshot.data!.docs.toList();
                      // Dart 메모리에서 정렬 (복합 인덱스 오류 방지 및 형변환 오류 방지)
                      notices.sort((a, b) {
                        try {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aDate = aData['createdAt'] is Timestamp ? aData['createdAt'] as Timestamp : null;
                          final bDate = bData['createdAt'] is Timestamp ? bData['createdAt'] as Timestamp : null;
                          
                          if (aDate == null && bDate == null) return 0;
                          if (aDate == null) return 1;
                          if (bDate == null) return -1;
                          return bDate.compareTo(aDate);
                        } catch (e) {
                          return 0;
                        }
                      });

                      return ListView.builder(
                        itemCount: notices.length,
                        itemBuilder: (ctx, index) {
                          final notice = notices[index];
                          final data = notice.data() as Map<String, dynamic>;
                          final title = data['title'] ?? '제목 없음';
                          final content = data['content'] ?? '';
                          final isRead = data['isRead'] as bool? ?? false;
                          final createdAt = data['createdAt'] as Timestamp?;
                          final dateStr = createdAt != null 
                              ? '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}-${createdAt.toDate().day.toString().padLeft(2, '0')} ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}' 
                              : '날짜 없음';
                          final imageUrls = data['image_urls'] as List<dynamic>? ?? [];
                          
                          final readAt = data['readAt'] as Timestamp?;
                          String readText = isRead ? '읽음' : '안읽음';
                          if (isRead && readAt != null) {
                            readText = '읽음\n${readAt.toDate().year.toString().substring(2)}-${readAt.toDate().month.toString().padLeft(2, '0')}-${readAt.toDate().day.toString().padLeft(2, '0')} ${readAt.toDate().hour.toString().padLeft(2, '0')}:${readAt.toDate().minute.toString().padLeft(2, '0')}';
                          }

                          return Card(
                            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black))),
                                  if (imageUrls.isNotEmpty)
                                    Icon(Icons.image, size: 16, color: Colors.blue[400]),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.blue[400])),
                                  const SizedBox(height: 4),
                                  Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.grey.withOpacity(0.2) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  readText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isRead ? Colors.grey : Colors.red,
                                  ),
                                ),
                              ),
                              isThreeLine: true,
                              onTap: () {
                                _showPersonalNoticeEditDialog(context, notice.id, userId, title, content, isDarkMode, initialImageUrls: imageUrls.cast<String>());
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showPersonalNoticeEditDialog(context, null, userId, '', '', isDarkMode, initialImageUrls: []);
                    },
                    child: const Text('신규 개별공지 작성', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showPersonalNoticeEditDialog(BuildContext context, String? docId, String userId, String initialTitle, String initialContent, bool isDarkMode, {List<String>? initialImageUrls}) {
    final titleCtrl = TextEditingController(text: initialTitle);
    final contentCtrl = TextEditingController(text: initialContent);
    bool isLoading = false;
    final ImagePicker picker = ImagePicker();
    List<XFile> selectedImages = [];
    List<String> existingImageUrls = initialImageUrls != null ? List<String>.from(initialImageUrls) : [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stContext, setSt) {
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              title: Text(docId == null ? '신규 개별공지' : '개별공지 수정', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: '제목',
                          labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 5,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: '내용',
                          alignLabelWithHint: true,
                          labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () async {
                          if (selectedImages.length + existingImageUrls.length >= 5) {
                            UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있습니다.');
                            return;
                          }
                          final List<XFile> images = await picker.pickMultiImage();
                          if (images.isNotEmpty) {
                            setSt(() {
                              int remaining = 5 - (selectedImages.length + existingImageUrls.length);
                              if (images.length > remaining) {
                                selectedImages.addAll(images.take(remaining));
                                UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있어 초과된 사진은 제외되었습니다.');
                              } else {
                                selectedImages.addAll(images);
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('사진 첨부 (최대 5장)'),
                      ),
                      if (existingImageUrls.isNotEmpty || selectedImages.isNotEmpty)
                        Container(
                          height: 100,
                          margin: const EdgeInsets.only(top: 8),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...existingImageUrls.asMap().entries.map((entry) {
                                int idx = entry.key;
                                String url = entry.value;
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8, top: 8),
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0, top: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          setSt(() => existingImageUrls.removeAt(idx));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              ...selectedImages.asMap().entries.map((entry) {
                                int idx = entry.key;
                                XFile file = entry.value;
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8, top: 8),
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: FutureBuilder<Uint8List>(
                                          future: file.readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                            return const Center(child: CircularProgressIndicator());
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0, top: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          setSt(() => selectedImages.removeAt(idx));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (docId != null)
                  TextButton(
                    onPressed: isLoading ? null : () async {
                      setSt(() => isLoading = true);
                      await FirebaseFirestore.instance.collection('personal_notices').doc(docId).delete();
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        UiUtils.showPopup(context, '삭제되었습니다.');
                      }
                    },
                    child: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      UiUtils.showPopup(context, '제목과 내용을 입력해주세요.');
                      return;
                    }
                    
                    setSt(() => isLoading = true);
                    
                    List<String> newUrls = [];
                    if (selectedImages.isNotEmpty) {
                      for (var file in selectedImages) {
                        final url = await FirebaseStorageService.uploadImage(file);
                        if (url != null) {
                          newUrls.add(url);
                        }
                      }
                    }
                    
                    final List<String> finalImageUrls = [...existingImageUrls, ...newUrls];
                    
                    final data = {
                      'userId': userId,
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'image_urls': finalImageUrls,
                      if (docId == null) 'createdAt': FieldValue.serverTimestamp(),
                      if (docId == null) 'isRead': false,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    
                    if (docId == null) {
                      await FirebaseFirestore.instance.collection('personal_notices').add(data);
                    } else {
                      await FirebaseFirestore.instance.collection('personal_notices').doc(docId).update(data);
                    }
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      UiUtils.showPopup(context, '저장되었습니다.');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('저장', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
