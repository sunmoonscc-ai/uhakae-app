import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'community_screen.dart';
import 'weather_screen.dart';
import 'exchange_screen.dart';
import 'news_screen.dart';
import 'contact_screen.dart';
import '../services/preferences_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import '../widgets/business_card.dart';
import 'business_detail_screen.dart';
import 'submit_info_screen.dart';
import '../widgets/business_map_view.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../utils/time_utils.dart';

// 메인 카테고리 (가나다 순)
final ValueNotifier<String> infoMainCategoryNotifier = ValueNotifier<String>('지역');
final List<String> infoMainCategories = [
  '지역',
  '날씨',
  '뉴스',
  '주요연락처',
  '커뮤니티',
  '환율',
];

// 공통 지역 카테고리 (2단)
final ValueNotifier<String> commonRegionNotifier = ValueNotifier<String>('바기오');
final List<String> commonRegions = ['바기오', '클락', '세부', '보홀'];

// 지역 하위 카테고리 (3단)
final ValueNotifier<String> regionSubCategoryNotifier = ValueNotifier<String>('전체');
final List<Map<String, dynamic>> regionSubCategories = [
  {'label': '전체', 'icon': Icons.apps, 'color': const Color(0xFFF5F5F5)},
  {'label': '관광', 'icon': Icons.tour, 'color': const Color(0xFFE8EAF6)},
  {'label': '마사지', 'icon': Icons.spa, 'color': const Color(0xFFF3E5F5)},
  {'label': '병원', 'icon': Icons.local_hospital, 'color': const Color(0xFFFFEBEE)},
  {'label': '뷰티', 'icon': Icons.face, 'color': const Color(0xFFFCE4EC)},
  {'label': '쇼핑', 'icon': Icons.shopping_bag, 'color': const Color(0xFFFFF8E1)},
  {'label': '식당', 'icon': Icons.restaurant, 'color': const Color(0xFFFFF3E0)},
  {'label': '카페·바', 'icon': Icons.local_cafe, 'color': const Color(0xFFEFEBE9)},
  {'label': '환전', 'icon': Icons.currency_exchange, 'color': const Color(0xFFF1F8E9)},
];

// 뉴스 3차 카테고리 (유형)
final ValueNotifier<String> newsTypeNotifier = ValueNotifier<String>('News');
final List<String> newsTypes = ['News', '업체 Event'];

class InfoScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;
  const InfoScreen({super.key, this.onNavigateHome});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final Map<String, GlobalKey> _subCatKeys = {};
  bool _showMap = false;
  String _sortMode = 'name_asc'; // name_asc, name_desc, dist_asc, dist_desc
  bool _openNowFilter = false;
  Position? _currentPosition;

  List<BusinessModel>? _cachedBusinesses;

  Future<void> _requestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')));
      }
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다.')));
      }
      return;
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
      _sortMode = 'dist_asc';
    });
  }

  double _getDistance(BusinessModel b) {
    if (_currentPosition == null || b.address3.isEmpty) return double.maxFinite;
    try {
      final parts = b.address3.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
      }
    } catch (e) {
      // ignore
    }
    return double.maxFinite;
  }

  @override
  void initState() {
    super.initState();
    String initialRegion = PreferencesService.isAdmin 
        ? PreferencesService.defaultRegion 
        : PreferencesService.userRegion;
    
    if (initialRegion == '전체' || !commonRegions.contains(initialRegion)) {
      initialRegion = '바기오';
    }
    commonRegionNotifier.value = initialRegion;

    for (var cat in regionSubCategories) {
      _subCatKeys[cat['label']] = GlobalKey();
    }
    
    regionSubCategoryNotifier.addListener(_scrollToSelectedSubCategory);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedSubCategory();
    });
  }

  @override
  void dispose() {
    regionSubCategoryNotifier.removeListener(_scrollToSelectedSubCategory);
    super.dispose();
  }

  void _scrollToSelectedSubCategory() {
    final key = _subCatKeys[regionSubCategoryNotifier.value];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onNavigateHome,
                child: Image.asset(
                  isDarkMode ? 'assets/images/logo_dark.png' : 'assets/images/logo.png',
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.school, color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '정보',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<String>(
            valueListenable: infoMainCategoryNotifier,
            builder: (context, mainTab, _) {
              return ValueListenableBuilder<String>(
                valueListenable: regionSubCategoryNotifier,
                builder: (context, subTab, _) {
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: PreferencesService.favoritesNotifier,
                    builder: (context, favorites, _) {
                      final id = mainTab == '지역' ? 'menu_지역_$subTab' : 'menu_$mainTab';
                      final isFav = PreferencesService.isFavorite(id);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : (isDarkMode ? Colors.white : Colors.black),
                        ),
                        onPressed: () {
                          if (isFav) {
                            PreferencesService.removeFavorite(id);
                          } else {
                            IconData icon = Icons.info;
                            int colorValue = 0xFFE6F3FF;
                            if (mainTab == '지역') {
                              final match = regionSubCategories.firstWhere((e) => e['label'] == subTab, orElse: () => {'icon': Icons.tour, 'color': const Color(0xFFE8EAF6)});
                              icon = match['icon'];
                              colorValue = (match['color'] as Color).value;
                            } else {
                              if (mainTab == '뉴스') { icon = Icons.article; colorValue = Colors.blue[50]!.value; }
                              else if (mainTab == '주요연락처') { icon = Icons.contact_phone; colorValue = Colors.green[50]!.value; }
                              else if (mainTab == '커뮤니티') { icon = Icons.forum; colorValue = Colors.orange[50]!.value; }
                              else if (mainTab == '환율') { icon = Icons.show_chart; colorValue = Colors.purple[50]!.value; }
                            }
                            PreferencesService.addFavorite({
                              'id': id,
                              'type': 'menu',
                              'title': mainTab == '지역' ? subTab : mainTab,
                              'iconCodePoint': icon.codePoint,
                              'iconFontFamily': icon.fontFamily,
                              'colorValue': colorValue,
                              'mainTab': mainTab,
                              'subCategory': subTab,
                              'tabIndex': 2,
                            });
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: infoMainCategoryNotifier,
        builder: (context, mainCategory, _) {
          return Column(
            children: [
              // 1차 메인 탭 (가로 스크롤)
              Container(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: infoMainCategories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final catName = infoMainCategories[index];
                    final isSelected = mainCategory == catName;
                    return InkWell(
                      onTap: () {
                        infoMainCategoryNotifier.value = catName;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected 
                                ? (isDarkMode ? Colors.blue[300]! : Colors.blue) 
                                : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          catName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? (isDarkMode ? Colors.blue[300] : Colors.blue)
                                : (isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2차 서브 탭 (지역, 뉴스, 주요연락처, 커뮤니티 선택 시에 표시) - 관리자에게만 표시
              if (PreferencesService.isAdmin && ['지역', '뉴스', '주요연락처', '커뮤니티'].contains(mainCategory))
                Container(
                  color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
                  height: 48,
                  child: ValueListenableBuilder<String>(
                    valueListenable: commonRegionNotifier,
                    builder: (context, region, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: commonRegions.map((reg) {
                            final isSelected = region == reg;
                            return Container(
                              child: InkWell(
                                onTap: () {
                                  commonRegionNotifier.value = reg;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  child: Text(
                                    reg,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? (isDarkMode ? Colors.blue[200] : Colors.blue[700])
                                          : (isDarkMode ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),

              // 3차 서브 탭 (지역 선택 시에만 표시)
              if (mainCategory == '지역')
                Container(
                  color: isDarkMode ? Colors.grey[900] : const Color(0xFFE9ECEF),
                  height: 48,
                  child: ValueListenableBuilder<String>(
                    valueListenable: regionSubCategoryNotifier,
                    builder: (context, subCategory, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: regionSubCategories.map((subCat) {
                            final isSelected = subCategory == subCat['label'];
                            return Container(
                              key: _subCatKeys[subCat['label']],
                              child: InkWell(
                                onTap: () {
                                  regionSubCategoryNotifier.value = subCat['label'];
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    subCat['label'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? (isDarkMode ? Colors.blue[200] : Colors.blue[700])
                                          : (isDarkMode ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),

              // 3차 서브 탭 (뉴스 선택 시에만 표시 - 유형)
              if (mainCategory == '뉴스')
                Container(
                  color: isDarkMode ? Colors.grey[900] : const Color(0xFFE9ECEF),
                  height: 40,
                  child: ValueListenableBuilder<String>(
                    valueListenable: newsTypeNotifier,
                    builder: (context, type, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: newsTypes.map((typ) {
                            final isSelected = type == typ;
                            return Container(
                              child: InkWell(
                                onTap: () {
                                  newsTypeNotifier.value = typ;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  child: Text(
                                    typ,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? (isDarkMode ? Colors.blue[300] : Colors.blue[800])
                                          : (isDarkMode ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),

              // 본문 내용
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (mainCategory == '날씨') {
                      return const WeatherScreen();
                    } else if (mainCategory == '환율') {
                      return const ExchangeScreen();
                    } else if (['지역', '뉴스', '주요연락처', '커뮤니티'].contains(mainCategory)) {
                      return ValueListenableBuilder<String>(
                        valueListenable: commonRegionNotifier,
                        builder: (context, currentRegion, _) {
                          // 비관리자는 자신의 지역을 고정 사용, 관리자는 선택한 지역 사용
                          final region = PreferencesService.isAdmin ? currentRegion : PreferencesService.userRegion;

                          if (region == '전체') {
                            return Center(
                              child: Text(
                                "위 탭에서 지역을 먼저 선택해 주세요.",
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            );
                          }

                          if (mainCategory == '지역') {
                            return ValueListenableBuilder<String>(
                              valueListenable: regionSubCategoryNotifier,
                              builder: (context, subCategory, _) {
                                return StreamBuilder<QuerySnapshot>(
                                  stream: subCategory == '전체'
                                      ? FirebaseFirestore.instance
                                          .collection('directory')
                                          .where('region', isEqualTo: region)
                                          .snapshots()
                                      : FirebaseFirestore.instance
                                          .collection('directory')
                                          .where('region', isEqualTo: region)
                                          .where('subCategory', isEqualTo: subCategory)
                                          .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(child: Text('오류가 발생했습니다.'));
                                    }
                                    if (snapshot.connectionState == ConnectionState.waiting && _cachedBusinesses == null) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasData) {
                                      final docs = snapshot.data?.docs ?? [];
                                      _cachedBusinesses = docs.map((doc) => BusinessModel.fromFirestore(doc)).toList();
                                    }
                                    
                                    List<BusinessModel> businesses = _cachedBusinesses ?? [];

                                    // 영업중 필터 적용
                                    if (_openNowFilter) {
                                      businesses = businesses.where((b) {
                                        if (b.operatingHours.isEmpty) return false;
                                        return TimeUtils.isOpenNow(b.operatingHours);
                                      }).toList();
                                    }

                                    // 정렬 적용
                                    businesses.sort((a, b) {
                                      if (_sortMode.startsWith('name')) {
                                        int cmp = a.name.compareTo(b.name);
                                        return _sortMode == 'name_asc' ? cmp : -cmp;
                                      } else {
                                        double distA = _getDistance(a);
                                        double distB = _getDistance(b);
                                        int cmp = distA.compareTo(distB);
                                        return _sortMode == 'dist_asc' ? cmp : -cmp;
                                      }
                                    });

                                    return Column(
                                      children: [
                                        // 정렬 및 필터 영역
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                          child: Row(
                                            children: [
                                              // 정렬 버튼 (이름순)
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _sortMode = _sortMode == 'name_asc' ? 'name_desc' : 'name_asc';
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _sortMode.startsWith('name') ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                                                    border: Border.all(color: _sortMode.startsWith('name') ? Colors.blue : Colors.grey),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '정렬(이름) ${_sortMode == 'name_asc' ? '↑' : '↓'}',
                                                    style: TextStyle(fontSize: 12, color: _sortMode.startsWith('name') ? Colors.blue : Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // 거리 버튼
                                              InkWell(
                                                onTap: () {
                                                  if (_currentPosition == null) {
                                                    _requestLocation();
                                                  } else {
                                                    setState(() {
                                                      _sortMode = _sortMode == 'dist_asc' ? 'dist_desc' : 'dist_asc';
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _sortMode.startsWith('dist') ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                                                    border: Border.all(color: _sortMode.startsWith('dist') ? Colors.blue : Colors.grey),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '거리 ${_sortMode == 'dist_asc' ? '↑' : _sortMode == 'dist_desc' ? '↓' : ''}',
                                                    style: TextStyle(fontSize: 12, color: _sortMode.startsWith('dist') ? Colors.blue : Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // 지도보기 토글
                                              InkWell(
                                                onTap: () async {
                                                  if (!_showMap && _currentPosition == null) {
                                                    await _requestLocation();
                                                  }
                                                  setState(() {
                                                    _showMap = !_showMap;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _showMap ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                                                    border: Border.all(color: _showMap ? Colors.blue : Colors.grey),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.map, size: 14, color: _showMap ? Colors.blue : Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text('지도보기', style: TextStyle(fontSize: 12, color: _showMap ? Colors.blue : Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              // 영업중 체크박스
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Checkbox(
                                                      value: _openNowFilter,
                                                      onChanged: (val) {
                                                        setState(() {
                                                          _openNowFilter = val ?? false;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text('영업중', style: TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: _showMap
                                              ? BusinessMapView(
                                                  businesses: businesses,
                                                  initialCenter: _currentPosition != null 
                                                      ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                                      : null,
                                                )
                                              : ListView.builder(
                                                  itemCount: businesses.length,
                                                  itemBuilder: (context, index) {
                                                    final business = businesses[index];
                                                    return BusinessCard(
                                                      business: business,
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => BusinessDetailScreen(business: business),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],

                                    );
                                  },
                                );
                              },
                            );
                          } else if (mainCategory == '뉴스') {
                            return ValueListenableBuilder<String>(
                              valueListenable: newsTypeNotifier,
                              builder: (context, type, _) {
                                if (type == 'News') {
                                  return NewsScreen(region: region);
                                } else {
                                  return Center(
                                    child: Text(
                                      "뉴스 > '$region' > '업체 Event' 상세 화면 준비 중입니다.",
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          } else if (mainCategory == '주요연락처') {
                            return ContactScreen(region: region);
                          } else if (mainCategory == '커뮤니티') {
                            return CommunityScreen(showAppBar: false, region: region);
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    } else {
                      return Center(
                        child: Text(
                          "'$mainCategory' 화면 준비 중입니다.",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
