import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:study_abroad_app/utils/ui_utils.dart';

class AdminPersonalNoticeTab extends StatefulWidget {
  final String region;
  
  const AdminPersonalNoticeTab({super.key, required this.region});

  @override
  State<AdminPersonalNoticeTab> createState() => _AdminPersonalNoticeTabState();
}

class _AdminPersonalNoticeTabState extends State<AdminPersonalNoticeTab> {
  String _personalNoticeSortField = 'name';
  bool _personalNoticeSortDescending = false;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        
        final List<String> adminEmails = [
          'cebufriends79@gmail.com',
          'slptas05@gmail.com',
          'sunmoon.scc@gmail.com',
          'hdcc6th@gmail.com',
        ];

        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'] as String? ?? '';
          if (adminEmails.contains(email)) return false;
          
          final school = data['school'] as String? ?? '';
          if (widget.region != '전체') {
            if (!school.startsWith('${widget.region}_')) return false;
          }
          return true;
        }).toList();

        final activeDocs = <QueryDocumentSnapshot>[];
        final endedDocs = <QueryDocumentSnapshot>[];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final level = data['level'] as String? ?? '정회원';
          if (level == '연수종료') {
            endedDocs.add(doc);
          } else if (level != '예비') { // 정회원
            activeDocs.add(doc);
          }
        }

        void sortDocs(List<QueryDocumentSnapshot> list) {
          list.sort((a, b) {
            final aMap = a.data() as Map<String, dynamic>;
            final bMap = b.data() as Map<String, dynamic>;
            String aVal = (aMap[_personalNoticeSortField] ?? '').toString().toLowerCase();
            String bVal = (bMap[_personalNoticeSortField] ?? '').toString().toLowerCase();
            return _personalNoticeSortDescending ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
          });
        }
        
        sortDocs(activeDocs);
        sortDocs(endedDocs);

        return Column(
          children: [
            _buildPersonalNoticeHeader(isDarkMode),
            Expanded(
              child: _buildPersonalNoticeList(activeDocs, isDarkMode, '정회원 목록'),
            ),
            if (endedDocs.isNotEmpty) ...[
              Container(height: 1, color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
              Container(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                padding: const EdgeInsets.all(8),
                alignment: Alignment.centerLeft,
                child: Text('연수종료 회원 목록', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              ),
              SizedBox(
                height: 180,
                child: _buildPersonalNoticeList(endedDocs, isDarkMode, '연수종료 회원 목록', hideHeader: true),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPersonalNoticeHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildPersonalNoticeSortHeader('이름', 'name', 3, isDarkMode),
          _buildPersonalNoticeSortHeader('어학원', 'school', 5, isDarkMode),
          _buildPersonalNoticeSortHeader('연수시작일', 'start_date', 4, isDarkMode),
          _buildPersonalNoticeSortHeader('연수종료일', 'end_date', 4, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildPersonalNoticeSortHeader(String title, String field, int flex, bool isDarkMode) {
    bool isSelected = _personalNoticeSortField == field;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _personalNoticeSortDescending = !_personalNoticeSortDescending;
            } else {
              _personalNoticeSortField = field;
              _personalNoticeSortDescending = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
            if (isSelected)
              Icon(_personalNoticeSortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalNoticeList(List<QueryDocumentSnapshot> docs, bool isDarkMode, String title, {bool hideHeader = false}) {
    if (docs.isEmpty) {
      return Center(
        child: Text('해당하는 회원이 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        final name = data['name'] ?? '이름 없음';
        String displaySchool = data['school'] ?? '소속 미정';
        if (widget.region != '전체' && displaySchool.startsWith('${widget.region}_')) {
          displaySchool = displaySchool.replaceFirst('${widget.region}_', '');
        }
        
        final startDate = data['start_date'] ?? '미정';
        final endDate = data['end_date'] ?? '미정';

        return InkWell(
          onTap: () => _showPersonalNoticeUserDialog(context, doc.id, name, isDarkMode),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(displaySchool, style: TextStyle(color: isDarkMode ? Colors.blue[200] : Colors.blue[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(startDate, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(endDate, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPersonalNoticeUserDialog(BuildContext context, String userId, String userName, bool isDarkMode) {
    bool isDescending = true;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('$userName 님의 쪽지 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isDescending = !isDescending;
                                });
                              },
                              child: Icon(isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: isDarkMode ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                        IconButton(icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Stack(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('personal_notices')
                                .where('userId', isEqualTo: userId)
                                .snapshots(),
                            builder: (ctx, snapshot) {
                              if (snapshot.hasError) {
                                return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.', style: TextStyle(color: Colors.red, fontSize: 12)));
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Center(child: Text('등록된 쪽지가 없습니다.', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)));
                              }

                              final notices = snapshot.data!.docs.toList();
                              notices.sort((a, b) {
                                try {
                                  final aData = a.data() as Map<String, dynamic>;
                                  final bData = b.data() as Map<String, dynamic>;
                                  final aDate = aData['createdAt'] is Timestamp ? aData['createdAt'] as Timestamp : null;
                                  final bDate = bData['createdAt'] is Timestamp ? bData['createdAt'] as Timestamp : null;
                                  
                                  if (aDate == null && bDate == null) return 0;
                                  if (aDate == null) return 1;
                                  if (bDate == null) return -1;
                                  final result = bDate.compareTo(aDate);
                                  return isDescending ? result : -result;
                                } catch (e) {
                                  return 0;
                                }
                              });

                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: notices.length,
                                itemBuilder: (ctx, index) {
                                  final notice = notices[index];
                                  final data = notice.data() as Map<String, dynamic>;
                                  final title = data['title'] ?? '제목 없음';
                                  final content = data['content'] ?? '';
                                  final isRead = data['isRead'] as bool? ?? false;
                                  final createdAt = data['createdAt'] as Timestamp?;
                                  final timeAgo = createdAt != null 
                                      ? '${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}' 
                                      : '';
                                  final imageUrls = data['image_urls'] as List<dynamic>? ?? [];
                                  
                                  final bool isFromMe = data['isFromUser'] != true;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    child: Row(
                                      mainAxisAlignment: !isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (isFromMe) ...[
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                            child: Icon(Icons.admin_panel_settings, size: 20, color: isDarkMode ? Colors.grey : Colors.black54),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (!isFromMe)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                if (!isRead) const Text('1', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                                Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        Flexible(
                                          child: InkWell(
                                            onTap: () {
                                              _showPersonalNoticeEditDialog(context, notice.id, userId, title, content, isDarkMode, initialImageUrls: imageUrls.cast<String>());
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isFromMe 
                                                    ? (isDarkMode ? Colors.grey[800] : Colors.white)
                                                    : (isDarkMode ? Colors.blue[900] : Colors.yellow[200]),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (title.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 8.0),
                                                      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                                                    ),
                                                  if (content.isNotEmpty)
                                                    Text(content, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13)),
                                                  if (imageUrls.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 8.0),
                                                      child: Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: imageUrls.map((url) => InkWell(
                                                          onTap: () => _showImagePreviewDialog(context, url as String),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.network(
                                                              url as String,
                                                              width: 60,
                                                              height: 60,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        )).toList(),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isFromMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!isRead) const Text('1', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                                Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton(
                              backgroundColor: Colors.blue,
                              onPressed: () => _showPersonalNoticeEditDialog(context, null, userId, '', '', isDarkMode),
                              child: const Icon(Icons.edit, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPersonalNoticeEditDialog(BuildContext context, String? noticeId, String userId, String initialTitle, String initialContent, bool isDarkMode, {List<String>? initialImageUrls}) {
    final titleCtrl = TextEditingController(text: initialTitle);
    final contentCtrl = TextEditingController(text: initialContent);
    List<String> existingImageUrls = initialImageUrls ?? [];
    List<XFile> newSelectedImages = [];
    final ImagePicker picker = ImagePicker();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stContext, setSt) {
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(noticeId == null ? '신규 쪽지 작성' : '쪽지 수정', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  if (noticeId != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('삭제 확인'),
                            content: const Text('이 쪽지를 삭제하시겠습니까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setSt(() => isLoading = true);
                          await FirebaseFirestore.instance.collection('personal_notices').doc(noticeId).delete();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: '제목 (선택)',
                          labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 5,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: '내용 입력',
                          hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('이미지 첨부'),
                        onPressed: () async {
                          final List<XFile> images = await picker.pickMultiImage();
                          if (images.isNotEmpty) {
                            setSt(() {
                              newSelectedImages.addAll(images);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      if (existingImageUrls.isNotEmpty || newSelectedImages.isNotEmpty)
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...existingImageUrls.map((url) => Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setSt(() {
                                          existingImageUrls.remove(url);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                              ...newSelectedImages.map((file) => Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(file.path, width: 70, height: 70, fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setSt(() {
                                          newSelectedImages.remove(file);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                            ],
                          ),
                        ),
                      if (isLoading) const Padding(padding: EdgeInsets.only(top: 16), child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (contentCtrl.text.trim().isEmpty && existingImageUrls.isEmpty && newSelectedImages.isEmpty) {
                      UiUtils.showPopup(context, '내용을 입력하거나 이미지를 첨부해주세요.');
                      return;
                    }
                    
                    setSt(() => isLoading = true);
                    
                    try {
                      List<String> finalImageUrls = List.from(existingImageUrls);
                      
                      for (var file in newSelectedImages) {
                        try {
                          final ref = FirebaseStorage.instance.ref().child('personal_notices/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
                          final bytes = await file.readAsBytes();
                          final task = await ref.putData(bytes);
                          final url = await task.ref.getDownloadURL();
                          finalImageUrls.add(url);
                        } catch (e) {
                          debugPrint('이미지 업로드 실패: $e');
                        }
                      }
                      
                      final data = {
                        'userId': userId,
                        'title': titleCtrl.text.trim(),
                        'content': contentCtrl.text.trim(),
                        'image_urls': finalImageUrls,
                        'isRead': false,
                        'isFromUser': false, // 관리자가 보낸 쪽지
                        'senderName': '관리자',
                      };

                      if (noticeId == null) {
                        data['createdAt'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('personal_notices').add(data);
                      } else {
                        data['updatedAt'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('personal_notices').doc(noticeId).update(data);
                      }
                      
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setSt(() => isLoading = false);
                      if (ctx.mounted) UiUtils.showPopup(context, '저장 중 오류가 발생했습니다.');
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
            Positioned(
              top: 10, right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
