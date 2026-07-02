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
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('point_history')
                    .where('userId', isEqualTo: user.uid)
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
                    };
                  }).toList();

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
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: IconThemeData(color: isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                        child: DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowColor: MaterialStateProperty.all(isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                          columns: [
                            DataColumn(
                              label: Text('날짜', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Text('내용', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Text('수입', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                              numeric: true,
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: Text('지출', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                              numeric: true,
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
                            final dateStr = date != null ? DateFormat('yyyy.MM.dd HH:mm').format(date) : '날짜 없음';
                            final amount = item['amount'] as double;
                            final isIncome = amount > 0;
                            final isExpense = amount < 0;

                            return DataRow(
                              cells: [
                                DataCell(Text(dateStr, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87))),
                                DataCell(Text(item['description'], style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87))),
                                DataCell(
                                  Text(
                                    isIncome ? NumberFormat('#,###').format(amount) : '-',
                                    style: TextStyle(
                                      color: isIncome ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black87),
                                      fontWeight: isIncome ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    isExpense ? NumberFormat('#,###').format(amount.abs()) : '-',
                                    style: TextStyle(
                                      color: isExpense ? Colors.red : (isDarkMode ? Colors.white70 : Colors.black87),
                                      fontWeight: isExpense ? FontWeight.bold : FontWeight.normal,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
