import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'school_admin_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _selectedTab = '컨시어지 관리';
  final List<String> _tabs = ['게시물 관리', '사용자 관리', '어학원 관리', '정보 관리', '컨시어지 관리'];
  
  final List<String> _schoolList = [
    '바기오_BECI',
    '바기오_CIJ',
    '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu',
    '세부_BK Academy',
    '세부_Blue Ocean',
    '세부_E FRIENDS',
    '세부_JIE',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문 상태가 업데이트되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
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
    if (_selectedTab == '어학원 관리') {
      // 어학원 리스트 가나다 순 정렬 (미리 정렬되어 있긴 하지만 명확하게)
      final sortedSchools = List<String>.from(_schoolList)..sort();
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedSchools.length,
        itemBuilder: (context, index) {
          final schoolName = sortedSchools[index];
          return Card(
            color: Colors.white,
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.school, color: Colors.blue),
              title: Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SchoolAdminDetailScreen(schoolName: schoolName),
                  ),
                );
              },
            ),
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
}
