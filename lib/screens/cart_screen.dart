import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:study_abroad_app/services/cart_provider.dart';
import 'package:study_abroad_app/services/order_service.dart';
import 'package:study_abroad_app/utils/ui_utils.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final OrderService _orderService = OrderService();
  bool _isSubmitting = false;

  void _submitOrder(CartProvider cart) async {
    if (cart.items.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    final orderData = {
      'timestamp': DateTime.now().toIso8601String(),
      'totalKrw': cart.totalPriceKrw,
      'items': cart.items.map((item) => {
        'productId': item.product.id,
        'name': item.product.name,
        'type': item.product.type,
        'quantity': item.quantity,
        'startDate': item.startDate?.toIso8601String(),
        'endDate': item.endDate?.toIso8601String(),
        'rentalDays': item.rentalDays,
        'totalPriceKrw': item.totalPriceKrw,
        'isBankTransferOnly': item.product.isBankTransferOnly,
      }).toList(),
    };

    final success = await _orderService.submitOrder(orderData);

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (success) {
      cart.clear();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('주문 완료'),
          content: const Text('주문/대여 신청이 성공적으로 접수되었습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (context.mounted) {
                  Navigator.pop(context); // Go back from cart
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else {
      if (context.mounted) {
        UiUtils.showPopup(context, '주문 전송에 실패했습니다. 다시 시도해주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('장바구니가 비어 있습니다.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.product.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.image)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (item.product.type == 'rent' && item.startDate != null && item.endDate != null)
                                      Text(
                                        '${DateFormat('MM.dd').format(item.startDate!)} ~ ${DateFormat('MM.dd').format(item.endDate!)} (${item.rentalDays}일)',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.savings_outlined, color: Colors.blueAccent, size: 16),
                                        const SizedBox(width: 2),
                                        Text(
                                          currencyFormatter.format(item.totalPriceKrw),
                                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Controls
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 20),
                                    onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 20),
                                    onPressed: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('총 결제금액', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.savings_outlined, color: Colors.redAccent, size: 24),
                                  const SizedBox(width: 4),
                                  Text(
                                    currencyFormatter.format(cart.totalPriceKrw),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submitOrder(cart),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('결제하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
