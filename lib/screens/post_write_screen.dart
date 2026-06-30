import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/firebase_storage_service.dart';
class PostWriteScreen extends StatefulWidget {
  final String? editPostId;
  final Map<String, dynamic>? editPostData;

  const PostWriteScreen({super.key, this.editPostId, this.editPostData});

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'community';
  bool _isSaving = false;
  
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;
  
  final List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && _adminEmails.contains(user.email);
    
    if (widget.editPostData != null) {
      _titleController.text = widget.editPostData!['title'] ?? '';
      _contentController.text = widget.editPostData!['content'] ?? '';
      _selectedCategory = widget.editPostData!['category'] ?? 'community';
    } else {
      if (isAdmin) {
        _selectedCategory = 'notice';
      } else {
        _selectedCategory = 'community';
      }
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있습니다.');
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        int remainingSlots = 5 - _selectedImages.length;
        if (images.length > remainingSlots) {
          _selectedImages.addAll(images.take(remainingSlots));
          UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있어 초과된 사진은 제외되었습니다.');
        } else {
          _selectedImages.addAll(images);
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      UiUtils.showPopup(context, '로그인이 필요합니다.');
      return;
    }

    if (title.isEmpty || content.isEmpty) {
      UiUtils.showPopup(context, '제목과 내용을 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bool isAdmin = _adminEmails.contains(user.email);
      
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        setState(() => _isUploadingImages = true);
        for (var file in _selectedImages) {
          final url = await FirebaseStorageService.uploadImage(file);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      List<String> finalImageUrls = [];
      if (widget.editPostData != null && widget.editPostData!['image_urls'] != null) {
        finalImageUrls.addAll(List<String>.from(widget.editPostData!['image_urls']));
      }
      finalImageUrls.addAll(imageUrls);

      final postData = {
        'title': _titleController.text,
        'content': _contentController.text,
        'category': _selectedCategory,
        'image_urls': finalImageUrls,
      };

      if (widget.editPostId != null) {
        // 수정 모드: 기존 문서 업데이트
        postData['updated_at'] = FieldValue.serverTimestamp(); 
        await FirebaseFirestore.instance.collection('posts').doc(widget.editPostId).update(postData);
        if (mounted) {
          UiUtils.showPopup(context, '게시글이 수정되었습니다.');
          Navigator.pop(context);
        }
        return;
      }

      // 새 글 작성
      postData['author_id'] = user.uid;
      postData['author_name'] = user.displayName ?? '익명';
      postData['is_admin'] = isAdmin;
      postData['created_at'] = FieldValue.serverTimestamp();
      postData['post_id'] = ''; // 임시

      final docRef = FirebaseFirestore.instance.collection('posts').doc();
      postData['post_id'] = docRef.id;
      await docRef.set(postData);

      if (mounted) {
        // 스낵바로 오프라인 지속성 안내
        UiUtils.showPopup(context, '게시글이 저장되었습니다. (네트워크 오프라인 시 연결 후 자동 업로드됩니다.)');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showPopup(context, '저장 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingImages = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && _adminEmails.contains(user.email);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              isDarkMode ? 'assets/images/logo(r).jpg' : 'assets/images/logo.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.forum, color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Text('글쓰기', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePost,
            child: _isSaving 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: isDarkMode ? Colors.white : Colors.black, strokeWidth: 2))
              : Text(widget.editPostId != null ? '수정' : '등록', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          IconButton(
            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('게시판 선택:', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                const SizedBox(width: 16),
                if (isAdmin)
                  DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    items: const [
                      DropdownMenuItem(value: 'notice', child: Text('공지사항')),
                      DropdownMenuItem(value: 'individual_notice', child: Text('쪽지')),
                      DropdownMenuItem(value: 'community', child: Text('자유 게시판')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  )
                else
                  Text('자유 게시판', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16)),
              ],
            ),
            Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '제목을 입력하세요',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white38 : Colors.black38),
              ),
            ),
            Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
            if (_selectedImages.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8, top: 8),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<Uint8List>(
                              future: _selectedImages[index].readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: TextField(
                controller: _contentController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: '내용을 작성해주세요.\n\n오프라인 상태에서도 작성 및 저장이 가능하며, 네트워크 복구 시 자동으로 서버에 동기화됩니다.',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImages,
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.blue,
        child: const Icon(Icons.photo_library, color: Colors.white),
      ),
    );
  }
}
