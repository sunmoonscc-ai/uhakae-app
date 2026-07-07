import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/firebase_storage_service.dart';
import 'school_admin_detail_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/business_map_view.dart';
import '../models/business_model.dart';
import '../widgets/business_card.dart';
import '../widgets/add_business_dialog.dart';
import 'business_detail_screen.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'info_screen.dart'; // for regionSubCategories
import '../widgets/admin_shop_management_tab.dart';
import '../widgets/admin_product_management_tab.dart';
import '../utils/time_utils.dart';
import '../services/preferences_service.dart';
import '../widgets/admin_point_management_dialog.dart';
import '../utils/admin_notification_manager.dart';
import 'dart:async';
import 'package:study_abroad_app/main.dart';

class AdminScreen extends StatefulWidget {
  final String? initialTab;
  final String? initialConciergeSubTab;
  const AdminScreen({super.key, this.initialTab, this.initialConciergeSubTab});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _selectedTab = '대시보드';
  String _postAdminRegion = '전체';
  String _postAdminSubTab = '공지사항'; // 게시물 관리 하위 탭
  String _userAdminRegion = '전체'; // 사용자 관리 탭의 선택된 지역
  String _userAdminSchool = '어학원 선택'; // 사용자 관리 탭의 선택된 어학원
  String _userAdminSubTab = '전체 회원'; // '신청자', '전체 회원', '연수종료'
  String _schoolAdminRegionTab = '전체'; // 어학원 관리 탭의 선택된 지역
  String _adminInfoRegion = '바기오'; // 정보 관리 탭 지역
  String _adminInfoSubCategory = '전체'; // 정보 관리 탭 카테고리
  String _infoSuggestionStatus = 'pending'; // 'pending' or 'completed'
  String _conciergeSubTab = '대시보드'; // 컨시어지 탭의 서브 탭
  String _adminOrderFilter = 'pending'; // 주문 관리 탭 필터
  String? _selectedProductId; // 선택된 물품 ID (물품현황 필터링용)
  
  String _adminInfoSortMode = 'name_asc'; // 'name_asc', 'name_desc', 'dist_asc', 'dist_desc'
  bool _adminInfoOpenNowFilter = false;
  bool _showMap = false;
  Position? _currentPosition;
  
  // 정렬 관련 상태
  bool _isNoticeDescending = true; // 쪽지 정렬 상태
  bool _isGeneralNoticeDescending = true; // 공지사항 정렬 상태
  bool _isCommunityDescending = true; // 자유게시판 정렬 상태
  
  String _userSortField = 'name';
  bool _userSortDescending = false;
  String _schoolAdminSortField = '어학원명';
  bool _schoolAdminSortDescending = false;
  String _personalNoticeSortField = 'name';
  bool _personalNoticeSortDescending = false;

  late Stream<QuerySnapshot> _adminNoticeStream;
  late Stream<QuerySnapshot> _adminIndividualNoticeStream;
  late Stream<QuerySnapshot> _adminCommunityStream;

  List<BusinessModel>? _cachedAdminBusinesses;
  
  int _lastPendingOrderCount = 0;
  StreamSubscription<QuerySnapshot>? _orderSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null && _tabs.contains(widget.initialTab)) {
      _selectedTab = widget.initialTab!;
    }
    if (widget.initialConciergeSubTab != null) {
      _conciergeSubTab = widget.initialConciergeSubTab!;
    }

    FirebaseFirestore.instance.collection('schools').get().then((snapshot) {
      final existingIds = snapshot.docs.map((d) => d.id).toSet();
      for (var school in _schoolList) {
        if (!existingIds.contains(school)) {
           FirebaseFirestore.instance.collection('schools').doc(school).set({
             'location': '',
             'rep_name': '',
             'features': '',
             'created_at': FieldValue.serverTimestamp(),
           });
        }
      }
    });
    
    final String defaultRegion = PreferencesService.defaultRegion;
    if (_regions.contains(defaultRegion)) {
      _postAdminRegion = defaultRegion;
      _userAdminRegion = defaultRegion;
      _schoolAdminRegionTab = defaultRegion;
    }
    
    if (commonRegions.contains(defaultRegion)) {
      _adminInfoRegion = defaultRegion;
    } else {
      _adminInfoRegion = '바기오';
    }

    _adminNoticeStream = FirebaseFirestore.instance.collection('posts').where('category', isEqualTo: 'notice').snapshots();
    _adminIndividualNoticeStream = FirebaseFirestore.instance.collection('posts').where('category', isEqualTo: 'individual_notice').snapshots();
    _adminCommunityStream = FirebaseFirestore.instance.collection('posts').where('category', isEqualTo: 'community').snapshots();
    
    AdminNotificationManager.onNavigate = () {
      if (mounted) {
        setState(() {
          _selectedTab = '컨시어지';
          _conciergeSubTab = '주문관리';
        });
      }
    };
    
    _orderSub = FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
      if (snapshot.docs.length > _lastPendingOrderCount && _lastPendingOrderCount > 0) {
        int newOrders = snapshot.docs.length - _lastPendingOrderCount;
        AdminNotificationManager.showNotification(newOrders);
      }
      _lastPendingOrderCount = snapshot.docs.length;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingSuggestions();
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    AdminNotificationManager.dismiss();
    super.dispose();
  }

  Future<void> _checkPendingSuggestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('info_suggestions').where('status', isEqualTo: 'pending').get();
      if (snapshot.docs.isNotEmpty && mounted) {
        UiUtils.showPopup(context, '새로운 정보 제보가 ${snapshot.docs.length}건 있습니다.\n정보 관리 탭에서 확인해주세요.');
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _requestLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) UiUtils.showPopup(context, '위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) UiUtils.showPopup(context, '위치 권한이 거부되었습니다.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) UiUtils.showPopup(context, '위치 권한이 영구적으로 거부되었습니다.');
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = pos;
      _adminInfoSortMode = 'dist_asc';
    });
  }

  double _getDistance(BusinessModel b) {
    if (_currentPosition == null || b.address3.isEmpty) return double.maxFinite;
    final parts = b.address3.split(',');
    if (parts.length >= 2) {
      try {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
      } catch (e) {
        return double.maxFinite;
      }
    }
    return double.maxFinite;
  }

  final List<String> _tabs = ['대시보드', '게시물', '사용자', '어학원', '정보', '컨시어지'];
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
    final pointsCtrl = TextEditingController(text: (data['points'] ?? 0).toString());
    final pointsReasonCtrl = TextEditingController();
    final int originalPoints = data['points'] ?? 0;
    String? selectedSchool = data['school'];
    
    final String userEmail = data['email'] ?? '';
    final bool isAdminEmail = [
      'cebufriends79@gmail.com',
      'slptas05@gmail.com',
      'sunmoon.scc@gmail.com',
      'hdcc6th@gmail.com',
      'uhakae2026@gmail.com',
    ].contains(userEmail);

    String selectedLevel = data['level'] ?? '정회원';
    if (isAdminEmail) {
      selectedLevel = '관리자';
    }
    
    final List<String> levels = ['정회원', '예비', '연수종료', '관리자'];
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
                      TextFormField(
                        controller: pointsCtrl,
                        decoration: const InputDecoration(labelText: '포인트'),
                        keyboardType: TextInputType.number,
                        validator: (val) => (val == null || val.trim().isEmpty) ? '포인트를 입력해주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pointsReasonCtrl,
                        decoration: const InputDecoration(labelText: '포인트 변경 사유 (변경 시 필수)', hintText: '예: 관리자 직권 수정'),
                        validator: (val) {
                          if (pointsCtrl.text.trim() != originalPoints.toString() && (val == null || val.trim().isEmpty)) {
                            return '포인트 변경 시 사유를 반드시 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedLevel,
                        decoration: const InputDecoration(labelText: '회원등급'),
                        items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: isAdminEmail ? null : (val) => setState(() => selectedLevel = val!),
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
                        onChanged: isAdminEmail ? null : (val) => setState(() => selectedSchool = val),
                        validator: isAdminEmail ? null : (val) => val == null ? '어학원을 선택해주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: startDateCtrl,
                        decoration: const InputDecoration(labelText: '연수시작일', hintText: '예: 2026-07-01'),
                        readOnly: true,
                        onTap: isAdminEmail ? null : () async {
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
                        validator: isAdminEmail ? null : (val) => (val == null || val.trim().isEmpty) ? '연수시작일을 선택해주세요.' : null,
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
                      final newPoints = int.tryParse(pointsCtrl.text.trim()) ?? originalPoints;
                      
                      await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                        'name': nameCtrl.text.trim(),
                        'level': selectedLevel,
                        'phone_kr': phoneKrCtrl.text.trim(),
                        'school': selectedSchool,
                        'start_date': startDateCtrl.text.trim(),
                        'points': newPoints,
                      });

                      if (newPoints != originalPoints) {
                        final diff = newPoints - originalPoints;
                        await FirebaseFirestore.instance.collection('point_history').add({
                          'userId': doc.id,
                          'amount': diff,
                          'type': 'admin_edit',
                          'description': pointsReasonCtrl.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }

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

  Future<void> _showAddSchoolDialog(BuildContext context, bool isDarkMode) async {
    String selectedRegion = '바기오';
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final repNameCtrl = TextEditingController();
    final contactMainCtrl = TextEditingController();
    final contactSubCtrl = TextEditingController();
    final emailMainCtrl = TextEditingController();
    final emailSubCtrl = TextEditingController();
    
    String? selectedBank;
    final bankAccountNumCtrl = TextEditingController();
    final bankAccountOwnerCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final featuresCtrl = TextEditingController();
    
    List<String> bankList = [
      '--- 한국 은행 ---',
      '경남은행', '광주은행', '국민은행', '기업은행', '농협은행', '대구은행', 
      '부산은행', '새마을금고', '수협은행', '신한은행', '신협', '우리은행', 
      '우체국', '전북은행', '제주은행', '카카오뱅크', '케이뱅크', '토스뱅크', 
      '하나은행', '한국투자증권', 'SC제일은행',
      '--- 필리핀 은행 ---',
      'BDO', 'BPI', 'Metrobank', 'PNB', 'RCBC', 'Security Bank', 'UnionBank'
    ];

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              title: const Text('어학원 새로 추가'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedRegion,
                          decoration: const InputDecoration(labelText: '지역'),
                          items: ['바기오', '클락', '세부', '보홀'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedRegion = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: '어학원 이름 (예: BECI)'),
                          validator: (v) => v!.isEmpty ? '이름을 입력하세요' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(labelText: '위치'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: repNameCtrl,
                          decoration: const InputDecoration(labelText: '대표자 이름'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: contactMainCtrl, decoration: const InputDecoration(labelText: '연락처 (대표)'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: contactSubCtrl, decoration: const InputDecoration(labelText: '연락처 (기타)'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: emailMainCtrl, decoration: const InputDecoration(labelText: '이메일 (대표)'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: emailSubCtrl, decoration: const InputDecoration(labelText: '이메일 (기타)'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedBank,
                          decoration: const InputDecoration(labelText: '입금계좌 은행 (선택)'),
                          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                          items: bankList.map((String value) {
                            bool isSeparator = value.startsWith('---');
                            return DropdownMenuItem<String>(
                              value: value,
                              enabled: !isSeparator,
                              child: Text(value, style: TextStyle(
                                color: isSeparator ? Colors.grey : (isDarkMode ? Colors.white : Colors.black),
                                fontWeight: isSeparator ? FontWeight.bold : FontWeight.normal,
                              )),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null && !val.startsWith('---')) setState(() => selectedBank = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(flex: 3, child: TextFormField(controller: bankAccountNumCtrl, decoration: const InputDecoration(labelText: '계좌번호'))),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: TextFormField(controller: bankAccountOwnerCtrl, decoration: const InputDecoration(labelText: '명의'))),
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() => isSaving = true);
                      try {
                        String schoolId = '${selectedRegion}_${nameCtrl.text.trim()}';
                        final existing = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
                        if (existing.exists) {
                          if (context.mounted) UiUtils.showPopup(context, '동일한 지역에 같은 이름의 어학원이 존재합니다.');
                          setState(() => isSaving = false);
                          return;
                        }
                        await FirebaseFirestore.instance.collection('schools').doc(schoolId).set({
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
                          'created_at': FieldValue.serverTimestamp(),
                          'updated_at': FieldValue.serverTimestamp(),
                        });
                        
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          UiUtils.showPopup(context, '어학원 정보가 추가되었습니다.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          UiUtils.showPopup(context, '추가 실패: $e');
                          setState(() => isSaving = false);
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('추가', style: TextStyle(color: Colors.white)),
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
                                  value: bank,
                                  enabled: !isSeparator,
                                  child: Text(bank, style: TextStyle(
                                    color: isSeparator ? Colors.grey : (isDarkMode ? Colors.white : Colors.black),
                                    fontWeight: isSeparator ? FontWeight.bold : FontWeight.normal,
                                  )),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && !val.startsWith('---')) setState(() => selectedBank = val);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
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
                  isDarkMode ? 'assets/images/logo_dark.png' : 'assets/images/logo.png',
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.admin_panel_settings, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                ),
              ),
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
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots(),
            builder: (context, snapshot) {
              int pendingCount = 0;
              if (snapshot.hasData) {
                pendingCount = snapshot.data!.docs.length;
              }
              if (pendingCount == 0) return const SizedBox.shrink();

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTab = '대시보드';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.pink),
                      const SizedBox(width: 4),
                      Text(
                        '+$pendingCount',
                        style: const TextStyle(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: PreferencesService.favoritesNotifier,
            builder: (context, favorites, _) {
              final String favId = 'admin_tab_$_selectedTab';
              final isFav = favorites.any((e) => e['id'] == favId);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  if (isFav) {
                    PreferencesService.removeFavorite(favId);
                  } else {
                    PreferencesService.addFavorite({
                      'id': favId,
                      'type': 'menu',
                      'title': '관리 - $_selectedTab',
                      'iconCodePoint': Icons.admin_panel_settings.codePoint,
                      'iconFontFamily': Icons.admin_panel_settings.fontFamily,
                      'colorValue': 0xFFE6F3FF, // Light blue
                      'isAdminMenu': true,
                      'adminTab': _selectedTab,
                    });
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 탭 영역
          Container(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
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
                        color: isSelected ? Colors.blue : (isDarkMode ? Colors.white54 : Colors.black54),
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

    if (_selectedTab == '대시보드') {
      return _buildDashboardTab(isDarkMode);
    }

    if (_selectedTab == '게시물') {
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
          // 하위 탭 (공지사항, 쪽지, 자유게시판)
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildPostAdminSubTabItem('공지사항', isDarkMode),
                _buildPostAdminSubTabItem('쪽지', isDarkMode),
                _buildPostAdminSubTabItem('자유게시판', isDarkMode),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: _postAdminSubTab == '공지사항'
                ? _buildPostList('notice', isDarkMode)
                : _postAdminSubTab == '쪽지'
                    ? _buildPersonalNoticeTab(isDarkMode)
                    : _buildPostList('community', isDarkMode),
          ),
        ],
      );
    }

    if (_selectedTab == '사용자') {
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

    if (_selectedTab == '어학원') {
      final List<String> regions = ['전체', '바기오', '클락', '세부', '보홀'];
      
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final schoolDataMap = { for (var doc in docs) doc.id: doc.data() as Map<String, dynamic> };
          
          final sortedSchools = docs
              .map((doc) => doc.id)
              .where((school) => _schoolAdminRegionTab == '전체' || school.startsWith('${_schoolAdminRegionTab}_'))
              .toList();

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    ...regions.map((region) {
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
                    }),
                    InkWell(
                      onTap: () => _showAddSchoolDialog(context, isDarkMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(right: 8, left: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('새로 추가', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
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

    if (_selectedTab == '컨시어지') {
      return Column(
        children: [
          // 서브 탭 바
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
              border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildConciergeSubTabItem('대시보드', isDarkMode),
                _buildConciergeSubTabItem('주문관리', isDarkMode),
                _buildConciergeSubTabItem('판매관리', isDarkMode),
                _buildConciergeSubTabItem('대여관리', isDarkMode),
              ],
            ),
          ),
          // 컨텐츠 영역
          Expanded(
            child: _conciergeSubTab == '대시보드'
                ? _buildConciergeDashboard(isDarkMode)
                : _conciergeSubTab == '주문관리'
                    ? AdminShopManagementTab(initialFilter: _adminOrderFilter)
                    : _conciergeSubTab == '판매관리'
                        ? AdminProductManagementTab(productType: 'buy', initialProductId: _selectedProductId)
                        : AdminProductManagementTab(productType: 'rent', initialProductId: _selectedProductId),
          ),
        ],
      );
    }
    if (_selectedTab == '정보') {
      return _buildInfoAdminTab(isDarkMode);
    }
    
    return Center(child: Text('$_selectedTab 기능은 준비 중입니다.'));
  }

  Widget _buildInfoAdminTab(bool isDarkMode) {
    return Column(
      children: [
        // 탭: 대기중 / 완료
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ToggleButtons(
                isSelected: [_infoSuggestionStatus == 'pending', _infoSuggestionStatus == 'completed'],
                onPressed: (index) {
                  setState(() {
                    _infoSuggestionStatus = index == 0 ? 'pending' : 'completed';
                  });
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                children: const [
                  Text('대기중'),
                  Text('확인 완료'),
                ],
              ),
            ),
          ],
        ),
        // 제보 리스트 (상단 고정 높이 3줄 정도 스크롤)
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('info_suggestions').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('오류가 발생했습니다.'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((doc) {
                final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
                if (_infoSuggestionStatus == 'pending') return status == 'pending';
                return status != 'pending';
              }).toList();

              if (docs.isEmpty) return const Center(child: Text('해당 상태의 제보가 없습니다.'));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  final type = data['type'] ?? '기타';
                  final businessPath = data['businessPath'] ?? type;
                  final reporterName = data['reporterName'] ?? data['userEmail'] ?? 'Unknown';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    child: InkWell(
                      onTap: () => _showInfoSuggestionPopup(context, docId, data, isDarkMode),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '[제보] $businessPath',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : Colors.black),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reporterName,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 지역 선택 탭
        Container(
          color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: commonRegions.map((reg) {
                final isSelected = _adminInfoRegion == reg;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _adminInfoRegion = reg;
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

        // 3차 서브 탭 (관광, 마사지 등)
        Container(
          color: isDarkMode ? Colors.grey[900] : const Color(0xFFE9ECEF),
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: regionSubCategories.map((subCat) {
                final isSelected = _adminInfoSubCategory == subCat['label'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _adminInfoSubCategory = subCat['label'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Text(
                      subCat['label'],
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

        // 등록된 업체 리스트 헤더 및 추가 버튼
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _adminInfoSubCategory == '전체' ? '$_adminInfoRegion 전체' : '$_adminInfoRegion $_adminInfoSubCategory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBusinessDialog(context, isDarkMode),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 정렬 토글 버튼 (가나다)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_adminInfoSortMode == 'name_asc') {
                          _adminInfoSortMode = 'name_desc';
                        } else {
                          _adminInfoSortMode = 'name_asc';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _adminInfoSortMode.startsWith('name') ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: _adminInfoSortMode.startsWith('name') ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Text('정렬(이름)', style: TextStyle(fontSize: 12)),
                          Icon(_adminInfoSortMode == 'name_asc' ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 거리순 토글
                  InkWell(
                    onTap: () async {
                      if (_adminInfoSortMode.startsWith('dist')) {
                        setState(() {
                          _adminInfoSortMode = _adminInfoSortMode == 'dist_asc' ? 'dist_desc' : 'dist_asc';
                        });
                      } else {
                        await _requestLocation();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _adminInfoSortMode.startsWith('dist') ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: _adminInfoSortMode.startsWith('dist') ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Text('거리', style: TextStyle(fontSize: 12)),
                          if (_adminInfoSortMode.startsWith('dist'))
                            Icon(_adminInfoSortMode == 'dist_asc' ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 지도보기 토글
                  InkWell(
                    onTap: () async {
                      if (!_showMap && _currentPosition == null) {
                        await _requestLocation();
                      }
                      setState(() {
                        _showMap = !_showMap;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showMap ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: _showMap ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.map, size: 14, color: _showMap ? Colors.blue : Colors.grey),
                          const SizedBox(width: 4),
                          Text('지도보기', style: TextStyle(fontSize: 12, color: _showMap ? Colors.blue : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 영업중 필터
                  Row(
                    children: [
                      Checkbox(
                        value: _adminInfoOpenNowFilter,
                        onChanged: (val) {
                          setState(() {
                            _adminInfoOpenNowFilter = val ?? false;
                          });
                        },
                      ),
                      const Text('영업중', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 등록된 업체 리스트
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _adminInfoSubCategory == '전체'
                ? FirebaseFirestore.instance.collection('directory').where('region', isEqualTo: _adminInfoRegion).snapshots()
                : FirebaseFirestore.instance.collection('directory').where('region', isEqualTo: _adminInfoRegion).where('subCategory', isEqualTo: _adminInfoSubCategory).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('오류가 발생했습니다.'));
              if (snapshot.connectionState == ConnectionState.waiting && _cachedAdminBusinesses == null) return const Center(child: CircularProgressIndicator());
              
              if (snapshot.hasData) {
                final docs = snapshot.data?.docs ?? [];
                _cachedAdminBusinesses = docs.map((doc) => BusinessModel.fromFirestore(doc)).toList();
              }
              
              var businesses = _cachedAdminBusinesses ?? [];
              
              if (businesses.isEmpty) {
                return Center(
                  child: Text(
                    "'$_adminInfoRegion' 지역의 '$_adminInfoSubCategory' 정보가 없습니다.",
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                );
              }
              
              // 영업중 필터
              if (_adminInfoOpenNowFilter) {
                businesses = businesses.where((b) => TimeUtils.isOpenNow(b.operatingHours)).toList();
              }
              
              // 정렬
              if (_adminInfoSortMode == 'name_asc') {
                businesses.sort((a, b) => a.name.compareTo(b.name));
              } else if (_adminInfoSortMode == 'name_desc') {
                businesses.sort((a, b) => b.name.compareTo(a.name));
              } else if (_adminInfoSortMode.startsWith('dist') && _currentPosition != null) {
                businesses.sort((a, b) {
                  final distA = _getDistance(a);
                  final distB = _getDistance(b);
                  if (_adminInfoSortMode == 'dist_asc') {
                    return distA.compareTo(distB);
                  } else {
                    return distB.compareTo(distA);
                  }
                });
              }
              
              if (businesses.isEmpty) {
                return Center(
                  child: Text(
                    "조건에 맞는 업체가 없습니다.",
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                );
              }

              if (_showMap) {
                return BusinessMapView(
                  businesses: businesses,
                  initialCenter: _currentPosition != null
                      ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : null,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  final distance = _getDistance(business);
                  return BusinessCard(
                    business: business,
                    distance: distance != double.maxFinite ? distance : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessDetailScreen(business: business),
                        ),
                      );
                    },
                    onEdit: () => _showEditBusinessDialog(context, business),
                    onDelete: () => _deleteBusiness(business),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddBusinessDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (ctx) => AddBusinessDialog(
        region: _adminInfoRegion,
        subCategory: _adminInfoSubCategory,
      ),
    );
  }

  void _showEditBusinessDialog(BuildContext context, BusinessModel business) {
    showDialog(
      context: context,
      builder: (ctx) => AddBusinessDialog(
        region: business.region,
        subCategory: business.subCategory,
        existingBusiness: business,
      ),
    );
  }

  void _deleteBusiness(BusinessModel business) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${business.name} 업체를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('directory').doc(business.id).delete();
                if (mounted) UiUtils.showPopup(context, '삭제되었습니다.');
              } catch (e) {
                if (mounted) UiUtils.showPopup(context, '삭제 중 오류 발생: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDirectUpdateDialog(BuildContext context, bool isDarkMode) {
    // A simple dialog for admin to update daily info directly
    final typeCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정보 직접 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: '정보 유형 (주유, 환율 등)')),
            const SizedBox(height: 8),
            TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '상세 내용')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
               await FirebaseFirestore.instance.collection('daily_info').add({
                 'type': typeCtrl.text,
                 'content': contentCtrl.text,
                 'updatedAt': FieldValue.serverTimestamp(),
               });
               if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
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

        var rawDocs = snapshot.data!.docs;
        var filteredDocs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'];
          final name = data['name'];
          return email != null && email.toString().isNotEmpty && name != null && name.toString().isNotEmpty;
        }).toList();
        
        var modifiableDocs = List<QueryDocumentSnapshot>.from(filteredDocs);
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
                      
                      final String email = data['email'] ?? '';
                      final bool isAdminUser = [
                        'cebufriends79@gmail.com',
                        'slptas05@gmail.com',
                        'sunmoon.scc@gmail.com',
                        'hdcc6th@gmail.com',
                        'uhakae2026@gmail.com',
                      ].contains(email);

                      String displaySchool = data['school'] ?? '소속 미정';
                      if (isAdminUser) {
                        displaySchool = '관리자';
                      } else if (_userAdminRegion != '전체' && displaySchool.startsWith('${_userAdminRegion}_')) {
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          startDate,
                                          style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AdminPointManagementDialog(userDoc: doc),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 4.0),
                                          child: Icon(Icons.savings, color: Colors.pinkAccent, size: 18),
                                        ),
                                      ),
                                    ],
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
    Stream<QuerySnapshot> stream;
    if (category == 'notice') stream = _adminNoticeStream;
    else if (category == 'individual_notice') stream = _adminIndividualNoticeStream;
    else stream = _adminCommunityStream;

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
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

        bool isDescending = true;
        if (category == 'notice') isDescending = _isGeneralNoticeDescending;
        else if (category == 'individual_notice') isDescending = _isNoticeDescending;
        else if (category == 'community') isDescending = _isCommunityDescending;

        var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
        modifiableDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          return isDescending ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
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
    
    bool? isDescending;
    if (title == '공지사항') isDescending = _isGeneralNoticeDescending;
    else if (title == '쪽지') isDescending = _isNoticeDescending;
    else if (title == '자유게시판') isDescending = _isCommunityDescending;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (_postAdminSubTab == title) {
              if (title == '공지사항') _isGeneralNoticeDescending = !_isGeneralNoticeDescending;
              else if (title == '쪽지') _isNoticeDescending = !_isNoticeDescending;
              else if (title == '자유게시판') _isCommunityDescending = !_isCommunityDescending;
            } else {
              _postAdminSubTab = title;
            }
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ),
              if (isDescending != null) ...[
                const SizedBox(width: 4),
                Icon(isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ],
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
    bool isDescending = true; // 정렬 상태
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                        Row(
                          children: [
                            Text('$userName 님의 쪽지 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  isDescending = !isDescending;
                                });
                              },
                              child: Icon(isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: isDarkMode ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                        IconButton(icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Stack(
                        children: [
                          StreamBuilder<QuerySnapshot>(
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
                                return Center(child: Text('등록된 쪽지가 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                              }

                              final notices = snapshot.data!.docs.toList();
                              // Dart 메모리에서 정렬
                              notices.sort((a, b) {
                                try {
                                  final aData = a.data() as Map<String, dynamic>;
                                  final bData = b.data() as Map<String, dynamic>;
                                  final aDate = aData['createdAt'] is Timestamp ? aData['createdAt'] as Timestamp : null;
                                  final bDate = bData['createdAt'] is Timestamp ? bData['createdAt'] as Timestamp : null;
                                  
                                  if (aDate == null && bDate == null) return 0;
                                  if (aDate == null) return 1;
                                  if (bDate == null) return -1;
                                  final result = bDate.compareTo(aDate);
                                  return isDescending ? result : -result;
                                } catch (e) {
                                  return 0;
                                }
                              });

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80), // FAB 가리지 않도록 여백
                            itemCount: notices.length,
                            itemBuilder: (ctx, index) {
                              final notice = notices[index];
                              final data = notice.data() as Map<String, dynamic>;
                              final title = data['title'] ?? '제목 없음';
                              final content = data['content'] ?? '';
                              final isRead = data['isRead'] as bool? ?? false;
                              final createdAt = data['createdAt'] as Timestamp?;
                              final timeAgo = createdAt != null 
                                  ? '${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}' 
                                  : '';
                              final imageUrls = data['image_urls'] as List<dynamic>? ?? [];
                              
                              // 관리자 화면이므로 관리자가 작성한 글(isFromUser != true)이 '내' 글입니다.
                              final bool isFromMe = data['isFromUser'] != true;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                child: Row(
                                  mainAxisAlignment: !isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (isFromMe) ...[
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                        child: Icon(Icons.admin_panel_settings, size: 20, color: isDarkMode ? Colors.grey : Colors.black54),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (!isFromMe)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (!isRead) const Text('1', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                            Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                    Flexible(
                                      child: InkWell(
                                        onTap: () {
                                          _showPersonalNoticeEditDialog(context, notice.id, userId, title, content, isDarkMode, initialImageUrls: imageUrls.cast<String>());
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isFromMe 
                                                ? (isDarkMode ? Colors.grey[800] : Colors.white)
                                                : (isDarkMode ? Colors.blue[900] : Colors.blue[100]),
                                            border: isFromMe ? Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300) : null,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: isFromMe ? const Radius.circular(4) : const Radius.circular(16),
                                              bottomRight: isFromMe ? const Radius.circular(16) : const Radius.circular(4),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                                              const SizedBox(height: 4),
                                              Text(
                                                content, 
                                                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
                                              ),
                                              if (imageUrls.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.image, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
                                                    const SizedBox(width: 4),
                                                    Text('사진 첨부됨', style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.black54)),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isFromMe)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isRead) const Text('1', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                            Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                    if (!isFromMe) ...[
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                        child: Icon(Icons.person, size: 20, color: isDarkMode ? Colors.grey : Colors.black54),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: isDarkMode ? Colors.blue[700] : Colors.white,
                          child: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                          onPressed: () {
                            _showPersonalNoticeEditDialog(context, null, userId, '', '', isDarkMode, initialImageUrls: []);
                          },
                        ),
                      ),
                    ],
                  ),
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
              title: Text(docId == null ? '신규 쪽지' : '쪽지 수정', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
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
                                      child: InkWell(
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
                                      child: InkWell(
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
                      if (docId == null) 'isFromUser': false,
                      if (docId == null) 'senderName': '관리자',
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
  Widget _buildDashboardTab(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('전체 상황 모니터링', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // 5 sections grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildDashboardCard('게시물', 'posts', Icons.article, isDarkMode),
              _buildDashboardCard('사용자', 'users', Icons.people, isDarkMode),
              _buildDashboardCard('어학원', 'directory', Icons.school, isDarkMode),
              _buildDashboardCard('정보', 'info_suggestions', Icons.info, isDarkMode),
              _buildDashboardCard('컨시어지', 'orders', Icons.room_service, isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, String collection, IconData icon, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: collection == 'users'
          ? FirebaseFirestore.instance.collection(collection).where('level', isEqualTo: '예비').snapshots()
          : collection == 'info_suggestions'
              ? FirebaseFirestore.instance.collection(collection).where('status', isEqualTo: 'pending').snapshots()
              : collection == 'orders'
                  ? FirebaseFirestore.instance.collection(collection).where('status', isEqualTo: 'pending').snapshots()
                  : collection == 'directory'
                      ? FirebaseFirestore.instance.collection(collection).where('category', isEqualTo: '어학원').snapshots()
                      : FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        String desc = '';
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
          if (collection == 'users') desc = '승인 대기 중';
          else if (collection == 'info_suggestions') desc = '대기 중인 제보';
          else if (collection == 'orders') desc = '접수 대기 중';
          else if (collection == 'posts') desc = '전체 게시물 수';
          else if (collection == 'directory') desc = '전체 어학원 수';
        }
        
        return Card(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTab = title;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    Text('$count 건', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                    if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54)),
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInfoSuggestionPopup(BuildContext context, String docId, Map<String, dynamic> data, bool isDarkMode) {
    final userEmail = data['userEmail'] ?? 'Unknown';
    final type = data['type'] ?? '기타';
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    String timeAgo = '';
    if (data['createdAt'] != null) {
      final dt = (data['createdAt'] as Timestamp).toDate();
      timeAgo = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('[$type] 제보 상세내용', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('제보자: $userEmail', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('일시: $timeAgo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                const Text('상세 내용:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                  child: Text(content),
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('첨부 사진:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('info_suggestions').doc(docId).update({'status': 'approved'});
                if (context.mounted) UiUtils.showPopup(context, '제보가 확인 완료 처리되었습니다.');
              },
              child: const Text('확인 완료 처리'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConciergeSubTabItem(String tabName, bool isDarkMode) {
    final isSelected = _conciergeSubTab == tabName;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _conciergeSubTab = tabName;
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
            tabName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConciergeDashboard(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('컨시어지 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // 주문 요약 카드
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnapshot) {
              int pending = 0;
              int approved = 0;
              int preparing = 0;
              int shipping = 0;
              int completed = 0;

              Map<String, int> itemActiveCount = {}; // itemId -> count of items in progress

              if (orderSnapshot.hasData) {
                for (var doc in orderSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'];
                  
                  if (status == 'pending') pending++;
                  else if (status == 'approved') approved++;
                  else if (status == 'preparing') preparing++;
                  else if (['shipping', 'delivered', 'not_received', 'receipt_confirmed'].contains(status)) shipping++;
                  else if (['completed', 'rejected', 'canceled'].contains(status)) completed++;

                  if (['pending', 'approved', 'preparing', 'shipping', 'delivered', 'not_received', 'receipt_confirmed'].contains(status)) {
                    final items = data['items'] as List<dynamic>? ?? [];
                    for (var item in items) {
                      final itemId = item['productId'];
                      final quantity = item['quantity'] ?? 1;
                      if (itemId != null) {
                        itemActiveCount[itemId] = (itemActiveCount[itemId] ?? 0) + (quantity as int);
                      }
                    }
                  }
                }
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('주문 처리 현황', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                                label: const Text('초기화', style: TextStyle(color: Colors.red)),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('초기화 확인'),
                                      content: const Text('모든 사용자의 주문 및 대여 기록을 완전히 삭제합니다.\n이 작업은 되돌릴 수 없습니다. 진행하시겠습니까?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('삭제'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    final snapshots = await FirebaseFirestore.instance.collection('orders').get();
                                    
                                    // Use a loop to delete in chunks since batch has a limit of 500, though testing usually has fewer.
                                    var batch = FirebaseFirestore.instance.batch();
                                    int count = 0;
                                    for (var doc in snapshots.docs) {
                                      batch.delete(doc.reference);
                                      count++;
                                      if (count == 400) {
                                        await batch.commit();
                                        batch = FirebaseFirestore.instance.batch();
                                        count = 0;
                                      }
                                    }
                                    if (count > 0) {
                                      await batch.commit();
                                    }
                                    
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('알림'),
                                          content: const Text('모든 주문 기록이 초기화되었습니다.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('확인'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(child: _buildStatItem('승인대기', pending.toString(), Colors.orange[700]!, onTap: () {
                                setState(() { _conciergeSubTab = '주문관리'; _adminOrderFilter = 'pending'; });
                              })),
                              Expanded(child: _buildStatItem('결제진행', approved.toString(), Colors.green[300]!, onTap: () {
                                setState(() { _conciergeSubTab = '주문관리'; _adminOrderFilter = 'approved'; });
                              })),
                              Expanded(child: _buildStatItem('배송준비', preparing.toString(), Colors.green[600]!, onTap: () {
                                setState(() { _conciergeSubTab = '주문관리'; _adminOrderFilter = 'preparing'; });
                              })),
                              Expanded(child: _buildStatItem('배송중', shipping.toString(), Colors.green[900]!, onTap: () {
                                setState(() { _conciergeSubTab = '주문관리'; _adminOrderFilter = 'shipping'; });
                              })),
                              Expanded(child: _buildStatItem('완료', completed.toString(), Colors.blue[700]!, onTap: () {
                                setState(() { _conciergeSubTab = '주문관리'; _adminOrderFilter = 'completed'; });
                              })),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 상품 현황 (상하 분리 리스트)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('shop_items').snapshots(),
                    builder: (context, productSnapshot) {
                      if (!productSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final allProducts = productSnapshot.data!.docs;
                      final buyProducts = allProducts.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'buy').toList();
                      final rentProducts = allProducts.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'rent').toList();
                      
                      return Column(
                        children: [
                          _buildProductListCard('판매 물품 현황', buyProducts, itemActiveCount, isDarkMode, onTapTitle: () {
                            setState(() { _conciergeSubTab = '판매관리'; _selectedProductId = null; });
                          }, onTapItem: (docId) {
                            setState(() { _conciergeSubTab = '판매관리'; _selectedProductId = docId; });
                          }),
                          const SizedBox(height: 16),
                          _buildProductListCard('대여 물품 현황', rentProducts, itemActiveCount, isDarkMode, onTapTitle: () {
                            setState(() { _conciergeSubTab = '대여관리'; _selectedProductId = null; });
                          }, onTapItem: (docId) {
                            setState(() { _conciergeSubTab = '대여관리'; _selectedProductId = docId; });
                          }),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductListCard(String title, List<QueryDocumentSnapshot> products, Map<String, int> activeCounts, bool isDarkMode, {VoidCallback? onTapTitle, void Function(String)? onTapItem}) {
    String sortColumn = '물품명';
    bool sortAscending = true;

    return StatefulBuilder(
      builder: (context, setState) {
        final sortedProducts = List<QueryDocumentSnapshot>.from(products);
        sortedProducts.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final nameA = dataA['name'] ?? '이름 없음';
          final nameB = dataB['name'] ?? '이름 없음';
          final totalA = dataA['totalQuantity'] ?? 0;
          final totalB = dataB['totalQuantity'] ?? 0;
          final progA = activeCounts[a.id] ?? 0;
          final progB = activeCounts[b.id] ?? 0;
          final availA = totalA > 0 ? (totalA - progA) : 0;
          final availB = totalB > 0 ? (totalB - progB) : 0;
          
          int cmp = 0;
          if (sortColumn == '물품명') cmp = nameA.compareTo(nameB);
          else if (sortColumn == '전체') cmp = totalA.compareTo(totalB);
          else if (sortColumn == '진행') cmp = progA.compareTo(progB);
          else if (sortColumn == '재고') cmp = availA.compareTo(availB);
          
          return sortAscending ? cmp : -cmp;
        });

        Widget buildHeader(String label, int flex, {TextAlign align = TextAlign.left}) {
          final isSelected = sortColumn == label;
          return Expanded(
            flex: flex,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (sortColumn == label) {
                    sortAscending = !sortAscending;
                  } else {
                    sortColumn = label;
                    sortAscending = true;
                  }
                });
              },
              child: Row(
                mainAxisAlignment: align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black87)),
                  if (isSelected) Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                  if (!isSelected) const SizedBox(width: 14), // placeholder for alignment
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onTapTitle,
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('등록된 물품이 없습니다.', style: TextStyle(color: Colors.grey)),
                  )
                else ...[
                  // Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        buildHeader('물품명', 5),
                        buildHeader('전체', 2, align: TextAlign.right),
                        buildHeader('진행', 2, align: TextAlign.right),
                        buildHeader('재고', 2, align: TextAlign.right),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250), // limits height to allow scrolling
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: sortedProducts.length,
                        itemBuilder: (context, index) {
                          final doc = sortedProducts[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] ?? '이름 없음';
                          final totalQuantity = data['totalQuantity'] ?? 0;
                          final inProgress = activeCounts[doc.id] ?? 0;
                          final available = totalQuantity > 0 ? (totalQuantity - inProgress) : 0;
                          
                          final isInfinite = totalQuantity == 0;

                          return InkWell(
                            onTap: onTapItem != null ? () => onTapItem(doc.id) : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5, 
                                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 14.0),
                                      child: Text(
                                        isInfinite ? '∞' : '$totalQuantity',
                                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                                        textAlign: TextAlign.right,
                                      ),
                                    )
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 14.0),
                                      child: Text(
                                        '$inProgress',
                                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                                        textAlign: TextAlign.right,
                                      ),
                                    )
                                  ),
                                  Expanded(
                                    flex: 2, 
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 14.0),
                                      child: Text(
                                        isInfinite ? '∞' : '$available',
                                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                                        textAlign: TextAlign.right,
                                      ),
                                    )
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatItem(String label, String value, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

