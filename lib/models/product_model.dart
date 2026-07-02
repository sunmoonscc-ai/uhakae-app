class Product {
  final String id;
  final String type; // 'buy' or 'rent'
  final String name;
  final double priceKrw;
  final double depositKrw;
  final String stockStatus; // e.g., 'in_stock', 'out_of_stock'
  final String imageUrl;
  final String description;
  final bool isBankTransferOnly;

  Product({
    required this.id,
    required this.type,
    required this.name,
    required this.priceKrw,
    this.depositKrw = 0.0,
    required this.stockStatus,
    required this.imageUrl,
    required this.description,
    this.isBankTransferOnly = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      type: json['type'] ?? 'buy',
      name: json['name'] ?? '',
      priceKrw: (json['priceKrw'] ?? json['pricePhp'] ?? 0.0).toDouble(), // fallback to pricePhp for old data
      depositKrw: (json['depositKrw'] ?? 0.0).toDouble(),
      stockStatus: json['stockStatus'] ?? 'in_stock',
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      isBankTransferOnly: json['isBankTransferOnly'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'priceKrw': priceKrw,
      'depositKrw': depositKrw,
      'stockStatus': stockStatus,
      'imageUrl': imageUrl,
      'description': description,
      'isBankTransferOnly': isBankTransferOnly,
    };
  }
}
