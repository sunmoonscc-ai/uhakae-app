import 'package:study_abroad_app/models/product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  final DateTime? startDate;
  final DateTime? endDate;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.startDate,
    this.endDate,
  });

  // Calculate the total days for rental items
  int get rentalDays {
    if (product.type != 'rent' || startDate == null || endDate == null) {
      return 1;
    }
    final difference = endDate!.difference(startDate!).inDays;
    return difference > 0 ? difference : 1;
  }

  // Calculate total price in KRW for this item
  double get totalPriceKrw {
    return (product.priceKrw * rentalDays + product.depositKrw) * quantity;
  }
}
