import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:study_abroad_app/models/order_model.dart';
import 'package:study_abroad_app/services/order_service.dart';
import 'package:study_abroad_app/utils/ui_utils.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();

  Future<void> _requestReturn(String orderId, Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('반납 요청'),
        content: Text('${item['name']} 물품의 반납을 요청하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final bool success = await _orderService.requestReturnForItem(orderId, item['productId']);
              if (mounted) {
                if (success) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('요청 접수 완료'),
                      content: const Text('반납 요청이 정상적으로 접수되었습니다.\n관리자 확인 후 회수가 진행됩니다.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('반납 요청 처리에 실패했습니다.')),
                  );
                }
              }
            },
            child: const Text('반납 요청', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return '승인 대기중';
      case 'approved': return '결제 대기중 (승인됨)';
      case 'rejected': return '주문 거절됨';
      case 'preparing': return '배송 준비중';
      case 'shipping': return '배송중';
      case 'delivered': return '배송 완료';
      case 'not_received': return '미수령';
      case 'receipt_confirmed': return '배송확인';
      case 'completed': return '수령/대여 완료';
      case 'canceled': return '주문 취소';
      default: return '알 수 없음';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.blue;
      case 'rejected': return Colors.red;
      case 'preparing': return Colors.amber;
      case 'shipping': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'receipt_confirmed': return Colors.teal;
      case 'completed': return Colors.grey;
      case 'not_received': return Colors.redAccent;
      case 'canceled': return Colors.red;
      default: return Colors.black;
    }
  }

  Color _getPointColor(BuildContext context, String status, bool isBankTransfer) {
    if (status == 'rejected' || status == 'canceled') {
      return Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    }
    return isBankTransfer ? Colors.blue : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 주문 내역'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: '진행중'),
              Tab(text: '대여중'),
              Tab(text: '완료'),
            ],
          ),
        ),
        body: StreamBuilder<List<OrderModel>>(
          stream: _orderService.getUserOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText('오류가 발생했습니다: ${snapshot.error}'),
                )
              );
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const Center(child: Text('주문 내역이 없습니다.'));
            }

            final inProgressOrders = orders.where((o) => !['completed', 'rejected', 'canceled'].contains(o.status)).toList();
            final rentingOrders = orders.where((o) => o.status == 'completed' && o.items.any((item) => item['type'] == 'rent' && item['returnStatus'] != 'returned' && item['returnStatus'] != 'returned_damaged')).toList();
            final completedOrders = orders.where((o) => ['completed', 'rejected', 'canceled'].contains(o.status) && !rentingOrders.contains(o)).toList();

            return TabBarView(
              children: [
                _buildOrderList(inProgressOrders, isRentingTab: false),
                _buildOrderList(rentingOrders, isRentingTab: true),
                _buildOrderList(completedOrders, isRentingTab: false),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isDescending = true;

  Widget _buildOrderList(List<OrderModel> orders, {bool isRentingTab = false}) {
    if (orders.isEmpty) {
      return const Center(child: Text('주문 내역이 없습니다.'));
    }

    final sortedOrders = List<OrderModel>.from(orders);
    sortedOrders.sort((a, b) => _isDescending ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));

    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isDescending = !_isDescending;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isDescending ? '최신순' : '과거순', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Builder(builder: (context) {
                  bool orderHasBankTransferOnly = false;
                  for (var item in order.items) {
                    if (item['isBankTransferOnly'] == true) {
                      orderHasBankTransferOnly = true;
                      break;
                    }
                  }

                  return Column(
                    children: [
                      ListTile(
                        onTap: () => _showOrderDetailsDialog(order),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: order.items.map<Widget>((item) {
                            final itemStatus = item['status'] ?? 'pending';
                            final isRejected = itemStatus == 'rejected';
                            final rejectReason = item['rejectReason'] ?? '사유 없음';
                            final rejectText = isRejected ? ' (거절됨: $rejectReason)' : '';

                            final returnStatus = item['returnStatus'];
                            
                            Widget returnUi = const SizedBox.shrink();
                            if (isRentingTab && item['type'] == 'rent' && returnStatus != 'returned' && returnStatus != 'returned_damaged') {
                              if (returnStatus == 'return_requested') {
                                returnUi = const Text(' [반납요청됨]', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold));
                              } else if (returnStatus == 'return_confirmed' || returnStatus == 'return_preparing') {
                                returnUi = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(' [회수 예정]', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: () => _orderService.updateItemReturnStatus(order.id, item['productId'], 'user_returned'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Colors.purple, foregroundColor: Colors.white,
                                      ),
                                      child: const Text('전달 완료', style: TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                );
                              } else if (returnStatus == 'user_returned') {
                                returnUi = const Text(' [회수 중]', style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold));
                              } else if (returnStatus == 'admin_received') {
                                returnUi = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(' [수령 확인됨]', style: TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: () => _orderService.updateItemReturnStatus(order.id, item['productId'], 'returned'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Colors.green, foregroundColor: Colors.white,
                                      ),
                                      child: const Text('최종 승인', style: TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                );
                              } else {
                                returnUi = TextButton(
                                  onPressed: () {
                                    _requestReturn(order.id, item);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('반납요청', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                );
                              }
                            } else if (isRentingTab && item['type'] == 'rent' && returnStatus == 'returned_damaged') {
                               returnUi = const Text(' [파손 반납됨]', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold));
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['name']} x ${item['quantity']}$rejectText',
                                      style: TextStyle(
                                        fontWeight: isRejected ? FontWeight.normal : FontWeight.bold, 
                                        fontSize: 14,
                                        color: isRejected ? Colors.grey : null,
                                        decoration: isRejected ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  if (returnUi != const SizedBox.shrink()) returnUi,
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(dateFormat.format(order.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _getStatusText(order.status),
                              style: TextStyle(color: _getStatusColor(order.status), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.savings, color: _getPointColor(context, order.status, orderHasBankTransferOnly), size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  '${currencyFormatter.format(order.totalKrw)}',
                                  style: TextStyle(
                                    color: _getPointColor(context, order.status, orderHasBankTransferOnly), 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (order.status == 'pending' || order.status == 'approved')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('주문 취소'),
                                          content: const Text('주문을 취소하시겠습니까?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('아니오')),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _orderService.updateOrderStatusByUser(order.id, 'canceled');
                                              },
                                              child: const Text('예', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('주문 취소', style: TextStyle(fontSize: 12)),
                                  ),
                                  if (order.status == 'approved' && orderHasBankTransferOnly) ...[
                                    const SizedBox(width: 8),
                                    if (order.isTransferNotified)
                                      const Text('송금 확인 대기중', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13))
                                    else
                                      ElevatedButton(
                                        onPressed: () {
                                          _orderService.notifyBankTransfer(order.id);
                                          if (context.mounted) {
                                            UiUtils.showPopup(context, '관리자에게 송금 완료 알림이 전송되었습니다.');
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade300,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                        ),
                                        child: const Text('위 금액을 계좌이체 후 눌러주세요.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                  ],
                                ],
                              ),
                              if (order.status == 'approved' && orderHasBankTransferOnly && !order.isTransferNotified) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('KB(국민은행) 484637-04-010357 김인환', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(const ClipboardData(text: '48463704010357'));
                                        if (context.mounted) {
                                          UiUtils.showPopup(context, '계좌번호가 복사되었습니다.');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('(복사하기)', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (order.status == 'delivered')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  _orderService.updateOrderStatusByUser(order.id, 'not_received');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('미수령', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _orderService.updateOrderStatusByUser(order.id, 'receipt_confirmed');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('배송확인', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showOrderDetailsDialog(OrderModel order) {
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    bool orderHasBankTransferOnly = false;
    for (var item in order.items) {
      if (item['isBankTransferOnly'] == true) {
        orderHasBankTransferOnly = true;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateFormat.format(order.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...order.items.map((item) {
                    final itemStatus = item['status'] ?? 'pending';
                    final isRejected = itemStatus == 'rejected';
                    final rejectReason = item['rejectReason'] ?? '사유 없음';
                    final rejectText = isRejected ? ' (거절됨: $rejectReason)' : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['name']} x ${item['quantity']}$rejectText',
                              style: TextStyle(
                                fontWeight: isRejected ? FontWeight.normal : FontWeight.bold,
                                color: isRejected ? Colors.grey : null,
                                decoration: isRejected ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.savings, size: 14, color: isRejected ? Colors.grey : null),
                              const SizedBox(width: 2),
                              Text(
                                '${currencyFormatter.format(item['totalPriceKrw'] ?? item['totalPricePhp'] ?? 0)}',
                                style: TextStyle(
                                  color: isRejected ? Colors.grey : null,
                                  decoration: isRejected ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('총 결제 포인트', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.savings, color: _getPointColor(context, order.status, orderHasBankTransferOnly), size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${currencyFormatter.format(order.totalKrw)}',
                            style: TextStyle(
                              color: _getPointColor(context, order.status, orderHasBankTransferOnly),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (order.status == 'rejected' && order.rejectReason != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '거절 사유: ${order.rejectReason}',
                        style: TextStyle(color: Colors.red[800], fontSize: 13),
                      ),
                    ),
                  ],
                  if (order.status == 'delivered') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _orderService.updateOrderStatusByUser(order.id, 'not_received');
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('미수령'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _orderService.updateOrderStatusByUser(order.id, 'receipt_confirmed');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                            child: const Text('배송확인', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기', style: TextStyle(color: Colors.grey)),
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
}
