import 'package:flutter/foundation.dart';
import 'package:study_abroad_app/models/cart_item_model.dart';
import 'package:study_abroad_app/models/product_model.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  
  List<CartItem> get items => [..._items];

  int get itemCount => _items.length;

  double get totalPriceKrw {
    return _items.fold(0.0, (sum, item) => sum + item.totalPriceKrw);
  }

  void addItem(Product product, {int quantity = 1, DateTime? startDate, DateTime? endDate}) {
    // Check if item already exists (for 'buy' items, we just increase quantity)
    // For 'rent' items, we might add it as a new line if dates differ, but for simplicity we'll just check product id
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0 && product.type == 'buy') {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(
        product: product,
        quantity: quantity,
        startDate: startDate,
        endDate: endDate,
      ));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productId);
      return;
    }
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void updateQuantityAt(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) return;
    if (newQuantity <= 0) {
      removeItemAt(index);
      return;
    }
    _items[index].quantity = newQuantity;
    notifyListeners();
  }
}
