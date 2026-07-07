import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userSchool;
  final String? userEmail;
  final double totalKrw;
  final List<dynamic> items;
  final String status;
  final String? rejectReason;
  final String? transferRejectReason;
  final DateTime createdAt;
  final bool isTransferNotified;

  OrderModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userSchool,
    this.userEmail,
    required this.totalKrw,
    required this.items,
    required this.status,
    this.rejectReason,
    this.transferRejectReason,
    required this.createdAt,
    this.isTransferNotified = false,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userSchool: data['userSchool'],
      userEmail: data['userEmail'],
      totalKrw: (data['totalKrw'] ?? data['totalPhp'] ?? 0.0).toDouble(), // fallback for old data
      items: data['items'] ?? [],
      status: data['status'] ?? 'pending',
      rejectReason: data['rejectReason'],
      transferRejectReason: data['transferRejectReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTransferNotified: data['isTransferNotified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (userName != null) 'userName': userName,
      if (userSchool != null) 'userSchool': userSchool,
      if (userEmail != null) 'userEmail': userEmail,
      'totalKrw': totalKrw,
      'items': items,
      'status': status,
      'rejectReason': rejectReason,
      if (transferRejectReason != null) 'transferRejectReason': transferRejectReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'isTransferNotified': isTransferNotified,
    };
  }
}
