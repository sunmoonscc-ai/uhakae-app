import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _userAdminRegion = '전체'; // 사용자 관리 탭의 선택된 지역
  String _userAdminSchool = '어학원 선택'; // 사용자 관리 탭의 선택된 어학원
  String _userAdminSubTab = '전체 회원'; // '신청자', '전체 회원', '연수종료'
  String _schoolAdminRegionTab = '바기오'; // 어학원 관리 탭의 선택된 지역
  
  // 정렬 관련 상태
  String _userSortField = '정렬 방식';
  bool _userSortDescending = false;

  final List<String> _tabs = ['게시물 관리', '사용자 관리', '어학원 관리', '정보 관리', '컨시어지 관리'];
  final List<String> _regions = ['전체', '바기오', '클락', '세부', '보홀'];
  
  final List<String> _schoolList = [
    '바기오_BECI', '바기오_CIJ', '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu', '세부_BK Academy', '세부_Blue Ocean', '세부_E FRIENDS',
    '세부_JIE', '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
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
      '세부_JIE', '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
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
      final contactCtrl = TextEditingController(text: data['contact'] ?? '');
      final repEmailCtrl = TextEditingController(text: data['rep_email'] ?? '');
      final bankAccountCtrl = TextEditingController(text: data['bank_account'] ?? '');
      final descriptionCtrl = TextEditingController(text: data['description'] ?? '');
      final featuresCtrl = TextEditingController(text: data['features'] ?? '');

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
                            TextFormField(
                              controller: contactCtrl,
                              decoration: const InputDecoration(labelText: '대표자 연락처'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: repEmailCtrl,
                              decoration: const InputDecoration(labelText: '대표자 이메일'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: bankAccountCtrl,
                              decoration: const InputDecoration(labelText: '입금계좌'),
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
                              'contact': contactCtrl.text,
                              'rep_email': repEmailCtrl.text,
                              'bank_account': bankAccountCtrl.text,
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
          // 하단 2단 레이아웃 (공지사항 / 자유게시판)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좌측: 공지사항
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                          child: Text('공지사항', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                        ),
                        Expanded(child: _buildPostList('notice', isDarkMode)),
                      ],
                    ),
                  ),
                ),
                // 우측: 자유게시판
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                        child: Text('자유게시판', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                      ),
                      Expanded(child: _buildPostList('community', isDarkMode)),
                    ],
                  ),
                ),
              ],
            ),
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
                const SizedBox(width: 12),
                
                // 정렬 기준 드롭다운
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _userSortField,
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: '정렬 방식', child: Text('정렬 방식')),
                        DropdownMenuItem(value: 'name', child: Text('이름 순')),
                        DropdownMenuItem(value: 'phone_kr', child: Text('한국 번호 순')),
                        DropdownMenuItem(value: 'school', child: Text('어학원 순')),
                        DropdownMenuItem(value: 'start_date', child: Text('시작일자 순')),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _userSortField = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                
                // 오름/내림차순 토글
                IconButton(
                  icon: Icon(
                    _userSortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _userSortDescending = !_userSortDescending;
                    });
                  },
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
      final List<String> regions = ['바기오', '클락', '세부', '보홀'];
      
      // 어학원 리스트 가나다 순 정렬 및 선택된 지역 필터링
      final sortedSchools = _schoolList
          .where((school) => school.startsWith('${_schoolAdminRegionTab}_'))
          .toList()..sort();
      
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
          Expanded(
            child: sortedSchools.isEmpty 
                ? Center(
                    child: Text('해당 지역에 등록된 어학원이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3.5,
                    ),
                    itemCount: sortedSchools.length,
                    itemBuilder: (context, index) {
                      final schoolName = sortedSchools[index];
                      return Card(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _showEditSchoolDialog(context, schoolName, isDarkMode),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.school, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    schoolName,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 13),
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
                  ),
          ),
        ],
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

          String sortKey = _userSortField == '정렬 방식' ? 'name' : _userSortField;
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
                Expanded(flex: 4, child: Text('이름', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
                Expanded(flex: 5, child: Text('전화', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
                Expanded(flex: 6, child: Text('어학원', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
                Expanded(flex: 4, child: Text('연수시작일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
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
                      final school = data['school'] ?? '소속 미정';
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
                                    school,
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
}
