import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_abroad_app/models/order_model.dart';
import 'package:study_abroad_app/services/order_service.dart';

class OrderGroup {
  final String userId;
  final String? userName;
  final String? userSchool;
  final String dateStr;
  final List<OrderModel> orders;
  
  OrderGroup({
    required this.userId,
    this.userName,
    this.userSchool,
    required this.dateStr,
    required this.orders,
  });

  double get totalKrw => orders.fold(0, (sum, o) => sum + o.totalKrw);
  DateTime get createdAt => orders.isNotEmpty ? orders.first.createdAt : DateTime.now();
  String get status => orders.isNotEmpty ? orders.first.status : 'pending';
}

class AdminShopManagementTab extends StatefulWidget {
  final String? initialFilter;
  const AdminShopManagementTab({Key? key, this.initialFilter}) : super(key: key);

  @override
  State<AdminShopManagementTab> createState() => _AdminShopManagementTabState();
}

class _AdminShopManagementTabState extends State<AdminShopManagementTab> {
  final OrderService _orderService = OrderService();
  String _selectedStatusFilter = 'pending';
  final Map<String, bool> _expandedState = {};
  String _filterDate = '';
  String _filterSchool = '전체';
  String _filterUser = '전체';


  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedStatusFilter = widget.initialFilter!;
    }
  }

  void _showItemRejectDialog(OrderModel order, int itemIndex) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개별 물품 거절'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: '거절 사유 (예: 재고 부족)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              await _orderService.updateOrderItemStatusByAdmin(
                order.id,
                itemIndex,
                'rejected',
                rejectReason: reason.isEmpty ? '재고 부족' : reason,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('거절하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAutoConfirmDialog({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) {
    bool isCancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 3), () async {
          if (!isCancelled) {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            await onConfirm();
          }
        });
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                isCancelled = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('취소', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                isCancelled = true; // Prevent the auto-timer from firing again
                Navigator.of(dialogContext).pop();
                await onConfirm();
              },
              child: const Text('즉시 승인'),
            ),
          ],
        );
      },
    );
  }

  void _showItemApproveDialog(OrderModel order, int itemIndex) {
    _showAutoConfirmDialog(
      title: '승인 대기 (개별 물품)',
      content: '승인 처리합니다. 취소하려면 3초 내에 취소 버튼을 누르세요.',
      onConfirm: () async {
        await _orderService.updateOrderItemStatusByAdmin(order.id, itemIndex, 'approved');
      },
    );
  }

  void _showGroupRejectDialog(OrderGroup group) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 주문 거절'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: '거절 사유 (예: 재고 부족)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              final finalReason = reason.isEmpty ? '재고 부족' : reason;
              for (var order in group.orders) {
                 await _orderService.updateOrderStatusByAdmin(order.id, 'rejected', rejectReason: finalReason);
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('거절하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGroupApproveDialog(OrderGroup group) {
    _showAutoConfirmDialog(
      title: '승인 대기 (전체 주문)',
      content: '전체 승인 처리합니다. 취소하려면 3초 내에 취소 버튼을 누르세요.',
      onConfirm: () async {
        for (var order in group.orders) {
           await _orderService.updateOrderStatusByAdmin(order.id, 'approved');
        }
      },
    );
  }

  void _showSingleOrderRejectDialog(OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 거절'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: '거절 사유 (예: 재고 부족)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              await _orderService.updateOrderStatusByAdmin(
                order.id,
                'rejected',
                rejectReason: reason.isEmpty ? '재고 부족' : reason,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('거절하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleGroupApprove(OrderGroup group, String userDocId) {
    _showAutoConfirmDialog(
      title: '주문 승인 처리',
      content: '해당 주문을 승인하고 배송준비 상태로 변경하시겠습니까?\n(3초 후 자동으로 승인됩니다. 취소하려면 취소 버튼을 누르세요.)',
      onConfirm: () async {
        bool allSuccess = true;
        for (var order in group.orders) {
          final success = await _orderService.updateOrderStatusByAdmin(order.id, 'preparing');
          if (!success) allSuccess = false;
        }
        if (context.mounted) {
          if (allSuccess) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('알림'),
                content: const Text('처리되었습니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('처리 실패'),
                content: const Text('주문 상태 변경에 실패했습니다.'),
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
    );
  }

  void _showStatusOverrideDialog(OrderGroup group) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상태 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['pending', 'approved', 'preparing', 'shipping', 'delivered', 'receipt_confirmed', 'completed', 'not_received', 'rejected'].map((status) {
              return ListTile(
                title: Text(_getStatusText(status)),
                onTap: () async {
                  Navigator.pop(context);
                  for (var order in group.orders) {
                    await _orderService.updateOrderStatusByAdmin(order.id, status);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return '승인대기';
      case 'approved': return '결제진행';
      case 'preparing': return '배송준비';
      case 'shipping': return '배송중';
      case 'completed': return '완료';
      case 'delivered': return '배송완료 (완료 대기)';
      case 'receipt_confirmed': return '수령완료';
      case 'not_received': return '미수령 신고';
      case 'rejected': return '거절됨';
      default: return status;
    }
  }

  List<OrderGroup> _groupOrders(List<OrderModel> orders) {
    final Map<String, OrderGroup> groups = {};
    for (var order in orders) {
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt);
      final key = order.id;
      if (groups.containsKey(key)) {
        groups[key]!.orders.add(order);
      } else {
        groups[key] = OrderGroup(
          userId: order.userId,
          userName: order.userName,
          userSchool: order.userSchool,
          dateStr: dateStr,
          orders: [order],
        );
      }
    }
    final result = groups.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _pickDateFilter() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        int selectedYear = DateTime.now().year;
        int selectedMonth = DateTime.now().month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('날짜/월 검색'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('특정 월(Month)로 검색'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: selectedYear,
                        items: List.generate(10, (i) => 2024 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y년'))).toList(),
                        onChanged: (v) => setDialogState(() => selectedYear = v!),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m월'))).toList(),
                        onChanged: (v) => setDialogState(() => selectedMonth = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final monthStr = selectedMonth.toString().padLeft(2, '0');
                      Navigator.pop(context, '$selectedYear-$monthStr');
                    },
                    child: const Text('월(Month) 단위로 검색하기'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  const Text('특정 일(Date)로 검색'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        if (context.mounted) Navigator.pop(context, DateFormat('yyyy-MM-dd').format(picked));
                      }
                    },
                    child: const Text('일(Date) 달력 열기'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'CLEAR'),
                  child: const Text('초기화', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result == 'CLEAR') {
        setState(() => _filterDate = '');
      } else {
        setState(() => _filterDate = result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getAllOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return const Center(child: Text('오류 발생'));
        
        final allOrders = snapshot.data ?? [];

        // 계산: 진행 중인 물품 수량 (재고 파악용)
        Map<String, int> activeCounts = {};
        for (var order in allOrders) {
          if (['pending', 'approved', 'preparing', 'shipping', 'delivered', 'not_received', 'receipt_confirmed'].contains(order.status)) {
            for (var item in order.items) {
              final itemId = item['productId'];
              final qty = item['quantity'] ?? 1;
              if (itemId != null) {
                activeCounts[itemId] = (activeCounts[itemId] ?? 0) + (qty as int);
              }
            }
          }
        }

        int getStatusCount(String status) {
          var filtered = allOrders;
          if (status == 'completed') {
            filtered = filtered.where((o) => ['completed', 'rejected', 'canceled'].contains(o.status)).toList();
          } else if (status == 'shipping') {
            filtered = filtered.where((o) => ['shipping', 'delivered', 'not_received', 'receipt_confirmed'].contains(o.status)).toList();
          } else {
            filtered = filtered.where((o) => o.status == status).toList();
          }
          return _groupOrders(filtered).length;
        }

        var displayOrders = allOrders;
        if (_selectedStatusFilter == 'completed') {
          displayOrders = displayOrders.where((o) => ['completed', 'rejected', 'canceled'].contains(o.status)).toList();
        } else if (_selectedStatusFilter == 'shipping') {
          displayOrders = displayOrders.where((o) => ['shipping', 'delivered', 'not_received', 'receipt_confirmed'].contains(o.status)).toList();
        } else {
          displayOrders = displayOrders.where((o) => o.status == _selectedStatusFilter).toList();
        }
        final displayGroups = _groupOrders(displayOrders);

        return Column(
          children: [
            // 필터 탭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: ['pending', 'approved', 'preparing', 'shipping', 'completed'].map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  final count = getStatusCount(status);
                  
                  Color getStatusColor(String status) {
                    switch (status) {
                      case 'pending': return Colors.orange.withValues(alpha: 0.7);
                      case 'approved': return Colors.green.withValues(alpha: 0.3);
                      case 'preparing': return Colors.green.withValues(alpha: 0.6);
                      case 'shipping': return Colors.green.withValues(alpha: 0.9);
                      case 'completed': return Colors.blue.withValues(alpha: 0.7);
                      default: return Colors.transparent;
                    }
                  }

                  return Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStatusFilter = status;
                          });
                        },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: isSelected ? getStatusColor(status) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${_getStatusText(status)} $count',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // 검색 필터
            Builder(
              builder: (context) {
                final Set<String> availableSchools = {'전체'};
                final Set<String> availableUsers = {'전체'};
                for (var group in displayGroups) {
                  if (group.userSchool != null && group.userSchool!.isNotEmpty) availableSchools.add(group.userSchool!);
                  final name = group.userName ?? group.userId.substring(0, 5);
                  if (name.isNotEmpty) availableUsers.add(name);
                }

                String currentSchoolFilter = availableSchools.contains(_filterSchool) ? _filterSchool : '전체';
                String currentUserFilter = availableUsers.contains(_filterUser) ? _filterUser : '전체';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDateFilter,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(_filterDate.isEmpty ? '날짜 전체' : _filterDate, overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: currentSchoolFilter,
                              hint: const Text('어학원 검색'),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _filterSchool = newValue;
                                  });
                                }
                              },
                              items: availableSchools.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: currentUserFilter,
                              hint: const Text('사용자 검색'),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _filterUser = newValue;
                                  });
                                }
                              },
                              items: availableUsers.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
            const SizedBox(height: 8),
            // 리스트
            Expanded(
              child: () {
                // 필터 적용
                var filteredGroups = displayGroups.where((group) {
                  if (_filterDate.isNotEmpty && !group.dateStr.contains(_filterDate)) return false;
                  
                  final currentSchoolFilter = _filterSchool.isEmpty ? '전체' : _filterSchool;
                  if (currentSchoolFilter != '전체' && (group.userSchool ?? '') != currentSchoolFilter) return false;
                  
                  final currentUserFilter = _filterUser.isEmpty ? '전체' : _filterUser;
                  final name = group.userName ?? group.userId.substring(0, 5);
                  if (currentUserFilter != '전체' && name != currentUserFilter) return false;
                  
                  return true;
                }).toList();

                if (filteredGroups.isEmpty) {
                  return const Center(child: Text('주문이 없습니다.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    
                    final groupKey = group.orders.isNotEmpty ? group.orders.first.id : '${group.userId}_${group.dateStr}';
                  final bool isCompletedTab = _selectedStatusFilter == 'completed';
                  final bool isExpanded = _expandedState[groupKey] ?? !isCompletedTab;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: group.orders.isNotEmpty && group.orders.first.userEmail != null 
                          ? FirebaseFirestore.instance.collection('users').where('email', isEqualTo: group.orders.first.userEmail).limit(1).snapshots()
                          : FirebaseFirestore.instance.collection('users').where('dummy', isEqualTo: 'dummy').snapshots(),
                      builder: (context, userSnapshot) {
                        int userPoints = 0;
                        String? userDocId;
                        if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                          final userDoc = userSnapshot.data!.docs.first;
                          userDocId = userDoc.id;
                          final userData = userDoc.data() as Map<String, dynamic>;
                          userPoints = (userData['points'] as num?)?.toInt() ?? 0;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: isCompletedTab ? () {
                                    setState(() {
                                      _expandedState[groupKey] = !isExpanded;
                                    });
                                  } : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '날짜: ${group.dateStr} / 어학원: ${group.userSchool ?? '미상'} / 사용자: ${group.userName ?? group.userId.substring(0, 5)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        if (isCompletedTab)
                                          Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showStatusOverrideDialog(group),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    border: Border.all(color: Colors.black87),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_getStatusText(group.status), style: const TextStyle(fontSize: 11)),
                                      const Icon(Icons.arrow_drop_down, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const Divider(),
                            
                            // 모든 주문의 아이템 나열
                          ...group.orders.expand((order) {
                            return order.items.asMap().entries.map((entry) {
                              final itemIndex = entry.key;
                              final item = entry.value;
                              final priceKrw = (item['totalPriceKrw'] ?? 0).toInt();
                              final itemStatus = item['status'] ?? 'pending';
                              
                              if (itemStatus != 'pending' && _selectedStatusFilter == 'pending') {
                                // 승인대기 탭에서 이미 처리된 개별 물품은 상태 텍스트로 대체
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text('- ${item['name']} x ${item['quantity']}', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough))),
                                      Text(_getStatusText(itemStatus), style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                );
                              }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: item['type'] == 'rent' && item['productId'] != null
                                              ? FutureBuilder<DocumentSnapshot>(
                                                  future: FirebaseFirestore.instance.collection('shop_items').doc(item['productId']).get(),
                                                  builder: (context, snapshot) {
                                                    String stockText = '';
                                                    if (snapshot.hasData && snapshot.data!.exists) {
                                                      final data = snapshot.data!.data() as Map<String, dynamic>;
                                                      final totalQuantity = data['totalQuantity'] ?? 0;
                                                      if (totalQuantity > 0) {
                                                        final inProgress = activeCounts[item['productId']] ?? 0;
                                                        final available = totalQuantity - inProgress;
                                                        stockText = ' (재고: $available)';
                                                      } else {
                                                        stockText = ' (재고: ∞)';
                                                      }
                                                    }
                                                    String dateText = '';
                                                    if (item['startDate'] != null && item['endDate'] != null) {
                                                      try {
                                                        final start = DateTime.parse(item['startDate']);
                                                        final end = DateTime.parse(item['endDate']);
                                                        dateText = ' [${DateFormat('MM.dd').format(start)}~${DateFormat('MM.dd').format(end)}]';
                                                      } catch (_) {}
                                                    }
                                                    return Text('- ${item['name']} x ${item['quantity']}$dateText$stockText',
                                                      style: TextStyle(
                                                        color: stockText.contains('재고: -') ? Colors.red : null,
                                                        fontWeight: stockText.contains('재고: -') ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Builder(
                                                  builder: (context) {
                                                    String dateText = '';
                                                    if (item['startDate'] != null && item['endDate'] != null) {
                                                      try {
                                                        final start = DateTime.parse(item['startDate']);
                                                        final end = DateTime.parse(item['endDate']);
                                                        dateText = ' [${DateFormat('MM.dd').format(start)}~${DateFormat('MM.dd').format(end)}]';
                                                      } catch (_) {}
                                                    }
                                                    return Text('- ${item['name']} x ${item['quantity']}$dateText');
                                                  },
                                                ),
                                        ),
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 12.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Icon(Icons.savings_outlined, size: 14),
                                            const SizedBox(width: 2),
                                            Text(
                                              NumberFormat('#,###').format(priceKrw), 
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_selectedStatusFilter == 'pending')
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 48,
                                              height: 28,
                                              child: OutlinedButton(
                                                onPressed: () => _showItemRejectDialog(order, itemIndex),
                                                style: OutlinedButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: const Text('거절', style: TextStyle(fontSize: 11)),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            SizedBox(
                                              width: 48,
                                              height: 28,
                                              child: ElevatedButton(
                                                onPressed: () => _showItemApproveDialog(order, itemIndex),
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: const Text('승인', style: TextStyle(fontSize: 11)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                              );
                            });
                          }).toList(),

                          const SizedBox(height: 8),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Row(
                                  children: [
                                    const Text('보유 포인트: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                    const Icon(Icons.savings_outlined, color: Colors.blue, size: 16),
                                    const SizedBox(width: 2),
                                    Text(NumberFormat('#,###').format(userPoints), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Row(
                                      children: [
                                        const Text('총액: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                        const Icon(Icons.savings_outlined, color: Colors.redAccent, size: 16),
                                        const SizedBox(width: 2),
                                        Text(NumberFormat('#,###').format(group.totalKrw.toInt()), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                  if (_selectedStatusFilter == 'pending') const SizedBox(width: 100),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          
                          // 상태별 액션 버튼 (그룹)
                          _buildActionButtonsWidget(group, userPoints, userDocId),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
                },
              );
              }(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtonsWidget(OrderGroup group, int userPoints, String? userDocId) {
    if (_selectedStatusFilter == 'pending') {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: OutlinedButton(
            onPressed: () => _showGroupRejectDialog(group),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('전체 거절'),
          ))),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ElevatedButton(
            onPressed: () => _showGroupApproveDialog(group),
            child: const Text('전체 승인'),
          ))),
        ],
      );
    } else if (group.status == 'approved') {
      final productIds = group.orders.expand((o) => o.items).map((i) => i['productId'] as String).toSet().toList();
      
      bool orderHasBankTransferOnly = false;
      for (var order in group.orders) {
        for (var item in order.items) {
          if (item['isBankTransferOnly'] == true) {
            orderHasBankTransferOnly = true;
            break;
          }
        }
        if (orderHasBankTransferOnly) break;
      }

      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('products').where(FieldPath.documentId, whereIn: productIds.isNotEmpty ? productIds : ['dummy']).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          
          bool hasBankTransferOnly = orderHasBankTransferOnly;
          if (snapshot.hasData && !hasBankTransferOnly) {
            for (var doc in snapshot.data!.docs) {
              if ((doc.data() as Map<String, dynamic>)['isBankTransferOnly'] == true) {
                hasBankTransferOnly = true;
                break;
              }
            }
          }

          final bool canPayWithPoints = userPoints >= group.totalKrw;
          final bool isPointPaymentAllowed = !hasBankTransferOnly && canPayWithPoints && userDocId != null;
          
          return Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    onPressed: hasBankTransferOnly ? () {
                      _showAutoConfirmDialog(
                        title: '계좌이체 확인됨',
                        content: '결제를 확인하고 배송준비 상태로 변경하시겠습니까?\n(3초 후 자동으로 승인됩니다. 취소하려면 취소 버튼을 누르세요.)',
                        onConfirm: () async {
                          for (var order in group.orders) {
                            if (hasBankTransferOnly && userDocId != null) {
                              await _orderService.confirmBankTransfer(order.id, userDocId);
                            } else {
                              await _orderService.updateOrderStatusByAdmin(order.id, 'preparing');
                            }
                          }
                        },
                      );
                    } : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: group.orders.any((o) => o.isTransferNotified) ? Colors.blue : Colors.black87,
                      side: BorderSide(color: group.orders.any((o) => o.isTransferNotified) ? Colors.blue : Colors.grey),
                    ),
                    child: Text(
                      group.orders.any((o) => o.isTransferNotified) ? '이체완료. 확인 필요' : '계좌이체확인됨',
                      style: TextStyle(
                        fontWeight: group.orders.any((o) => o.isTransferNotified) ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: isPointPaymentAllowed ? () => _handleGroupApprove(group, userDocId!) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                    child: const Text('포인트로결제진행'),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else if (group.status == 'preparing') {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ElevatedButton(
            onPressed: () async {
              for (var order in group.orders) {
                await _orderService.updateOrderStatusByAdmin(order.id, 'shipping');
              }
            },
            child: const Text('배송 시작'),
          ))),
        ],
      );
    } else if (group.status == 'shipping') {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ElevatedButton(
            onPressed: () async {
              for (var order in group.orders) {
                await _orderService.updateOrderStatusByAdmin(order.id, 'delivered');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('배송 완료 처리', style: TextStyle(color: Colors.white)),
          ))),
        ],
      );
    } else if (group.status == 'not_received') {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ElevatedButton(
            onPressed: () async {
              for (var order in group.orders) {
                await _orderService.updateOrderStatusByAdmin(order.id, 'delivered');
              }
            },
            child: const Text('재배송 완료'),
          ))),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: OutlinedButton(
            onPressed: () => _showGroupRejectDialog(group),
            child: const Text('주문 취소'),
          ))),
        ],
      );
    } else if (group.status == 'receipt_confirmed') {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ElevatedButton(
            onPressed: () async {
              for (var order in group.orders) {
                await _orderService.updateOrderStatusByAdmin(order.id, 'completed');
              }
            },
            child: const Text('최종 완료'),
          ))),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
