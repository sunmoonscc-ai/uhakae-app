import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_storage_service.dart';
import '../utils/ui_utils.dart';
import '../utils/telecom_utils.dart';
import '../models/business_model.dart';
import '../screens/info_screen.dart';
import '../main.dart';
import 'global_upload_indicator.dart';

class ImageItem {
  final String? url;
  final XFile? file;
  
  ImageItem({this.url, this.file});
  
  bool get isLocal => file != null;
  bool get isRemote => url != null;
}

class AddBusinessDialog extends StatefulWidget {
  final String region;
  final String subCategory;
  final BusinessModel? existingBusiness;

  const AddBusinessDialog({
    super.key,
    required this.region,
    required this.subCategory,
    this.existingBusiness,
  });

  @override
  State<AddBusinessDialog> createState() => _AddBusinessDialogState();
}

class _AddBusinessDialogState extends State<AddBusinessDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _addr3Ctrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _snsCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _providerDescCtrl = TextEditingController();

  late String _selectedRegion;
  late String _selectedSubCategory;
  bool _canPop = false;

  final ValueNotifier<String> _telecomCarrier = ValueNotifier<String>('');

  List<ImageItem> _relatedImages = [];
  List<ImageItem> _priceImages = [];
  List<ImageItem> _providerImages = [];
  final List<TextEditingController> _relatedLinksCtrls = [];

  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.existingBusiness?.region ?? widget.region;
    _selectedSubCategory = widget.existingBusiness?.subCategory ?? widget.subCategory;
    if (_selectedSubCategory == '전체') {
      _selectedSubCategory = '관광';
    }
    
    _contactCtrl.addListener(() {
      final carrier = TelecomUtils.getPhilippineTelecom(_contactCtrl.text);
      if (_telecomCarrier.value != carrier) {
        _telecomCarrier.value = carrier;
      }
    });

    if (widget.existingBusiness != null) {
      final b = widget.existingBusiness!;
      _nameCtrl.text = b.name;
      _descCtrl.text = b.description;
      _addr1Ctrl.text = b.address;
      _addr2Ctrl.text = b.address2;
      _addr3Ctrl.text = b.address3;
      _contactCtrl.text = b.contact;
      _snsCtrl.text = b.sns;
      _hoursCtrl.text = b.operatingHours;
      _providerDescCtrl.text = b.providerDescription;

      _relatedImages = b.relatedImages.map((url) => ImageItem(url: url)).toList();
      _priceImages = b.priceImages.map((url) => ImageItem(url: url)).toList();
      _providerImages = b.providerImages.map((url) => ImageItem(url: url)).toList();
      _relatedLinksCtrls.addAll(
        b.relatedLinks.map((link) => TextEditingController(text: link)),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _addr3Ctrl.dispose();
    _contactCtrl.dispose();
    _snsCtrl.dispose();
    _hoursCtrl.dispose();
    _providerDescCtrl.dispose();
    for (var ctrl in _relatedLinksCtrls) {
      ctrl.dispose();
    }
    _telecomCarrier.dispose();
    super.dispose();
  }

  Future<void> _pickImages(List<ImageItem> currentList, Function(List<ImageItem>) onUpdate) async {
    if (currentList.length >= 20) {
      UiUtils.showPopup(context, '최대 20장까지만 업로드 가능합니다.');
      return;
    }
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        final remaining = 20 - currentList.length;
        final toAdd = picked.take(remaining).map((f) => ImageItem(file: f)).toList();
        onUpdate([...currentList, ...toAdd]);
        if (picked.length > remaining) {
          if (mounted) UiUtils.showPopup(context, '20장을 초과하여 일부 이미지만 추가되었습니다.');
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Widget _buildImageSection(String title, List<ImageItem> images, Function(List<ImageItem>) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => _pickImages(images, onUpdate),
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: Text('${images.length}/20'),
            ),
          ],
        ),
        if (images.isNotEmpty)
          SizedBox(
            height: 90,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
              itemCount: images.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = images.removeAt(oldIndex);
                  images.insert(newIndex, item);
                  onUpdate(images);
                });
              },
              itemBuilder: (context, index) {
                final item = images[index];
                return ReorderableDragStartListener(
                  index: index,
                  key: ValueKey(item.url ?? item.file!.path),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.isLocal
                                ? (kIsWeb ? Image.network(item.file!.path, fit: BoxFit.cover) : Image.file(File(item.file!.path), fit: BoxFit.cover))
                                : CachedNetworkImage(
                                    imageUrl: item.url!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              final newList = List<ImageItem>.from(images)..removeAt(index);
                              onUpdate(newList);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
      ],
    );
  }

  Future<List<String>> _uploadAndMergeImages(List<ImageItem> images, String pathPrefix) async {
    List<String> finalUrls = [];
    final storage = FirebaseStorageService();
    
    for (var item in images) {
      if (item.isRemote) {
        finalUrls.add(item.url!);
      } else if (item.isLocal) {
        List<String> uploaded = await storage.uploadMultipleImages([item.file!], pathPrefix);
        if (uploaded.isNotEmpty) {
          finalUrls.add(uploaded.first);
        }
      }
    }
    return finalUrls;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      UiUtils.showPopup(context, '업체명을 입력해주세요.');
      return;
    }

    // Capture variables locally
    final bool isEdit = widget.existingBusiness != null;
    final String? existingId = widget.existingBusiness?.id;
    final String region = widget.region;
    final String subCategory = widget.subCategory;
    final String selectedRegion = _selectedRegion;
    final String selectedSubCategory = _selectedSubCategory;
    final String name = _nameCtrl.text.trim();
    final String desc = _descCtrl.text.trim();
    final String addr1 = _addr1Ctrl.text.trim();
    final String addr2 = _addr2Ctrl.text.trim();
    final String addr3 = _addr3Ctrl.text.trim();
    final String contact = _contactCtrl.text.trim();
    final String sns = _snsCtrl.text.trim();
    final String hours = _hoursCtrl.text.trim();
    final String providerDesc = _providerDescCtrl.text.trim();
    
    // Copy the lists
    final List<ImageItem> relatedImages = List.from(_relatedImages);
    final List<ImageItem> priceImages = List.from(_priceImages);
    final List<ImageItem> providerImages = List.from(_providerImages);
    final List<String> relatedLinks = _relatedLinksCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Pop the dialog immediately
    setState(() { _canPop = true; });
    Navigator.pop(context);

    final BuildContext? rootContext = rootNavigatorKey.currentContext;
    if (rootContext != null) {
      GlobalUploadManager.init(rootContext);
    }

    // Start background task
    Future.microtask(() async {
      globalUploadingNotifier.value = [...globalUploadingNotifier.value, name];
      try {
        List<String> relatedUrls = await _uploadAndMergeImages(
          relatedImages,
          'directory/$region/$subCategory/related',
        );

        List<String> priceUrls = await _uploadAndMergeImages(
          priceImages,
          'directory/$region/$subCategory/price',
        );

        List<String> providerUrls = await _uploadAndMergeImages(
          providerImages,
          'directory/$region/$subCategory/provider',
        );

        String thumbnailUrl = relatedUrls.isNotEmpty 
            ? relatedUrls.first 
            : '';

        final Map<String, dynamic> data = {
          'category': '지역',
          'region': selectedRegion,
          'subCategory': selectedSubCategory,
          'name': name,
          'description': desc,
          'address': addr1,
          'address2': addr2,
          'address3': addr3,
          'contact': contact,
          'sns': sns,
          'operatingHours': hours,
          'thumbnailUrl': thumbnailUrl,
          'relatedImages': relatedUrls,
          'priceImages': priceUrls,
          'providerDescription': providerDesc,
          'providerImages': providerUrls,
          'relatedLinks': relatedLinks,
        };

        if (isEdit && existingId != null) {
          await FirebaseFirestore.instance.collection('directory').doc(existingId).update(data);
          if (rootContext != null) {
            UiUtils.showPopup(rootContext, '[$name] 정보 수정이 완료되었습니다.');
          }
        } else {
          data['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('directory').add(data);
          if (rootContext != null) {
            UiUtils.showPopup(rootContext, '[$name] 정보 추가가 완료되었습니다.');
          }
        }
      } catch (e) {
        if (rootContext != null) {
          UiUtils.showPopup(rootContext, '[$name] 저장 중 오류 발생: $e');
        }
      } finally {
        final currentList = List<String>.from(globalUploadingNotifier.value);
        currentList.remove(name);
        globalUploadingNotifier.value = currentList;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingBusiness != null;
    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('닫기'),
            content: const Text('입력 중인 내용이 저장되지 않았습니다. 정말 닫으시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('확인', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          setState(() {
            _canPop = true;
          });
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? '업체 정보 수정' : '${widget.region} - ${widget.subCategory} 업체 추가',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: commonRegions.contains(_selectedRegion) ? _selectedRegion : commonRegions.first,
                              decoration: const InputDecoration(labelText: '지역', border: OutlineInputBorder()),
                              items: commonRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (v) => setState(() => _selectedRegion = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubCategory,
                              decoration: const InputDecoration(labelText: '분류', border: OutlineInputBorder()),
                              items: regionSubCategories
                                  .where((c) => c['label'] != '전체')
                                  .map((c) => DropdownMenuItem(value: c['label'].toString(), child: Text(c['label'].toString())))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedSubCategory = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: '설명', border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 16),
                    const Text('주소 정보', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addr1Ctrl,
                      decoration: const InputDecoration(labelText: '주소 1 (장소명 등)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addr2Ctrl,
                      decoration: const InputDecoration(labelText: '주소 2 (구글맵 링크)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addr3Ctrl,
                      decoration: const InputDecoration(labelText: '주소 3 (구글맵 좌표)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _snsCtrl,
                      decoration: const InputDecoration(labelText: 'SNS (k/ 카카오, l/ 라인, w/ 위챗, f/ 페이스북, i/ 인스타, t/ 텔레그램)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _hoursCtrl,
                      decoration: const InputDecoration(labelText: '영업시간 (예: 09:00 - 22:00)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildImageSection('관련 사진 (최대 20장, 길게 눌러 순서 변경)', _relatedImages, (newList) => setState(() => _relatedImages = newList)),
                    const SizedBox(height: 16),
                    _buildImageSection('가격 사진 (최대 20장, 길게 눌러 순서 변경)', _priceImages, (newList) => setState(() => _priceImages = newList)),
                    const SizedBox(height: 16),
                    _buildImageSection('업체 제공 사진 (최대 20장, 길게 눌러 순서 변경)', _providerImages, (newList) => setState(() => _providerImages = newList)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _providerDescCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: '업체 제공 설명', border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildRelatedLinksSection(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEdit ? '수정하기' : '추가하기', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildRelatedLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('관련 링크 (블로그, 유튜브 등)', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () {
                setState(() {
                  _relatedLinksCtrls.add(TextEditingController());
                });
              },
            ),
          ],
        ),
        if (_relatedLinksCtrls.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('등록된 관련 링크가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ...List.generate(_relatedLinksCtrls.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _relatedLinksCtrls[index],
                      decoration: const InputDecoration(
                        labelText: '설명과 링크를 함께 입력 (예: 2026 핫한 장소 https://...)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _relatedLinksCtrls[index].dispose();
                        _relatedLinksCtrls.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
