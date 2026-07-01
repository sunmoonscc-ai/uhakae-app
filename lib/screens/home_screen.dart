import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import 'community_screen.dart';
import 'post_detail_screen.dart';
import 'info_screen.dart';
import '../services/preferences_service.dart';
import '../models/business_model.dart';
import 'business_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;
  const HomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
        elevation: 0,
        title: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onNavigateTab?.call(0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.school, color: isDarkMode ? Colors.white : Colors.black),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '유학애',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : const Color(0xFF0C6780),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
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
        body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 실시간 환율 및 날씨 정보 (API 연동)
                  _TopInfoSection(onNavigateTab: onNavigateTab, isDarkMode: isDarkMode),
                  const SizedBox(height: 24),
                  
                  // 공지사항 (2단 레이아웃)
                  const _NoticeSection(),
                  const SizedBox(height: 24),

                  const _FavoriteListSection(title: '즐겨찾기 장소', type: 'business'),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _FavoriteListSection(title: '즐겨찾기 메뉴', type: 'menu'),
                  ],
                ),
              ),
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

class _FavoriteListSection extends StatefulWidget {
  final String title;
  final String type;
  const _FavoriteListSection({required this.title, required this.type});

  @override
  State<_FavoriteListSection> createState() => _FavoriteListSectionState();
}

class _FavoriteListSectionState extends State<_FavoriteListSection> {
  final ScrollController _scrollController = ScrollController();

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 150,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 150,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: PreferencesService.favoritesNotifier,
      builder: (context, allFavorites, child) {
        final favorites = allFavorites.where((e) => e['type'] == widget.type).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            if (favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    '(즐겨찾기 없음)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Row(
                children: [
                  InkWell(
                    onTap: _scrollLeft,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                      child: Icon(Icons.chevron_left, color: isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Builder(
                        builder: (context) {
                          if (widget.type == 'business') {
                            // Calculate how many items fit in one row based on screen width
                            int itemsPerRow = (MediaQuery.of(context).size.width - 64) ~/ 80;
                            if (itemsPerRow < 1) itemsPerRow = 1;

                            List<Widget> row1 = [];
                            List<Widget> row2 = [];
                            
                            if (favorites.length <= itemsPerRow) {
                              row1 = favorites.map((cat) => _buildFavoriteItem(cat, context)).toList();
                            } else {
                              for (int i = 0; i < favorites.length; i++) {
                                if (i % 2 == 0) row1.add(_buildFavoriteItem(favorites[i], context));
                                else row2.add(_buildFavoriteItem(favorites[i], context));
                              }
                            }

                            return SizedBox(
                              height: 228,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: row1,
                                  ),
                                  if (row2.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: row2,
                                    ),
                                  ]
                                ],
                              ),
                            );
                          } else {
                            return Row(
                              children: favorites.map((cat) => _buildFavoriteItem(cat, context)).toList(),
                            );
                          }
                        }
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _scrollRight,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                      child: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
          ],
        );
      }
    );
  }
  Widget _buildFavoriteItem(Map<String, dynamic> cat, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (cat['type'] == 'business') {
            final business = BusinessModel.fromMap(cat['businessData'], cat['id']);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BusinessDetailScreen(business: business)),
            );
          } else {
            if (cat['isAdminMenu'] == true) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminScreen(initialTab: cat['adminTab'])),
              );
            } else {
              infoMainCategoryNotifier.value = cat['mainTab'] ?? '지역';
              if (cat['mainTab'] == '지역' && cat['subCategory'] != null) {
                regionSubCategoryNotifier.value = cat['subCategory'];
              }
              final homeScreen = context.findAncestorWidgetOfExactType<HomeScreen>();
              if (homeScreen?.onNavigateTab != null) {
                homeScreen!.onNavigateTab!(cat['tabIndex'] ?? 2);
              }
            }
          }
        },
        child: SizedBox(
          width: widget.type == 'business' ? 76 : 80,
          height: widget.type == 'business' ? 110 : 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (widget.type == 'business') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (cat['businessData']?['thumbnailUrl'] != null && cat['businessData']['thumbnailUrl'].toString().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: cat['businessData']['thumbnailUrl'],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 64, height: 64, color: Colors.grey[300]),
                          errorWidget: (context, url, error) => Container(width: 64, height: 64, color: Colors.grey[300], child: const Icon(Icons.business, color: Colors.grey)),
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: Colors.white,
                          child: Image.asset(
                            _getPlaceholderImage(cat['businessData']?['subCategory'] ?? ''),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.business, color: Colors.grey)),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Color(cat['colorValue'] ?? 0xFFEEEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(IconData(cat['iconCodePoint'], fontFamily: cat['iconFontFamily'] ?? 'MaterialIcons'), color: Colors.black87, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  cat['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  String _getPlaceholderImage(String category) {
    String assetPath = 'assets/images/logo.png'; // default
    if (category.contains('쇼핑')) assetPath = 'assets/images/ph_shopping.png';
    else if (category.contains('식당') || category.contains('음식')) assetPath = 'assets/images/ph_restaurant.png';
    else if (category.contains('카페')) assetPath = 'assets/images/ph_cafebar.png';
    else if (category.contains('마사지')) assetPath = 'assets/images/ph_massage.png';
    else if (category.contains('뷰티')) assetPath = 'assets/images/ph_beauty.png';
    else if (category.contains('환전') || category.contains('은행')) assetPath = 'assets/images/ph_exchange.png';
    else if (category.contains('관광') || category.contains('여행')) assetPath = 'assets/images/ph_travel.png';
    else if (category.contains('병원')) assetPath = 'assets/images/ph_hospital.png';
    return assetPath;
  }
}

class _NoticeSection extends StatefulWidget {
  const _NoticeSection();

  @override
  State<_NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends State<_NoticeSection> {
  int _selectedIndex = 0;
  late final Stream<QuerySnapshot> _noticeStream;

  @override
  void initState() {
    super.initState();
    _noticeStream = FirebaseFirestore.instance
        .collection('posts')
        .where('category', isEqualTo: 'notice')
        .snapshots();
  }

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
          stream: _noticeStream,
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
            return SizedBox(
              height: 160, // 스크롤을 위해 고정 높이 지정 (오른쪽 3줄 표시 및 왼쪽 4개 딱 맞춤)
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
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
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
                            ),
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
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
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
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
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
                                  ),
                                ],
                              ),
                            ),
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
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
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

class _TopInfoSection extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final bool isDarkMode;
  const _TopInfoSection({required this.onNavigateTab, required this.isDarkMode});
  
  @override
  State<_TopInfoSection> createState() => _TopInfoSectionState();
}

class _TopInfoSectionState extends State<_TopInfoSection> {
  String _weatherText = '날씨 불러오는 중...';
  String _exchangeText = '환율 불러오는 중...';
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  Future<void> _fetchData() async {
    // 1. 환율 가져오기 (open.er-api.com 활용)
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final php = data['rates']['PHP'];
        
        // 필리핀 시간 (UTC+8) 기준 현재 시각
        final nowPh = DateTime.now().toUtc().add(const Duration(hours: 8));
        
        // KST 08:59 발표는 필리핀 시간 07:59 임
        bool isAfterAnnouncement = false;
        if (nowPh.hour > 7 || (nowPh.hour == 7 && nowPh.minute >= 59)) {
          isAfterAnnouncement = true;
        }
        
        // 발표 전이면 어제 날짜 사용
        final targetDate = isAfterAnnouncement ? nowPh : nowPh.subtract(const Duration(days: 1));
        final dateStr = '${targetDate.month}/${targetDate.day}';
        
        if (mounted) {
          setState(() {
            _exchangeText = '$dateStr 08:59(kr) 기준환율 1\$=${php.toStringAsFixed(2)}php';
          });
        }
      } else {
        if (mounted) setState(() => _exchangeText = '환율 정보를 불러올 수 없습니다.');
      }
    } catch(e) {
      if (mounted) setState(() => _exchangeText = '환율 정보를 불러올 수 없습니다.');
    }
    
    // 2. 날씨 가져오기 (WeatherService 활용)
    try {
      final weatherService = WeatherService();
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('No GPS');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) throw Exception('No GPS');
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final weatherData = await weatherService.fetchWeather(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _weatherText = '${weatherData.locationName} ${weatherData.tempC.round()}°C';
        });
      }
    } catch(e) {
      if (mounted) setState(() => _weatherText = '날씨를 확인하려면 클릭하세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측: 환율 위젯
        Expanded(
          child: InkWell(
            onTap: () {
              if (widget.onNavigateTab != null) {
                infoMainCategoryNotifier.value = '환율';
                widget.onNavigateTab!(2);
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFF0C6780), size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _exchangeText,
                    style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 우측: 날씨 위젯
        InkWell(
          onTap: () {
            if (widget.onNavigateTab != null) {
              infoMainCategoryNotifier.value = '날씨';
              widget.onNavigateTab!(2);
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.light_mode, color: Color(0xFF0C6780), size: 14),
              const SizedBox(width: 4),
              Text(
                _weatherText,
                style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
