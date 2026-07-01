import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  final String id;
  final String category; // e.g. "지역"
  final String region; // e.g. "바기오"
  final String subCategory; // e.g. "식당"
  final String name;
  final String description;
  final String address;
  final String address2;
  final String address3;
  final String contact;
  final String sns;
  final String operatingHours;
  final String thumbnailUrl;
  final List<String> relatedImages;
  final List<String> priceImages;
  final String providerDescription;
  final List<String> providerImages;
  final List<String> relatedLinks;

  BusinessModel({
    required this.id,
    required this.category,
    required this.region,
    required this.subCategory,
    required this.name,
    required this.description,
    required this.address,
    this.address2 = '',
    this.address3 = '',
    required this.contact,
    this.sns = '',
    required this.operatingHours,
    required this.thumbnailUrl,
    this.relatedImages = const [],
    this.priceImages = const [],
    this.providerDescription = '',
    this.providerImages = const [],
    this.relatedLinks = const [],
  });

  factory BusinessModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BusinessModel.fromMap(data, doc.id);
  }

  factory BusinessModel.fromMap(Map<String, dynamic> data, String id) {
    return BusinessModel(
      id: id,
      category: data['category'] ?? '',
      region: data['region'] ?? '',
      subCategory: data['subCategory'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      address2: data['address2'] ?? '',
      address3: data['address3'] ?? '',
      contact: data['contact'] ?? '',
      sns: data['sns'] ?? '',
      operatingHours: data['operatingHours'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      relatedImages: List<String>.from(data['relatedImages'] ?? []),
      priceImages: List<String>.from(data['priceImages'] ?? []),
      providerDescription: data['providerDescription'] ?? '',
      providerImages: List<String>.from(data['providerImages'] ?? []),
      relatedLinks: List<String>.from(data['relatedLinks'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'region': region,
      'subCategory': subCategory,
      'name': name,
      'description': description,
      'address': address,
      'address2': address2,
      'address3': address3,
      'contact': contact,
      'sns': sns,
      'operatingHours': operatingHours,
      'thumbnailUrl': thumbnailUrl,
      'relatedImages': relatedImages,
      'priceImages': priceImages,
      'providerDescription': providerDescription,
      'providerImages': providerImages,
      'relatedLinks': relatedLinks,
    };
  }
}
