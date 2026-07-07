import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_storage_service.dart';
import 'package:intl/intl.dart';

class AdminProductManagementTab extends StatefulWidget {
  final String productType; // 'buy' or 'rent'
  final String? initialProductId;

  const AdminProductManagementTab({super.key, required this.productType, this.initialProductId});

  @override
  State<AdminProductManagementTab> createState() => _AdminProductManagementTabState();
}

class _AdminProductManagementTabState extends State<AdminProductManagementTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  void _showProductDialog({Map<String, dynamic>? existingData, String? docId}) {
    final nameCtrl = TextEditingController(text: existingData?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existingData?['priceKrw']?.toString() ?? existingData?['pricePhp']?.toString() ?? '');
    final depositCtrl = TextEditingController(text: existingData != null ? (existingData['depositKrw']?.toString() ?? '0') : '');
    final descCtrl = TextEditingController(text: existingData?['description'] ?? '');
    final quantityCtrl = TextEditingController(text: existingData != null ? (existingData['totalQuantity']?.toString() ?? '999') : (widget.productType == 'rent' ? '' : '999'));
    String status = existingData?['stockStatus'] ?? 'in_stock';
    bool isBankTransferOnly = existingData?['isBankTransferOnly'] ?? false;
    String? existingImageUrl = existingData?['imageUrl'];
    XFile? selectedImage;
    bool isUploading = false;
    final picker = ImagePicker();

    bool hasChanges() {
      if (selectedImage != null) return true;
      if (nameCtrl.text.trim() != (existingData?['name'] ?? '')) return true;
      
      // Use double comparison for price and deposit to avoid "3000" vs "3000.0" issues
      final origPrice = double.tryParse(existingData?['priceKrw']?.toString() ?? existingData?['pricePhp']?.toString() ?? '0') ?? 0.0;
      final newPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
      if (newPrice != origPrice) return true;
      
      final origDepositStr = existingData != null ? (existingData['depositKrw']?.toString() ?? '0') : '';
      if (depositCtrl.text.trim() != origDepositStr && !(depositCtrl.text.trim().isEmpty && origDepositStr == '')) {
        final origDepVal = double.tryParse(origDepositStr) ?? 0.0;
        final newDepVal = double.tryParse(depositCtrl.text.trim()) ?? 0.0;
        if (newDepVal != origDepVal) return true;
      }

      if (descCtrl.text.trim() != (existingData?['description'] ?? '')) return true;
      
      final origQuantityStr = existingData != null ? (existingData['totalQuantity']?.toString() ?? '999') : (widget.productType == 'rent' ? '' : '999');
      if (quantityCtrl.text.trim() != origQuantityStr) return true;
      
      if (status != (existingData?['stockStatus'] ?? 'in_stock')) return true;
      if (isBankTransferOnly != (existingData?['isBankTransferOnly'] ?? false)) return true;
      
      return false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return PopScope(
              canPop: false,
              onPopInvoked: (didPop) async {
                if (didPop) return;
                if (!hasChanges()) {
                  Navigator.pop(context);
                  return;
                }
                final shouldClose = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('작성 취소'),
                    content: const Text('저장하지 않고 나가시겠습니까? 작성 중인 내용이 모두 사라집니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 작성하기')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('나가기', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (shouldClose == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: AlertDialog(
                title: Text(docId == null 
                  ? (widget.productType == 'buy' ? '판매물품 등록' : '대여물품 등록') 
                  : (widget.productType == 'buy' ? '판매물품 수정' : '대여물품 수정')),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '물품명'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: '가격 (원)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    if (widget.productType == 'rent') ...[
                      TextField(
                        controller: depositCtrl,
                        decoration: const InputDecoration(labelText: '보증금 (원)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: '설명'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityCtrl,
                      decoration: const InputDecoration(
                        labelText: '총 재고 수량',
                        helperText: '999 = 무제한, 0 = 재고 없음',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: '재고 상태'),
                      items: const [
                        DropdownMenuItem(value: 'in_stock', child: Text('판매중 (재고있음)')),
                        DropdownMenuItem(value: 'out_of_stock', child: Text('품절 (재고없음)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('계좌이체로만 가능 (포인트 충전용)'),
                      subtitle: const Text('체크 시 이 물품은 계좌이체로만 결제할 수 있으며, 이체 확인 시 사용자에게 금액만큼 포인트가 충전됩니다.'),
                      value: isBankTransferOnly,
                      onChanged: (val) {
                        setState(() => isBankTransferOnly = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    // 이미지 선택 영역
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setState(() {
                                selectedImage = pickedFile;
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('이미지 선택'),
                        ),
                        const SizedBox(width: 16),
                        if (selectedImage != null)
                          const Text('새 이미지 선택됨', style: TextStyle(color: Colors.green))
                        else if (existingImageUrl != null && existingImageUrl!.isNotEmpty)
                          const Text('기존 이미지 유지', style: TextStyle(color: Colors.grey))
                        else
                          const Text('이미지 없음'),
                      ],
                    ),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: kIsWeb
                            ? Image.network(selectedImage!.path, height: 100, fit: BoxFit.cover)
                            : Image.file(File(selectedImage!.path), height: 100, fit: BoxFit.cover),
                      )
                    else if (existingImageUrl != null && existingImageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Image.network(existingImageUrl!, height: 100, fit: BoxFit.cover),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () async {
                    if (!hasChanges()) {
                      Navigator.pop(context);
                      return;
                    }
                    final shouldClose = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('작성 취소'),
                        content: const Text('저장하지 않고 나가시겠습니까? 작성 중인 내용이 모두 사라집니다.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 작성하기')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text('나가기', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (shouldClose == true && context.mounted) {
                      Navigator.pop(context);
                    }
                  }, 
                  child: const Text('취소')
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    setState(() { isUploading = true; });
                    
                    String finalImageUrl = existingImageUrl ?? '';

                    try {
                      if (selectedImage != null) {
                        final uploadUrl = await FirebaseStorageService.uploadImage(selectedImage!);
                        if (uploadUrl != null) {
                          finalImageUrl = uploadUrl;
                        }
                      }

                      final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      double depositVal = 0.0;
                      if (widget.productType == 'rent') {
                        if (depositCtrl.text.trim().isEmpty) {
                          depositVal = priceVal * 0.1;
                        } else {
                          depositVal = double.tryParse(depositCtrl.text.trim()) ?? 0.0;
                        }
                      }

                      final data = {
                        'type': widget.productType,
                        'name': nameCtrl.text.trim(),
                        'priceKrw': priceVal,
                        'depositKrw': depositVal,
                        'description': descCtrl.text.trim(),
                        'imageUrl': finalImageUrl,
                        'totalQuantity': int.tryParse(quantityCtrl.text.trim()) ?? 999,
                        'stockStatus': status,
                        'isBankTransferOnly': isBankTransferOnly,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (docId == null) {
                        data['createdAt'] = FieldValue.serverTimestamp();
                        await _firestore.collection('shop_items').add(data);
                      } else {
                        await _firestore.collection('shop_items').doc(docId).update(data);
                      }
                    } catch (e) {
                      print('Error saving product: $e');
                    } finally {
                      setState(() { isUploading = false; });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: isUploading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('저장'),
                ),
              ],
            ),
            );
          }
        );
      },
    );
  }

  void _deleteProduct(String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text("'$name' 물품을 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('shop_items').doc(docId).delete();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                print('Error deleting product: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.productType == 'buy' ? '판매 물품 목록' : '대여 물품 목록',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton.icon(
                onPressed: () => _showProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('물품 추가'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('shop_items')
                .where('type', isEqualTo: widget.productType)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('오류: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = (snapshot.data?.docs ?? []).toList();
              
              if (widget.initialProductId != null) {
                docs = docs.where((doc) => doc.id == widget.initialProductId).toList();
              }

              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });
              if (docs.isEmpty) return const Center(child: Text('등록된 물품이 없습니다.'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isOutOfStock = data['stockStatus'] == 'out_of_stock';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                          ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50, color: Colors.grey))
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                      title: Row(
                        children: [
                          Expanded(child: Text(data['name'] ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (isOutOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                              child: const Text('품절', style: TextStyle(color: Colors.red, fontSize: 10)),
                            ),
                        ],
                      ),
                      subtitle: Text.rich(
                        TextSpan(
                          children: widget.productType == 'buy'
                            ? [
                                const WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.savings, size: 14, color: Colors.grey))),
                                TextSpan(text: '${NumberFormat('#,##0').format(data['priceKrw'] ?? data['pricePhp'] ?? 0)}\n${data['description'] ?? ''}'),
                              ]
                            : [
                                const WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.savings, size: 14, color: Colors.grey))),
                                TextSpan(text: '${NumberFormat('#,##0').format(data['priceKrw'] ?? data['pricePhp'] ?? 0)} (보증금: '),
                                const WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.savings, size: 14, color: Colors.grey))),
                                TextSpan(text: '${NumberFormat('#,##0').format(data['depositKrw'] ?? 0)})\n${data['description'] ?? ''}'),
                              ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showProductDialog(existingData: data, docId: doc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(doc.id, data['name'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
