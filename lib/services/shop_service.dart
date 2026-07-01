import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_abroad_app/models/product_model.dart';

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Product>> fetchProducts() async {
    try {
      final snapshot = await _firestore.collection('shop_items').get();
      if (snapshot.docs.isEmpty) {
        // Return some dummy data if the collection is empty for testing
        return _getMockProducts();
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Product.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return _getMockProducts(); // Fallback to mock data if there's an error
    }
  }

  List<Product> _getMockProducts() {
    return [
      // Buy items
      Product(
        id: 'b1',
        type: 'buy',
        name: '두루마리 휴지 30롤',
        priceKrw: 25000.0,
        stockStatus: 'in_stock',
        imageUrl: 'https://via.placeholder.com/150',
        description: '생활 필수품 두루마리 휴지입니다.',
      ),
      Product(
        id: 'b2',
        type: 'buy',
        name: '한국 라면 모음 (5봉)',
        priceKrw: 20000.0,
        stockStatus: 'in_stock',
        imageUrl: 'https://via.placeholder.com/150',
        description: '그리운 한국의 맛!',
      ),
      Product(
        id: 'b3',
        type: 'buy',
        name: '필리핀 어학연수 필수 교재',
        priceKrw: 45000.0,
        stockStatus: 'out_of_stock',
        imageUrl: 'https://via.placeholder.com/150',
        description: '문법 및 회화 마스터 교재',
      ),
      // Rent items
      Product(
        id: 'r1',
        type: 'rent',
        name: '포켓 와이파이 (무제한)',
        priceKrw: 15000.0,
        stockStatus: 'in_stock',
        imageUrl: 'https://via.placeholder.com/150',
        description: '필리핀 전역에서 사용 가능한 무제한 포켓 와이파이 (일 요금)',
      ),
      Product(
        id: 'r2',
        type: 'rent',
        name: '여행용 멀티 어댑터',
        priceKrw: 5000.0,
        stockStatus: 'in_stock',
        imageUrl: 'https://via.placeholder.com/150',
        description: '전 세계 어디서든 사용 가능한 멀티 어댑터 (일 요금)',
      ),
    ];
  }
}
