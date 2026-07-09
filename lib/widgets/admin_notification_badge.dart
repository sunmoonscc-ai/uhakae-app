import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/admin_screen.dart';

class AdminNotificationBadge extends StatelessWidget {
  final Color iconColor;
  final Color textColor;

  const AdminNotificationBadge({
    super.key, 
    this.iconColor = Colors.pink, 
    this.textColor = Colors.pink
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isAdminEmail = [
      'cebufriends79@gmail.com',
      'slptas05@gmail.com',
      'sunmoon.scc@gmail.com',
      'hdcc6th@gmail.com',
      'uhakae2026@gmail.com',
    ].contains(user.email);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        bool isAdmin = isAdminEmail;
        if (!isAdmin && userSnapshot.hasData && userSnapshot.data?.data() != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final level = userData['level'] as String?;
          if (level == '관리자' || level == '최고관리자') {
            isAdmin = true;
          }
        }
        
        if (!isAdmin) return const SizedBox.shrink();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, orderSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('level', isEqualTo: '예비').snapshots(),
              builder: (context, userSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('info_suggestions').where('status', isEqualTo: 'pending').snapshots(),
                  builder: (context, infoSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('orders').where('hasUnreadReturnRequest', isEqualTo: true).snapshots(),
                      builder: (context, returnSnapshot) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('personal_notices')
                              .where('isFromUser', isEqualTo: true)
                              .where('isRead', isEqualTo: false)
                              .snapshots(),
                          builder: (context, noticeSnapshot) {
                            int pendingCount = 0;
                            if (orderSnapshot.hasData) pendingCount += orderSnapshot.data!.docs.length;
                            if (userSnapshot.hasData) pendingCount += userSnapshot.data!.docs.length;
                            if (infoSnapshot.hasData) pendingCount += infoSnapshot.data!.docs.length;
                            if (returnSnapshot.hasData) pendingCount += returnSnapshot.data!.docs.length;
                            if (noticeSnapshot.hasData) pendingCount += noticeSnapshot.data!.docs.length;

                            if (pendingCount == 0) return const SizedBox.shrink();

                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) {
                                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                                return Dialog(
                                  backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                                            IconButton(icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                                          ],
                                        ),
                                        const Divider(),
                                        Expanded(
                                          child: ListView(
                                            children: [
                                              if (orderSnapshot.hasData && orderSnapshot.data!.docs.isNotEmpty)
                                                ListTile(
                                                  leading: const Icon(Icons.shopping_cart, color: Colors.blue),
                                                  title: Text('신규 주문 (${orderSnapshot.data!.docs.length}건)'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '쇼핑몰 관리')));
                                                  },
                                                ),
                                              if (returnSnapshot.hasData && returnSnapshot.data!.docs.isNotEmpty)
                                                ListTile(
                                                  leading: const Icon(Icons.assignment_return, color: Colors.orange),
                                                  title: Text('반품 요청 (${returnSnapshot.data!.docs.length}건)'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '쇼핑몰 관리')));
                                                  },
                                                ),
                                              if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty)
                                                ListTile(
                                                  leading: const Icon(Icons.person_add, color: Colors.green),
                                                  title: Text('신규 가입 대기 (${userSnapshot.data!.docs.length}명)'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '사용자 관리')));
                                                  },
                                                ),
                                              if (infoSnapshot.hasData && infoSnapshot.data!.docs.isNotEmpty)
                                                ListTile(
                                                  leading: const Icon(Icons.info_outline, color: Colors.purple),
                                                  title: Text('정보수정 제안 (${infoSnapshot.data!.docs.length}건)'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '정보수정제안')));
                                                  },
                                                ),
                                              if (noticeSnapshot.hasData && noticeSnapshot.data!.docs.isNotEmpty)
                                                ...noticeSnapshot.data!.docs.map((doc) {
                                                  final data = doc.data() as Map<String, dynamic>;
                                                  final senderName = data['senderName'] ?? '사용자';
                                                  return ListTile(
                                                    leading: const Icon(Icons.mark_email_unread, color: Colors.pink),
                                                    title: Text('새 쪽지 ($senderName)'),
                                                    onTap: () async {
                                                      await doc.reference.update({'isRead': true});
                                                      if (context.mounted) {
                                                        Navigator.pop(ctx);
                                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '개별공지(쪽지)')));
                                                      }
                                                    },
                                                  );
                                                }).toList(),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_active, color: iconColor),
                                const SizedBox(width: 4),
                                Text('+$pendingCount', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
          },
        );
      },
    );
  }
}
