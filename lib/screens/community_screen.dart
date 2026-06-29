import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_write_screen.dart';
import 'post_detail_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Image.asset(
                isDarkMode ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
                height: 28,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.forum, color: isDarkMode ? Colors.white : Colors.black),
              ),
              const SizedBox(width: 8),
              Text(
                '유학애 커뮤니티',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: '공지사항'),
              Tab(text: '자유 게시판'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPostList('notice'),
            _buildPostList('community'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostWriteScreen()),
            );
          },
          child: const Icon(Icons.edit, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildPostList(String category) {
    return StreamBuilder<QuerySnapshot>(
      // Firestore에서 카테고리에 맞는 글을 시간 역순으로 가져옴
      // 오프라인 상태일 경우 캐시에서 가져옵니다.
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: category)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                category == 'notice' ? '등록된 공지사항이 없습니다.' : '등록된 게시글이 없습니다.\n(오프라인 상태일 수 있습니다)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? '제목 없음';
            final content = data['content'] ?? '';
            final authorName = data['author_name'] ?? '익명';
            
            // 날짜 포맷팅 (임시 로직)
            String timeAgo = '조금 전';
            if (data['created_at'] != null) {
              final Timestamp ts = data['created_at'];
              final DateTime dt = ts.toDate();
              timeAgo = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.grey[900],
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PostDetailScreen(postData: data)),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (category == 'notice')
                            const Chip(
                              label: Text('공지', style: TextStyle(color: Colors.black, fontSize: 10)),
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.grey[800],
                                child: const Icon(Icons.person, size: 12, color: Colors.grey),
                              ),
                              const SizedBox(width: 6),
                              Text(authorName, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                            ],
                          ),
                          Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
