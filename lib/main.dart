import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/more_menu_sheet.dart';
import 'screens/shop_screen.dart';
import 'screens/info_screen.dart';
import 'services/preferences_service.dart';
import 'widgets/global_upload_indicator.dart';
import 'utils/time_utils.dart';
import 'utils/ui_utils.dart';
import 'package:provider/provider.dart';
import 'services/cart_provider.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 파이어베이스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore 오프라인 지속성(Offline Persistence) 활성화
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 로컬 설정(SharedPreferences) 초기화
  await PreferencesService.init();
  // 저장된 다크모드 설정 불러오기
  themeNotifier.value = PreferencesService.isDarkMode
      ? ThemeMode.dark
      : ThemeMode.light;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const StudyAbroadApp(),
    ),
  );
}

class StudyAbroadApp extends StatelessWidget {
  const StudyAbroadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: '유학원 컴패니언',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              surface: Color(0xFF121212),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Widget? _customScreen;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _adminOrderSubscription;
  bool _isFirstOrderLoad = true;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null && mounted) {
        setState(() {
          _customScreen = null;
          _selectedIndex = 0;
        });
      } else if (user != null && mounted) {
        // 권한 검증 및 로그아웃은 LoginScreen에서 모두 처리하므로, 여기서는 새 알림(개별공지) 체크만 수행합니다.
        try {
          final result = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();

          if (result.docs.isNotEmpty) {
            final userDoc = result.docs.first;
            final level = userDoc.data()['level'] as String? ?? '정회원';

            // 승인된 회원인 경우에만 알림 체크 및 일일 포인트 체크
            if (level == '정회원') {
              _checkPersonalNotices(userDoc.id);
              _checkDailyPoints(userDoc);
            } else if (level == '관리자' || level == '최고관리자') {
              _listenForNewOrders();
            }
          }
        } catch (e) {
          debugPrint('Error checking user level: $e');
        }
      }
    });
  }

  void _listenForNewOrders() {
    _adminOrderSubscription?.cancel();
    _isFirstOrderLoad = true;
    _adminOrderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (_isFirstOrderLoad) {
        _isFirstOrderLoad = false;
        if (snapshot.docs.isNotEmpty) {
          _showPendingOrdersDialog(snapshot.docs.length);
        }
        return;
      }
      
      int newlyAdded = 0;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          newlyAdded++;
        }
      }
      if (newlyAdded > 0) {
        _showPendingOrdersDialog(snapshot.docs.length);
      }
    });
  }

  void _showPendingOrdersDialog(int count) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새로운 주문 알림', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('현재 승인 대기 중인 주문/대여 요청이 $count건 있습니다.\n주문관리 메뉴에서 확인해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _checkDailyPoints(QueryDocumentSnapshot userDoc) async {
    try {
      final data = userDoc.data() as Map<String, dynamic>;
      final lastPointDate = data['last_point_date'] as String? ?? '';
      final todayDate = TimeUtils.getPhilippineDateString();
      
      if (lastPointDate != todayDate) {
        // 포인트 100 추가하고 last_point_date 오늘로 변경
        await FirebaseFirestore.instance.collection('users').doc(userDoc.id).update({
          'points': FieldValue.increment(100),
          'last_point_date': todayDate,
        });
        
        // 내역 기록
        await FirebaseFirestore.instance.collection('point_history').add({
          'userId': userDoc.id,
          'amount': 100,
          'type': 'daily_login',
          'description': '일일 접속 보상',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error checking daily points: $e');
    }
  }

  void _checkPersonalNotices(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_notices')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        if (!mounted) return;
        final notices = snapshot.docs;

        showDialog(
          context: context,
          builder: (ctx) {
            final bool isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              title: Text(
                '새로운 알림이 도착했습니다',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notices.length,
                  itemBuilder: (context, index) {
                    final data = notices[index].data();
                    final title = data['title'] ?? '제목 없음';
                    final content = data['content'] ?? '';

                    Timestamp? createdAt;
                    if (data['createdAt'] is Timestamp) {
                      createdAt = data['createdAt'] as Timestamp;
                    }

                    final dateStr = createdAt != null
                        ? '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}-${createdAt.toDate().day.toString().padLeft(2, '0')}'
                        : '';

                    List<String> imageUrls = [];
                    if (data['image_urls'] is List) {
                      imageUrls = (data['image_urls'] as List)
                          .map((e) => e.toString())
                          .toList();
                    }

                    return Card(
                      color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[400],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (imageUrls.isNotEmpty)
                              Container(
                                height: 120,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: imageUrls.length,
                                  itemBuilder: (ctx, imgIdx) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrls[imgIdx],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Text(
                              content,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    // 알림 읽음 처리
                    for (var doc in notices) {
                      await FirebaseFirestore.instance
                          .collection('personal_notices')
                          .doc(doc.id)
                          .update({
                            'isRead': true,
                            'readAt': FieldValue.serverTimestamp(),
                          });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    '확인',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking personal notices: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _adminOrderSubscription?.cancel();
    super.dispose();
  }

  late final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(onNavigateTab: (index) => _onItemTapped(index)),
    ShopScreen(onNavigateHome: () => _onItemTapped(0)),
    InfoScreen(onNavigateHome: () => _onItemTapped(0)),
    const SizedBox(), // 4번째 탭
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      // 4번째 탭('더보기') 클릭 시 바텀시트 대신 우측 하단 팝업 메뉴 띄우기
      showDialog(
        context: context,
        barrierColor: Colors.transparent, // 배경을 투명하게 해서 뒤가 보이게 함
        builder: (context) => Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: kBottomNavigationBarHeight + 8,
              right: 16,
            ),
            child: Material(
              color: Colors.transparent,
              child: MoreMenuSheet(
                onNavigate: (Widget screen) {
                  setState(() {
                    _customScreen = screen;
                    _selectedIndex = 3;
                  });
                  // 새 메뉴를 선택했을 때 네비게이터 스택을 초기화하여 화면 덮어쓰기 문제 해결
                  _navigatorKeys[3].currentState?.popUntil((route) => route.isFirst);
                },
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (index == 0) {
      // 홈 탭을 누르면 (현재 탭이든 다른 탭에서 넘어오든) 항상 랜딩페이지(최상단)로 초기화
      _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
    } else if (_selectedIndex == index && _selectedIndex != 3) {
      // 이미 선택된 탭을 다시 누르면 최상단(루트) 화면으로 이동
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _customScreen = null;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final isFirstRouteInCurrentTab = !await _navigatorKeys[_selectedIndex]
              .currentState!
              .maybePop();
          if (isFirstRouteInCurrentTab) {
            if (_selectedIndex != 0) {
              _onItemTapped(0);
            }
          }
        },
        child: IndexedStack(
          index: _selectedIndex,
          children: List.generate(4, (index) {
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) {
                    if (index == 3) {
                      return _customScreen ?? const SizedBox();
                    }
                    return _widgetOptions[index];
                  },
                );
              },
            );
          }),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.face_unlock_outlined),
            label: '컨시어지',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: '정보'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
