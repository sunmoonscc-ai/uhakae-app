import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:study_abroad_app/models/product_model.dart';
import 'package:study_abroad_app/services/cart_provider.dart';
import 'package:study_abroad_app/screens/cart_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_abroad_app/utils/ui_utils.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  int _quantity = 1;

  int get _rentalDays {
    if (_startDate == null || _endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays;
    return diff > 0 ? diff : 1;
  }

  double get _totalPriceKrw {
    if (widget.product.type == 'rent') {
      return (widget.product.priceKrw + widget.product.depositKrw) * _quantity;
    }
    return widget.product.priceKrw * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(widget.product.imageUrl),
                  fit: BoxFit.contain,
                  onError: (error, stackTrace) => const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.savings, color: Colors.blueAccent, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            '${currencyFormatter.format(widget.product.priceKrw)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.type == 'rent' ? '대여료' : '',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (widget.product.type == 'rent' && widget.product.depositKrw > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('보증금: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const Icon(Icons.savings, color: Colors.grey, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${currencyFormatter.format(widget.product.depositKrw)}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Quantity
                  Row(
                    children: [
                      const Text('수량', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (widget.product.totalQuantity == 999) ...[
                        const SizedBox(width: 8),
                        Text('(재고: 무제한)', style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.bold)),
                      ] else ...[
                        const SizedBox(width: 8),
                        Text('(재고: ${widget.product.totalQuantity}개)', 
                          style: TextStyle(
                            fontSize: 14, 
                            color: widget.product.totalQuantity > 0 ? Colors.green[700] : Colors.red, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      InkWell(
                        onTap: () {
                          final ctrl = TextEditingController(text: '$_quantity');
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('수량 입력', style: TextStyle(fontSize: 16)),
                              content: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: '수량을 입력하세요'),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                                TextButton(
                                  onPressed: () {
                                    final val = int.tryParse(ctrl.text.trim());
                                    if (val != null && val > 0) {
                                      setState(() {
                                        if (widget.product.totalQuantity > 0 && val > widget.product.totalQuantity) {
                                          _quantity = widget.product.totalQuantity;
                                        } else {
                                          _quantity = val;
                                        }
                                      });
                                    }
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: (widget.product.totalQuantity == 0 || _quantity < widget.product.totalQuantity)
                            ? () => setState(() => _quantity++)
                            : null,
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Rental Calendar
                  if (widget.product.type == 'rent') ...[
                    const Text('대여 기간 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _startDate ?? DateTime.now(),
                      selectedDayPredicate: (day) => isSameDay(_startDate, day) || isSameDay(_endDate, day),
                      rangeStartDay: _startDate,
                      rangeEndDay: _endDate,
                      rangeSelectionMode: RangeSelectionMode.enforced,
                      onRangeSelected: (start, end, focusedDay) {
                        setState(() {
                          _startDate = start;
                          _endDate = end;
                        });
                      },
                      calendarStyle: const CalendarStyle(
                        rangeHighlightColor: Colors.blueAccent,
                        rangeStartDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        rangeEndDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      ),
                    ),
                    if (_startDate != null && _endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          '선택된 기간: 총 $_rentalDays 일',
                          style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const Divider(height: 32),
                  ],

                  // Total Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('총 필요 포인트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.savings, color: Colors.redAccent, size: 22),
                              const SizedBox(width: 4),
                              Text(
                                '${currencyFormatter.format(_totalPriceKrw)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: widget.product.stockStatus == 'out_of_stock'
                ? null
                : () async {
                    if (widget.product.type == 'rent' && (_startDate == null || _endDate == null)) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('대여 기간을 선택해주세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    if (!widget.product.isBankTransferOnly) {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        final cartProvider = Provider.of<CartProvider>(context, listen: false);
                        int currentCartQty = 0;
                        for (var item in cartProvider.items) {
                          if (item.product.id == widget.product.id) {
                            currentCartQty += item.quantity;
                          }
                        }
                        
                        int actualTotalQuantity = widget.product.totalQuantity;
                        if (widget.product.totalQuantity > 0) {
                          int inProgress = 0;
                          final activeOrders = await FirebaseFirestore.instance
                              .collection('orders')
                              .where('status', whereIn: ['pending', 'processing', 'shipping'])
                              .get();
                          for (var doc in activeOrders.docs) {
                            final items = doc.data()['items'] as List<dynamic>? ?? [];
                            for (var item in items) {
                              if (item['productId'] == widget.product.id) {
                                inProgress += (item['quantity'] as num?)?.toInt() ?? 0;
                              }
                            }
                          }
                          actualTotalQuantity = widget.product.totalQuantity - inProgress;
                          if (actualTotalQuantity < 0) actualTotalQuantity = 0;
                        }

                        if (widget.product.totalQuantity > 0 && (_quantity + currentCartQty) > actualTotalQuantity) {
                          if (context.mounted) {
                            final maxAllowed = actualTotalQuantity - currentCartQty;
                            
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    maxAllowed > 0 
                                      ? '재고수량($actualTotalQuantity개)보다 많은 수량을 요청하셨습니다.\n(현재 장바구니: $currentCartQty개)\n\n지금 추가할 수 있는 최대 수량인 $maxAllowed개로 조정됩니다.'
                                      : '더 이상 장바구니에 담을 수 없습니다.\n현재 신청 가능한 재고수량($actualTotalQuantity개)을 모두 장바구니에 담으셨습니다.', 
                                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
                                ],
                              ),
                            );
                            
                            if (maxAllowed > 0) {
                              setState(() {
                                _quantity = maxAllowed;
                              });
                            }
                          }
                          return;
                        }

                        final cart = Provider.of<CartProvider>(context, listen: false);
                        final currentCartTotal = cart.totalPriceKrw;
                        final requiredPointsForThis = widget.product.isBankTransferOnly ? 0.0 : _totalPriceKrw;
                        
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                        final currentPoints = userDoc.exists ? ((userDoc.data()?['points'] as num?)?.toDouble() ?? 0.0) : 0.0;
                        final lockedPoints = userDoc.exists ? ((userDoc.data()?['lockedPoints'] as num?)?.toDouble() ?? 0.0) : 0.0;
                        final availablePoints = currentPoints - lockedPoints;
                        
                        if (availablePoints < (currentCartTotal + requiredPointsForThis)) {
                          if (context.mounted) {
                            final currencyFormatter = NumberFormat('#,##0', 'en_US');
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('보유 포인트가 부족합니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      if (currentCartTotal > 0)
                                        Text('장바구니 총액: ${currencyFormatter.format(currentCartTotal)}', style: const TextStyle(fontSize: 14)),
                                      Text('현재 추가 품목: ${currencyFormatter.format(requiredPointsForThis)}', style: const TextStyle(fontSize: 14)),
                                      const Divider(height: 16),
                                      Text('총 필요 포인트: ${currencyFormatter.format(currentCartTotal + requiredPointsForThis)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      Text('현재 보유 포인트: ${currencyFormatter.format(availablePoints)}', style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      const Text('포인트를 충전하시겠습니까?', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('아니요', style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      final snapshot = await FirebaseFirestore.instance.collection('shop_items')
                                        .where('name', isEqualTo: '컨시어지 포인트카드')
                                        .limit(1)
                                        .get();
                                      
                                      if (snapshot.docs.isNotEmpty) {
                                        final doc = snapshot.docs.first;
                                        final data = doc.data();
                                        data['id'] = doc.id;
                                        final product = Product.fromJson(data);
                                        if (context.mounted) {
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
                                        }
                                      } else {
                                        if (context.mounted) {
                                          UiUtils.showPopup(context, '포인트 카드를 찾을 수 없습니다.');
                                        }
                                      }
                                    },
                                    child: const Text('네', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }
                      }
                    }
                    
                    if (context.mounted) {
                      Provider.of<CartProvider>(context, listen: false).addItem(
                        widget.product,
                        quantity: _quantity,
                        startDate: _startDate,
                        endDate: _endDate,
                      );
                      Navigator.pop(context, true);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              widget.product.stockStatus == 'out_of_stock' ? '품절' : '장바구니 담기',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
