import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_abroad_app/models/product_model.dart';
import 'package:study_abroad_app/screens/product_detail_screen.dart';
import 'package:study_abroad_app/screens/cart_screen.dart';
import 'package:study_abroad_app/services/cart_provider.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: ProductDetailScreen(product: product),
              ),
            ),
          );

          if (result is Product && context.mounted) {
            final pointCardResult = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: ProductDetailScreen(product: result),
                ),
              ),
            );

            if (pointCardResult == true && context.mounted) {
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
            }
          } else if (result == true && context.mounted) {
            bool isClosed = false;
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (dialogContext) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (!isClosed && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                });
                return AlertDialog(
                  contentPadding: const EdgeInsets.all(20),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      const Text('장바구니에 추가되었습니다.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          isClosed = true;
                          Navigator.pop(dialogContext); // close dialog
                          if (context.mounted) {
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
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        child: const Text('장바구니 가기', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ).then((_) => isClosed = true);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image.network(
                product.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.type == 'rent' ? '대여료' : '판매가',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.savings_outlined, color: product.isBankTransferOnly ? Colors.blueAccent : Colors.redAccent, size: 18),
                        const SizedBox(width: 2),
                        Text(
                          currencyFormatter.format(product.priceKrw),
                          style: TextStyle(
                              color: product.isBankTransferOnly ? Colors.blueAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        if (product.type == 'rent' && product.depositKrw > 0)
                          Row(
                            children: [
                              Text(
                                '보증금 ',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                              Icon(Icons.savings_outlined, color: Colors.grey[500], size: 14),
                              const SizedBox(width: 2),
                              Text(
                                currencyFormatter.format(product.depositKrw),
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.totalQuantity == 999 
                          ? '재고: 무제한' 
                          : '재고: ${product.totalQuantity}개',
                      style: TextStyle(
                        fontSize: 12, 
                        color: product.totalQuantity > 0 ? Colors.green[700] : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Stock Status
            if (product.stockStatus == 'out_of_stock')
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '품절',
                    style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
