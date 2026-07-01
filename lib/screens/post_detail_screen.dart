import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_write_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostDetailScreen({super.key, required this.postData});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final category = postData['category'] == 'notice' 
        ? '공지사항' 
        : (postData['category'] == 'individual_notice' ? '쪽지' : '자유 게시판');
    final postId = postData['id'] as String?;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              isDarkMode ? 'assets/images/logo_dark.png' : 'assets/images/logo.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.forum, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Text(category, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        actions: [
          if (postId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                final currentData = snapshot.data!.data() as Map<String, dynamic>;
                currentData['id'] = postId;
                
                final user = FirebaseAuth.instance.currentUser;
                final bool isAdmin = user != null && [
                  'cebufriends79@gmail.com',
                  'slptas05@gmail.com',
                  'sunmoon.scc@gmail.com',
                  'hdcc6th@gmail.com',
                ].contains(user.email);
                
                final bool isAuthor = user != null && currentData['author_id'] == user.uid;
                final bool canEditOrDelete = isAdmin || isAuthor;

                if (!canEditOrDelete) return const SizedBox();

                return PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : Colors.black),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostWriteScreen(
                            editPostId: postId,
                            editPostData: currentData,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      // 삭제 전 확인 다이얼로그
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('게시글 삭제'),
                          content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true), 
                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                          if (context.mounted) {
                            UiUtils.showPopup(context, '게시글이 삭제되었습니다.');
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            UiUtils.showPopup(context, '삭제 실패: $e');
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                    const PopupMenuItem(value: 'delete', child: Text('삭제하기', style: TextStyle(color: Colors.red))),
                  ],
                );
              }
            ),
          IconButton(
            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: postId == null 
        ? _buildContent(context, postData, isDarkMode) 
        : StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('게시글을 찾을 수 없습니다.'));
              }
              final currentData = snapshot.data!.data() as Map<String, dynamic>;
              currentData['id'] = postId;
              return _buildContent(context, currentData, isDarkMode);
            },
          ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data, bool isDarkMode) {
    final title = data['title'] ?? '제목 없음';
    final content = data['content'] ?? '';
    final imageUrls = List<String>.from(data['image_urls'] ?? []);
    final authorName = data['author_name'] ?? data['senderName'] ?? (data['isFromUser'] == true ? '나' : (data['isFromUser'] == false ? '관리자' : '익명'));
    
    String dateStr = '';
    final Timestamp? ts = data['created_at'] as Timestamp? ?? data['createdAt'] as Timestamp?;
    if (ts != null) {
      final DateTime dt = ts.toDate();
      dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.person, size: 20, color: isDarkMode ? Colors.grey : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(authorName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
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
              style: TextStyle(fontSize: 16, height: 1.6, color: isDarkMode ? Colors.white70 : Colors.black87),
            ),
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...imageUrls.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      );
  }
}
