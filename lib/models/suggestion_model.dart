import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestionModel {
  final String id;
  final String userId;
  final String userEmail;
  final String type; // 'exchange', 'gas', 'directory'
  final String content;
  final String imageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final Timestamp createdAt;

  SuggestionModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.content,
    required this.imageUrl,
    this.status = 'pending',
    required this.createdAt,
  });

  factory SuggestionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SuggestionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      type: data['type'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'type': type,
      'content': content,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
