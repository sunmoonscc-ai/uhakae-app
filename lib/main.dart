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

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 파이어베이스 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Firestore 오프라인 지속성(Offline Persistence) 활성화
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 로컬 설정(SharedPreferences) 초기화
  await PreferencesService.init();
  // 저장된 다크모드 설정 불러오기
  themeNotifier.value = PreferencesService.isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const StudyAbroadApp());
}

class StudyAbroadApp extends StatelessWidget {
  const StudyAbroadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
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
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            useMaterial3: true,
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
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            useMaterial3: true,
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
  
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];
  
  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null && mounted) {
        setState(() {
          _customScreen = null;
          _selectedIndex = 0;
        });
      } else if (user != null && mounted) {
        if (!PreferencesService.isAdmin) {
          final result = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          
          if (result.docs.isNotEmpty) {
            final userDoc = result.docs.first;
            final level = userDoc.data()['level'] as String? ?? '정회원';
            if (level != '정회원') {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn(
                clientId: '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
              ).signOut();
            } else {
              _checkPersonalNotices(userDoc.id);
            }
          } else {
            await FirebaseAuth.instance.signOut();
            await GoogleSignIn(
              clientId: '728466681157-hqbrfqmv0fu4s5jibin426sn027ah32v.apps.googleusercontent.com',
            ).signOut();
          }
        } else {
          // 어드민일 경우에도 개별공지 체크가 필요한지? 보통 어드민은 개별공지 받는 주체가 아니지만,
          // DB에 본인 이메일로 생성된 문서가 있다면 체크.
          final result = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          if (result.docs.isNotEmpty) {
            _checkPersonalNotices(result.docs.first.id);
          }
        }
      }
    });
  }

  void _checkPersonalNotices(String userId) async {
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
            title: Text('새로운 알림이 도착했습니다', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final data = notices[index].data();
                  final title = data['title'] ?? '제목 없음';
                  final content = data['content'] ?? '';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null 
                      ? '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}-${createdAt.toDate().day.toString().padLeft(2, '0')}' 
                      : '';
                  final imageUrls = data['image_urls'] as List<dynamic>? ?? [];
                  
                  return Card(
                    color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.blue[400])),
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
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(imageUrls[imgIdx], fit: BoxFit.cover),
                                    ),
                                  );
                                },
                              ),
                            ),
                          Text(content, style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
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
                    await FirebaseFirestore.instance.collection('personal_notices').doc(doc.id).update({
                      'isRead': true,
                      'readAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('확인', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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
            padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 8, right: 16),
            child: Material(
              color: Colors.transparent,
              child: MoreMenuSheet(
                onNavigate: (Widget screen) {
                  setState(() {
                    _customScreen = screen;
                    _selectedIndex = 3;
                  });
                },
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (_selectedIndex == index && _selectedIndex != 3) {
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
          final isFirstRouteInCurrentTab = !await _navigatorKeys[_selectedIndex].currentState!.maybePop();
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.face_unlock_outlined),
            label: '컨시어지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: '정보',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
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
