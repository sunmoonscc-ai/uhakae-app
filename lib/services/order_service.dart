import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_abroad_app/models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Submit a new order
  Future<bool> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      orderData['userId'] = user.uid;
      
      String? userDocId;
      if (user.email != null) {
        final userSnap = await _firestore.collection('users').where('email', isEqualTo: user.email).limit(1).get();
        if (userSnap.docs.isNotEmpty) {
          userDocId = userSnap.docs.first.id;
          final userData = userSnap.docs.first.data();
          orderData['userName'] = userData['name'];
          orderData['userSchool'] = userData['school'];
          orderData['userEmail'] = userData['email'];
        }
      }

      orderData['status'] = 'pending';
      orderData['createdAt'] = FieldValue.serverTimestamp();

      return await _firestore.runTransaction((transaction) async {
        double pointsToDeduct = 0;
        final items = List<dynamic>.from(orderData['items'] ?? []);
        for (var item in items) {
          if (item['isBankTransferOnly'] != true) {
            pointsToDeduct += (item['totalPriceKrw'] ?? 0).toDouble();
          }
        }

        if (pointsToDeduct > 0 && userDocId != null) {
          final userRef = _firestore.collection('users').doc(userDocId);
          final userDoc = await transaction.get(userRef);
          if (userDoc.exists) {
            final currentPoints = (userDoc.data()?['points'] as num?)?.toDouble() ?? 0.0;
            if (currentPoints < pointsToDeduct) {
              throw Exception('Not enough points');
            }
            transaction.update(userRef, {
              'points': FieldValue.increment(-pointsToDeduct),
            });
            
            final historyRef = _firestore.collection('point_history').doc();
            transaction.set(historyRef, {
              'userId': userDocId,
              'amount': -pointsToDeduct,
              'type': 'order_payment',
              'description': '물품 구매',
              'orderId': 'pending_order', // Will be updated later if needed, or we just don't have orderId yet
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        final newOrderRef = _firestore.collection('orders').doc();
        transaction.set(newOrderRef, orderData);
        
        return true;
      });
    } catch (e) {
      print('Error submitting order: $e');
      return false;
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
          }
          
          final userEmail = orderData['userEmail'];
          if (refundKrw > 0 && userEmail != null) {
            final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
            if (userSnap.docs.isNotEmpty) {
              final userDocId = userSnap.docs.first.id;
              final userRef = _firestore.collection('users').doc(userDocId);
              
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

        transaction.update(orderRef, updates);

        if (newStatus == 'rejected' && currentStatus != 'pending' && currentStatus != 'rejected') {
          // Calculate how much was paid with points
          double refundKrw = 0;
          for (var item in items) {
            if (item['isBankTransferOnly'] != true) {
              refundKrw += (item['totalPriceKrw'] ?? 0).toDouble();
            }
          }
          
          final userEmail = orderData['userEmail'];
          
          if (refundKrw > 0 && userEmail != null) {
            final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
            if (userSnap.docs.isNotEmpty) {
              final userDocId = userSnap.docs.first.id;
              final userRef = _firestore.collection('users').doc(userDocId);
              
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

        if (newStatus == 'rejected') {
          final priceKrw = (item['totalPriceKrw'] ?? 0).toDouble();
          newTotalKrw -= priceKrw;
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
             if (item['isBankTransferOnly'] == true) {
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
}
