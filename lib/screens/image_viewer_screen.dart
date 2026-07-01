import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/ui_utils.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool isAdmin;
  final String? businessId;
  final String? imageType; // 'imageUrls' or 'priceImageUrls'

  const ImageViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.isAdmin = false,
    this.businessId,
    this.imageType,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.isAdmin && widget.businessId != null && widget.imageType != null)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('대표사진 지정'),
                    content: const Text('이 사진을 대표사진(첫 번째)으로 지정하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('지정'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final currentUrl = widget.imageUrls[_currentIndex];
                    final newList = List<String>.from(widget.imageUrls);
                    newList.removeAt(_currentIndex);
                    newList.insert(0, currentUrl);

                    await FirebaseFirestore.instance
                        .collection('directory')
                        .doc(widget.businessId)
                        .update({
                          widget.imageType!: newList,
                          'thumbnailUrl': currentUrl,
                        });

                    if (mounted) {
                      UiUtils.showPopup(context, '대표사진으로 지정되었습니다. 변경 사항을 보려면 앱을 새로고침 해주세요.');
                    }
                  } catch (e) {
                    debugPrint('Error updating representative image: $e');
                  }
                }
              },
              child: Text(
                _currentIndex == 0 ? '현재 대표사진' : '대표사진 지정',
                style: TextStyle(color: _currentIndex == 0 ? Colors.grey : Colors.blue),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                ),
              );
            },
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 40),
                  onPressed: () {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 40),
                  onPressed: () {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
