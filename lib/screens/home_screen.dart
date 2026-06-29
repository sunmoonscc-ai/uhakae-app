import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : const Color(0xFFF3F4F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDarkMode ? Colors.white24 : const Color(0xFFE1E3E4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.light_mode, color: Color(0xFF0C6780), size: 18),
                        SizedBox(width: 4),
                        Text('세부 날씨는 맑음, 32°C'),
                      ],
                    ),
                  ),
                ),
                // 환율 위젯
                InkWell(
                  onTap: () {
                    if (onNavigateTab != null) {
                      onNavigateTab!(2); // 환율도 정보 탭으로 이동
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : const Color(0xFFF3F4F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDarkMode ? Colors.white24 : const Color(0xFFE1E3E4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on, color: Color(0xFF0C6780), size: 18),
                        SizedBox(width: 4),
                        Text('1\$ = 61.31 PHP (BPI)'),
                      ],
                    ),
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

  final List<Map<String, String>> _notices = [
    {
      'title': '비자 갱신 세미나 안내',
      'content': '2024년 새로운 학생 비자 갱신 절차에 대한 세미나를 개최합니다. 학생 여러분의 많은 참여 바랍니다.',
      'author': '유학애 관리자',
      'date': '10월 24일',
    },
    {
      'title': '시눌룩 축제 안전 가이드',
      'content': '세부 최대 축제인 시눌룩 축제를 안전하고 즐겁게 즐기기 위한 가이드라인입니다.',
      'author': '유학애 안전팀',
      'date': '10월 20일',
    },
    {
      'title': '기숙사 식당 메뉴 변경 안내',
      'content': '다음 주부터 기숙사 식당의 메뉴가 일부 변경됩니다. 새로운 식단을 확인해주세요.',
      'author': '기숙사 관리팀',
      'date': '10월 18일',
    },
    {
      'title': '신입생 오리엔테이션 일정',
      'content': '2024년도 하반기 신입생들을 위한 오리엔테이션 일정을 안내해 드립니다.',
      'author': '유학애 관리자',
      'date': '10월 15일',
    },
    {
      'title': '캠퍼스 내 와이파이 점검',
      'content': '금주 주말 동안 캠퍼스 내 전체 와이파이 네트워크 점검이 있을 예정입니다.',
      'author': 'IT 지원팀',
      'date': '10월 10일',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final notice = _notices[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공지사항',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
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
                          ...List.generate(_notices.length, (index) {
                            final n = _notices[index];
                            final isSelected = _selectedIndex == index;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 위아래 폭을 더 얇게 줄임 (8 -> 4)
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? (isDarkMode ? Colors.grey[800] : Colors.blue.shade50) 
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: index == _notices.length - 1 ? Colors.transparent : (isDarkMode ? Colors.white12 : Colors.grey.shade200),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n['title']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          // 글씨 두께 수정 (볼드체 제거, 선택 시 색상으로 강조)
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
                              // 공지사항 전체 보기 화면으로 이동
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
                            notice['title']!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: isDarkMode ? Colors.white70 : Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                notice['date']!,
                                style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.black54),
                              ),
                              const Spacer(),
                              Icon(Icons.person, size: 12, color: isDarkMode ? Colors.white70 : Colors.black54),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  notice['author']!,
                                  style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.black54),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            notice['content']!,
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
                              // 자세히보기 이동
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
        ),
      ],
    );
  }
}
