import 'package:flutter/material.dart';
import '../models/business_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/time_utils.dart';

class BusinessCard extends StatelessWidget {
  final BusinessModel business;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final double? distance;

  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.distance,
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
                        placeholder: (context, url) => _buildPlaceholder(context, business.subCategory),
                        errorWidget: (context, url, error) => _buildPlaceholder(context, business.subCategory),
                      )
                    : _buildPlaceholder(context, business.subCategory),
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
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              children: [
                                if (business.operatingHours.isNotEmpty)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6, bottom: 2),
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: TimeUtils.isOpenNow(business.operatingHours) ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                TextSpan(
                                  text: business.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: distance != null 
                                      ? ' / ${business.city}, ${(distance! / 1000).toStringAsFixed(1)}km'
                                      : ' / ${business.city}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
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
                      maxLines: 2,
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

  Widget _buildPlaceholder(BuildContext context, String category) {
    String assetPath = (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'); // default
    if (category.contains('쇼핑')) assetPath = 'assets/images/ph_shopping.png';
    else if (category.contains('식당') || category.contains('음식')) assetPath = 'assets/images/ph_restaurant.png';
    else if (category.contains('카페')) assetPath = 'assets/images/ph_cafebar.png';
    else if (category.contains('마사지')) assetPath = 'assets/images/ph_massage.png';
    else if (category.contains('뷰티')) assetPath = 'assets/images/ph_beauty.png';
    else if (category.contains('환전') || category.contains('은행')) assetPath = 'assets/images/ph_exchange.png';
    else if (category.contains('관광') || category.contains('여행')) assetPath = 'assets/images/ph_travel.png';
    else if (category.contains('병원')) assetPath = 'assets/images/ph_hospital.png';
    
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
