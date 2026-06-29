import 'package:flutter/material.dart';
import 'community_screen.dart';
import 'weather_screen.dart';
import 'exchange_screen.dart';

// 메인 카테고리 (가나다 순)
final ValueNotifier<String> infoMainCategoryNotifier = ValueNotifier<String>('Cebu 정보');
final List<String> infoMainCategories = [
  'Cebu 정보',
  '날씨',
  '뉴스',
  '주요연락처',
  '커뮤니티',
  '환율',
];

// Cebu 정보 하위 카테고리 (가나다 순)
final ValueNotifier<String> cebuSubCategoryNotifier = ValueNotifier<String>('레저');
final List<Map<String, dynamic>> cebuSubCategories = [
  {'label': '레저', 'icon': Icons.directions_run, 'color': const Color(0xFFE6F3FF)},
  {'label': '마사지', 'icon': Icons.spa, 'color': const Color(0xFFF3E5F5)},
  {'label': '병원', 'icon': Icons.local_hospital, 'color': const Color(0xFFFFEBEE)},
  {'label': '뷰티', 'icon': Icons.face, 'color': const Color(0xFFFCE4EC)},
  {'label': '세탁', 'icon': Icons.local_laundry_service, 'color': const Color(0xFFE0F7FA)},
  {'label': '쇼핑', 'icon': Icons.shopping_bag, 'color': const Color(0xFFFFF8E1)},
  {'label': '식당', 'icon': Icons.restaurant, 'color': const Color(0xFFFFF3E0)},
  {'label': '여행', 'icon': Icons.flight, 'color': const Color(0xFFE8EAF6)},
  {'label': '음식', 'icon': Icons.fastfood, 'color': const Color(0xFFFFE0B2)},
  {'label': '카페·바', 'icon': Icons.local_cafe, 'color': const Color(0xFFEFEBE9)},
  {'label': '환전', 'icon': Icons.currency_exchange, 'color': const Color(0xFFF1F8E9)},
];

class InfoScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;
  const InfoScreen({super.key, this.onNavigateHome});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final Map<String, GlobalKey> _subCatKeys = {};

  @override
  void initState() {
    super.initState();
    for (var cat in cebuSubCategories) {
      _subCatKeys[cat['label']] = GlobalKey();
    }
    
    cebuSubCategoryNotifier.addListener(_scrollToSelectedSubCategory);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedSubCategory();
    });
  }

  @override
  void dispose() {
    cebuSubCategoryNotifier.removeListener(_scrollToSelectedSubCategory);
    super.dispose();
  }

  void _scrollToSelectedSubCategory() {
    final key = _subCatKeys[cebuSubCategoryNotifier.value];
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
                  isDarkMode ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
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

              // 2차 서브 탭 (Cebu 정보 선택 시에만 표시)
              if (mainCategory == 'Cebu 정보')
                Container(
                  color: isDarkMode ? Colors.black : const Color(0xFFF1F3F5),
                  height: 48,
                  child: ValueListenableBuilder<String>(
                    valueListenable: cebuSubCategoryNotifier,
                    builder: (context, subCategory, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: cebuSubCategories.map((subCat) {
                            final isSelected = subCategory == subCat['label'];
                            return Container(
                              key: _subCatKeys[subCat['label']],
                              child: InkWell(
                                onTap: () {
                                  cebuSubCategoryNotifier.value = subCat['label'];
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

              // 본문 내용
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (mainCategory == '날씨') {
                      return const WeatherScreen();
                    } else if (mainCategory == '환율') {
                      return const ExchangeScreen();
                    } else if (mainCategory == '커뮤니티') {
                      return const CommunityScreen(showAppBar: false); // AppBar 숨김 처리 필요 시 대응
                    } else if (mainCategory == 'Cebu 정보') {
                      return ValueListenableBuilder<String>(
                        valueListenable: cebuSubCategoryNotifier,
                        builder: (context, subCategory, _) {
                          return Center(
                            child: Text(
                              "Cebu 정보 > '$subCategory' 상세 화면 준비 중입니다.",
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          );
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
