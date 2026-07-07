import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/ui_utils.dart';

class SystemPointHistoryDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> historyDocs;

  const SystemPointHistoryDialog({super.key, required this.historyDocs});

  @override
  State<SystemPointHistoryDialog> createState() => _SystemPointHistoryDialogState();
}

class _SystemPointHistoryDialogState extends State<SystemPointHistoryDialog> {
  DateTimeRange? _selectedDateRange;
  String? _selectedUserId;
  List<QueryDocumentSnapshot> _users = [];
  Map<String, String> _userNames = {};
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      if (mounted) {
        setState(() {
          final adminEmails = [
            'cebufriends79@gmail.com',
            'slptas05@gmail.com',
            'sunmoon.scc@gmail.com',
            'hdcc6th@gmail.com',
            'uhak2026@gmail.com',
          ];
          
          _users = snap.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? '';
            final name = (data['name'] ?? '').toString().toLowerCase();
            if (adminEmails.contains(email)) return false;
            if (name == 'in hwan kim') return false;
            return true;
          }).toList();
          
          for (var doc in _users) {
            final data = doc.data() as Map<String, dynamic>;
            _userNames[doc.id] = data['name'] ?? '알 수 없음';
          }
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _showDetailPopup(Map<String, dynamic> data, String userName, String finalTitle, String dateStr, double adminEffect) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final orderId = data['orderId'] as String?;

    List<Widget> orderItemsWidgets = [];
    if (orderId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        if (doc.exists) {
          final orderData = doc.data() as Map<String, dynamic>;
          final items = List<dynamic>.from(orderData['items'] ?? []);
          orderItemsWidgets.add(const SizedBox(height: 16));
          orderItemsWidgets.add(const Text('주문 상세:', style: TextStyle(fontWeight: FontWeight.bold)));
          for (var item in items) {
            final name = item['name'] ?? '';
            final quantity = item['quantity'] ?? 1;
            final price = item['totalPriceKrw'] ?? 0;
            orderItemsWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '- $name x $quantity ('),
                      const WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.savings, size: 14))),
                      TextSpan(text: '${NumberFormat('#,###').format(price)})'),
                    ],
                  ),
                  style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ),
            );
          }
        }
      } catch (e) {
        orderItemsWidgets.add(const Text('\n주문 정보를 불러오지 못했습니다.', style: TextStyle(color: Colors.red)));
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('상세 내역', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('사용자: $userName'),
                const SizedBox(height: 8),
                Text('일시: $dateStr'),
                const SizedBox(height: 8),
                Text('내용: $finalTitle'),
                const SizedBox(height: 8),
                Text(
                  '변동 포인트: ${adminEffect > 0 ? '+' : ''}${currencyFormatter.format(adminEffect)} P',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: adminEffect > 0 ? Colors.blue : Colors.red,
                  ),
                ),
                ...orderItemsWidgets,
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildList(List<QueryDocumentSnapshot> rawDocs, bool isDarkMode) {
    final docs = rawDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      return userId != null && _userNames.containsKey(userId);
    }).toList();

    if (docs.isEmpty) {
      return const Center(child: Text('해당 내역이 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] ?? '';
        final amount = (data['amount'] ?? 0).toDouble();
        final desc = data['description'] ?? '';
        final createdAt = data['createdAt'] as Timestamp?;
        final dateStr = createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate()) : '';
        final userId = data['userId'] as String?;
        final userName = userId != null ? (_userNames[userId] ?? '알 수 없음') : '알 수 없음';

        double adminEffect = -amount; // User point loss means admin point gain
        String typeLabel = type;

        if (type == 'order_payment' || type == 'order_payment_by_admin') {
          typeLabel = '물품/서비스 결제';
        } else if (type == 'order_refund') {
          typeLabel = '결제 취소 (환불)';
        } else if (type == 'deposit_refund') {
          typeLabel = '물품 반납 (보증금 환불)';
        } else if (type == 'point_recharge_by_admin') {
          typeLabel = '무통장 입금 승인 (포인트 충전)';
        } else if (type == 'admin_edit') {
          typeLabel = '관리자 포인트 직접 수정';
        } else if (type == 'initial_bonus') {
          typeLabel = '가입 축하 포인트 지급';
        } else if (type == 'login_bonus' || type == 'daily_login') {
          typeLabel = '일일 접속 포인트 지급';
        }

        String finalTitle = desc.isNotEmpty ? desc : typeLabel;
        if (finalTitle.contains('상품 주문 결제 (대기중)')) {
          finalTitle = '물품 주문 결제 (이전 기록)';
        }

        return ListTile(
          onTap: () => _showDetailPopup(data, userName, finalTitle, dateStr, adminEffect),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          title: Text('[$userName] $finalTitle', style: const TextStyle(fontSize: 13)),
          subtitle: Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: Text(
            '${adminEffect > 0 ? '+' : ''}${currencyFormatter.format(adminEffect)} P',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: adminEffect > 0 ? Colors.blue : Colors.red,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.all(20),
        title: const Text('시스템 포인트 변동 내역', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: '전체'),
                  Tab(text: '기간'),
                  Tab(text: '사용자'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe to change tabs so dropdowns/pickers don't conflict
                  children: [
                    // Tab 1: 전체
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildList(widget.historyDocs, isDarkMode),
                    ),
                    
                    // Tab 2: 기간
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDateRange == null 
                                      ? '기간을 선택해주세요' 
                                      : '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _pickDateRange,
                                child: const Text('기간 선택'),
                              ),
                            ],
                          ),
                          const Divider(),
                          Expanded(
                            child: _buildList(
                              widget.historyDocs.where((doc) {
                                if (_selectedDateRange == null) return false;
                                final data = doc.data() as Map<String, dynamic>;
                                final createdAt = data['createdAt'] as Timestamp?;
                                if (createdAt == null) return false;
                                final date = createdAt.toDate();
                                // end date should include the whole day
                                final endOfDay = _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
                                return date.isAfter(_selectedDateRange!.start) && date.isBefore(endOfDay);
                              }).toList(),
                              isDarkMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tab 3: 사용자
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _isLoadingUsers 
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('사용자를 선택해주세요'),
                                value: _selectedUserId,
                                items: _users.map((userDoc) {
                                  final data = userDoc.data() as Map<String, dynamic>;
                                  final name = data['name'] ?? '알 수 없음';
                                  return DropdownMenuItem<String>(
                                    value: userDoc.id,
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedUserId = val;
                                  });
                                },
                              ),
                          const Divider(),
                          Expanded(
                            child: _buildList(
                              widget.historyDocs.where((doc) {
                                if (_selectedUserId == null) return false;
                                final data = doc.data() as Map<String, dynamic>;
                                return data['userId'] == _selectedUserId;
                              }).toList(),
                              isDarkMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('경고'),
                  content: const Text(
                    '정말 전체 내역을 초기화하시겠습니까?\\n\\n이 작업은 다음을 수행하며 절대 되돌릴 수 없습니다:\\n1. 모든 사용자의 보유 포인트를 0으로 초기화\\n2. 시스템 포인트 변동 내역 전체 삭제\\n3. 초기 예비 포인트를 0으로 리셋',
                    style: TextStyle(color: Colors.red),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('초기화', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // 1. Reset all users points to 0
                final usersSnap = await FirebaseFirestore.instance.collection('users').get();
                final batch = FirebaseFirestore.instance.batch();
                for (var doc in usersSnap.docs) {
                  batch.update(doc.reference, {'points': 0});
                }
                
                // 2. Clear point_history
                final historySnap = await FirebaseFirestore.instance.collection('point_history').get();
                for (var doc in historySnap.docs) {
                  batch.delete(doc.reference);
                }

                // 3. Reset initial admin points to 0
                final settingsRef = FirebaseFirestore.instance.collection('system_settings').doc('system_points');
                batch.set(settingsRef, {'initial_points': 0}, SetOptions(merge: true));

                try {
                  await batch.commit();
                  if (context.mounted) {
                    UiUtils.showPopup(context, '전체 내역이 초기화되었습니다.');
                    Navigator.pop(context); // Close dialog
                  }
                } catch (e) {
                  if (context.mounted) {
                    UiUtils.showPopup(context, '초기화 중 오류가 발생했습니다: $e');
                  }
                }
              }
            },
            child: const Text('전체 내역 초기화', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
