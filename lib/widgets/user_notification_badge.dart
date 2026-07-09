import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/community_screen.dart';

class UserNotificationBadge extends StatelessWidget {
  final Color iconColor;
  final Color textColor;

  const UserNotificationBadge({
    super.key, 
    this.iconColor = Colors.blue, 
    this.textColor = Colors.blue
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('personal_notices')
          .where('userId', isEqualTo: user.uid)
          .where('isFromUser', isEqualTo: false)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        int unreadCount = snapshot.data!.docs.length;
        if (unreadCount == 0) return const SizedBox.shrink();

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunityScreen(initialTabIndex: 1)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread, color: iconColor),
                const SizedBox(width: 4),
                Text('+$unreadCount', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
