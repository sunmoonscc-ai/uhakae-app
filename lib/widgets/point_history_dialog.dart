import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PointHistoryDialog extends StatefulWidget {
  const PointHistoryDialog({super.key});

  @override
  State<PointHistoryDialog> createState() => _PointHistoryDialogState();
}

class _PointHistoryDialogState extends State<PointHistoryDialog> {
  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      return const AlertDialog(content: Text('로그인이 필요합니다.'));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(16),
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
                  '포인트 내역',
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
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  double currentPoints = 0.0;
                  if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                    currentPoints = (userSnap.data!.data() as Map<String, dynamic>)['points']?.toDouble() ?? 0.0;
                  } else {
                    return Center(child: Text('사용자 정보를 찾을 수 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                  }
                  final userDocId = userSnap.data!.id;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('point_history')
                        .where('userId', isEqualTo: userDocId)
                        .snapshots(),
                    builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('오류가 발생했습니다: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('포인트 내역이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                  }

                  List<Map<String, dynamic>> history = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'createdAt': data['createdAt'] as Timestamp?,
                      'description': data['description'] ?? '',
                      'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                      'orderId': data['orderId'],
                    };
                  }).toList();

                  // 1. Calculate running balance (currentPoints is already calculated in the outer builder)
                  history.sort((a, b) {
                    final aTime = a['createdAt']?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime = b['createdAt']?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime); // DESCENDING
                  });

                  double runningBalance = currentPoints;
                  for (int i = 0; i < history.length; i++) {
                    history[i]['balance'] = runningBalance;
                    runningBalance -= history[i]['amount'];
                  }

                  // 정렬 적용
                  history.sort((a, b) {
                    int result = 0;
                    switch (_sortColumnIndex) {
                      case 0: // 날짜
                        final aTime = a['createdAt']?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime = b['createdAt']?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                        result = aTime.compareTo(bTime);
                        break;
                      case 1: // 내용
                        result = a['description'].compareTo(b['description']);
                        break;
                      case 2: // 수입
                        final aIncome = a['amount'] > 0 ? a['amount'] : 0.0;
                        final bIncome = b['amount'] > 0 ? b['amount'] : 0.0;
                        result = aIncome.compareTo(bIncome);
                        break;
                      case 3: // 지출
                        final aExpense = a['amount'] < 0 ? a['amount'].abs() : 0.0;
                        final bExpense = b['amount'] < 0 ? b['amount'].abs() : 0.0;
                        result = aExpense.compareTo(bExpense);
                        break;
                    }
                    return _sortAscending ? result : -result;
                  });

                  return SingleChildScrollView(
                    primary: false,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: IconThemeData(color: isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 16.0,
                          horizontalMargin: 12.0,
                          dataRowMinHeight: 40.0,
                          dataRowMaxHeight: 60.0,
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowColor: MaterialStateProperty.all(isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                          columns: [
                            DataColumn(
                              label: Expanded(child: Text('날짜', textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Expanded(child: Text('내용', textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Expanded(child: Text('+', textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Expanded(child: Text('-', textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Expanded(child: Align(alignment: Alignment.center, child: Icon(Icons.savings, size: 20, color: isDarkMode ? Colors.white : Colors.black))),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                          ],
                          rows: history.map((item) {
                            final date = item['createdAt']?.toDate();
                            final dateStr = date != null ? DateFormat("MM.dd\nHH:mm").format(date) : "날짜\n없음";
                            final amount = item['amount'] as double;
                            final balance = item['balance'] as double;
                            final isIncome = amount > 0;
                            final isExpense = amount < 0;
                            
                            String desc = item['description'] ?? '';
                            if (desc.contains('계좌이체 확인') || desc.contains('포인트 충전')) {
                              desc = '포인트 충전';
                            } else if (desc.contains('대여')) {
                              desc = '물품대여';
                            } else if (desc.contains('포인트카드') || desc.contains('포인트 카드')) {
                              desc = '포인트카드구매';
                            } else if (desc.contains('구매') || desc.contains('결제') || desc.contains('주문')) {
                              desc = '물품구매';
                            } else {
                              desc = desc; // keep original if none matches
                            }

                            return DataRow(
                              onSelectChanged: item['orderId'] != null 
                                  ? (selected) => _showOrderDetails(context, item['orderId']) 
                                  : null,
                              cells: [
                                DataCell(
                                  Center(
                                    child: Text(
                                      dateStr, 
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: 80,
                                    alignment: Alignment.center,
                                    child: Text(
                                      desc, 
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white70 : Colors.black87, 
                                        fontSize: 12,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      isIncome ? NumberFormat('#,###').format(amount) : '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isIncome ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
                                        fontWeight: isIncome ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      isExpense ? NumberFormat('#,###').format(amount.abs()) : '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isExpense ? Colors.red : (isDarkMode ? Colors.white70 : Colors.black87),
                                        fontWeight: isExpense ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      NumberFormat('#,###').format(balance),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderDetails(BuildContext context, String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문 정보를 찾을 수 없습니다.')));
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final items = List<dynamic>.from(data['items'] ?? []);
      
      showDialog(
        context: context,
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('주문 상세 내역', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  final name = item['name'] ?? '';
                  final quantity = item['quantity'] ?? 1;
                  final price = item['totalPriceKrw'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$name x $quantity\n'),
                          const WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.savings, size: 14))),
                          TextSpan(text: '${NumberFormat('#,###').format(price)}'),
                        ],
                      ),
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    }
  }
}
