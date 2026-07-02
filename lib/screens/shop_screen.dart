import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_abroad_app/models/product_model.dart';
import 'package:study_abroad_app/screens/cart_screen.dart';
import 'package:study_abroad_app/services/cart_provider.dart';
import 'package:study_abroad_app/services/shop_service.dart';
import 'package:study_abroad_app/widgets/product_card.dart';
import 'package:study_abroad_app/screens/order_history_screen.dart';
import 'package:study_abroad_app/widgets/point_history_dialog.dart';
import '../services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;
  const ShopScreen({super.key, this.onNavigateHome});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopService _shopService = ShopService();
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _productsFuture = _shopService.fetchProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onNavigateHome,
                child: Image.asset(
                  (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.school, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '컨시어지',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final String name = (user != null && user.displayName != null && user.displayName!.isNotEmpty) 
                      ? user.displayName! 
                      : (user != null ? '회원' : '게스트');
                  return StreamBuilder<QuerySnapshot>(
                    stream: user != null && user.email != null
                        ? FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).snapshots()
                        : null,
                    builder: (context, userSnapshot) {
                      int points = 0;
                      if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                        final data = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        points = (data['points'] as num?)?.toInt() ?? 0;
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: user != null
                            ? FirebaseFirestore.instance
                                .collection('orders')
                                .where('userId', isEqualTo: user.uid)
                                .where('status', whereIn: ['pending', 'approved'])
                                .limit(1)
                                .snapshots()
                            : null,
                        builder: (context, pendingSnapshot) {
                          bool hasPending = pendingSnapshot.hasData && pendingSnapshot.data!.docs.isNotEmpty;

                          Color pointColor = Colors.amber;
                          if (hasPending) {
                            pointColor = Colors.green;
                          } else if (points <= 0) {
                            pointColor = Colors.red;
                          } else if (points <= 10000) {
                            pointColor = Colors.orange;
                          }

                          return InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => const PointHistoryDialog(),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                              child: Row(
                                children: [
                                  Icon(Icons.savings_outlined, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 20),
                                  const SizedBox(width: 2),
                                  Text(
                                    NumberFormat('#,###').format(points),
                                    style: TextStyle(
                                      color: pointColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          // 1. 장바구니 (Icon + Text + Badge)
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.9,
                    child: const CartScreen(),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.shopping_bag_outlined, color: Colors.black),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Consumer<CartProvider>(
                          builder: (context, cart, child) {
                            if (cart.itemCount == 0) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 2),
                  const Text('장바구니', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.9,
                    child: const OrderHistoryScreen(),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.receipt_long, color: Colors.black),
                  ),
                  const SizedBox(width: 2),
                  const Text('주문내역', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          // 3. 즐겨찾기 (별)
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: PreferencesService.favoritesNotifier,
            builder: (context, favorites, _) {
              final id = 'menu_쇼핑몰';
              final isFav = PreferencesService.isFavorite(id);
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : (isDarkMode ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  if (isFav) {
                    PreferencesService.removeFavorite(id);
                  } else {
                    PreferencesService.addFavorite({
                      'id': id,
                      'type': 'menu',
                      'title': '쇼핑몰/대여',
                      'iconCodePoint': Icons.shopping_cart.codePoint,
                      'iconFontFamily': Icons.shopping_cart.fontFamily,
                      'colorValue': 0xFFFFF9C4,
                      'mainTab': '컨시어지',
                      'tabIndex': 1,
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              '필수 아이템을 안전하고 편리하게 이용하세요. 필요한 물품 구매를 요청하거나 장비를 대여할 수 있습니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              tabs: const [
                Tab(text: '구매 대행'),
                Tab(text: '대여'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('에러 발생: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('물품이 없습니다.'));
                }

                final allProducts = snapshot.data!;
                final buyProducts = allProducts.where((p) => p.type == 'buy').toList();
                final rentProducts = allProducts.where((p) => p.type == 'rent').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductList(buyProducts),
                    _buildProductList(rentProducts),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (products.isEmpty) {
      return const Center(child: Text('등록된 물품이 없습니다.'));
    }
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index]);
      },
    );
  }
}
