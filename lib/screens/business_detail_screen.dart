import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import 'submit_info_screen.dart';
import 'image_viewer_screen.dart';
import '../utils/telecom_utils.dart';
import '../services/preferences_service.dart';
import '../utils/ui_utils.dart';

class BusinessDetailScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  late BusinessModel _business;

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _refreshBusinessData();
  }

  Future<void> _refreshBusinessData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('directory').doc(_business.id).get();
      if (doc.exists) {
        final updatedBusiness = BusinessModel.fromMap(doc.data()!, doc.id);
        if (mounted) {
          setState(() {
            _business = updatedBusiness;
          });
        }
        if (PreferencesService.isFavorite(_business.id)) {
          PreferencesService.updateFavoriteBusinessData(_business.id, updatedBusiness.toMap());
        }
      }
    } catch (e) {
      debugPrint('Failed to refresh business data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BusinessDetailScreenContent(business: _business);
  }
}

class _BusinessDetailScreenContent extends StatelessWidget {
  final BusinessModel business;

  const _BusinessDetailScreenContent({required this.business});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _openMap() async {
    if (business.address2.isNotEmpty && business.address2.startsWith('http')) {
      await _launchUrl(business.address2);
      return;
    }
    String query = '';
    if (business.address2.isNotEmpty) {
      query = business.address2;
    } else {
      query = business.address;
    }
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
    await _launchUrl(url);
  }

  Future<void> _makeCall(BuildContext context) async {
    if (business.contact.isEmpty) return;
    
    final parts = business.contact.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) {
      _dialNumber(parts.first);
    } else {
      // Show bottom sheet to select which number to call
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('어떤 번호로 전화를 거시겠습니까?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ...parts.map((contactPart) {
                  return ListTile(
                    leading: const Icon(Icons.call),
                    title: Text(_formatSingleContact(contactPart)),
                    onTap: () {
                      Navigator.pop(context);
                      _dialNumber(contactPart);
                    },
                  );
                }),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _dialNumber(String contact) async {
    String cleanContact = contact.toLowerCase().trim();
    if (cleanContact.startsWith('k') || cleanContact.startsWith('p')) {
      cleanContact = cleanContact.substring(1).trim();
    }
    final url = 'tel:${cleanContact.replaceAll(RegExp(r'[^0-9+]'), '')}';
    await _launchUrl(url);
  }

  String _formatSingleContact(String contact) {
    String prefix = '';
    String cleanContact = contact.trim();
    
    if (cleanContact.toLowerCase().startsWith('k')) {
      prefix = '[한국인] ';
      cleanContact = cleanContact.substring(1).trim();
    } else if (cleanContact.toLowerCase().startsWith('p')) {
      prefix = '[필리핀인] ';
      cleanContact = cleanContact.substring(1).trim();
    }
    
    final telecom = TelecomUtils.getPhilippineTelecom(cleanContact);
    if (telecom.isNotEmpty) {
      return '$prefix($telecom) $cleanContact';
    }
    return '$prefix$cleanContact';
  }

  String _formatContactDisplay() {
    if (business.contact.isEmpty) return '';
    
    final parts = business.contact.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.map((e) => _formatSingleContact(e)).join('\n');
  }

  String _formatSingleSns(String sns) {
    String prefix = '';
    String cleanSns = sns.trim();
    
    if (RegExp(r'^(k|ㅏ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[카카오톡] ';
      cleanSns = cleanSns.substring(2).trim();
    } else if (RegExp(r'^(l|ㅣ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[라인] ';
      cleanSns = cleanSns.substring(2).trim();
    } else if (RegExp(r'^(w|ㅈ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[위챗] ';
      cleanSns = cleanSns.substring(2).trim();
    } else if (RegExp(r'^(f|ㄹ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[페이스북] ';
      cleanSns = cleanSns.substring(2).trim();
    } else if (RegExp(r'^(i|ㅑ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[인스타그램] ';
      cleanSns = cleanSns.substring(2).trim();
    } else if (RegExp(r'^(t|ㅅ)/', caseSensitive: false).hasMatch(cleanSns)) {
      prefix = '[텔레그램] ';
      cleanSns = cleanSns.substring(2).trim();
    }
    
    return '$prefix$cleanSns';
  }

  String _formatSnsDisplay() {
    if (business.sns.isEmpty) return '';
    
    final parts = business.sns.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.map((e) => _formatSingleSns(e)).join('\n');
  }

  Future<void> _handleSnsTap(BuildContext context) async {
    if (business.sns.isEmpty) return;
    
    final parts = business.sns.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) {
      _handleSnsAction(context, parts.first);
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('SNS 작업을 선택하세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ...parts.map((snsPart) {
                  final isLink = snsPart.contains('http');
                  return ListTile(
                    leading: Icon(isLink ? Icons.link : Icons.copy),
                    title: Text(_formatSingleSns(snsPart)),
                    onTap: () {
                      Navigator.pop(context);
                      _handleSnsAction(context, snsPart);
                    },
                  );
                }),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _handleSnsAction(BuildContext context, String snsPart) async {
    String cleanSns = snsPart.trim();
    if (RegExp(r'^([klwfitKLWFIT]|[ㅏㅣㅈㄹㅑㅅ])/', caseSensitive: false).hasMatch(cleanSns)) {
      cleanSns = cleanSns.substring(2).trim();
    }
    
    final match = RegExp(r'https?://[^\s]+').firstMatch(cleanSns);
    if (match != null) {
      final url = match.group(0)!;
      await _launchUrl(url);
    } else {
      Clipboard.setData(ClipboardData(text: cleanSns));
      UiUtils.showPopup(context, 'SNS 아이디가 복사되었습니다.');
    }
  }

  String _buildFullAddress() {
    return business.address;
  }

  String _extractCity(String address) {
    final lowerAddr = address.toLowerCase();
    if (lowerAddr.contains('lapu-lapu') || lowerAddr.contains('lapu lapu')) return 'Lapu-Lapu';
    if (lowerAddr.contains('mandaue')) return 'Mandaue';
    if (lowerAddr.contains('cebu')) return 'Cebu';
    if (lowerAddr.contains('manila')) return 'Manila';
    if (lowerAddr.contains('makati')) return 'Makati';
    if (lowerAddr.contains('baguio')) return 'Baguio';
    if (lowerAddr.contains('clark')) return 'Clark';
    if (lowerAddr.contains('angeles')) return 'Angeles';
    if (lowerAddr.contains('pasay')) return 'Pasay';
    if (lowerAddr.contains('quezon')) return 'Quezon';
    if (lowerAddr.contains('taguig')) return 'Taguig';
    if (lowerAddr.contains('pasig')) return 'Pasig';
    if (lowerAddr.contains('alabang') || lowerAddr.contains('muntinlupa')) return 'Alabang';
    if (lowerAddr.contains('subic')) return 'Subic';
    return business.category;
  }

  Widget _buildImageGallery(String title, List<String> imageUrls, String imageType) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) const SizedBox(height: 24),
        if (title.isNotEmpty) Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (title.isNotEmpty) const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageViewerScreen(
                          imageUrls: imageUrls,
                          initialIndex: index,
                          isAdmin: PreferencesService.isAdmin,
                          businessId: business.id,
                          imageType: imageType,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(width: 120, color: Colors.grey[300]),
                      errorWidget: (context, url, error) => Container(width: 120, color: Colors.grey[300], child: const Icon(Icons.error)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = PreferencesService.isAdmin;
    final regionText = business.category == '지역' ? _extractCity(business.address) : business.category;
    final prefix = isAdmin ? '${business.region} > $regionText > ${business.subCategory} > ' : '$regionText > ${business.subCategory} > ';

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: business.name,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: PreferencesService.favoritesNotifier,
            builder: (context, favorites, _) {
              final isFav = PreferencesService.isFavorite(business.id);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : (isDarkMode ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  if (isFav) {
                    PreferencesService.removeFavorite(business.id);
                  } else {
                    PreferencesService.addFavorite({
                      'id': business.id,
                      'type': 'business',
                      'title': business.name,
                      'iconCodePoint': Icons.business.codePoint,
                      'iconFontFamily': Icons.business.fontFamily,
                      'colorValue': 0xFFE6F3FF, // Light blue default
                      'businessData': business.toMap(),
                    });
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail / Header Image
            if (business.thumbnailUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(
                    imageUrl: business.thumbnailUrl,
                    fit: BoxFit.contain,
                    memCacheWidth: 600, // Optimize memory for detail view
                    maxWidthDiskCache: 1200,
                    placeholder: (context, url) => Container(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDarkMode ? Colors.black : Colors.white,
                      child: Image.asset(
                        _getPlaceholderImage(business.subCategory),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: const Icon(Icons.business, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    color: isDarkMode ? Colors.black : Colors.white,
                    child: Image.asset(
                      _getPlaceholderImage(business.subCategory),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(Icons.business, size: 100, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    '상세 설명',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: business.description
                        .split('\n')
                        .map((line) => line.trim())
                        .where((line) => line.isNotEmpty)
                        .map((line) {
                      if (line.startsWith('-')) {
                        line = line.substring(1).trim();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '- ',
                              style: TextStyle(fontSize: 16, height: 1.5),
                            ),
                            Expanded(
                              child: Text(
                                line,
                                style: const TextStyle(fontSize: 16, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Info Cards
                  _buildInfoRow(
                    icon: Icons.location_on,
                    title: '주소',
                    content: _buildFullAddress(),
                    onTap: business.address.isNotEmpty ? _openMap : null,
                    actionIcon: Icons.map,
                  ),
                  const Divider(),
                  _buildInfoRow(
                    icon: Icons.phone,
                    title: '전화번호',
                    content: _formatContactDisplay(),
                    onTap: business.contact.isNotEmpty ? () => _makeCall(context) : null,
                    actionIcon: Icons.call,
                  ),
                  if (business.sns.isNotEmpty) ...[
                    const Divider(),
                    _buildInfoRow(
                      icon: Icons.chat_bubble_outline,
                      title: 'SNS',
                      content: _formatSnsDisplay(),
                      onTap: () => _handleSnsTap(context),
                      actionIcon: business.sns.contains('http') ? Icons.link : Icons.copy,
                    ),
                  ],
                  const Divider(),
                  _buildInfoRow(
                    icon: Icons.access_time,
                    title: '영업시간',
                    content: business.operatingHours,
                  ),
                  
                  _buildImageGallery('관련 사진', business.relatedImages, 'relatedImages'),
                  _buildImageGallery('가격 사진', business.priceImages, 'priceImages'),
                  
                  if (business.providerDescription.isNotEmpty || business.providerImages.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('※ 아래 내용은 업체에서 홍보하는 내용입니다.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (business.providerDescription.isNotEmpty)
                      Text(business.providerDescription, style: const TextStyle(fontSize: 16, height: 1.5)),
                    
                    if (business.providerImages.isNotEmpty)
                      _buildImageGallery('', business.providerImages, 'providerImages'),
                  ],

                  if (business.relatedLinks.isNotEmpty)
                    _buildRelatedLinks(business.relatedLinks),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final businessPath = '${business.category} > ${business.subCategory} > ${business.name}';
          Navigator.push(context, MaterialPageRoute(builder: (context) => SubmitInfoScreen(initialType: '디렉토리', businessPath: businessPath)));
        },
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('정보 제보', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
    IconData? actionIcon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    content.isNotEmpty ? content : '정보 없음',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            if (onTap != null && actionIcon != null)
              Icon(actionIcon, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  String _getPlaceholderImage(String category) {
    String assetPath = 'assets/images/logo.png'; // default
    if (category.contains('쇼핑')) assetPath = 'assets/images/ph_shopping.png';
    else if (category.contains('식당') || category.contains('음식')) assetPath = 'assets/images/ph_restaurant.png';
    else if (category.contains('카페')) assetPath = 'assets/images/ph_cafebar.png';
    else if (category.contains('마사지')) assetPath = 'assets/images/ph_massage.png';
    else if (category.contains('뷰티')) assetPath = 'assets/images/ph_beauty.png';
    else if (category.contains('환전') || category.contains('은행')) assetPath = 'assets/images/ph_exchange.png';
    else if (category.contains('관광') || category.contains('여행')) assetPath = 'assets/images/ph_travel.png';
    else if (category.contains('병원')) assetPath = 'assets/images/ph_hospital.png';
    return assetPath;
  }

  Widget _buildRelatedLinks(List<String> links) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('관련 링크', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...links.map((link) {
          final match = RegExp(r'https?://[^\s]+').firstMatch(link);
          final url = match?.group(0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: url != null ? () => _launchUrl(url) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.link, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link,
                        style: TextStyle(
                          fontSize: 15,
                          color: url != null ? Colors.blue.shade800 : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
