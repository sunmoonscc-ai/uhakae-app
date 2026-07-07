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
                    int pendingCount = 0;
                    if (orderSnapshot.hasData) pendingCount += orderSnapshot.data!.docs.length;
                    if (userSnapshot.hasData) pendingCount += userSnapshot.data!.docs.length;
                    if (infoSnapshot.hasData) pendingCount += infoSnapshot.data!.docs.length;

                    if (pendingCount == 0) return const SizedBox.shrink();

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminScreen(initialTab: '대시보드')),
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
  }
}
