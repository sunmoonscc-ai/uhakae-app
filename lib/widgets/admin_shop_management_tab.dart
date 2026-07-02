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

  void _handleGroupDeductPoints(OrderGroup group, String userDocId) {
    _showAutoConfirmDialog(
      title: '바우처 결제 처리',
      content: '총액 ₩${NumberFormat('#,###').format(group.totalKrw.toInt())}을 차감하고 배송준비 상태로 변경하시겠습니까?\n(3초 후 자동으로 승인됩니다. 취소하려면 취소 버튼을 누르세요.)',
      onConfirm: () async {
        bool allSuccess = true;
        for (var order in group.orders) {
          final success = await _orderService.deductPointsAndPrepare(order.id, userDocId, order.totalKrw);
          if (!success) allSuccess = false;
        }
        if (context.mounted) {
          if (allSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('처리되었습니다.')));
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('처리 실패'),
                content: const Text('해당 사용자의 보유 포인트가 부족하여 결제(차감) 처리에 실패했습니다.\n사용자 관리에서 포인트를 먼저 지급해 주세요.'),
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
          title: const Text('상태 강제 변경 (오류 수정용)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['pending', 'approved', 'preparing', 'shipping', 'delivered', 'completed', 'not_received', 'rejected'].map((status) {
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
      case 'not_received': return '미수령 신고';
      case 'rejected': return '거절됨';
      default: return status;
    }
  }

  List<OrderGroup> _groupOrders(List<OrderModel> orders) {
    final Map<String, OrderGroup> groups = {};
    for (var order in orders) {
      final dateStr = DateFormat('yyyy-MM-dd').format(order.createdAt);
      final key = '${order.userId}_$dateStr';
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

        int getStatusCount(String status) {
          var filtered = allOrders;
          if (status == 'completed') {
            filtered = filtered.where((o) => ['completed', 'delivered', 'not_received', 'rejected'].contains(o.status)).toList();
          } else {
            filtered = filtered.where((o) => o.status == status).toList();
          }
          return _groupOrders(filtered).length;
        }

        var displayOrders = allOrders;
        if (_selectedStatusFilter == 'completed') {
          displayOrders = displayOrders.where((o) => ['completed', 'delivered', 'not_received', 'rejected'].contains(o.status)).toList();
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
            // 리스트
            Expanded(
              child: displayGroups.isEmpty
                  ? const Center(child: Text('주문이 없습니다.'))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayGroups.length,
                itemBuilder: (context, index) {
                  final group = displayGroups[index];
                  
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${group.dateStr} / ${group.userSchool ?? '어학원 미상'} / ${group.userName ?? group.userId.substring(0, 5)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showStatusOverrideDialog(group),
                                borderRadius: BorderRadius.circular(16),
                                child: Chip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_getStatusText(group.status), style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.arrow_drop_down, size: 16),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue[50],
                                ),
                              ),
                            ],
                          ),
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
                                      child: Text('- ${item['name']} x ${item['quantity']}')
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
                      ),
                    );
                  },
                ),
              );
                },
              ),
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
      
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('products').where(FieldPath.documentId, whereIn: productIds.isNotEmpty ? productIds : ['dummy']).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          
          bool hasBankTransferOnly = false;
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              if ((doc.data() as Map<String, dynamic>)['isBankTransferOnly'] == true) {
                hasBankTransferOnly = true;
                break;
              }
            }
          }

          final bool canPayWithPoints = userPoints >= group.totalKrw;
          
          return Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    onPressed: () {
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
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87),
                    child: const Text('계좌이체확인됨'),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: (!hasBankTransferOnly && canPayWithPoints && userDocId != null) ? () => _handleGroupDeductPoints(group, userDocId) : null,
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
    }
    return const SizedBox.shrink();
  }
}
