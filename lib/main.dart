import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];
  
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
