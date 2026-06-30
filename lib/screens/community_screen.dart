import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_write_screen.dart';
import 'post_detail_screen.dart';

class CommunityScreen extends StatelessWidget {
  final bool showAppBar;
  final String region;
  const CommunityScreen({super.key, this.showAppBar = true, this.region = '전체'});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
        appBar: showAppBar ? AppBar(
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
          bottom: TabBar(
            labelColor: isDarkMode ? Colors.white : Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: isDarkMode ? Colors.white : Colors.black,
            tabs: const [
              Tab(text: '공지사항'),
              Tab(text: '개별공지'),
              Tab(text: '자유 게시판'),
            ],
          ),
        ) : PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: SafeArea(
            child: TabBar(
              labelColor: isDarkMode ? Colors.white : Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: isDarkMode ? Colors.white : Colors.black,
              tabs: const [
                Tab(text: '공지사항'),
                Tab(text: '개별공지'),
                Tab(text: '자유 게시판'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildPostList('notice'),
            _buildPostList('individual_notice'),
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
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        if (snapshot.hasError) {
          return Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.white : Colors.blue));
        }

        var docs = snapshot.data?.docs ?? [];
        
        // 지역 필터링 (클라이언트 단 처리 - 인덱스 오류 방지)
        if (region != '전체') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // 기존 데이터에 region 필드가 없으면 '세부'로 간주
            final docRegion = data['region'] as String? ?? '세부';
            return docRegion == region;
          }).toList();
        }
        
        // 클라이언트에서 최신순 정렬 (복합 인덱스 에러 방지)
        var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
        modifiableDocs.sort((a, b) {
          final aMap = a.data() as Map<String, dynamic>;
          final bMap = b.data() as Map<String, dynamic>;
          final aTime = aMap['created_at'] as Timestamp?;
          final bTime = bMap['created_at'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1; // 방금 작성한 글(null)은 최상단
          if (bTime == null) return 1;
          return bTime.compareTo(aTime); // 내림차순
        });

        if (modifiableDocs.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
              ),
              child: Text(
                category == 'notice' ? '등록된 공지사항이 없습니다.' : '등록된 게시글이 없습니다.\n(오프라인 상태일 수 있습니다)',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: modifiableDocs.length,
          itemBuilder: (context, index) {
            final doc = modifiableDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            final title = data['title'] ?? '제목 없음';
            final content = data['content'] ?? '';
            final imageUrls = List<String>.from(data['image_urls'] ?? []);
            final authorName = data['author_name'] ?? '익명';
            final bool isAdminPost = data['is_admin'] == true;
            final displayAuthorName = isAdminPost ? '관리자' : authorName;
            
            // 날짜 포맷팅 (임시 로직)
            String timeAgo = '조금 전';
            if (data['created_at'] != null) {
              final Timestamp ts = data['created_at'];
              final DateTime dt = ts.toDate();
              timeAgo = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(timeAgo, style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (imageUrls.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.image, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                child: Icon(Icons.person, size: 10, color: isDarkMode ? Colors.grey : Colors.black54),
                              ),
                              const SizedBox(width: 4),
                              Text(displayAuthorName, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54)),
                            ],
                          ),
                          if (category == 'notice' || category == 'individual_notice') ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('공지', style: TextStyle(color: isDarkMode ? Colors.black : Colors.white, fontSize: 10)),
                              backgroundColor: isDarkMode ? Colors.white : Colors.black,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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
