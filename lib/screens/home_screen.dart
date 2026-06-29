import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              '안녕하세요, 민수님! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
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
                  Text('오늘 세부 날씨는 맑음, 32°C'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 공지사항 (가로 스크롤)
            Text(
              '공지사항',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildNoticeCard(
                    title: '비자 갱신 세미나',
                    desc: '2024년 새로운 학생 비자 갱신 절차에 대한 다가오는 세미나에 참석하세요.',
                    date: '10월 24일, 오후 2:00',
                    color: Colors.black,
                    icon: Icons.campaign,
                  ),
                  const SizedBox(width: 16),
                  _buildNoticeCard(
                    title: '시눌룩 축제 가이드',
                    desc: '안전하고 즐겁게 시눌룩을 축하하기 위해 알아야 할 모든 것.',
                    date: '새로운 가이드',
                    color: const Color(0xFF0C6780),
                    icon: Icons.festival,
                  ),
                ],
              ),
            ),
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

  Widget _buildNoticeCard({
    required String title,
    required String desc,
    required String date,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              date,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
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
