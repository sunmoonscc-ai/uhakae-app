import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '유학애 관리자 대시보드 (주문 관리)',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
      ),
    );
  }
}
