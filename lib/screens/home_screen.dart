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
import '../widgets/admin_notification_badge.dart';

import 'package:study_abroad_app/main.dart';
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
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: InkWell(
          onTap: () {
            // Scroll to top
          },
          child: Container(
            color: Colors.transparent,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const MainScreen()),
                            (route) => false,
                          );
                        },
                        child: Image.asset(
                          (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.school, color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return FutureBuilder<DocumentSnapshot?>(
                    future: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).get() : Future.value(null),
                    builder: (context, userSnapshot) {
                      String name = '게스트';
                      if (user != null) {
                        final isAdminEmail = [
                          'cebufriends79@gmail.com',
                          'slptas05@gmail.com',
                          'sunmoon.scc@gmail.com',
                          'hdcc6th@gmail.com',
                          'uhakae2026@gmail.com',
                        ].contains(user?.email);

                        if (isAdminEmail) {
                          name = '관리자';
                        } else if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                          final data = userSnapshot.data!.data() as Map<String, dynamic>;
                          final level = data['level'] as String?;
                          if (level == '관리자' || level == '최고관리자') {
                            name = '관리자';
                          } else {
                            name = (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : '회원';
                          }
                        } else {
                          name = (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : '회원';
                        }
                      }
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (name == '관리자')
                            const AdminNotificationBadge(),
                          Text(
                            '안녕하세요, $name님!',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }
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
          SliverToBoxAdapter(
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
                          double availableWidth = MediaQuery.of(context).size.width - 96;
                          double minPadding = 2.0; // 최소 간격 (양옆 2px씩, 즉 아이콘 사이 4px)
                          
                          int itemsPerRow = availableWidth ~/ (80 + minPadding * 2);
                          if (itemsPerRow < 3) itemsPerRow = 3; // 아무리 좁아도 최소 3개
                          if (itemsPerRow > 8) itemsPerRow = 8; // 너무 넓을 때 제한

                          double hPad = (availableWidth - (80 * itemsPerRow)) / (itemsPerRow * 2);
                          if (hPad < minPadding) hPad = minPadding;
                          if (hPad > 20.0) hPad = 20.0; // 최대 간격 제한

                          return Row(
                            children: favorites.map((cat) => _buildFavoriteItem(cat, context, hPad)).toList(),
                          );
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
            const SizedBox(height: 16),
          ],
        );
      }
    );
  }
  Widget _buildFavoriteItem(Map<String, dynamic> cat, BuildContext context, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
            width: 80,
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
    String assetPath = (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'); // default
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
  late final Stream<QuerySnapshot> _noticeStream;
  Stream<QuerySnapshot>? _messageStream;
  bool _isLoadingMessage = true;

  @override
  void initState() {
    super.initState();
    _noticeStream = FirebaseFirestore.instance
        .collection('posts')
        .where('category', isEqualTo: 'notice')
        .snapshots();
    _initMessageStream();
  }

  Future<void> _initMessageStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _messageStream = FirebaseFirestore.instance.collection('personal_notices').where('userId', isEqualTo: user.uid).snapshots();
    }
    if (mounted) {
      setState(() {
        _isLoadingMessage = false;
      });
    }
  }

  Widget _buildEmptyBox(bool isDarkMode, String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
      ),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
      ),
    );
  }

  Widget _buildListPane({
    required BuildContext context,
    required bool isDarkMode,
    required List<QueryDocumentSnapshot> docs,
    required String emptyText,
    required bool isNotice,
  }) {
    if (docs.isEmpty) {
      return _buildEmptyBox(isDarkMode, emptyText);
    }

    var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
    modifiableDocs.sort((a, b) {
      final aMap = a.data() as Map<String, dynamic>;
      final bMap = b.data() as Map<String, dynamic>;
      final aTime = isNotice ? aMap['created_at'] as Timestamp? : aMap['createdAt'] as Timestamp?;
      final bTime = isNotice ? bMap['created_at'] as Timestamp? : bMap['createdAt'] as Timestamp?;
      
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return bTime.compareTo(aTime);
    });

    return Container(
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
                children: modifiableDocs.map((doc) {
                  final n = doc.data() as Map<String, dynamic>;
                  // We avoid setting n['id'] = doc.id for messages to prevent PostDetailScreen from crashing trying to fetch from 'posts'
                  if (isNotice) {
                    n['id'] = doc.id;
                  } else {
                    n['category'] = 'individual_notice';
                  }
                  
                  final title = n['title'] ?? '제목 없음';
                  String titleWithDate = title;
                  final timestamp = isNotice ? n['created_at'] : n['createdAt'];
                  if (timestamp != null) {
                    final Timestamp ts = timestamp as Timestamp;
                    final DateTime dt = ts.toDate();
                    final yy = dt.year.toString().substring(2);
                    final mm = dt.month.toString().padLeft(2, '0');
                    final dd = dt.day.toString().padLeft(2, '0');
                    titleWithDate = '$yy.$mm.$dd $title';
                  } else {
                    titleWithDate = '방금 전 $title';
                  }
                  bool isUnread = false;
                  final isAdmin = PreferencesService.isAdmin;
                  if (!isAdmin) {
                    if (isNotice) {
                      isUnread = !PreferencesService.readNotices.contains(n['id']);
                    } else {
                      final bool messageIsRead = n['isRead'] ?? false;
                      final bool isFromUser = n['isFromUser'] ?? true;
                      if (!isFromUser && !messageIsRead) {
                        isUnread = true;
                      }
                    }
                  }

                  Color textColor = isDarkMode ? Colors.white : Colors.black87;
                  FontWeight fontWeight = FontWeight.normal;

                  if (!isAdmin) {
                    if (isUnread) {
                      fontWeight = FontWeight.bold;
                      textColor = isDarkMode ? Colors.white : Colors.black;
                    } else {
                      textColor = Colors.grey;
                    }
                  }
                  
                  return InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(postData: n))).then((_) {
                        setState(() {});
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: doc == modifiableDocs.last ? Colors.transparent : (isDarkMode ? Colors.white12 : Colors.grey.shade200),
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
                                color: textColor,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '공지사항',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '쪽지',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              // 왼쪽 칸: 공지사항 목록
              Expanded(
                flex: 1,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _noticeStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _buildEmptyBox(isDarkMode, '오류가 발생했습니다.');
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    return _buildListPane(
                      context: context, 
                      isDarkMode: isDarkMode, 
                      docs: snapshot.data?.docs ?? [], 
                      emptyText: '등록된 공지사항이 없습니다.',
                      isNotice: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // 오른쪽 칸: 쪽지 목록
              Expanded(
                flex: 1,
                child: _isLoadingMessage 
                  ? const Center(child: CircularProgressIndicator())
                  : (_messageStream == null 
                     ? _buildEmptyBox(isDarkMode, '쪽지가 없습니다.')
                     : StreamBuilder<QuerySnapshot>(
                         stream: _messageStream,
                         builder: (context, snapshot) {
                            if (snapshot.hasError) return _buildEmptyBox(isDarkMode, '오류가 발생했습니다.');
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            return _buildListPane(
                              context: context, 
                              isDarkMode: isDarkMode, 
                              docs: snapshot.data?.docs ?? [], 
                              emptyText: '쪽지가 없습니다.',
                              isNotice: false,
                            );
                         }
                       )
                    ),
              ),
            ],
          ),
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
