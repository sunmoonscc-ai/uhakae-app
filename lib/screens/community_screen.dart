import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_abroad_app/widgets/admin_personal_notice_tab.dart';
import 'package:study_abroad_app/widgets/admin_notification_badge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:study_abroad_app/main.dart';
import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:study_abroad_app/services/preferences_service.dart';
import 'post_write_screen.dart';
import 'post_detail_screen.dart';
import '../utils/ui_utils.dart';
import '../services/firebase_storage_service.dart';

class CommunityScreen extends StatefulWidget {
  final bool showAppBar;
  final String region;
  const CommunityScreen({super.key, this.showAppBar = true, this.region = '전체'});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late String region;
  bool isLoading = false;
  bool _isNoticeDescending = true; // 개별공지(쪽지) 최신순/과거순 정렬 상태
  bool _isGeneralNoticeDescending = true; // 공지사항 정렬 상태
  bool _isCommunityDescending = true; // 자유게시판 정렬 상태
  late TabController _tabController;
  int _lastSelectedIndex = 0;
  
  late StreamSubscription<QuerySnapshot> _noticeSub;
  late StreamSubscription<QuerySnapshot> _communitySub;

  List<QueryDocumentSnapshot>? _noticeDocs;
  List<QueryDocumentSnapshot>? _communityDocs;

  Stream<QuerySnapshot>? _individualNoticeStream;
  bool _isLoadingIndividualNotice = true;

  @override
  void initState() {
    super.initState();
    region = widget.region ?? '전체';
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _lastSelectedIndex = _tabController.index;
      }
    });
    
    _noticeSub = FirebaseFirestore.instance.collection('posts').where('category', isEqualTo: 'notice').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _noticeDocs = snapshot.docs;
        });
      }
    });

    _communitySub = FirebaseFirestore.instance.collection('posts').where('category', isEqualTo: 'community').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _communityDocs = snapshot.docs;
        });
      }
    });

    _initIndividualNoticeStream();
  }

  @override
  void didUpdateWidget(CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.region != oldWidget.region) {
      setState(() {
        region = widget.region ?? '전체';
      });
    }
  }

  Future<void> _initIndividualNoticeStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (PreferencesService.isAdmin) {
        _individualNoticeStream = FirebaseFirestore.instance.collection('personal_notices').snapshots();
      } else {
        _individualNoticeStream = FirebaseFirestore.instance.collection('personal_notices').where('userId', isEqualTo: user.uid).snapshots();
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingIndividualNotice = false;
      });
    }
  }

  void _handleTabTap(int index) {
    if (_lastSelectedIndex == index) {
      setState(() {
        if (index == 0) _isGeneralNoticeDescending = !_isGeneralNoticeDescending;
        else if (index == 1) _isNoticeDescending = !_isNoticeDescending;
        else if (index == 2) _isCommunityDescending = !_isCommunityDescending;
      });
    } else {
      _lastSelectedIndex = index;
    }
  }

  @override
  void dispose() {
    _noticeSub.cancel();
    _communitySub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && [
      'cebufriends79@gmail.com',
      'slptas05@gmail.com',
      'sunmoon.scc@gmail.com',
      'hdcc6th@gmail.com',
      'uhakae2026@gmail.com',
    ].contains(user.email);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                    (route) => false,
                  );
                },
                child: Image.asset(
                  (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                  height: 28,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.forum, color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '커뮤니티',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: const [
          AdminNotificationBadge(),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _handleTabTap,
          labelColor: isDarkMode ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: isDarkMode ? Colors.white : Colors.black,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('공지사항'),
                  const SizedBox(width: 4),
                  Icon(_isGeneralNoticeDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('쪽지'),
                  const SizedBox(width: 4),
                  Icon(_isNoticeDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('자유 게시판'),
                  const SizedBox(width: 4),
                  Icon(_isCommunityDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                ],
              ),
            ),
          ],
        ),
      ) : PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: TabBar(
            controller: _tabController,
            onTap: _handleTabTap,
            labelColor: isDarkMode ? Colors.white : Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: isDarkMode ? Colors.white : Colors.black,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('공지사항'),
                    const SizedBox(width: 4),
                    Icon(_isGeneralNoticeDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('쪽지'),
                    const SizedBox(width: 4),
                    Icon(_isNoticeDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('자유 게시판'),
                    const SizedBox(width: 4),
                    Icon(_isCommunityDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostList(context, 'notice'),
            isAdmin ? AdminPersonalNoticeTab(region: region) : _buildPostList(context, 'individual_notice'),
            _buildPostList(context, 'community'),
          ],
        ),
        floatingActionButton: Builder(
          builder: (fabContext) => FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {
              final tabIndex = _tabController.index;
              final bool isIndividualNoticeTab = !isAdmin && tabIndex == 1;

              if (isIndividualNoticeTab) { // 개별공지
                if (user != null) {
                  _showUserNoticeDialog(fabContext);
                } else {
                  UiUtils.showPopup(fabContext, '로그인이 필요합니다.');
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PostWriteScreen()),
                );
              }
            },
            child: const Icon(Icons.edit, color: Colors.black),
          ),
        ),
      );
  }

  void _showUserNoticeDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isLoading = false;
    final ImagePicker picker = ImagePicker();
    List<XFile> selectedImages = [];
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stContext, setSt) {
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              title: Text('신규 쪽지', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: '제목',
                          labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 5,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: '내용',
                          hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () async {
                          if (selectedImages.length >= 5) {
                            UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있습니다.');
                            return;
                          }
                          final List<XFile> images = await picker.pickMultiImage();
                          if (images.isNotEmpty) {
                            setSt(() {
                              int remaining = 5 - selectedImages.length;
                              if (images.length > remaining) {
                                selectedImages.addAll(images.take(remaining));
                                UiUtils.showPopup(context, '사진은 최대 5개까지만 첨부할 수 있어 초과된 사진은 제외되었습니다.');
                              } else {
                                selectedImages.addAll(images);
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('사진 첨부 (최대 5장)'),
                      ),
                      if (selectedImages.isNotEmpty)
                        Container(
                          height: 100,
                          margin: const EdgeInsets.only(top: 8),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...selectedImages.asMap().entries.map((entry) {
                                int idx = entry.key;
                                XFile file = entry.value;
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8, top: 8),
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: FutureBuilder<Uint8List>(
                                          future: file.readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                            return const Center(child: CircularProgressIndicator());
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0, top: 0,
                                      child: InkWell(
                                        onTap: () {
                                          setSt(() => selectedImages.removeAt(idx));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      UiUtils.showPopup(context, '제목과 내용을 입력해주세요.');
                      return;
                    }
                    
                    setSt(() => isLoading = true);
                    
                    List<String> newUrls = [];
                    if (selectedImages.isNotEmpty) {
                      for (var file in selectedImages) {
                        final url = await FirebaseStorageService.uploadImage(file);
                        if (url != null) {
                          newUrls.add(url);
                        }
                      }
                    }
                    
                    final user = FirebaseAuth.instance.currentUser;
                    
                    // Firestore에서 사용자의 users 문서 ID를 가져옵니다.
                    String? userDocId;
                    try {
                      final snap = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user!.email).limit(1).get();
                      if (snap.docs.isNotEmpty) {
                        userDocId = snap.docs.first.id;
                      }
                    } catch (e) {
                      debugPrint('Error fetching user doc: $e');
                    }
                    
                    if (userDocId == null) {
                      if (context.mounted) UiUtils.showPopup(context, '회원 정보를 확인할 수 없습니다.');
                      setSt(() => isLoading = false);
                      return;
                    }

                    final data = {
                      'userId': userDocId,
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'image_urls': newUrls,
                      'createdAt': FieldValue.serverTimestamp(),
                      'isRead': false, // 관리자가 읽어야 하므로 false로 변경! (중요)
                      'isFromUser': true, // 사용자가 관리자에게 보낸 것임을 표시
                      'senderName': user?.displayName ?? '사용자',
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    
                    await FirebaseFirestore.instance.collection('personal_notices').add(data);
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      UiUtils.showPopup(context, '관리자에게 쪽지가 전송되었습니다.');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('저장', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildPostList(BuildContext context, String category) {
    if (category == 'individual_notice') {
      if (_isLoadingIndividualNotice || _individualNoticeStream == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<QuerySnapshot>(
        stream: _individualNoticeStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return _buildListFromDocs(context, snapshot.data?.docs ?? [], category);
        },
      );
    }
    List<QueryDocumentSnapshot>? targetDocs;
    if (category == 'notice') targetDocs = _noticeDocs;
    else targetDocs = _communityDocs;

    if (targetDocs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildListFromDocs(context, targetDocs, category);
  }

  Widget _buildListFromDocs(BuildContext context, List<QueryDocumentSnapshot> originalDocs, String category) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && [
      'cebufriends79@gmail.com',
      'slptas05@gmail.com',
      'sunmoon.scc@gmail.com',
      'hdcc6th@gmail.com',
      'uhakae2026@gmail.com',
    ].contains(user.email);

    var docs = List<QueryDocumentSnapshot>.from(originalDocs);
    
    // 지역 필터링 (클라이언트 단 처리 - 인덱스 오류 방지)
    if (region != '전체') {
      docs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // 기존 데이터에 region 필드가 없으면 '세부'로 간주
        final docRegion = data['region'] as String? ?? '세부';
        return docRegion == region;
      }).toList();
    }
    
    var modifiableDocs = List<QueryDocumentSnapshot>.from(docs);
    modifiableDocs.sort((a, b) {
      final aMap = a.data() as Map<String, dynamic>;
      final bMap = b.data() as Map<String, dynamic>;
      final aTime = aMap['created_at'] as Timestamp? ?? aMap['createdAt'] as Timestamp?;
      final bTime = bMap['created_at'] as Timestamp? ?? bMap['createdAt'] as Timestamp?;
      
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1; // 방금 작성한 글(null)은 최상단
      if (bTime == null) return 1;
      final int result = bTime.compareTo(aTime); // 기본: 내림차순 (최신순)
      // 각 탭의 정렬 상태 적용
      if (category == 'individual_notice' && !_isNoticeDescending) {
        return -result; // 오름차순 (과거순)
      } else if (category == 'notice' && !_isGeneralNoticeDescending) {
        return -result;
      } else if (category == 'community' && !_isCommunityDescending) {
        return -result;
      }
      return result;
    });

        if (modifiableDocs.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
              ),
              child: Text(
                category == 'notice' ? '등록된 공지사항이 없습니다.' : '등록된 게시글이 없습니다.\n(오프라인 상태일 수 있습니다)',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: modifiableDocs.length,
          itemBuilder: (context, index) {
            final doc = modifiableDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            if (category != 'individual_notice') {
              data['id'] = doc.id;
            } else {
              data['category'] = 'individual_notice';
            }
            final title = data['title'] ?? '제목 없음';
            final content = data['content'] ?? '';
            final imageUrls = List<String>.from(data['image_urls'] ?? []);
            
            String authorName = '익명';
            bool isAdminPost = false;
            
            if (category == 'individual_notice') {
              final isFromUser = data['isFromUser'] == true;
              authorName = isFromUser ? (data['senderName'] ?? '나') : '관리자';
              isAdminPost = !isFromUser;
            } else {
              authorName = data['author_name'] ?? '익명';
              isAdminPost = data['is_admin'] == true;
            }
            
            final displayAuthorName = isAdminPost ? '관리자' : authorName;
            
            // 날짜 포맷팅 (임시 로직)
            String timeAgo = '조금 전';
            final Timestamp? ts = data['created_at'] as Timestamp? ?? data['createdAt'] as Timestamp?;
            if (ts != null) {
              final DateTime dt = ts.toDate();
              timeAgo = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            }

            if (category == 'individual_notice') {
              final bool isFromMe = data['isFromUser'] == true;
              final bool isRead = data['isRead'] == true;
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: PostDetailScreen(postData: data),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: !isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isFromMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: Icon(Icons.person, size: 20, color: isDarkMode ? Colors.grey : Colors.black54),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isFromMe 
                                ? (isDarkMode ? Colors.grey[800] : Colors.white)
                                : (isDarkMode ? Colors.blue[900] : Colors.blue[100]),
                            border: isFromMe ? Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300) : null,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isFromMe ? const Radius.circular(4) : const Radius.circular(16),
                              bottomRight: isFromMe ? const Radius.circular(16) : const Radius.circular(4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                content, 
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
                              ),
                              if (imageUrls.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
                                    const SizedBox(width: 4),
                                    Text('사진 첨부됨', style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.black54)),
                                  ],
                                ),
                              ],
                            ],
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
                ),
              );
            }

            bool isNoticeUnread = false;
            if (category == 'notice' && !isAdmin) {
              isNoticeUnread = !PreferencesService.readNotices.contains(data['id']);
            }

            FontWeight fontWeight = FontWeight.bold;
            Color titleColor = isDarkMode ? Colors.white : Colors.black;

            if (category == 'notice' && !isAdmin) {
              if (isNoticeUnread) {
                fontWeight = FontWeight.bold;
                titleColor = isDarkMode ? Colors.white : Colors.black;
              } else {
                fontWeight = FontWeight.normal;
                titleColor = Colors.grey;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: PostDetailScreen(postData: data),
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: titleColor, fontSize: 14, fontWeight: fontWeight)
                      ),
                    ),
                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.image, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
                    ],
                  ],
                ),
                subtitle: Text(
                  '$displayAuthorName | $timeAgo',
                  style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12)
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category == 'notice' || category == 'individual_notice') ...[
                      Chip(
                        label: Text('공지', style: TextStyle(color: isDarkMode ? Colors.black : Colors.white, fontSize: 10)),
                        backgroundColor: isDarkMode ? Colors.white : Colors.black,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (isAdmin && category != 'individual_notice') ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('삭제 확인'),
                              content: const Text('이 게시물을 정말 삭제하시겠습니까?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
                            if (context.mounted) UiUtils.showPopup(context, '삭제되었습니다.');
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
  }
}
