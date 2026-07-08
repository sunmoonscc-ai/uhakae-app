import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminPointManagementDialog extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const AdminPointManagementDialog({super.key, required this.userDoc});

  @override
  State<AdminPointManagementDialog> createState() => _AdminPointManagementDialogState();
}

class _AdminPointManagementDialogState extends State<AdminPointManagementDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _adjustPoints(bool isAdding) async {
    final amountStr = _amountController.text.replaceAll(',', '').trim();
    final desc = _descController.text.trim();
    if (amountStr.isEmpty || desc.isEmpty) {
      UiUtils.showPopup(context, '포인트와 사유를 모두 입력해주세요.');
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      UiUtils.showPopup(context, '올바른 포인트를 입력해주세요.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final double finalAmount = isAdding ? amount : -amount;
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = widget.userDoc.reference;
        final docSnapshot = await transaction.get(docRef);
        final currentPoints = (docSnapshot.data() as Map<String, dynamic>)['points'] ?? 0.0;
        final double currentPointsDouble = currentPoints is int ? currentPoints.toDouble() : currentPoints as double;

        transaction.update(docRef, {
          'points': currentPointsDouble + finalAmount,
        });

        final historyRef = FirebaseFirestore.instance.collection('point_history').doc();
        transaction.set(historyRef, {
          'userId': widget.userDoc.id,
          'amount': finalAmount,
          'description': desc,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'admin_adjustment',
        });
      });

      if (mounted) {
        _amountController.clear();
        _descController.clear();
        UiUtils.showPopup(context, '포인트가 조정되었습니다.');
      }
    } catch (e) {
      if (mounted) UiUtils.showPopup(context, '오류 발생: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetPoints() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초기화 확인', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('정말 사용자의 포인트를 0으로 만들고 모든 사용 내역을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('초기화', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      // 1. Delete all point history
      final historyQuery = await FirebaseFirestore.instance
          .collection('point_history')
          .where('userId', isEqualTo: widget.userDoc.id)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in historyQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete all orders for the user
      final userEmail = widget.userDoc['email'];
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userEmail', isEqualTo: userEmail)
          .get();
      for (var doc in ordersQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // 3. Set points to 0
      batch.update(widget.userDoc.reference, {'points': 0.0});
      
      await batch.commit();

      if (mounted) {
        UiUtils.showPopup(context, '포인트, 내역 및 주문 내역이 초기화되었습니다.');
      }
    } catch (e) {
      if (mounted) UiUtils.showPopup(context, '오류 발생: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userName = (widget.userDoc.data() as Map<String, dynamic>)['name'] ?? '이름 없음';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$userName 님 포인트 관리',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current points
            StreamBuilder<DocumentSnapshot>(
              stream: widget.userDoc.reference.snapshots(),
              builder: (context, snapshot) {
                double currentPoints = 0.0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final val = (snapshot.data!.data() as Map<String, dynamic>)['points'] ?? 0.0;
                  currentPoints = val is int ? val.toDouble() : val as double;
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('현재 포인트:', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black87)),
                      Text(
                        NumberFormat('#,###').format(currentPoints),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.blue[800]),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Adjustment Form
            Text('포인트 조정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '포인트',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: '조정 사유',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _adjustPoints(false),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('차감'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _adjustPoints(true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('지급'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // History list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('사용 내역', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                TextButton.icon(
                  onPressed: _isSaving ? null : _resetPoints,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                  label: const Text('사용내역 초기화', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('point_history')
                      .where('userId', isEqualTo: widget.userDoc.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('오류 발생: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('내역이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                    }

                    // 클라이언트에서 정렬 (Firestore 인덱스 오류 방지)
                    final docs = snapshot.data!.docs;
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime); // descending
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final desc = data['description'] ?? '';
                        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        final isIncome = amount > 0;
                        final date = data['createdAt'] as Timestamp?;
                        final dateStr = date != null ? DateFormat('MM.dd HH:mm').format(date.toDate()) : '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(desc, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black)),
                          subtitle: Text(dateStr, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.black54)),
                          trailing: Text(
                            '${isIncome ? '+' : ''}${NumberFormat('#,###').format(amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isIncome ? Colors.blue : Colors.red,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
