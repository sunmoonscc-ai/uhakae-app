import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community_screen.dart';
import 'post_detail_screen.dart';
class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;
  const HomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              isDarkMode ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.school, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              '유학애',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final String name = (user != null && user.displayName != null && user.displayName!.isNotEmpty) 
                      ? user.displayName! 
                      : (user != null ? '회원' : '게스트');
                  return Text(
                    '안녕하세요, $name님!',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header removed (Moved to AppBar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 날씨 위젯 (클릭 시 정보 탭으로 이동)
                InkWell(
                  onTap: () {
                    if (onNavigateTab != null) {
                      onNavigateTab!(2); // 2번 인덱스가 '정보' 탭
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.light_mode, color: Color(0xFF0C6780), size: 14),
                      SizedBox(width: 4),
                      Text(
                        '세부 날씨는 맑음, 32°C',
                        style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
                // 환율 위젯
                InkWell(
                  onTap: () {
                    if (onNavigateTab != null) {
                      onNavigateTab!(2); // 환율도 정보 탭으로 이동
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on, color: Color(0xFF0C6780), size: 14),
                      SizedBox(width: 4),
                      Text(
                        '1\$ = 61.31 PHP (BPI)',
                        style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 공지사항 (2단 레이아웃)
            const _NoticeSection(),
            const SizedBox(height: 24),

            // 빠른 서비스
            Text(
              '빠른 서비스',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildServiceIcon(Icons.restaurant, '식당', const Color(0xFF9AE1FF)),
                _buildServiceIcon(Icons.local_mall, '쇼핑몰', const Color(0xFFDAE2FF)),
                _buildServiceIcon(Icons.home_work, '숙소', const Color(0xFFFFDCC3)),
                _buildServiceIcon(Icons.groups, '커뮤니티', const Color(0xFFE1E3E4)),
              ],
            ),
            const SizedBox(height: 32),

            // 현지 인프라 목록 (Firestore 실시간 오프라인 연동)
            Text(
              '추천 현지 장소',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('places').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('데이터를 불러오는 중 오류가 발생했습니다.');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                    ),
                    child: Text('아직 등록된 장소가 없습니다.\n(오프라인 상태일 수 있습니다)', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(data['name'] ?? '이름 없음', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                        subtitle: Text(data['description'] ?? '', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDarkMode ? Colors.white54 : Colors.black54),
                        onTap: () {
                          // 상세 화면 이동 로직
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildServiceIcon(IconData icon, String label, Color bgColor) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NoticeSection extends StatefulWidget {
  const _NoticeSection();

  @override
  State<_NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends State<_NoticeSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공지사항',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('category', isEqualTo: 'notice')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.white : Colors.blue));
            }

            var docs = snapshot.data?.docs ?? [];
            
            var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
            modifiableDocs.sort((a, b) {
              final aMap = a.data() as Map<String, dynamic>;
              final bMap = b.data() as Map<String, dynamic>;
              final aTime = aMap['created_at'] as Timestamp?;
              final bTime = bMap['created_at'] as Timestamp?;
              
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return -1;
              if (bTime == null) return 1;
              return bTime.compareTo(aTime);
            });
            
            if (modifiableDocs.length > 5) {
              modifiableDocs = modifiableDocs.sublist(0, 5);
            }

            if (modifiableDocs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                ),
                child: Text('등록된 공지사항이 없습니다.', textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
              );
            }

            if (_selectedIndex >= modifiableDocs.length) {
              _selectedIndex = 0;
            }

            final selectedDoc = modifiableDocs[_selectedIndex].data() as Map<String, dynamic>;
            selectedDoc['id'] = modifiableDocs[_selectedIndex].id;
            final selectedTitle = selectedDoc['title'] ?? '제목 없음';
            final selectedContent = selectedDoc['content'] ?? '';
            String selectedTitleWithDate = selectedTitle;
            if (selectedDoc['created_at'] != null) {
              final Timestamp ts = selectedDoc['created_at'];
              final DateTime dt = ts.toDate();
              final yy = dt.year.toString().substring(2);
              final mm = dt.month.toString().padLeft(2, '0');
              final dd = dt.day.toString().padLeft(2, '0');
              selectedTitleWithDate = '$yy.$mm.$dd $selectedTitle';
            } else {
              selectedTitleWithDate = '방금 전 $selectedTitle';
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                    // 왼쪽 칸: 공지사항 목록
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                                ...List.generate(modifiableDocs.length, (index) {
                                  final n = modifiableDocs[index].data() as Map<String, dynamic>;
                                  n['id'] = modifiableDocs[index].id;
                                  final title = n['title'] ?? '제목 없음';
                                  String titleWithDate = title;
                                  if (n['created_at'] != null) {
                                    final Timestamp ts = n['created_at'];
                                    final DateTime dt = ts.toDate();
                                    final yy = dt.year.toString().substring(2);
                                    final mm = dt.month.toString().padLeft(2, '0');
                                    final dd = dt.day.toString().padLeft(2, '0');
                                    titleWithDate = '$yy.$mm.$dd $title';
                                  } else {
                                    titleWithDate = '방금 전 $title';
                                  }
                                  
                                  final isSelected = _selectedIndex == index;
                                  return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? (isDarkMode ? Colors.grey[800] : Colors.blue.shade50) 
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: index == modifiableDocs.length - 1 ? Colors.transparent : (isDarkMode ? Colors.white12 : Colors.grey.shade200),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            titleWithDate,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                              color: isSelected 
                                                  ? (isDarkMode ? Colors.blue[300] : Colors.blue[700]) 
                                                  : (isDarkMode ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          Column(
                            children: [
                              const Divider(height: 1),
                              InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityScreen()));
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '더보기', 
                                        style: TextStyle(color: isDarkMode ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Icon(Icons.chevron_right, size: 16, color: isDarkMode ? Colors.blue[300] : Colors.blue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 오른쪽 칸: 미리보기
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                                selectedTitleWithDate,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDarkMode ? Colors.white : Colors.black,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 12),
                              Text(
                                selectedContent,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  height: 1.5,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(postData: selectedDoc)));
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '자세히보기', 
                                        style: TextStyle(color: isDarkMode ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Icon(Icons.chevron_right, size: 16, color: isDarkMode ? Colors.blue[300] : Colors.blue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
