import 'package:flutter/material.dart';
import '../models/business_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BusinessCard extends StatelessWidget {
  final BusinessModel business;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: business.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: business.thumbnailUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        memCacheWidth: 200, // Optimize memory for thumbnails
                        maxWidthDiskCache: 400,
                        placeholder: (context, url) => _buildPlaceholder(business.subCategory),
                        errorWidget: (context, url, error) => _buildPlaceholder(business.subCategory),
                      )
                    : _buildPlaceholder(business.subCategory),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onEdit != null || onDelete != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: onEdit,
                                ),
                              if (onEdit != null && onDelete != null)
                                const SizedBox(width: 8),
                              if (onDelete != null)
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: onDelete,
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.description,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String category) {
    String assetPath = 'assets/images/logo.png'; // default
    if (category.contains('쇼핑')) assetPath = 'assets/images/ph_shopping.png';
    else if (category.contains('식당') || category.contains('음식')) assetPath = 'assets/images/ph_food.png';
    else if (category.contains('카페') || category.contains('마사지') || category.contains('뷰티')) assetPath = 'assets/images/ph_cafe.png';
    else if (category.contains('환전') || category.contains('은행')) assetPath = 'assets/images/ph_exchange.png';
    else if (category.contains('관광') || category.contains('여행')) assetPath = 'assets/images/ph_tour.png';
    
    return Container(
      width: 80,
      height: 80,
      color: Colors.white,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.business, color: Colors.grey),
        ),
      ),
    );
  }
}
