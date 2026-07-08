import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_abroad_app/models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Submit a new order
  Future<String?> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '로그인이 필요합니다.';

      orderData['userId'] = user.uid;
      
      String? userDocId = user.uid;
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        orderData['userName'] = userData['name'];
        orderData['userSchool'] = userData['school'];
        orderData['userEmail'] = userData['email'];
      }

      orderData['status'] = 'pending';
      orderData['createdAt'] = FieldValue.serverTimestamp();

      final result = await _firestore.runTransaction((transaction) async {
        double pointsToDeduct = 0;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        for (var item in items) {
          final itemPrice = (item['totalPriceKrw'] ?? 0).toDouble();
          if (item['isBankTransferOnly'] != true) {
            pointsToDeduct += itemPrice;
          }
        }

        // --- READ PHASE ---
        DocumentSnapshot<Map<String, dynamic>>? userDoc;
        final userRef = userDocId != null ? _firestore.collection('users').doc(userDocId) : null;
        if (userRef != null) {
          userDoc = await transaction.get(userRef);
        }

        final productDocs = <String, DocumentSnapshot>{};
        for (var item in items) {
          final productId = item['productId'];
          if (productId != null && !productDocs.containsKey(productId)) {
            final productRef = _firestore.collection('shop_items').doc(productId);
            final productSnap = await transaction.get(productRef);
            if (productSnap.exists) {
              productDocs[productId] = productSnap;
            }
          }
        }

        // --- VALIDATION PHASE ---
        if (userDoc != null && userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final currentPoints = (userData['points'] as num?)?.toDouble() ?? 0.0;
          final lockedPoints = (userData['lockedPoints'] as num?)?.toDouble() ?? 0.0;
          final availablePoints = currentPoints - lockedPoints;
          
          if (availablePoints < pointsToDeduct) {
            return 'NOT_ENOUGH_POINTS';
          }
        }

        for (var item in items) {
          final productId = item['productId'];
          final qty = item['quantity'] ?? 1;
          if (productId != null && productDocs.containsKey(productId)) {
            final productSnap = productDocs[productId]!;
            final currentQty = (productSnap.data() as Map<String, dynamic>)['totalQuantity'] ?? 999;
            if (currentQty != 999 && currentQty < qty) {
              return 'NOT_ENOUGH_STOCK:${item['name']}';
            }
          }
        }

        // --- WRITE PHASE ---
        if (userDoc != null && userDoc.exists && pointsToDeduct > 0) {
          // 실제 포인트(points)는 주문이 확정(preparing/approved)될 때 차감합니다.
          // 대기 중인 동안에는 lockedPoints만 증가시켜 중복 사용을 방지합니다.
          transaction.update(userRef!, {
            'lockedPoints': FieldValue.increment(pointsToDeduct),
          });
        }

        for (var item in items) {
          final productId = item['productId'];
          final qty = item['quantity'] ?? 1;
          if (productId != null && productDocs.containsKey(productId)) {
            final productSnap = productDocs[productId]!;
            final currentQty = (productSnap.data() as Map<String, dynamic>)['totalQuantity'] ?? 999;
            if (currentQty != 999) {
              final productRef = _firestore.collection('shop_items').doc(productId);
              transaction.update(productRef, {
                'totalQuantity': FieldValue.increment(-qty),
              });
            }
          }
        }

        final newOrderRef = _firestore.collection('orders').doc();
        transaction.set(newOrderRef, orderData);
        
        return null; // null means success
      });

      if (result == 'NOT_ENOUGH_POINTS') {
        return '보유하신 포인트가 부족합니다.';
      } else if (result != null && result is String && result.startsWith('NOT_ENOUGH_STOCK:')) {
        final productName = result.split(':')[1];
        return '[$productName] 상품의 재고가 부족합니다.';
      }
      
      return null;
    } catch (e) {
      print('Error submitting order: $e');
      return '주문 전송에 실패했습니다. 에러: $e';
    }
  }

  // 2. Stream user's orders
  Stream<List<OrderModel>> getUserOrdersStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // 3. User updates order status (e.g. completed, not_received, canceled)
  Future<bool> updateOrderStatusByUser(String orderId, String newStatus) async {
    try {
      if (newStatus == 'canceled') {
        return await _firestore.runTransaction((transaction) async {
          final orderRef = _firestore.collection('orders').doc(orderId);
          final freshSnap = await transaction.get(orderRef);
          if (!freshSnap.exists) return false;
          
          final orderData = freshSnap.data() as Map<String, dynamic>;
          final currentStatus = orderData['status'];
          
          if (currentStatus != 'pending' && currentStatus != 'approved') return false;

          transaction.update(orderRef, {'status': newStatus});

          double refundKrw = 0;
          final items = List<dynamic>.from(orderData['items'] ?? []);
          for (var item in items) {
            if (item['isBankTransferOnly'] != true) {
              refundKrw += (item['totalPriceKrw'] ?? 0).toDouble();
            }
            // Restore inventory
            final productId = item['productId'];
            final qty = item['quantity'] ?? 1;
            if (productId != null) {
              final productRef = _firestore.collection('shop_items').doc(productId);
              final productSnap = await transaction.get(productRef);
              if (productSnap.exists) {
                final currentQty = (productSnap.data() as Map<String, dynamic>)['totalQuantity'] ?? 999;
                if (currentQty != 999) {
                  transaction.update(productRef, {
                    'totalQuantity': FieldValue.increment(qty),
                  });
                }
              }
            }
          }
          
          final userEmail = orderData['userEmail'];
          final isPointDeducted = orderData['isPointDeducted'] == true;

          if (refundKrw > 0 && userEmail != null) {
            final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
            if (userSnap.docs.isNotEmpty) {
              final userDocId = userSnap.docs.first.id;
              final userRef = _firestore.collection('users').doc(userDocId);
              
              if (isPointDeducted) {
                transaction.update(userRef, {
                  'points': FieldValue.increment(refundKrw),
                });
                
                final historyRef = _firestore.collection('point_history').doc();
                transaction.set(historyRef, {
                  'userId': userDocId,
                  'amount': refundKrw,
                  'type': 'order_cancel_refund',
                  'description': '주문 취소 포인트 환불',
                  'orderId': orderId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                transaction.update(userRef, {
                  'lockedPoints': FieldValue.increment(-refundKrw),
                });
              }
            }
          }
          return true;
        });
      } else {
        await _firestore.collection('orders').doc(orderId).update({'status': newStatus});
        return true;
      }
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // ---- ADMIN FUNCTIONS ---- //

  // 4. Stream all orders (Admin)
  Stream<List<OrderModel>> getAllOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // 5. Admin updates order status (e.g. approved, rejected, shipping, delivered)
  Future<bool> updateOrderStatusByAdmin(String orderId, String newStatus, {String? rejectReason}) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      
      return await _firestore.runTransaction((transaction) async {
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;
        
        final orderData = freshSnap.data() as Map<String, dynamic>;
        final currentStatus = orderData['status'];
        
        final isPointDeducted = orderData['isPointDeducted'] == true;

        // Prevent double processing
        if (currentStatus == newStatus) return true;

        final items = List<dynamic>.from(orderData['items'] ?? []);
        bool itemsChanged = false;
        for (int i = 0; i < items.length; i++) {
          final item = Map<String, dynamic>.from(items[i]);
          if (item['status'] == null || item['status'] == 'pending') {
             item['status'] = newStatus;
             if (newStatus == 'rejected' && rejectReason != null) {
               item['rejectReason'] = rejectReason;
             }
             items[i] = item;
             itemsChanged = true;
          }
        }

        final updates = <String, dynamic>{'status': newStatus};
        if (rejectReason != null) {
          updates['rejectReason'] = rejectReason;
        }
        if (itemsChanged) {
          updates['items'] = items;
        }

        if (['delivered', 'receipt_confirmed', 'completed', 'not_received'].contains(newStatus) && !isPointDeducted) {
           double paymentKrw = 0;
           for (var item in items) {
             if (item['isBankTransferOnly'] != true) {
               paymentKrw += (item['totalPriceKrw'] ?? 0).toDouble();
             }
           }
           if (paymentKrw > 0) {
             final userEmail = orderData['userEmail'];
             if (userEmail != null) {
               final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
               if (userSnap.docs.isNotEmpty) {
                 final userDocId = userSnap.docs.first.id;
                 final userRef = _firestore.collection('users').doc(userDocId);
                 transaction.update(userRef, {
                   'points': FieldValue.increment(-paymentKrw),
                   'lockedPoints': FieldValue.increment(-paymentKrw),
                 });
                 final historyRef = _firestore.collection('point_history').doc();
                 transaction.set(historyRef, {
                   'userId': userDocId,
                   'amount': -paymentKrw,
                   'type': 'order_payment',
                   'description': '물품 구매/대여 결제 완료',
                   'orderId': orderId,
                   'createdAt': FieldValue.serverTimestamp(),
                 });
                 updates['isPointDeducted'] = true;
               }
             }
           }
        }

        transaction.update(orderRef, updates);

        if (newStatus == 'rejected' && currentStatus != 'rejected' && currentStatus != 'canceled') {
          // Calculate how much was paid with points
          double refundKrw = 0;
          for (var item in items) {
            if (item['isBankTransferOnly'] != true) {
              refundKrw += (item['totalPriceKrw'] ?? 0).toDouble();
            }
            // Restore inventory
            final productId = item['productId'];
            final qty = item['quantity'] ?? 1;
            if (productId != null) {
              final productRef = _firestore.collection('shop_items').doc(productId);
              final productSnap = await transaction.get(productRef);
              if (productSnap.exists) {
                final currentQty = (productSnap.data() as Map<String, dynamic>)['totalQuantity'] ?? 999;
                if (currentQty != 999) {
                  transaction.update(productRef, {
                    'totalQuantity': FieldValue.increment(qty),
                  });
                }
              }
            }
          }
          
          final userEmail = orderData['userEmail'];
          
          if (refundKrw > 0 && userEmail != null) {
            final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
            if (userSnap.docs.isNotEmpty) {
              final userDocId = userSnap.docs.first.id;
              final userRef = _firestore.collection('users').doc(userDocId);
              
              if (isPointDeducted) {
                transaction.update(userRef, {
                  'points': FieldValue.increment(refundKrw),
                });
                
                final historyRef = _firestore.collection('point_history').doc();
                transaction.set(historyRef, {
                  'userId': userDocId,
                  'amount': refundKrw,
                  'type': 'order_refund',
                  'description': '전체 거절로 인한 포인트 환불',
                  'orderId': orderId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                transaction.update(userRef, {
                  'lockedPoints': FieldValue.increment(-refundKrw),
                });
              }
            }
          }
        }
        return true;
      });
    } catch (e) {
      print('Error admin updating order status: $e');
      return false;
    }
  }

  // 5.0 User notifies bank transfer completion
  Future<bool> notifyBankTransfer(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'isTransferNotified': true,
      });
      return true;
    } catch (e) {
      print('Error notifying bank transfer: $e');
      return false;
    }
  }

  // 5.0.1 Admin requests bank transfer again (no record found)
  Future<bool> requestTransferAgain(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'isTransferNotified': false,
        'transferRejectReason': '이체 내역을 찾을 수 없습니다. 다시 확인 후 송금 완료를 눌러주세요.', // Optional field to show to user
      });
      return true;
    } catch (e) {
      print('Error requesting bank transfer again: $e');
      return false;
    }
  }

  // 5.1 Admin updates individual item status
  Future<bool> updateOrderItemStatusByAdmin(String orderId, int itemIndex, String newStatus, {String? rejectReason}) async {
    try {
      final orderSnap = await _firestore.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) return false;
      
      final initialData = orderSnap.data() as Map<String, dynamic>;
      final userEmail = initialData['userEmail'];
      String? userDocId;
      if (userEmail != null) {
        final userQuery = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          userDocId = userQuery.docs.first.id;
        }
      }

      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;

        final orderData = freshSnap.data() as Map<String, dynamic>;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        if (itemIndex < 0 || itemIndex >= items.length) return false;

        final item = Map<String, dynamic>.from(items[itemIndex]);
        final currentStatus = item['status'] ?? 'pending';
        if (currentStatus != 'pending') return false; // already processed

        item['status'] = newStatus;
        if (newStatus == 'rejected' && rejectReason != null) {
          item['rejectReason'] = rejectReason;
        }
        items[itemIndex] = item;

        double newTotalKrw = (orderData['totalKrw'] ?? 0).toDouble();

        final isPointDeducted = orderData['isPointDeducted'] == true;

        if (newStatus == 'rejected') {
          final priceKrw = (item['totalPriceKrw'] ?? 0).toDouble();
          newTotalKrw -= priceKrw;

          if (item['isBankTransferOnly'] != true && priceKrw > 0 && userDocId != null) {
            final userRef = _firestore.collection('users').doc(userDocId);
            
            if (isPointDeducted) {
              transaction.update(userRef, {
                'points': FieldValue.increment(priceKrw),
              });
              
              final historyRef = _firestore.collection('point_history').doc();
              transaction.set(historyRef, {
                'userId': userDocId,
                'amount': priceKrw,
                'type': 'order_refund',
                'description': '부분 거절로 인한 포인트 환불',
                'orderId': orderId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } else {
              transaction.update(userRef, {
                'lockedPoints': FieldValue.increment(-priceKrw),
              });
            }
          }
        }

        bool allProcessed = true;
        bool anyApproved = false;
        for (var i in items) {
          final s = i['status'] ?? 'pending';
          if (s == 'pending') allProcessed = false;
          if (s == 'approved') anyApproved = true;
        }

        String orderStatus = orderData['status'] ?? 'pending';
        if (allProcessed) {
          orderStatus = anyApproved ? 'approved' : 'rejected';
        }

        transaction.update(orderRef, {
          'items': items,
          'totalKrw': newTotalKrw,
          'status': orderStatus,
        });

        return true;
      });
    } catch (e) {
      print('Error admin updating item status: $e');
      return false;
    }
  }



  // 7. Admin confirms bank transfer and adds points for recharge items
  Future<bool> confirmBankTransfer(String orderId, String userDocId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;

        final orderData = freshSnap.data() as Map<String, dynamic>;
        final items = List<dynamic>.from(orderData['items'] ?? []);

        double pointsToAdd = 0;
        bool itemsChanged = false;

        for (int i = 0; i < items.length; i++) {
          final item = Map<String, dynamic>.from(items[i]);
          if (item['status'] == null || item['status'] == 'approved' || item['status'] == 'pending') {
             item['status'] = 'completed';
             final isPointCard = item['name'].toString().contains('포인트카드') || item['name'].toString().contains('포인트 충전');
             if (item['isBankTransferOnly'] == true || isPointCard) {
               pointsToAdd += (item['totalPriceKrw'] ?? 0).toDouble();
             }
             items[i] = item;
             itemsChanged = true;
          }
        }

        final updates = <String, dynamic>{'status': 'completed'};
        if (itemsChanged) {
          updates['items'] = items;
        }

        transaction.update(orderRef, updates);

        if (pointsToAdd > 0) {
          final userDocRef = _firestore.collection('users').doc(userDocId);
          transaction.update(userDocRef, {
            'points': FieldValue.increment(pointsToAdd)
          });

          final historyRef = _firestore.collection('point_history').doc();
          transaction.set(historyRef, {
            'userId': userDocId,
            'amount': pointsToAdd,
            'type': 'point_recharge_by_admin',
            'description': '계좌이체 확인 (포인트 충전 물품)',
            'orderId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        return true;
      });
    } catch (e) {
      print('Error confirming bank transfer: $e');
      return false;
    }
  }
  // 10. Process Return (Admin)
  Future<bool> processReturn(String orderId, bool isDamaged) async {
    try {
      final orderSnap = await _firestore.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) return false;
      
      final orderData = orderSnap.data() as Map<String, dynamic>;
      final userEmail = orderData['userEmail'];
      String? userDocId;

      if (userEmail != null) {
        final userQuery = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          userDocId = userQuery.docs.first.id;
        }
      }

      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;

        final freshData = freshSnap.data() as Map<String, dynamic>;
        
        final newStatus = isDamaged ? 'returned_damaged' : 'returned';
        transaction.update(orderRef, {'status': newStatus});

        if (!isDamaged && userDocId != null) {
          // Calculate refund (sum of depositKrw * quantity)
          double depositRefund = 0;
          final items = freshData['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            if (item['type'] == 'rent') {
              final deposit = (item['depositKrw'] ?? 0).toDouble();
              final quantity = (item['quantity'] ?? 1) as int;
              depositRefund += deposit * quantity;
            }
          }

          if (depositRefund > 0) {
            final userRef = _firestore.collection('users').doc(userDocId);
            transaction.update(userRef, {
              'points': FieldValue.increment(depositRefund),
            });

            final historyRef = _firestore.collection('point_history').doc();
            transaction.set(historyRef, {
              'userId': userDocId,
              'amount': depositRefund,
              'type': 'deposit_refund',
              'description': '물품 정상 반납에 따른 보증금 환불',
              'orderId': orderId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        return true;
      });
    } catch (e) {
      print('Error processing return: $e');
      return false;
    }
  }

  // 6. Request return for a specific rental item
  Future<bool> requestReturnForItem(String orderId, int itemIndex, int returnQty) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;
        
        final orderData = freshSnap.data() as Map<String, dynamic>;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        bool updated = false;
        
        if (itemIndex >= 0 && itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          if (item['type'] == 'rent' && item['returnStatus'] != 'returned') {
            final currentQty = (item['quantity'] ?? 1) as int;
            
            if (returnQty >= currentQty) {
              item['returnStatus'] = 'return_requested';
              items[itemIndex] = item;
            } else {
              item['quantity'] = currentQty - returnQty;
              final unitPrice = ((item['totalPriceKrw'] ?? 0) as num).toDouble() / currentQty;
              item['totalPriceKrw'] = unitPrice * (currentQty - returnQty);
              items[itemIndex] = item;
              
              final returnItem = Map<String, dynamic>.from(item);
              returnItem['quantity'] = returnQty;
              returnItem['totalPriceKrw'] = unitPrice * returnQty;
              returnItem['returnStatus'] = 'return_requested';
              items.insert(itemIndex + 1, returnItem);
            }
            updated = true;
          }
        }
        
        if (updated) {
          transaction.update(orderRef, {
            'items': items,
            'hasUnreadReturnRequest': true,
          });
        }
        return updated;
      });
    } catch (e) {
      print('Error requesting return: $e');
      return false;
    }
  }

  // 6.5. Cancel return request for a specific rental item
  Future<bool> cancelReturnRequest(String orderId, int itemIndex) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;
        
        final orderData = freshSnap.data() as Map<String, dynamic>;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        bool updated = false;
        
        if (itemIndex >= 0 && itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          if (item['type'] == 'rent' && item['returnStatus'] == 'return_requested') {
            item.remove('returnStatus');
            items[itemIndex] = item;
            updated = true;
          }
        }
        
        if (updated) {
          bool stillHasUnread = items.any((item) => item['returnStatus'] == 'return_requested');
          transaction.update(orderRef, {
            'items': items,
            if (!stillHasUnread) 'hasUnreadReturnRequest': FieldValue.delete(),
          });
        }
        return updated;
      });
    } catch (e) {
      print('Error canceling return request: $e');
      return false;
    }
  }

  // 7. Update return status for a rental item (User & Admin)
  Future<bool> updateItemReturnStatus(String orderId, int itemIndex, String newReturnStatus) async {
    try {
      final orderSnapForEmail = await _firestore.collection('orders').doc(orderId).get();
      if (!orderSnapForEmail.exists) return false;
      
      final orderDataOutside = orderSnapForEmail.data() as Map<String, dynamic>;
      final userDocId = orderDataOutside['userId'];

      return await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final freshSnap = await transaction.get(orderRef);
        if (!freshSnap.exists) return false;
        
        final orderData = freshSnap.data() as Map<String, dynamic>;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        bool updated = false;
        int qtyToRestore = 0;
        double depositRefund = 0;
        String? productId;
        
        if (itemIndex >= 0 && itemIndex < items.length) {
          final item = Map<String, dynamic>.from(items[itemIndex]);
          if (item['type'] == 'rent') {
            productId = item['productId'];
            item['returnStatus'] = newReturnStatus;
            if (newReturnStatus == 'returned' || newReturnStatus == 'returned_damaged') {
              item['returnCompletedAt'] = DateTime.now().toIso8601String();
            }
            items[itemIndex] = item;
            updated = true;
            if (newReturnStatus == 'returned' || newReturnStatus == 'returned_damaged') {
              qtyToRestore = item['quantity'] ?? 1;
              if (newReturnStatus == 'returned') {
                final deposit = (item['depositKrw'] ?? 0).toDouble();
                depositRefund += deposit * qtyToRestore;
              }
            }
          }
        }
        
        if (!updated) return false;
        
        // All Reads must happen before Writes
        DocumentSnapshot? productSnap;
        DocumentReference? productRef;
        if (productId != null) {
          productRef = _firestore.collection('shop_items').doc(productId);
          if ((newReturnStatus == 'returned' || newReturnStatus == 'returned_damaged') && qtyToRestore > 0) {
            productSnap = await transaction.get(productRef);
          }
        }
        
        // Now perform Writes
        bool stillHasUnread = items.any((item) => item['returnStatus'] == 'return_requested');
        
        transaction.update(orderRef, {
          'items': items,
          if (!stillHasUnread) 'hasUnreadReturnRequest': FieldValue.delete(),
        });
        
        if (productSnap != null && productSnap.exists) {
          final currentQty = (productSnap.data() as Map<String, dynamic>)['totalQuantity'] ?? 999;
          if (currentQty != 999) {
            transaction.update(productRef!, {
              'totalQuantity': FieldValue.increment(qtyToRestore),
            });
          }
        }
        
        if (depositRefund > 0 && userDocId != null) {
          final userRef = _firestore.collection('users').doc(userDocId);
          transaction.update(userRef, {
            'points': FieldValue.increment(depositRefund),
          });

          final historyRef = _firestore.collection('point_history').doc();
          transaction.set(historyRef, {
            'userId': userDocId,
            'amount': depositRefund,
            'type': 'deposit_refund',
            'description': '물품 정상 반납 보증금 환불',
            'orderId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        return true;
      });
    } catch (e) {
      print('Error updating item return status: $e');
      return false;
    }
  }
}
