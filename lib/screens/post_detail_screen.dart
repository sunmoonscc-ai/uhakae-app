import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostDetailScreen({super.key, required this.postData});

  @override
  Widget build(BuildContext context) {
    final title = postData['title'] ?? '제목 없음';
    final content = postData['content'] ?? '';
    final authorName = postData['author_name'] ?? '익명';
    final category = postData['category'] == 'notice' ? '공지사항' : '자유 게시판';
    
    String dateStr = '';
    if (postData['created_at'] != null) {
      final Timestamp ts = postData['created_at'];
      final DateTime dt = ts.toDate();
      dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // 관리자이거나 작성자인지 여부를 상태 관리나 Auth 연동을 통해 체크하여 수정/삭제 버튼을 노출합니다.
    // 여기서는 UI 표시 목적으로 임시 표시
    final bool canEditOrDelete = true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(category, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (canEditOrDelete)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'delete') {
                  // 삭제 로직 (Firestore document 삭제)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제는 준비 중입니다.')),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                const PopupMenuItem(value: 'delete', child: Text('삭제하기', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[800],
                      child: const Icon(Icons.person, size: 20, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
