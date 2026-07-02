import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:study_abroad_app/models/product_model.dart';
import 'package:study_abroad_app/services/cart_provider.dart';
import 'package:study_abroad_app/screens/cart_screen.dart';

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
      return (widget.product.priceKrw * _rentalDays + widget.product.depositKrw) * _quantity;
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
                      Text(
                        '₩${currencyFormatter.format(widget.product.priceKrw)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
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
                      child: Text(
                        '보증금: ₩${currencyFormatter.format(widget.product.depositKrw)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Quantity
                  Row(
                    children: [
                      const Text('수량', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _quantity++),
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
                      const Text('총 물품 금액', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₩${currencyFormatter.format(_totalPriceKrw)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
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
                : () {
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
                    
                    Provider.of<CartProvider>(context, listen: false).addItem(
                      widget.product,
                      quantity: _quantity,
                      startDate: _startDate,
                      endDate: _endDate,
                    );
                    Navigator.pop(context, true);
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
