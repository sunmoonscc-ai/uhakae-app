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

      orderData['userId'] = user.uid; // Or user.email if preferred
      
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

      orderData['status'] = 'pending'; // Initial status
      orderData['createdAt'] = FieldValue.serverTimestamp();

      final newOrderRef = await _firestore.collection('orders').add(orderData);

      // 포인트 차감 및 이력 저장
      if (userDocId != null) {
        final totalKrw = (orderData['totalKrw'] ?? 0).toDouble();
        if (totalKrw > 0) {
          await _firestore.collection('users').doc(userDocId).update({
            'points': FieldValue.increment(-totalKrw),
          });

          await _firestore.collection('point_history').add({
            'userId': userDocId,
            'amount': -totalKrw,
            'type': 'order_payment',
            'description': '상품 주문 결제 (대기중)',
            'orderId': newOrderRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
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

  // 3. User updates order status (e.g. completed, not_received)
  Future<bool> updateOrderStatusByUser(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({'status': newStatus});
      return true;
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

        if (newStatus == 'rejected' && currentStatus != 'rejected') {
          final totalKrw = (orderData['totalKrw'] ?? 0).toDouble();
          final userEmail = orderData['userEmail'];
          
          if (totalKrw > 0 && userEmail != null) {
            final userSnap = await _firestore.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
            if (userSnap.docs.isNotEmpty) {
              final userDocId = userSnap.docs.first.id;
              final userRef = _firestore.collection('users').doc(userDocId);
              
              transaction.update(userRef, {
                'points': FieldValue.increment(totalKrw),
              });
              
              final historyRef = _firestore.collection('point_history').doc();
              transaction.set(historyRef, {
                'userId': userDocId,
                'amount': totalKrw,
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

          if (priceKrw > 0 && userDocId != null) {
            final userRef = _firestore.collection('users').doc(userDocId);
            transaction.update(userRef, {
              'points': FieldValue.increment(priceKrw),
            });
            
            final historyRef = _firestore.collection('point_history').doc();
            transaction.set(historyRef, {
              'userId': userDocId,
              'amount': priceKrw,
              'type': 'order_refund_partial',
              'description': '부분 거절(${item['name']}) 환불',
              'orderId': orderId,
              'createdAt': FieldValue.serverTimestamp(),
            });
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

  // 6. Admin deducts points and sets status to preparing
  Future<bool> deductPointsAndPrepare(String orderId, String userId, double amount) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Assume users collection uses uid or email. Let's find user by uid
        final userDocRef = _firestore.collection('users').doc(userId); // Needs exact doc id match
        // Or query by userId if uid is not doc ID. Assuming uid IS doc ID.
        
        final userSnapshot = await transaction.get(userDocRef);
        if (!userSnapshot.exists) {
          // If the users collection is keyed by email in this app, we need to adapt.
          throw Exception("User not found");
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final currentPoints = (userData['points'] ?? 0).toDouble();

        if (currentPoints < amount) {
          throw Exception("Insufficient points");
        }

        transaction.update(userDocRef, {
          'points': currentPoints - amount
        });

        transaction.update(_firestore.collection('orders').doc(orderId), {
          'status': 'preparing'
        });
        return true;
      });
    } catch (e) {
      print('Error in deductPointsAndPrepare: $e');
      return false;
    }
  }
}
